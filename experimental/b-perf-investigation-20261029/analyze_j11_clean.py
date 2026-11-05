import json
from pathlib import Path
BASE = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-j11-clean-01'
runs = [('A','01-A'),('B','02-B'),('A','03-A'),('B','04-B')]
def pct(a,q):
    a=sorted(a);return a[min(len(a)-1,int(len(a)*q))] if a else 0
data={}
for label,d in runs:
    for role in ('host','join'):
        p=BASE/d/role/'ABBench.log'
        if not p.exists(): continue
        for line in open(p,encoding='utf-8',errors='replace'):
            try:o=json.loads(line)
            except Exception:continue
            if o.get('kind')!='result':continue
            x=o['data'];iv=x.get('intervals') or []
            if not iv:continue
            key=(label,role,x.get('expectedEnemies'))
            data.setdefault(key,[]).append(iv)
for label in ('A','B'):
    for role in ('host','join'):
        for enemies in (8,80):
            runs_iv=data.get((label,role,enemies),[])
            if not runs_iv:continue
            print(f'### {label} {role} {enemies} runs={len(runs_iv)}')
            for iv in runs_iv:
                dts=sorted(iv);n=len(dts)
                print(f'  n={n} mean={sum(dts)/n:.2f} p95={pct(dts,.95)} max={dts[-1]} >100={sum(1 for x in dts if x>=100)} >50={sum(1 for x in dts if x>=50)}')
