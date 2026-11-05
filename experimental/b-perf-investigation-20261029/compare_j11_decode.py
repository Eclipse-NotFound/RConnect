import json
from pathlib import Path
BASE = Path(__file__).resolve().parents[2] / 'build' / 'ab'
NAMES = ["client.present","client.render","client.tween","client.players","client.sceneAndMap","replica.units",
         "replica.objectsAndEffects","replica.terrain","client.decode","network.receiveBatch","client.character",
         "client.projectiles","client.prune","client.prediction","client.pointer","host.publish","host.simulate",
         "capture.unitsAndTiles","host.delta","host.send","wire.decode"]

def load(run, role):
    out=[]
    p=BASE/run/'01-A'/role/'RConnect-B.log'
    for line in open(p,encoding='utf-8',errors='replace'):
        try:o=json.loads(line)
        except Exception:continue
        if o.get('kind')=='frame-profile':out.extend(o['data']['records'])
    return [r for r in out if len(r)==52]

def pct(a,q):
    a=sorted(a);return a[min(len(a)-1,int(len(a)*q))] if a else 0

for run in ('b-perfdiag-run-08','b-j11-diag-run-01'):
    rs=load(run,'join'); sub=[r for r in rs if r[2]==1 and r[-15]==80]
    dts=[r[1] for r in sub]; dec=[r[6+NAMES.index('client.decode')] for r in sub]
    print('\n###',run,'n',len(sub),'dt mean',round(sum(dts)/len(dts),2),'p95',pct(dts,.95),'max',max(dts),'>100',sum(1 for x in dts if x>=100))
    print(' decode mean',round(sum(dec)/len(dec),2),'p95',pct(dec,.95),'max',max(dec),'>20',sum(1 for x in dec if x>=20),'>40',sum(1 for x in dec if x>=40))
    print(' stats mean ops/grp/clone/fields/pose/keys:',
          round(sum(r[-6] for r in sub)/len(sub),1),round(sum(r[-5] for r in sub)/len(sub),1),
          round(sum(r[-4] for r in sub)/len(sub),1),round(sum(r[-3] for r in sub)/len(sub),1),
          round(sum(r[-2] for r in sub)/len(sub),1),round(sum(r[-1] for r in sub)/len(sub),1))
    # frames with decode >=20: show
    for r in sorted([x for x in sub if x[6+NAMES.index('client.decode')]>=20],key=lambda x:-x[1])[:6]:
        print('  dt',r[1],'dec',r[6+NAMES.index('client.decode')],'clone',r[-4],'fields',r[-3],'pose',r[-2],'keys',r[-1])
