"""Combine disjoint test runs only when their complete RTL snapshots agree."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import shutil

FW=Path(__file__).resolve().parents[1]
OUT=FW/'reports/final-simulation'
OUT.mkdir(parents=True,exist_ok=True)
runs=[FW/'reports/preset-focused',FW/'reports/regression']
reports=[json.loads((p/'simulation_summary.json').read_text(encoding='utf-8')) for p in runs]
sources=reports[0]['source_sha256']
for report in reports:
    assert report['source_sha256']==sources, 'test runs used different RTL'
    assert not report['failed_tests']
for name,digest in sources.items():
    assert hashlib.sha256((FW/name).read_bytes()).hexdigest()==digest,('RTL changed since testing',name)
tests={}
for folder,report in zip(runs,reports):
    for name,passed in report['tests'].items():
        tests.setdefault(name,[]).extend(passed)
    for source in folder.iterdir():
        if source.suffix not in ('.log','.ppm','.raw','.csv'):
            continue
        target=OUT/source.name
        if target.exists() and source.read_bytes()!=target.read_bytes():
            if source.suffix!='.log':
                raise AssertionError(('conflicting artifact',source.name))
            target=OUT/(folder.name+'_'+source.name)
        shutil.copy2(source,target)
expected=set(json.loads((FW/'scripts/release_tests.json').read_text(encoding='utf-8')))
assert set(tests)==expected,(set(tests)^expected)
merged=dict(reports[0],tested_at=datetime.now(timezone.utc).isoformat(),tests=tests,
    failed_tests=[],run_reports=[p.relative_to(FW).as_posix()+'/simulation_summary.json' for p in runs],
    note='Focused preset and remaining regression groups share an identical production RTL snapshot; native display covers distinct capture selections in each run.')
(OUT/'simulation_summary.json').write_text(json.dumps(merged,indent=2),encoding='utf-8')
print('VERIFIED',len(tests),'test groups from identical RTL snapshots')
