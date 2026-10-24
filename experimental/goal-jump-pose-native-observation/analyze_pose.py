"""Conservative observed endpoint/interior evidence; never reconstruct a cursor."""
from pathlib import Path
import hashlib,json,math
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def number(x):return type(x) in (int,float) and math.isfinite(x)
def frame(dy):return max(1,min(32,math.floor(16+dy+.5)))
def normal(s,marked):
 return (s.get('pose')=='jump' and s.get('bodyPlaying') is False and s.get('stay')==0
  and s.get('sost')==1 and number(s.get('hp')) and s['hp']>0
  and all(number(s.get(k)) for k in ('sampleTime','x','y','dx','dy','poseFrame','bodyFrame','roomEpoch'))
  and s['bodyFrame']==frame(s['dy']) and s['poseFrame']>=1
  and bool(s.get('roomKey')) and s.get('landId') is not None and s.get('locId') is not None
  and (not marked or (number(s.get('nativeJumpRun')) and s['nativeJumpRun']>0 and s['nativeJumpRun']==int(s['nativeJumpRun']))))
def same(a,b,marked):
 keys=('roomKey','roomEpoch','landId','locId','poseFrame')+(('nativeJumpRun',) if marked else ())
 return normal(a,marked) and normal(b,marked) and b['sampleTime']>a['sampleTime'] and all(a[k]==b[k] for k in keys)
def role(probe,candidate):
 assert probe['poseObservationVersion']==1 and probe['cursorAvailable'] is False
 assert probe['kind']=='native-jump' and probe['round']==0 and probe['reason']=='measurement-complete'
 assert probe['dropped']==0 and probe['timingOwned'] and probe['timingRestored']
 events=sorted([(r['order'],'packet',r) for r in probe['incoming']]+[(r['order'],'render',r) for r in probe['render']])
 assert len({e[0] for e in events})==len(events)
 expected='playerstate' if probe['role']=='host' else 'worldstate'
 timeline=[];pairs=set();interiors=[];selected_matches=0;ambiguous=0;shown=0;normal_packets=0;marked_packets=0
 fields={'poseFrame','bodyPlaying','bodyTotal','bodyOnStage','bodyVisible','aJump','jumpNumb','animState','animOff','work','isFly','isLaz','isPlav','t_port','hp','sost'}
 rejected_order=0
 for order,kind,r in events:
  if kind=='packet':
   if r['type']!=expected:continue
   for s in r['snapshots']:
    assert {'nativeJumpRun','pose','poseFrame','bodyFrame','bodyPlaying','roomKey','roomEpoch','landId','locId','hp','sost'}<=set(s)
    if normal(s,False):normal_packets+=1
    if normal(s,True):marked_packets+=1
    if not number(s.get('sampleTime')):continue
    if timeline and s['sampleTime']<timeline[-1]['sampleTime']:
     rejected_order+=1;continue
    if timeline and s['sampleTime']==timeline[-1]['sampleTime']:timeline[-1]=s
    else:timeline.append(s)
    if len(timeline)>=2 and same(timeline[-2],timeline[-1],candidate):
     a,b=timeline[-2:];pairs.add((a['sampleTime'],b['sampleTime'],a.get('nativeJumpRun')))
   continue
  for who in ('local','peer'):
   if r.get(who) is not None:assert fields<=set(r[who])
  p=r.get('peer')
  if not p or p['pose']!='jump' or p['bodyPlaying'] is not False or not p['bodyOnStage'] or not p['shown'] or p['visible'] is not True or p['bodyVisible'] is not True:continue
  if not all(number(p.get(k)) for k in ('x','y','dx','dy','poseFrame','body')):continue
  shown+=1
  # Native ghost velocities are copied from the selected endpoint, not interpolated.
  # Require one exact matching observed endpoint among ALL observed history.
  anchors=[(i,s) for i,s in enumerate(timeline) if normal(s,candidate)
   and s['roomKey']==r['roomKey'] and s['roomEpoch']==r['roomEpoch'] and s['poseFrame']==p['poseFrame']
   and s['dx']==p['dx'] and s['dy']==p['dy'] and bool(s['stay'])==bool(p['stay'])]
  if len(anchors)!=1:
   ambiguous+=1;continue
  i,a=anchors[0]
  if p['body']==a['bodyFrame']:selected_matches+=1
  if i+1>=len(timeline):continue
  b=timeline[i+1]
  if not same(a,b,candidate):continue
  if not all(min(a[k],b[k])-.01<=p[k]<=max(a[k],b[k])+.01 for k in ('x','y')):continue
  if min(a['bodyFrame'],b['bodyFrame'])<p['body']<max(a['bodyFrame'],b['bodyFrame']):
   interiors.append(dict(order=order,render_at=r['at'],render_frame=r['frame'],body=p['body'],
    selected_sample=a['sampleTime'],next_sample=b['sampleTime'],a_frame=a['bodyFrame'],b_frame=b['bodyFrame'],
    a_dy=a['dy'],b_dy=b['dy'],nativeJumpRun=a.get('nativeJumpRun'),cursor=None))
 return dict(normal_packets=normal_packets,marked_packets=marked_packets,qualifying_pairs=len(pairs),
  actual_stopped_jump_renders=shown,exact_selected_frame_matches=selected_matches,
  unambiguous_interior_frames=len(interiors),interior_evidence=interiors[:32],ambiguous_renders=ambiguous,
  backward_packets=rejected_order,qualified=normal_packets>0 and shown>0 and rejected_order==0
   and (marked_packets>0 and bool(pairs) and bool(interiors) if candidate else marked_packets==0),
  caveat='Unique packet-velocity endpoint and bounded actual display only; private sourceTime/cursor is not observed.')
def analyze(out,candidate):
 out=Path(out);result=read(out/'result.json');rows={};error=None
 try:
  assert result['passed'] is True
  for name in ('host','join'):
   path=out/(name+'-measurements.json');p=read(path);assert len(p)==1 and p[0]['role']==name
   rows[name]=role(p[0],candidate);rows[name]['measurements_sha256']=sha(path)
 except Exception as exc:error=repr(exc)
 return dict(kind='native-jump-passive-qualification-v1',functional_pass=result.get('passed') is True,
  functional_result_sha256=sha(out/'result.json'),candidate=candidate,
  observation_qualified=error is None and len(rows)==2 and all(x['qualified'] for x in rows.values()),
  roles=rows,error=error,cursor_available=False,source_time_alignment_proved=False,
  performanceQualified=False,smoothnessQualified=False,
  definition='Direct real packet metadata plus final MovieClip properties. Non-unique matches are unclassified, never fitted.')
