"""Read two finished native runs and preserve a small, honest replay input.

Pure offline analysis, no game/compiler import or process launch. The observed
stream begins at measurement start: it is NOT a complete RemoteMotion replay.
The cumulative-calibration schedule is explicitly synthetic, for later use
against the actual AS3 class through the existing component runner.
"""
from pathlib import Path
import argparse,hashlib,json,math,statistics
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RUNS={'baseline':('74932502cf','78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'),
      'candidate':('99eea9cf09','89f1b9235b809c1595559ede873b763dc15f9ca7c393c82231c48981b1d78215')}
def read(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):
 with p.open('x',encoding='utf8') as f:json.dump(v,f,ensure_ascii=False,indent=2);f.write('\n')
def distribution(values):
 s=sorted(values)
 return dict(count=len(s),mean=statistics.mean(s) if s else None,p95=s[math.ceil(.95*len(s))-1] if s else None,maximum=max(s) if s else None)
def sample_rows(p):
 return [dict(at=packet['at'],**s) for packet in p['incoming'] for s in packet['snapshots']]
def movement(p):
 eligible=[];repeat=[]
 for a,b in zip(p['render'],p['render'][1:]):
  x,y=a['peer'],b['peer']
  if x['pose']=='die' or y['pose']=='die' or x['stay'] is not False or y['stay'] is not False:continue
  if min(abs(x['dy']),abs(y['dy']))<3 or x['dy']*y['dy']<=0 or max(x['vy'],y['vy'])>=620:continue
  eligible.append((a,b))
  if math.hypot(y['vx']-x['vx'],y['vy']-x['vy'])<.01:repeat.append((a,b))
 return dict(filter='Both samples airborne, vy<620 on floor640, same-sign |dy|>=3, no die pose',
  pairs=len(eligible),repeated_pairs=len(repeat),repeated_ms=sum(b['at']-a['at'] for a,b in repeat),
  events=[dict(at=b['at']-p['startedAt'],ms=b['at']-a['at'],dy=b['peer']['dy']) for a,b in repeat],
  qualification=False)
def extract(label):
 runid,digest=RUNS[label];out=ROOT/('build/m52/goal-three-issues-native-jump-'+label+'-01')
 run=ROOT/'build/cooperation'/runid;result=read(out/'result.json')
 assert result['passed'] and result['candidate_sha256']==digest
 assert result['installation_unchanged'] and result['inputs_unchanged']
 assert result['smoothnessQualified'] is False and result['performanceQualified'] is False
 evidence=dict(run=runid,result_sha256=sha(out/'result.json'),roles={});replays={}
 for role in ('host','join'):
  raw=out/(role+'-measurements.json');summary=out/(role+'-summary.json')
  assert sha(raw)==result['roles'][role]['measurements_sha256'] and sha(summary)==result['roles'][role]['summary_sha256']
  p=read(raw)[0];s=read(summary)[0]
  assert p['timingOwned'] and p['timingRestored'] and p['dropped']==0 and p['reason']=='measurement-complete'
  snaps=sample_rows(p);unique=[];offset=None;calibrations=[]
  for snap in snaps:
   if not unique or unique[-1]['sampleTime']!=snap['sampleTime']:unique.append(snap)
   actual=snap['at']-snap['sampleTime']
   if offset is None or actual<offset:
    calibrations.append(dict(at=snap['at']-p['startedAt'],offset=actual,improvement=0 if offset is None else offset-actual));offset=actual
  gap=[b['at']-a['at'] for a,b in zip(unique,unique[1:])]
  old=[v for v in p['render'] if v['peer']['pose']=='die' or v['peer']['vy']>640.01]
  role_summary=dict(raw_sha256=sha(raw),checks=result['roles'][role]['checks'],
   enter=s['local_enter']['all'],render=s['final_render']['all'],fps=s['local_enter']['background']['fps'],
   foreground_intervals=s['local_enter']['foreground']['intervals']['count'],
   packets=len(snaps),distinct_stamps=len(unique),distinct_arrivals=distribution(gap),
   calibration_minima=calibrations,air_motion=movement(p),
   old_pose_count=len(old),old_pose_last_ms=old[-1]['at']-p['startedAt'] if old else None,
   old_pose_first=old[0]['peer'] if old else None)
  evidence['roles'][role]=role_summary
  if role=='join':
   replays[role]=dict(origin='actual final native measurement window',run=runid,raw_sha256=sha(raw),
    lacks_pre_window_packets=True,lacks_internal_cursor_offset=True,
    callback_is_after_production_listener=True,render_frameAt_is_not_proven_exact_sample_argument=True,
    startedAt=p['startedAt'],
    arrivals=[[v['at'],v['sampleTime'],v['x'],v['y'],v['dx'],v['dy'],v['stay']] for v in snaps],
    displays=[[v['at'],v['frameAt'],v['peer']['vx'],v['peer']['vy'],v['peer']['dy'],v['peer']['stay'],v['peer']['pose']] for v in p['render']],
    note='Useful bounded observations; cannot recreate the preexisting motion queue or prove a whole-run clock replay.')
 m=read(run/'memory-timeline.json')
 evidence['memory']=dict(minimum_free_commit_gib=min(x['free_commit_bytes'] for x in m['rows'])/2**30,
  stopped_for_pressure=m['stopped_for_pressure'],stopped_for_overlap=m['stopped_for_overlap'])
 return evidence,replays
