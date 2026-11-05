import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-perfdiag-run-08' / '01-A'
NAMES = ["client.present","client.render","client.tween","client.players","client.sceneAndMap","replica.units",
         "replica.objectsAndEffects","replica.terrain","client.decode","network.receiveBatch","client.character",
         "client.projectiles","client.prune","client.prediction","client.pointer","host.publish","host.simulate",
         "capture.unitsAndTiles","host.delta","host.send","wire.decode"]

def load(role):
    out=[]
    for line in open(BASE/role/'RConnect-B.log', encoding='utf-8', errors='replace'):
        try: o=json.loads(line)
        except Exception: continue
        if o.get('kind')=='frame-profile': out.extend(o['data']['records'])
    return out

def pct(a,q):
    a=sorted(a); return a[min(len(a)-1,int(len(a)*q))] if a else 0

for role in ('host','join'):
    rs=[r for r in load(role) if len(r)==52]
    print('###',role,'records',len(rs))
    if not rs: continue
    for units in (8,80):
        sub=[r for r in rs if r[2]==1 and r[-15]==units]
        if not sub: continue
        dts=[r[1] for r in sub]
        print(f'\n== {role} units={units} n={len(sub)} dt mean={sum(dts)/len(dts):.2f} p95={pct(dts,.95)} max={max(dts)} >100={sum(1 for x in dts if x>=100)}')
        means={n:sum(r[6+i] for r in sub)/len(sub) for i,n in enumerate(NAMES)}
        print(' means:', ', '.join(f'{k}={v:.2f}' for k,v in sorted(means.items(),key=lambda kv:-kv[1])[:9]))
        if role=='join':
            print(' decode stats mean: ops',round(sum(r[-6] for r in sub)/len(sub),1),'grouped',round(sum(r[-5] for r in sub)/len(sub),1),
                  'clone',round(sum(r[-4] for r in sub)/len(sub),1),'fields',round(sum(r[-3] for r in sub)/len(sub),1),
                  'pose',round(sum(r[-2] for r in sub)/len(sub),1),'fieldKeys',round(sum(r[-1] for r in sub)/len(sub),1))
        longs=[r for r in sub if r[1]>=80]
        print(' long>=80:',len(longs))
        for r in sorted(longs,key=lambda x:-x[1])[:8]:
            dec=r[6+NAMES.index('client.decode')];recv=r[6+NAMES.index('network.receiveBatch')]
            sums=sorted(((NAMES[i],r[6+i]) for i in range(len(NAMES))),key=lambda kv:-kv[1])[:4]
            print(f"  dt={r[1]:4d} dec={dec} recv={recv} ops={r[-6]} grp={r[-5]} clone={r[-4]} fields={r[-3]} pose={r[-2]} keys={r[-1]} :: "+', '.join(f'{k}={v}' for k,v in sums))
