import json, statistics as st
from pathlib import Path

BASE = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-perfdiag-run-06' / '01-A'
NAMES = ["client.present","client.render","client.tween","client.players","client.sceneAndMap","replica.units",
         "replica.objectsAndEffects","replica.terrain","client.decode","network.receiveBatch","client.character",
         "client.projectiles","client.prune","client.prediction","client.pointer","host.publish","host.simulate",
         "capture.unitsAndTiles","host.delta","host.send"]
COUNTS = ["client.present","client.render","network.receiveBatch","host.publish"]

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
    if not rows:
        print(name,'no rows'); return
    dts=[r[1] for r in rows]
    print(f'\n== {name} n={len(rows)} dt mean={sum(dts)/len(dts):.2f} p50={pct(dts,.5)} p90={pct(dts,.9)} p95={pct(dts,.95)} max={max(dts)} >50={sum(1 for x in dts if x>=50)} >67={sum(1 for x in dts if x>=67)} >100={sum(1 for x in dts if x>=100)}')
    # mean per-frame deltas
    means={n:sum(r[6+i] for r in rows)/len(rows) for i,n in enumerate(NAMES)}
    top=sorted(means.items(), key=lambda kv:-kv[1])[:9]
    print(' top mean/frame:', ', '.join(f'{k}={v:.2f}' for k,v in top))
    if name.startswith('join'):
        print(' ready hist:', {k:sum(1 for r in rows if r[-8]==k) for k in (0,1,2,3,4)})
        print(' delay mean/p95/max:', round(sum(r[-6] for r in rows)/len(rows),1), pct([r[-6] for r in rows],.95), max(r[-6] for r in rows))
        print(' underflows max:', max(r[-5] for r in rows), 'queued mean:', round(sum(r[-7] for r in rows)/len(rows),2))
        print(' heapDrop frames:', sum(1 for r in rows if r[5]))
        print(' units/effects/proj mean:', round(sum(r[-4] for r in rows)/len(rows),1), round(sum(r[-3] for r in rows)/len(rows),1), round(sum(r[-2] for r in rows)/len(rows),1))
    else:
        print(' publish count/frame mean:', round(sum(r[26+3] for r in rows)/len(rows),2))
        print(' units/effects/proj mean:', round(sum(r[-4] for r in rows)/len(rows),1), round(sum(r[-3] for r in rows)/len(rows),1), round(sum(r[-2] for r in rows)/len(rows),1))
    # long frames >67
    longs=[r for r in rows if r[1]>=67]
    print(' long>=67:',len(longs))
    for r in sorted(longs,key=lambda x:-x[1])[:5]:
        sums=sorted(((NAMES[i],r[6+i]) for i in range(len(NAMES))), key=lambda kv:-kv[1])[:6]
        print(f"  dt={r[1]:4d} on={r[2]} ready={r[-8]} delay={r[-6]} heapDrop={r[5]} units={r[-4]} eff={r[-3]} proj={r[-2]} :: " + ', '.join(f'{k}={v}' for k,v in sums))

for role in ('host','join'):
    rs=[r for r in load(role) if len(r)==38]
    for units in (8,80):
        sub=[r for r in rs if r[2]==1 and r[-4]==units]
        show(f'{role} units={units}', sub)
