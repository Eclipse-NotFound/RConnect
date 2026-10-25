from pathlib import Path
import json,sys,statistics
ROOT=Path(__file__).resolve().parents[2]
def trace(run,role,tag):
 for line in (ROOT/'build/cooperation'/run/(role+'.log')).read_text('utf8').splitlines():
  if tag in line:return json.loads(line.split(tag,1)[1])
 raise AssertionError((run,role,tag))
def final_rows(rows):
 out=[]
 for row in rows:
  if out and row['at']-out[-1]['at']<10:out[-1]=row
  else:out.append(row)
 return out
def stats(seq):
 return dict(n=len(seq),min=min(seq),median=statistics.median(seq),max=max(seq),mean=round(statistics.mean(seq),3)) if seq else {}
def enemy(run):
 result={}
 for role in ('host','join'):
  t=trace(run,role,'ENEMY ANIMATION TRACE ');rows=final_rows(t['rows']);actors={}
  for id in ('alicorn','raider','turret'):
   # MirrorHitUnit has the source id but no source animation; only the first
   # native actor per id is the displayed enemy (preserve raw rows separately).
   samples=[dict(next(a for a in r['actors'] if a['id']=='animprobe_'+id),at=r['at'],age=r['age'])
            for r in rows if any(a['id']=='animprobe_'+id for a in r['actors'])]
   moves=[a for a in samples if 3000<a['age']<11000]
   poses=[a['pose'].get('blit',{}).get('f') for a in moves]
   death=[a for a in samples if a['sost']>=3]
   muzzle=[a.get('barrel') for a in moves]
   actors[id]=dict(count=len(samples),move_repeats=sum(a['x']==b['x'] and a['y']==b['y'] for a,b in zip(moves,moves[1:])),
    pose_repeats=sum(a==b for a,b in zip(poses,poses[1:])),pose_first=poses[:24],
    muzzle_first=muzzle[:35],muzzle_frames={str(f):muzzle.count(f) for f in set(muzzle)},
    death_first=[dict(age=a['age'],anim=a['anim'],f=a['pose'].get('blit',{}).get('f')) for a in death[:16]])
  events=[e for w in t['wire'] for e in w['events']]
  result[role]=dict(frames=len(rows),frame_ms=stats([b['at']-a['at'] for a,b in zip(rows,rows[1:])]),actors=actors,
    event_send_age=stats([e['sent']-e['born'] for e in events]),events=len(events),
    projectile_frames=sum(bool(r['bullets']) for r in rows),projectile_classes=sorted({b['cls'] for r in rows for b in r['bullets']}))
 return result
if __name__=='__main__':print(json.dumps(enemy(sys.argv[1]),ensure_ascii=False,indent=2))
