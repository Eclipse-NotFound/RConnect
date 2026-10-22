"""Read-only source-final -> peer-final bounds for the existing recovery22 run."""
from pathlib import Path
import hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EVIDENCE=ROOT/'build/m52/recovery22-wall-surfaces-native-01'
REVIEW=ROOT/'experimental/recovery-wall-surfaces-native-proof-review/recovery22-reanalysis-01.json'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pairs(a):return dict(zip(a[::2],a[1::2]))
def stable_final(row,key):
 expected={i:n for i,n in enumerate(row['finalNative' if key=='native' else 'finalDisplay']) if n!=row['baseline' if key=='native' else 'baselineDisplay'][i]}
 frames=row['frames'];bad=[i for i,f in enumerate(frames) if pairs(f[key])!=expected]
 i=max(bad)+1 if bad else 0
 assert i<len(frames)
 return dict(before_wall=frames[i-1]['wall'] if i else None,observed_wall=frames[i]['wall'],index=i,
             stable_frames=len(frames)-i,pixels=len(expected))
def main():
 files=[REVIEW,EVIDENCE/'result.json',EVIDENCE/'wall-surface-result.json']
 review=read(REVIEW);framework=read(files[1]);original=read(files[2]);rows=[]
 assert review['passed'] and review['source_unchanged'] and framework['passed'] and not original['passed']
 for n,role in enumerate(('host','join','host','join')):
  a=EVIDENCE/'wall-proof'/role/f'round-{n}-proof.json'
  b=EVIDENCE/'wall-proof'/('join' if role=='host' else 'host')/f'round-{n}-proof.json'
  files.extend((a,b));source,peer=read(a),read(b)
  assert source['source'] and not peer['source']
  assert source['baseline']==peer['baseline'] and source['finalNative']==peer['finalNative']
  source_end=stable_final(source,'native');peer_end=stable_final(peer,'native')
  display_source=stable_final(source,'display');display_peer=stable_final(peer,'display')
  hits=[h['wall'] for h in source['hits']]
  rows.append(dict(round=n,source=role,weapon=source['weapon'],shots=source['shots'],hits=len(hits),
   first_hit_wall=min(hits),last_hit_wall=max(hits),hit_span_ms=max(hits)-min(hits),
   first_source_observed=source['sourceFirst'],first_to_remote_complete_ms=peer_end['observed_wall']-source['sourceFirst'],
   source_native_final=source_end,remote_native_final=peer_end,
   last_source_to_remote_observed_ms=peer_end['observed_wall']-source_end['observed_wall'],
   last_source_to_remote_bounds_ms=[None if peer_end['before_wall'] is None else peer_end['before_wall']-source_end['observed_wall'],
                                  None if source_end['before_wall'] is None else peer_end['observed_wall']-source_end['before_wall']],
   source_display_final=display_source,remote_display_final=display_peer,
   maximum_observation_gap_ms={r['role']:max(y['wall']-x['wall'] for x,y in zip(r['frames'],r['frames'][1:])) for r in (source,peer)}))
 result=dict(run='58af664bec',candidate_sha256=review['candidate_sha256'],native_host_sha256=review['native_host_sha256'],
  framework_passed=True,old_png_failure_preserved=True,strict_source_peer_uint_passed=True,source_unchanged=True,
  rows=rows,inputs={str(p):sha(p) for p in files},performance_qualified=False,jvm_started=False,air_started=False,
  bounds_note='Final source/peer transitions are bracketed by adjacent RENDER copies, not exact propagation timestamps. No private queue/ACK timing was recorded.')
 target=HERE/'recovery22-large-review.json'
 target.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
