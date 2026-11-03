"""Register only coordinate predicates in the existing surface stage.

Palette selection uses those registered predicates without an extra RGB stage.
The transformation is the same equal-latency scheme as the supplied KNOB5 PIPE
project and is rerun after geometry generation so regeneration stays safe.
"""
from pathlib import Path
import re

def optimize_geometry(src: Path):
    pattern=re.compile(r'\b[xy]\s*(?:>=|<=|==|>|<)\s*\d+')
    expressions=[]
    indices={}
    for name in ['instrument_paint.vh','pressure_matrix_paint.vh']:
        path=src/name
        original=path.read_text(encoding='utf-8')
        assert 'surface_cmp[' not in original, 'Run geometry generation before pipelining'
        def replace(match):
            expression=re.sub(r'\s+','',match.group())
            if expression not in indices:
                indices[expression]=len(expressions)
                expressions.append(expression)
            return f'surface_cmp[{indices[expression]}]'
        path.write_text(pattern.sub(replace,original),encoding='utf-8')
    lines=['// Generated coordinate comparisons; one existing surface stage.',
        f'reg [{len(expressions)-1}:0] surface_cmp=0;',
        'always @(posedge clk)begin']
    lines += [f' surface_cmp[{i}]<=({expression});' for i,expression in enumerate(expressions)]
    lines += ['end']
    (src/'surface_compare_stage.vh').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('PIPELINED',len(expressions),'coordinate comparisons; RGB latency unchanged')
