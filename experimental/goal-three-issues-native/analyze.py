"""Separate frame, receive and presentation evidence; never infer smooth PASS.

No cross-process clock calibration is available. Source timestamp gaps are
valid within one source clock, but absolute end-to-end latency is not claimed.
"""
import math
def stats(values):
 values=sorted(float(x) for x in values if x is not None and math.isfinite(float(x)))
 if not values:return dict(count=0)
 def pct(p):return values[min(len(values)-1,max(0,math.ceil(len(values)*p)-1))]
 return dict(count=len(values),mean=sum(values)/len(values),p50=pct(.5),p95=pct(.95),p99=pct(.99),maximum=values[-1],
  over50=sum(x>50 for x in values),over100=sum(x>100 for x in values),over200=sum(x>200 for x in values))
def intervals(rows):
 pairs=[(a,b,b['at']-a['at']) for a,b in zip(rows,rows[1:])]
 result=dict(all=stats([d for a,b,d in pairs]))
 for label,focused in [('foreground',True),('background',False)]:
  ds=[d for a,b,d in pairs if a['focused'] is focused and b['focused'] is focused]
  result[label]=dict(intervals=stats(ds),fps=len(ds)*1000/sum(ds) if ds and sum(ds)>0 else None)
 result['focus_boundary_intervals']=sum(a['focused']!=b['focused'] for a,b,d in pairs)
 result['unknown_focus_samples']=sum(r['focused'] is None for r in rows)
 return result
def display(rows,field):
 present=[r for r in rows if r.get(field) and r[field]['shown'] and r[field]['vx'] is not None and r[field]['vy'] is not None]
 repeated=0;steps=[];repeated_ms=0
 for a,b in zip(rows,rows[1:]):
  x,y=a.get(field),b.get(field)
  if not x or not y or not x['shown'] or not y['shown']:continue
  if any(v is None for v in (x['vx'],x['vy'],y['vx'],y['vy'])):continue
  d=math.hypot(y['vx']-x['vx'],y['vy']-x['vy']);steps.append(d)
  if d<.01:repeated+=1;repeated_ms+=b['at']-a['at']
 return dict(visible_samples=len(present),missing_or_detached=len(rows)-len(present),repeated_positions=repeated,
  repeated_position_ms=repeated_ms,step_pixels=stats(steps),
  caveat='Repeated positions include intentional rest; this count alone is not a stutter verdict.')
def summarize(probe):
 assert probe['diagnosticOnly'] is True and probe['smoothnessQualified'] is False
 streams={}
 for packet in probe['incoming']:
  for s in packet['snapshots']:
   streams.setdefault('remote-player',[]).append(dict(at=packet['at'],focused=packet['focused'],source=s['sampleTime'],x=s['x'],y=s['y']))
  for s in packet['positions']:
   streams.setdefault(s['collection']+':'+str(s['k']),[]).append(dict(at=packet['at'],focused=packet['focused'],source=s['sampleTime'],x=s['x'],y=s['y']))
 network={}
 for name,rows in streams.items():
  stamps=[r['source'] for r in rows if isinstance(r['source'],(int,float))]
  gaps=[b-a for a,b in zip(stamps,stamps[1:])]
  network[name]=dict(arrivals=intervals(rows),source_stamp_intervals=stats(gaps),
   nonincreasing_source_stamps=sum(g<=0 for g in gaps),unstamped=len(rows)-len(stamps))
 renders=probe['render'];enters=probe['enter'];frames={r['frame'] for r in renders}
 # These are segment sums, not the duration of an individual invocation.
 timing={name:dict(total=probe['timingTotal'][name],per_render_segment=stats([r['timing'][name] for r in renders]+[probe['timingTail'][name]]))
  for name in ('viewMs','viewCalls','motionMs','motionCalls')}
 return dict(kind=probe['kind'],round=probe['round'],role=probe['role'],room=probe['room'],
  measured_ms=probe['endedAt']-probe['startedAt'],local_enter=intervals(enters),final_render=intervals(renders),
  enter_without_final_render=sum(r['frame'] not in frames for r in enters),
  enter_to_render_ms=stats([r['at']-r['frameAt'] for r in renders if r['frame']>0]),
  local=display(renders,'local'),remote=display(renders,'peer'),held=display(renders,'target'),
  production_streams=network,presentation_timing=timing,dropped=probe['dropped'],
  clock_alignment='none; no absolute cross-process latency or source-aligned position error claimed',
  smoothnessQualified=False,performanceQualified=False)
