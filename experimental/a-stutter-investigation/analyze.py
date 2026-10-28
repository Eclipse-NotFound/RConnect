"""Summarize actual source/remote display movement and native frame delivery. Read-only by default."""
from pathlib import Path
import argparse, json, statistics
def stats(values):
 values=sorted(x for x in values if isinstance(x,(int,float)) and x>0)
 return None if not values else dict(n=len(values),mean=round(statistics.mean(values),3),p95=values[min(len(values)-1,int(len(values)*.95))],maximum=max(values),over100=sum(x>100 for x in values))
def inspect(path):
 data=json.loads(path.read_text('utf8'));out=[]
 for p in data['phases']:
  seen={};local=remote=repeatLocal=repeatRemote=0
  for row in p['rows']:
   for c in row['clips']:
    if c['id'] in seen:
     before=seen[c['id']];repeat=all(c[k]==before[k] for k in ('x','y','rot'))
     if c['native']:local+=1;repeatLocal+=repeat
     else:remote+=1;repeatRemote+=repeat
    seen[c['id']]=c
  xs=[r['local']['x'] for r in p['rows']];ys=[r['local']['y'] for r in p['rows']]
  out.append(dict(name=p['name'],shots=len(p['births']),sourceEnds=len(p.get('sourceEnds',[])),
   movement=dict(xRange=round(max(xs)-min(xs),3) if xs else None,yRange=round(max(ys)-min(ys),3) if ys else None,
    resurrectionFrames=sum(r['local'].get('work')=='res' or r['local'].get('anim')=='res' for r in p['rows'])),
   enter=stats([r['enterGap'] for r in p['rows']]),render=stats([r['renderGap'] for r in p['rows']]),work=stats([r['work'] for r in p['rows']]),
   sourceRepeat=[repeatLocal,local],remoteRepeat=[repeatRemote,remote],
   wireShots=len(p['wire']),tailGap=stats([w.get('tailGap') for w in p['wire']]),
   emptyFlights=sum(w.get('frames')==0 for w in p['wire']),nullFlights=p.get('nullFlights'),wireSamples=p.get('wireSamples'),
   socketBytes=p['bytes'],messages=p['messages'],packetEvents=p['packetEvents'],packetFrames=p['packetFrames']))
 return dict(role=data['role'],completed=data['completed'],error=data['error'],audioVolume=data['audioVolume'],phases=out)
def main():
 p=argparse.ArgumentParser();p.add_argument('run',type=Path);a=p.parse_args()
 print(json.dumps({role:inspect(a.run/'logs'/role/'stutter-result.json') for role in ('host','join')},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
