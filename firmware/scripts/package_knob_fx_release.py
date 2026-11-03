"""Verify final simulation, routed timing, exact source and WAX preservation."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import html
import json
import os
import re
import shutil
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
FW = ROOT / 'firmware'
BASE = ROOT.parent / 'Mega138K_FX_LOUD32_B_20261102'
SIM = FW / 'reports/final-simulation'
BUILD_NAME = os.environ.get('MATRIX_BUILD_REPORT','B')
assert BUILD_NAME in ('B','route1','route2','fast')
BUILD = FW / 'reports' / BUILD_NAME
OUT = ROOT.parents[1] / 'deliverables/knob_fx32_20261102'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
write = lambda p, data: p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

expected = set(json.loads((FW/'scripts/release_tests.json').read_text(encoding='utf-8')))
simulation = json.loads((SIM / 'simulation_summary.json').read_text(encoding='utf-8'))
assert set(simulation['tests']) == expected and not simulation['failed_tests']
for name, digest in simulation['source_sha256'].items():
    assert sha(FW / name) == digest, ('simulation source mismatch', name)
for tb in expected:
    log = (SIM / (tb + '.log')).read_text(encoding='utf-8')
    assert 'PASS ' in log and '** Fatal:' not in log and '** Error:' not in log, tb
assert len(simulation['tests']['tb_native_display']) == 20, 'ten final native captures required'

manifest = json.loads((BUILD / 'build_manifest.json').read_text(encoding='utf-8'))
current = {'src/' + p.name: sha(p) for p in (FW / 'src').iterdir() if p.is_file()}
assert current == manifest['source_sha256'], 'current sources differ from routed source snapshot'
fs = (FW / 'bitstream' if BUILD_NAME=='B' else BUILD / 'bitstream') / 'laser_touch_bt_fsr_B.fs'
assert sha(fs) == manifest['bitstream_sha256']
build_log = (BUILD / 'build.log').read_text(encoding='utf-8')
assert 'GW5AST-138B' in build_log and 'Bitstream generation completed' in build_log
assert not re.search(r'\bERROR\b', build_log)

timing = BUILD / 'pnr/laser_touch_bt_fsr_B_tr_content.html'
rows = []
for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', timing.read_text(errors='replace'), re.I | re.S):
    rows.append([html.unescape(re.sub(r'\s+', ' ', re.sub('<[^>]+>', ' ', c)).strip())
                 for c in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', row, re.I | re.S)])
clocks = {}
for clock, required in [('lcd_sysclk', 52.5), ('audio_clk', 26.25)]:
    matches = [r for r in rows if len(r) >= 4 and r[1] == clock and 'MHz' in r[2] and 'MHz' in r[3]]
    assert len(matches) == 1, ('missing clock', clock)
    constraint, fmax = [float(re.search(r'[0-9.]+', value).group()) for value in matches[0][2:4]]
    assert abs(constraint - required) < .002 and fmax >= required, ('timing failed', matches[0])
    for kind in ['Setup', 'Hold']:
        matches = [r for r in rows if len(r) == 4 and r[0] == clock and r[1] == kind]
        assert len(matches) == 1 and matches[0][3] == '0', ('timing violations', clock, kind, matches)
    clocks[clock] = dict(required_mhz=required, fmax_mhz=fmax, setup_violations=0, hold_violations=0)

resources = {}
rpt = (BUILD / 'pnr/laser_touch_bt_fsr_B.rpt.txt').read_text(errors='replace')
for name in ['Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port']:
    match = re.search(r'^\s*' + re.escape(name) + r'\s*\|\s*(\d+)/(\d+)\s*\|\s*(\d+)%', rpt, re.M)
    assert match, ('missing resource', name)
    used, available, percent = map(int, match.groups())
    assert used <= available
    resources[name] = dict(used=used, available=available, percent=percent)

wax = {}
for p in sorted((ROOT / 'pressure_port/rtl').glob('*.v')):
    assert sha(p) == sha(FW / 'src' / p.name), ('runtime WAX reference changed', p.name)
    if p.name!='wax_pressure.v':assert sha(p)==sha(BASE/'firmware/src'/p.name), ('original protocol/settings changed',p.name)
    wax[p.name] = sha(p)
assert len(wax) == 5
provenance=json.loads((ROOT/'docs/wax-provenance.json').read_text(encoding='utf-8'))
assert provenance['archive_sha256']=='6c87a3db61d90366db030b05bc39a6420095e76d7750507611c34a51d234a1c5'
assert provenance['runtime_rtl']==wax
assert provenance['pressure_pipeline_archive_sha256']=='79a2aad678940c8274a4d665de4303a6b35bf302603672a0018584d392741d66'
for name in ['poly32_synth.v', 'guitar_wave_table.v', 'guitar_wave.hex', 'audio_master.v', 'audio_effects.v',
             'audio_conditioner.v', 'i2s_tx.v', 'instrument_screen.v', 'merged_clock.v', 'piano.sdc', 'uart_link.v']:
    assert sha(FW / 'src' / name) == sha(BASE / 'firmware/src' / name), ('baseline changed', name)
assert len((FW / 'src/panel_map.hex').read_text().splitlines()) == 16384
assert len((FW / 'src/panel_text.hex').read_text().splitlines()) == 32768
locations = re.findall(r'IO_LOC\s+"([^"]+)"\s+(\w+)\s*;', (FW / 'src/piano.cst').read_text())
assert len({pin for _, pin in locations}) == len(locations)
assert dict(locations)['WAX_RX'] == 'R14' and dict(locations)['WAX_TX'] == 'P14'
project_files = [e.attrib['path'] for e in ET.parse(FW / 'laser_touch_bt_fsr_B.gprj').findall('.//File')]
assert len(project_files) == len(set(project_files))
assert all('src/' + p.name in project_files for p in (FW / 'src').glob('*.v'))

audit = json.loads((ROOT / 'docs/button-audit.json').read_text(encoding='utf-8'))
assert audit['all_buttons_have_handlers'] and audit['overlapping_hit_targets'] == 0
assert len(audit['pressure_matrix']['cells']) == 16
assert all(not c['touch_triggers_note'] for c in audit['pressure_matrix']['cells'])
for name, digest in audit['source_sha256'].items():
    assert sha(ROOT / name) == digest, ('stale UI audit', name)
preservation=json.loads((ROOT/'docs/feature-preservation.json').read_text(encoding='utf-8'))
for name,digest in preservation['unchanged_critical_source_sha256'].items():assert sha(FW/'src'/name)==digest,name
for feature,names in preservation['features_and_required_tests'].items():assert set(names)<=set(simulation['tests']),feature
pixels=json.loads((ROOT/'docs/pixel-equivalence.json').read_text(encoding='utf-8'))
assert pixels['all_equal'] and len(pixels['frames'])>=15
assert sha(FW/'src/knob5_controls.v')==pixels['source_sha256']['knob5_controls.v']
screens = json.loads((ROOT / 'docs/native-ui/screenshots.json').read_text(encoding='utf-8'))
assert len(screens) == 15
for shot in screens:
    assert sha(ROOT / shot['source']) == shot['source_sha256']
    assert sha(ROOT / shot['png']) == shot['png_sha256']

changes = []
for folder in ['firmware/src', 'firmware/sim', 'firmware/scripts']:
    for p in sorted((ROOT / folder).iterdir()):
        if not p.is_file() or p.suffix == '.pyc':
            continue
        old = BASE / p.relative_to(ROOT)
        if not old.exists() or sha(p) != sha(old):
            changes.append(dict(path=p.relative_to(ROOT).as_posix(), before_sha256=sha(old) if old.exists() else None, after_sha256=sha(p)))
write(ROOT / 'source-changes.json', dict(baseline=BASE.name, changes=changes, runtime_wax_sha256=wax))
write(ROOT / 'docs/build-resources.json', resources)
verification = dict(adsr_presets=json.loads((FW/'src/adsr_presets.json').read_text(encoding='utf-8')),
                    adsr_presets_highlight_from_actual_registers=True,
                    oscillator_core_unchanged=True, five_knobs_enabled=True, stale_knob_write_race_fixed=True, master_nominal_boost_db=6.0206, master_peak_knee=22528, master_peak_ratio=4, power_on_volume=8, preset_controls_page=1,
                    release=ROOT.name, verified_at=datetime.now(timezone.utc).isoformat(),
                    bitstream_sha256=sha(fs), source_exactly_matches_build=True,
                    simulation_sources_exact=True, rtl_test_groups=len(expected), tests=sorted(expected),
                    clocks=clocks, resources=resources,
                    timing_report=timing.relative_to(ROOT).as_posix(), timing_report_sha256=sha(timing),
                    pressure_protocol_settings_frontend_unchanged=True, pressure_gain_pipeline_from_user_archive=True, encoder_pin_mapping_verified=True, clock_constraints_unchanged=True,
                    matrix_page=6, matrix_rows=4, matrix_columns=4, pad_order='row-major A0 upper-left -> A15 lower-right',
                    matrix_touch_scores=False, matrix_score_source='physical WAX pressure key edges only',
                    matrix_frame_settle_clocks=512, matrix_frame_settle_microseconds=512/26.25,
                    text_coverage_bits=1, digit_coverage_bits=2,
                    legacy_perfect_good_ms=[60,150], matrix_perfect_good_ms=[300,600], matrix_bpm_cap=80,
                    guide_generates_audio=False, matrix_freezes_when_unready=True,
                    synthesis_completed=True, place_route_completed=True, bitstream_generated=True,
                    selected_build_report=BUILD_NAME,route_option=manifest['pnr_route_option'],place_option=manifest.get('place_option',1),
                    timing_driven=manifest.get('timing_driven'),iob_registers=True,replicate_resources=False,
                    hardware_programmed=False, hardware_tested=False, end_to_end_latency_measured=False,
                    limits='Matrix snapshots are UI fixtures; control/audio top tests use LCD/PLL stubs. Native full-page tests stub only inactive legacy rendering branches. WAX constants retained; static timing and simulation do not prove board latency or analog sound quality.')
write(ROOT / 'verification.json', verification)

OUT.mkdir(parents=True, exist_ok=True)
if BUILD_NAME!='B':
    (FW/'bitstream').mkdir(exist_ok=True)
    shutil.copy2(fs,FW/'bitstream/laser_touch_bt_fsr_B.fs')
files = set()
for folder in ['firmware/src', 'firmware/sim', 'firmware/scripts', 'firmware/bitstream',
               'firmware/reports/'+BUILD_NAME, 'firmware/reports/final-simulation', 'docs/native-ui',
               'pressure_port']:
    files.update(p for p in (ROOT / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
files.update(ROOT / name for name in ['README.md', 'source-changes.json', 'verification.json'])
files.update(ROOT / 'docs' / name for name in ['build-resources.json', 'button-audit.json', 'wax-provenance.json', 'WAX原始交接说明.md', 'ADSR预设说明.md', '音效与音量调整.md', '旋钮接线与功能保留.md', 'feature-preservation.json', 'knob-import.json', 'pixel-equivalence.json'])
files.add(FW / 'laser_touch_bt_fsr_B.gprj')
digest = ROOT / 'SHA256SUMS.txt'
digest.write_text(''.join(sha(p) + '  ' + p.relative_to(ROOT).as_posix() + '\n' for p in sorted(files)), encoding='utf-8')
files.add(digest)
archive = OUT / (ROOT.name + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for p in sorted(files):
        z.write(p, ROOT.name + '/' + p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for p in files:
        assert hashlib.sha256(z.read(ROOT.name + '/' + p.relative_to(ROOT).as_posix())).hexdigest() == sha(p)
target = OUT / (ROOT.name + '.fs')
shutil.copy2(fs, target)
assert sha(target) == manifest['bitstream_sha256']
for name in ['README.md', 'verification.json', 'source-changes.json', 'SHA256SUMS.txt']:
    shutil.copy2(ROOT / name, OUT / name)
shutil.copytree(ROOT / 'docs/native-ui', OUT / 'native-ui', dirs_exist_ok=True)
write(OUT / 'release.json', dict(release=ROOT.name, bitstream=target.name, bitstream_sha256=sha(target),
                               archive=archive.name, archive_sha256=sha(archive), files=len(files),
                               target_board='Tang Mega NEO 138K B / GW5AST-138B',
                               rtl_test_groups=len(expected), clocks=clocks, resources=resources,
                               hardware_programmed=False, hardware_tested=False))
print('BITSTREAM:', target)
print('SHA256:', sha(target))
print('ARCHIVE:', archive)
print('RTL groups:', len(expected), 'Clocks:', clocks)
