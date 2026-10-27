"""Read completed fixed workload diagnostics; do not turn them into release qualification."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
run=ROOT/'build/ab/b-dense-profile01';receipt=json.loads((run/'result.json').read_text())
assert receipt['passed'] and receipt['profile'] and receipt['diagnostic_only']
rows=[]
for role in ('host','join'):
 for result in receipt['roles'][role]['results']:
  t=result['timings'];outer='capture.units' if role=='host' else 'replica.units';n=t[outer]['n']
  prefix='capture.unit.' if role=='host' else 'replica.unit.'
  parts={k:round(v['totalMs']/n,4) for k,v in t.items() if k.startswith(prefix)}
  rows.append(dict(role=role,enemies=result['expectedEnemies'],frames=result['frames'],outer_calls=n,
   stage_ms=result['elapsed']/result['frames'],outer_ms=t[outer]['totalMs']/n,parts_ms_per_capture=parts,
   residual_ms=(t[outer]['totalMs']-sum(v['totalMs'] for k,v in t.items() if k.startswith(prefix)))/n))
out=Path(__file__).parent/'profile01-analysis.json'
out.write_text(json.dumps(dict(diagnostic_only=True,receipt=str(run/'result.json'),sha256=hashlib.sha256((run/'result.json').read_bytes()).hexdigest(),rows=rows),indent=2)+'\n',encoding='utf-8')
print(json.dumps(rows,indent=2))
