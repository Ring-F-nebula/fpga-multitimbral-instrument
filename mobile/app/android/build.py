"""Build the offline Android APK with the official SDK tools, no Gradle needed."""
from pathlib import Path
import os, subprocess, zipfile, shutil, json, hashlib, tempfile, sys
sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).resolve().parent
WORKSPACE=ROOT.parents[1]
SDK=Path(os.environ.get('PIANO_ANDROID_TOOLS',str(next((p/'tmp/android-tools' for p in ROOT.parents if (p/'tmp/android-tools/android-15/aapt2.exe').exists()),WORKSPACE/'tmp/android-tools'))))
JDK=Path(os.environ.get('PIANO_JDK',os.environ.get('JAVA_HOME','')))
if not (JDK/'bin/javac.exe').is_file():raise SystemExit('Set PIANO_JDK to a JDK directory')
BUILD=Path(tempfile.mkdtemp(prefix='touch_piano_apk_'))
TOOLS=SDK/'android-15';ANDROID=BUILD/'android.jar'
shutil.copy2(SDK/'android-35-ext15/android.jar',ANDROID)
shutil.copy2(ROOT/'AndroidManifest.xml',BUILD/'AndroidManifest.xml')
OUT=WORKSPACE/'build/android';OUT.mkdir(parents=True,exist_ok=True)
def run(args):
    p=subprocess.run([str(x) for x in args],capture_output=True)
    for data in [p.stdout,p.stderr]:
        try:message=data.decode('utf-8')
        except UnicodeDecodeError:message=data.decode('gb18030',errors='replace')
        print(message,flush=True)
    if p.returncode:raise SystemExit(f'FAILED: {args[0]} ({p.returncode})')
run([TOOLS/'aapt2.exe','link','-I',ANDROID,'--manifest',BUILD/'AndroidManifest.xml','-o',BUILD/'base.apk'])
classes=BUILD/'classes';classes.mkdir(exist_ok=True)
run([JDK/'bin/javac.exe','-encoding','UTF-8','-source','8','-target','8','-bootclasspath',str(ANDROID)+os.pathsep+str(TOOLS/'core-lambda-stubs.jar'),'-d',classes,*ROOT.glob('src/**/*.java')])
with zipfile.ZipFile(BUILD/'classes.jar','w') as z:
    for p in classes.rglob('*.class'):z.write(p,p.relative_to(classes).as_posix())
run([JDK/'bin/java.exe','-cp',TOOLS/'lib/d8.jar','com.android.tools.r8.D8','--min-api','26','--lib',ANDROID,'--output',BUILD,BUILD/'classes.jar'])
shutil.copy2(BUILD/'base.apk',BUILD/'unsigned.apk')
with zipfile.ZipFile(BUILD/'unsigned.apk','a',compression=zipfile.ZIP_DEFLATED) as z:
    z.write(BUILD/'classes.dex','classes.dex')
    for p in (WORKSPACE/'app/public').rglob('*'):
        if p.is_file():z.write(p,'assets/public/'+p.relative_to(WORKSPACE/'app/public').as_posix())
run([TOOLS/'zipalign.exe','-f','4',BUILD/'unsigned.apk',BUILD/'aligned.apk'])
# Signing material stays outside the source repository.
key=Path(os.environ.get('PIANO_SIGNING_KEY',''))
assert key.is_file(),'Set PIANO_SIGNING_KEY to your signing keystore'
os.environ.setdefault('PIANO_SIGNING_STORE_PASS','android')
apk=BUILD/'TouchPiano-0.4.3.apk'
run([JDK/'bin/java.exe','-jar',TOOLS/'lib/apksigner.jar','sign','--ks',key,'--ks-pass','env:PIANO_SIGNING_STORE_PASS','--ks-key-alias','piano','--out',apk,BUILD/'aligned.apk'])
run([JDK/'bin/java.exe','-jar',TOOLS/'lib/apksigner.jar','verify','--verbose',apk])
shutil.copy2(apk,OUT/apk.name)
(OUT/'apk-build-0.4.3.json').write_text(json.dumps({'apk':apk.name,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'hardware_tested':False,'min_android':8,'target_sdk':35,'source_sha256':{str(p.relative_to(WORKSPACE)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for folder in [ROOT/'src',WORKSPACE/'app/public'] for p in folder.rglob('*') if p.is_file()}},indent=2),encoding='utf-8')
print('APK:',apk)
