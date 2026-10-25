"""Collect the exact tested candidate's evidence; no test results are rewritten."""
from pathlib import Path
import json,sys,re,statistics
from build_probe import ROOT,sha,save,installation
from build_product import inventory
from analyze import trace,final_rows,stats
P=ROOT/'build/m52/a-live-animation-product-04'
E={}
def evidence(p):
 E[p.relative_to(ROOT).as_posix()]=sha(p)
 return json.loads(p.read_text('utf-8-sig')) if p.suffix=='.json' else p.read_text('utf8')
def run(name,expected):
 p=ROOT/'build/cooperation'/name
 info=evidence(p/'run.json');assert info['sha256']==expected
 assert evidence(p/'registry-result.json')['passed']
 selection=evidence(p/'reduced-selection-result.json');assert selection['passed'] and selection['enabled']==['RConnectMod']
 assert all(r['requested']==r['ok']==['RConnectMod'] and not r['err'] for r in selection['roles'].values())
 assert evidence(p/'reduced-installation-after.json')['unchanged']
 for role in ('host','join'):evidence(p/(role+'.log'))
 return p
def combat(name):
 result={}
 for role in ('host','join'):
  t=trace(name,role,'ENEMY ANIMATION TRACE ');rows=final_rows(t['rows'])
  c=[r for r in rows if 3000<r['age']<t['fireEndAge']]
  ds=[b['at']-a['at'] for a,b in zip(c,c[1:])]
  events=[e for w in t['wire'] for e in w['events']]
  result[role]=dict(frame_ms=stats(ds),p95=sorted(ds)[int(len(ds)*.95)],events=len(events),
    first_send_wait_ms=stats([e['sent']-e['born'] for e in events]))
  if role=='host':assert t['firingFrames']==255 and t['sourceShots']==[7,0,85,85,85,85,85,85,85]
  else:assert len(events)==602
 return result
def method(text,name):
 match=re.search(r'^      public function '+name+r'\b[\s\S]*?(?=^      (?:public|private|protected) function |\Z)',text,re.M)
 assert match;return match.group(0)
def main():
 assert len(sys.argv)==3,'door run and shooter-death run required'
 new=sha(P/'RConnectMod.swf');meta=evidence(P/'prepared.json');compiled=evidence(P/'compile.json')
 assert compiled['compiled'] and compiled['candidate_sha256']==new and compiled['reaped']
 assert evidence(P/'class-audit.json')['passed'] and inventory(P/'src')==meta['source']
 assert installation()==meta['installation_before']
 for name in ('f8edcc78f1','8330110f6a',sys.argv[1],sys.argv[2]):run(name,new)
 old='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
 for name in ('d372a676c0','439aa143c1'):run(name,old)
 # Keep both old runs; compare against the faster old run, not the favourable one.
 baselines={name:combat(name) for name in ('d372a676c0','439aa143c1')};current=combat('8330110f6a')
 ratios={}
 for role in ('host','join'):
  fastest=min(v[role]['frame_ms']['mean'] for v in baselines.values())
  best_tail=min(v[role]['p95'] for v in baselines.values())
  ratios[role]=dict(mean=current[role]['frame_ms']['mean']/fastest,p95=current[role]['p95']/best_tail)
  assert ratios[role]['mean']<=1.05 and ratios[role]['p95']<=1.10
 fly={}
 for role in ('host','join'):
  t=trace('f8edcc78f1',role,'ENEMY ANIMATION TRACE ')
  rows=final_rows(t['rows']);poses=[a['pose']['blit']['f'] for r in rows if r['age']>1000 for a in r['actors'] if a['id']=='animprobe_alicorn' and a['anim']=='fly']
  fly[role]=dict(samples=len(poses),exact_stalls=sum(a==b for a,b in zip(poses,poses[1:])),paint_repeats=sum(int(a)==int(b) for a,b in zip(poses,poses[1:])))
  assert len(poses)>500 and fly[role]['exact_stalls']==0
 doors={role:trace(sys.argv[1],role,'ANIMATION REPAIR TRACE ')['parts'] for role in ('host','join')}
 assert doors=={'host':[12,12],'join':[12,12]},doors
 paths={}
 for role in ('host','join'):
  rows=final_rows(trace(sys.argv[2],role,'ENEMY ANIMATION TRACE ')['rows']);points=[]
  for r in rows:
   for b in r['bullets']:
    point=[b['cls'],b['x'],b['y'],b['rot']]
    if not points or point!=points[-1]:points.append(point)
  assert len(points)>=4
  assert not any(r['bullets'] for r in rows if r['age']>5000)
  paths[role]=points
 assert paths['host']==paths['join'],paths
 # Actual native keyboard slope test is reused only for the unchanged method.
 earlier=ROOT/'build/m52/a-live-animation-product-02'
 run('e0e4b9c6fa',sha(earlier/'RConnectMod.swf'))
 before=method(evidence(earlier/'src/rconnect/game/GameBridge.as'),'readSnapshot')
 after=method(evidence(P/'src/rconnect/game/GameBridge.as'),'readSnapshot')
 assert before==after
 result=dict(passed=True,candidate_sha256=new,version='0.2.24-animfix1',evidence=E,
  dense_baselines=baselines,dense_candidate=current,ratios_against_faster_baseline=ratios,
  native_alicorn=fly,door_particles=doors,shooter_death_path=paths,
  scope='Only RConnect. Latest three animation issues; no qualification for prior loading goals or all mod combinations.',
  slope='Native keyboard test e0e4b9c6fa plus unchanged readSnapshot; repeat from installed bytes after deployment.',
  historical_restore='Source review: restoreCheckpoint passes live=false; not a new room-travel runtime claim.',
  failed_runs_retained=['f07902dbfd','5e551b4f56','ea09da3ae3','32e282ee1c','6e3d03a0ab','0bfec4d117','13b8405138','78877bdc29'],
  script_sha256=sha(__file__))
 save(P/'qualification.json',result);print(json.dumps({k:result[k] for k in ('passed','candidate_sha256','ratios_against_faster_baseline','native_alicorn','door_particles')},ensure_ascii=False))
if __name__=='__main__':main()
