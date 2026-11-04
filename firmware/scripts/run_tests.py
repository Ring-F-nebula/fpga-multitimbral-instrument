"""Run independent PCM scoreboard, serial DAC, controls, and complete score tests."""
from pathlib import Path
import os, shutil, subprocess, sys, json, tempfile, hashlib
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor,as_completed
ROOT=Path(__file__).resolve().parents[1]
REPORTS=Path(os.environ.get("SIM_REPORT_DIR",str(ROOT/"reports/release-simulation")))
REPORTS.mkdir(parents=True,exist_ok=True)
(ROOT/"work").mkdir(exist_ok=True)
SIM=Path(tempfile.mkdtemp(prefix="simulation_",dir=ROOT/"work"))
drive=None
for letter in os.environ.get("SIM_DRIVE","YXWVUTSRQPONMLKJIH"):
    candidate=letter+":"
    if not Path(candidate+"/").exists():
        claim=subprocess.run(["subst",candidate,str(SIM.resolve())],capture_output=True)
        if claim.returncode==0:
            drive=candidate
            break
if drive is None: raise SystemExit("No unused SUBST drive available")
import atexit
atexit.register(lambda:subprocess.run(["subst",drive,"/D"]))
SIM=Path(drive+"/")
sources={}
for folder in ("src","sim"):
    (SIM/folder).mkdir()
    for p in sorted((ROOT/folder).iterdir()):
        if p.is_file() and p.suffix in (".v",".sv",".vh",".mem",".hex"):
            shutil.copy2(p,SIM/folder/p.name)
            sources[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
vsim=shutil.which("vsim")
if not vsim:
    vsim="vsim.exe"
BIN=Path(os.environ.get("MODELSIM_BIN") or str(Path(vsim).parent))
if not (BIN/"vsim.exe").exists(): raise SystemExit("Set MODELSIM_BIN to the folder containing vsim.exe")
SIM_OPTIONS=["-voptargs=+acc"] if os.environ.get("SIM_DEBUG_ACCESS")=="1" else []
SIM_TIMEOUT=int(os.environ.get("SIM_TIMEOUT","1800"))
def run(name,args):
    p=subprocess.run([str(BIN/name),*map(str,args)],cwd=SIM,capture_output=True,text=True,errors="replace",timeout=SIM_TIMEOUT)
    if p.returncode or "** Error:" in p.stdout or "** Fatal:" in p.stdout:
        print('TOOL EXIT',name,p.returncode,p.stdout,p.stderr); raise SystemExit(f"FAILED: {name} {args}")
    return p.stdout+p.stderr
run("vlib.exe",["work"])
vendor=Path(os.environ.get("GOWIN_PRIMITIVES",""))
if not vendor.exists(): raise SystemExit("Set GOWIN_PRIMITIVES to Gowin GW5A prim_sim.v")
run("vlog.exe",[vendor])
compile_inputs=[*sorted((SIM/'src').glob('*.v')),*sorted((SIM/'sim').glob('*.sv'))]
compile_log=''
for offset in range(0,len(compile_inputs),20):
    compile_log+=run('vlog.exe',['-sv','+incdir+src',*compile_inputs[offset:offset+20]])
(REPORTS/"compile.log").write_text(compile_log,encoding="utf-8")
results={}
requested=set(sys.argv[1:])
selected=requested or set(json.loads(Path(__file__).with_name('release_tests.json').read_text()))
available={p.stem for p in (ROOT/'sim').glob('tb_*.sv')}
if selected-available:raise SystemExit('Unknown test names: '+', '.join(sorted(selected-available)))
def run_test(path):
    tb=path.stem
    sim_top="cfg_"+tb if os.environ.get("SIM_LCD_STUB")=="1" and tb in {"tb_laser_spi_main","tb_knob5_top","tb_pressure_matrix_top","tb_wax_top_merge","tb_guitar_control","tb_report_latency","tb_competition_top","tb_ui_actions","tb_volume_path","tb_practice_exit","tb_touch_spectrum_top","tb_integration","tb_touch_top","tb_laser_merge","tb_touch_bluetooth_merge","tb_fsr_top","tb_fsr_guard_top","tb_bt_audio","tb_game_bluetooth","tb_game_top","tb_fsr_latency","tb_panel_regression","tb_fsr_response","tb_fx_stop_top","tb_native_top"} else tb
    if tb=="tb_native_display":
        sim_top="cfg_tb_native_display"
        def capture(view):
            return run("vsim.exe",["-c",*SIM_OPTIONS,"-l",f"native_{view}.log","-wlf",f"native_{view}.wlf",sim_top,f"+CAPTURE={view}","-do","onerror {quit -code 1}; run -all; quit -f"])
        captures=[int(v) for v in os.environ.get('NATIVE_CAPTURES','0,1,2,3,4,5,6,7').split(',')]
        with ThreadPoolExecutor(max_workers=3) as pool:out='\n'.join(pool.map(capture,captures))
    else:
        out=run("vsim.exe",["-c",*SIM_OPTIONS,"-l",tb+'.transcript.log',"-wlf",tb+'.wlf',sim_top,"-do","onerror {quit -code 1}; run -all; quit -f"])
    (REPORTS/f"{tb}.log").write_text(out,encoding="utf-8")
    passed=[line for line in out.splitlines() if "PASS " in line]
    if not passed: print(out); raise SystemExit(f"No PASS from {tb}")
    return tb,passed
failures=[]
paths=[p for p in sorted((ROOT/'sim').glob('tb_*.sv')) if not selected or p.stem in selected]
with ThreadPoolExecutor(max_workers=int(os.environ.get('SIM_JOBS','1'))) as pool:
    futures={pool.submit(run_test,p):p.stem for p in paths}
    for future in as_completed(futures):
        try:
            tb,passed=future.result();results[tb]=passed;print(*passed,sep='\n',flush=True)
        except BaseException as error:
            failures.append(futures[future]);print('FAILED GROUP',futures[future],str(error),flush=True)
for pattern in ['*.raw','screen_*.ppm','*.csv']:
    for artifact in SIM.glob(pattern):shutil.copy2(artifact,REPORTS/artifact.name)
report=dict(tested_at=datetime.now(timezone.utc).isoformat(),source_sha256=sources,
    simulator=str(BIN),simulator_options=SIM_OPTIONS,integration_display_stub=os.environ.get("SIM_LCD_STUB")=="1",snapshot=str(SIM),tests=results,failed_tests=failures,hardware_tested=False)
(REPORTS/"simulation_summary.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("Simulation logs:",REPORTS)
if failures:raise SystemExit('Failed test groups: '+', '.join(failures))
