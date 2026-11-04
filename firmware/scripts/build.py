"""Reproducible Gowin build; an unused SUBST drive avoids non-ASCII EDA paths."""
import argparse, hashlib, json, os, pathlib, shutil, stat, subprocess, sys, re

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--revision', choices=['B'], default='B')
parser.add_argument('--pnr-only', action='store_true', help='Reuse cached synthesis only when all synthesis inputs are byte-identical')
parser.add_argument('--work-name',default='build',help='Isolated ASCII build directory prefix')
parser.add_argument('--report-name',default='B',help='Isolated ASCII report directory name')
parser.add_argument('--route-option',type=int,choices=[0,1,2],default=2)
parser.add_argument('--place-option',type=int,choices=[0,1,2,3,4],default=1)
parser.add_argument('--timing-driven',type=int,choices=[0,1],default=1)
parser.add_argument('--collect-only', action='store_true', help='Export a completed local build only after verifying its staged sources')
parser.add_argument('--eda', default=shutil.which('gw_sh.exe') or shutil.which('gw_sh') or '')
args = parser.parse_args()
if not args.collect_only and not pathlib.Path(args.eda).is_file():
    sys.exit('gw_sh.exe not found. Supply --eda with its installed path.')
if not all(re.fullmatch(r'[A-Za-z0-9_-]+',n) for n in (args.work_name,args.report_name)):sys.exit('Invalid build/report name')
stage = ROOT / 'work' / (args.work_name+'_' + args.revision)
reports = ROOT / 'reports' / args.report_name
stage.mkdir(parents=True, exist_ok=True)
if args.collect_only:
    current={p.name:p.read_bytes() for p in (ROOT/'src').iterdir() if p.is_file()}
    staged={p.name:p.read_bytes() for p in (stage/'src').iterdir() if p.is_file()}
    if current!=staged: sys.exit('Completed build sources differ from delivered sources')
    source=stage/'bitstream'/('multimodal_instrument_'+args.revision+'.fs')
    if not source.is_file(): sys.exit('No completed bitstream to collect')
    if 'Bitstream generation completed' not in (reports/'build.log').read_text(encoding='utf-8'):
        sys.exit('Completed Gowin bitstream generation not recorded')
    target=(ROOT/'bitstream' if args.report_name=='B' else reports/'bitstream')/source.name
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists():target.chmod(stat.S_IWRITE|stat.S_IREAD)
    shutil.copy2(source,target)
    manifest={'revision':args.revision,'pnr_route_option':args.route_option,'bitstream_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
              'source_sha256':{'src/'+name:hashlib.sha256(content).hexdigest() for name,content in sorted(current.items())}}
    (reports/'build_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('COLLECTED:',target)
    sys.exit(0)
if args.pnr_only:
    cache=stage/'impl/gwsynthesis/multimodal_instrument_B.vg'
    if not cache.is_file():sys.exit('No cached synthesis netlist')
    for source in (ROOT/'src').iterdir():
        if not source.is_file() or source.suffix=='.sdc':continue
        staged=stage/'src'/source.name
        if not staged.is_file() or source.read_bytes()!=staged.read_bytes() or staged.stat().st_mtime>cache.stat().st_mtime:
            sys.exit('Cached synthesis does not match '+source.name)
for folder in ['src', 'scripts']:
    # Remove stale direct source files only inside this script's own build stage.
    for old in (stage / folder).glob('*'):
        if old.is_file() and not (ROOT / folder / old.name).exists():
            old.unlink()
    shutil.copytree(ROOT / folder, stage / folder, dirs_exist_ok=True)
(stage / 'bitstream').mkdir(exist_ok=True)
drive=None
for letter in 'ZYXWVUTSRQPONMLKJIH':
    candidate=letter+':'
    if pathlib.Path(candidate+'/').exists():continue
    claim=subprocess.run(['subst',candidate,str(stage)],capture_output=True)
    if claim.returncode==0:
        drive=candidate
        break
if not drive:
    sys.exit('No unused drive letter for temporary build mapping.')
env = dict(os.environ, HARP_REVISION=args.revision,HARP_PNR_ONLY='1' if args.pnr_only else '0',HARP_ROUTE_OPTION=str(args.route_option),HARP_PLACE_OPTION=str(args.place_option),HARP_TIMING_DRIVEN=str(args.timing_driven))
reports.mkdir(parents=True, exist_ok=True)
try:
    with (reports / 'build.log').open('w', encoding='utf-8') as log:
        proc = subprocess.Popen([args.eda, 'scripts/build.tcl'], cwd=drive + '/', env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in iter(proc.stdout.readline, b''):
            text = line.decode('utf-8', errors='replace')
            log.write(text)
            print(text, end='', flush=True)
        code = proc.wait()
    for p in (stage / 'impl').rglob('*'):
        if p.is_file() and p.suffix.lower() in ['.html','.rpt','.txt','.xml','.csv','.css']:
            dest = reports / p.relative_to(stage / 'impl')
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists(): dest.chmod(stat.S_IWRITE | stat.S_IREAD)
            shutil.copy2(p, dest)
    source = stage / 'bitstream' / ('multimodal_instrument_' + args.revision + '.fs')
    if code or not source.exists():
        sys.exit('Build failed (tool exit '+str(code)+'). Inspect '+str(reports/'build.log'))
    target = (ROOT/'bitstream' if args.report_name=='B' else reports/'bitstream') / source.name
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists(): target.chmod(stat.S_IWRITE | stat.S_IREAD)
    shutil.copy2(source, target)
    manifest = {'revision': args.revision,'pnr_route_option':args.route_option,'place_option':args.place_option,'timing_driven':args.timing_driven,
                'bitstream_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                'source_sha256': {str(p.relative_to(stage)).replace('\\','/'):
                    hashlib.sha256(p.read_bytes()).hexdigest()
                    for folder in ['src'] for p in (stage/folder).glob('*') if p.is_file()}}
    (reports/'build_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('BITSTREAM:', target)
finally:
    subprocess.run(['subst', drive, '/D'], check=True)