def synthetic():
 # Thirty-two fresh packets improve clock offset by 50ms each. Every
 # correction is below100ms; the accumulated improvement is1600ms.
 # No source gap/arrival gap exceeds1000ms and coordinates do not teleport.
 arrivals=[[5000+i*50,i*100,300+i*5,640] for i in range(33)]
 # Continue a regular50ms stream after calibration, to test recovery.
 arrivals += [[6650+i*50,3250+i*50,462.5+i*2.5,640] for i in range(41)]
 return dict(origin='constructed counterexample, NOT a recovered native prefix',interval_ms=50,
  use_actual_as3_class=True,policies=['ordinary player','held'],arrivals=arrivals,
  cumulative_improvement_ms=1600,maximum_single_improvement_ms=50,
  call_order='sample(arrival), push(packet,arrival), sample(arrival), sample(arrival+16), sample(arrival+16)',
  checks=['same-playAt position/cursor unchanged by push','same-playAt repeat after a positive step consumes no correction twice',
   'compare recovery to legacy baseline on identical input; record absolute lag and cross-frame steps',
   'bounded/monotone source cursor and no extrapolation beyond received positions'],
  extensions=['duplicate/out-of-order arrivals do not increase debt','settle/reset clears obsolete correction',
   'retainRate keeps finite effect duration; post-release recovery must not lose correction',
   'immediateStart drops retain the existing recorded arc test'],
  runtime_validated=False)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--write',action='store_true');a=ap.parse_args()
 report={};replays={}
 for label in RUNS:report[label],replays[label]=extract(label)
 report['inference_boundary']='Observed replay of stale first-jump data; pre-window offset/cursor unobserved. A causal account for every millisecond is not proven.'
 if a.write:
  save(HERE/'evidence.json',report);save(HERE/'replay-inputs.json',dict(observed_partial=replays,constructed_calibration=synthetic()))
 for label,e in report.items():
  if label=='inference_boundary':continue
  print(label,json.dumps({role:dict(fps=s['fps'],render_p95=s['render']['p95'],old_pose_last_ms=s['old_pose_last_ms'],
   strict_air_repeats=s['air_motion']['repeated_pairs'],strict_air_pairs=s['air_motion']['pairs']) for role,s in e['roles'].items()}))
 print('Offline only; no source changes, compiler or AIR; no performance qualification')
if __name__=='__main__':main()
