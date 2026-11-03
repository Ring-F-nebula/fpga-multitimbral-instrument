"""Verify complete production RGB frames against the prior FX/ADSR project."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
REFERENCE=ROOT.parent/'Mega138K_FX_LOUD32_B_20261102'
CURRENT=ROOT/'firmware/reports/final-simulation'
BEFORE=REFERENCE/'firmware/reports/final-simulation'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
frames=[]
for source in sorted(BEFORE.glob('screen_*.ppm')):
    target=CURRENT/source.name
    assert target.is_file(),('missing current capture',source.name)
    assert source.read_bytes()==target.read_bytes(),('pixel mismatch',source.name)
    frames.append(dict(name=source.name,before_sha256=sha(source),after_sha256=sha(target)))
assert len(frames)>=19, 'all fixture and PCM-driven complete frames required'
files=['knob5_controls.v','panel_renderer.v','instrument_paint.vh','pressure_matrix_paint.vh',
       'surface_compare_stage.vh','panel_rom.v','panel_map.hex','panel_text.hex']
report=dict(reference=REFERENCE.name,method='complete RTL RGB frame files compared byte-for-byte',
            all_equal=True,frames=frames,
            source_sha256={name:sha(ROOT/'firmware/src'/name) for name in files},
            hardware_photos=False)
(ROOT/'docs/pixel-equivalence.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PIXEL EQUIVALENCE:',len(frames),'complete frames identical')
