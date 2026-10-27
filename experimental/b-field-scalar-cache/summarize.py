"""Describe measured frame cost and chosen playback reserve; reserve is NOT end-to-end latency."""
from pathlib import Path
import argparse,json,statistics,hashlib
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--revision',required=True,choices=['02','04']);args=ap.parse_args()
out=Path(__file__).parent/('measurements'+args.revision+'-v2.json')
if out.exists():raise FileExistsError(out)
rows=[]
def quantile(values,fraction):
 # Use the frozen qualifier's index, int(sample_count * fraction).
 values=sorted(values);return values[min(len(values)-1,int(len(values)*fraction))]
for group in ('baseline','candidate'):
 for number in (1,2):
  folder=ROOT/('build/ab/b-scalar'+args.revision+'-'+group+'-0'+str(number))
  receipt=json.loads((folder/'result.json').read_text());assert receipt['passed'] and not receipt['profile']
  for role,entry in receipt['roles'].items():
   for r in entry['results']:
    row=dict(group=group,run=number,role=role,enemies=r['expectedEnemies'],frames=r['frames'],
     frame_mean_ms=statistics.mean(r['intervals']),frame_p95_ms=quantile(r['intervals'],.95),
     source=str(folder.relative_to(ROOT)),receipt_sha256=hashlib.sha256((folder/'result.json').read_bytes()).hexdigest())
    if role=='join':
     samples=r['samples'];delays=[s['delay'] for s in samples if 'delay' in s]
     row.update(playback_reserve_median_ms=statistics.median(delays),playback_reserve_p95_ms=quantile(delays,.95),
      queued_mean=statistics.mean(s['queued'] for s in samples),
      underflow_take_calls=samples[-1]['underflows']-samples[0]['underflows'])
    rows.append(row)
out.write_text(json.dumps(dict(scope='Stage frame intervals and sampled chosen playback reserve, not measured input-to-screen latency or packet loss',percentile_index='min(n-1, int(n * fraction)); same frame rule as frozen qualifier',rows=rows),indent=2)+'\n',encoding='utf-8')
print(out)
