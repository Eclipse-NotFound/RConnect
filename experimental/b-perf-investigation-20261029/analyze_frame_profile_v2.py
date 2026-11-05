import json
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-perfdiag-run-07' / '01-A'
NAMES = ["client.present","client.render","client.tween","client.players","client.sceneAndMap","replica.units",
         "replica.objectsAndEffects","replica.terrain","client.decode","network.receiveBatch","client.character",
         "client.projectiles","client.prune","client.prediction","client.pointer","host.publish","host.simulate",
         "capture.unitsAndTiles","host.delta","host.send","wire.decode"]
COUNTS = ["client.present","client.render","network.receiveBatch","host.publish","client.decode","wire.decode"]

def load(role):
    out=[]
    for line in open(BASE/role/'RConnect-B.log', encoding='utf-8', errors='replace'):
        try: o=json.loads(line)
        except Exception: continue
        if o.get('kind')=='frame-profile':
            out.extend(o['data']['records'])
    return out

def pct(a,q):
    a=sorted(a); return a[min(len(a)-1,int(len(a)*q))] if a else 0

def show(name, rows):
    if not rows: print(name,'none'); return
    dts=[r[1] for r in rows]
    print(f'\n== {name} n={len(rows)} dt mean={sum(dts)/len(dts):.2f} p50={pct(dts,.5)} p90={pct(dts,.9)} p95={pct(dts,.95)} max={max(dts)} >67={sum(1 for x in dts if x>=67)} >100={sum(1 for x in dts if x>=100)}')
    means={n:sum(r[6+i] for r in rows)/len(rows) for i,n in enumerate(NAMES)}
    print(' means:', ', '.join(f'{k}={v:.2f}' for k,v in sorted(means.items(),key=lambda kv:-kv[1])[:10]))
    if name.startswith('join'):
        print(' ready:', {k:sum(1 for r in rows if r[-13]==k) for k in (0,1,2,3)})
        print(' delay mean/p95/max:', round(sum(r[-11] for r in rows)/len(rows),1), pct([r[-11] for r in rows],.95), max(r[-11] for r in rows))
        print(' underflows max/queued mean:', max(r[-10] for r in rows), round(sum(r[-12] for r in rows)/len(rows),2))
        print(' heapDrop:',sum(1 for r in rows if r[5]),'units/eff/proj:',round(sum(r[-9] for r in rows)/len(rows),1),round(sum(r[-8] for r in rows)/len(rows),1),round(sum(r[-7] for r in rows)/len(rows),1))
    else:
        print(' units/eff/proj:',round(sum(r[-9] for r in rows)/len(rows),1),round(sum(r[-8] for r in rows)/len(rows),1),round(sum(r[-7] for r in rows)/len(rows),1))
    longs=[r for r in rows if r[1]>=67]
    print(' long>=67:',len(longs))
    for r in sorted(longs,key=lambda x:-x[1])[:8]:
        sums=sorted(((NAMES[i],r[6+i]) for i in range(len(NAMES))),key=lambda kv:-kv[1])[:6]
        wire=f"wire(cnt={r[-5]},bytes={r[-4]},ms={r[-3]},full={r[-2]})"
        print(f"  dt={r[1]:4d} ready={r[-13]} delay={r[-11]} heapDrop={r[5]} units={r[-9]} eff={r[-8]} proj={r[-7]} {wire} :: " + ', '.join(f'{k}={v}' for k,v in sums))

for role in ('host','join'):
    rs=[r for r in load(role) if len(r)==46]
    print('###',role,'records',len(rs),'len',len(rs[0]) if rs else 0)
    for units in (8,80):
        show(f'{role} units={units}', [r for r in rs if r[2]==1 and r[-9]==units])
