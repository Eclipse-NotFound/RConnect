import json
import statistics
from pathlib import Path
from run import ROOT
rows=[]
for directory in sorted((ROOT/'build/ab').glob('b-field-clean-*')):
    if not (directory/'result.json').exists():continue
    r=json.loads((directory/'result.json').read_text())
    if not r.get('complete'):continue
    machine=json.loads((directory/'machine.json').read_text());cpu=[]
    for a,b in zip(machine,machine[1:]):
        delta=[y-x for x,y in zip(a['cpuTicks'],b['cpuTicks'])];total=delta[1]+delta[2]
        if total>0:cpu.append(100*(1-delta[0]/total))
    row=dict(run=directory.name,cpu_median=round(statistics.median(cpu),1),min_free_gib=round(min(v['free_gib'] for v in machine),1),roles={})
    for role,entry in r['roles'].items():
        row['roles'][role]=[dict(enemies=v['expectedEnemies'],fps=round(1000*v['frames']/v['elapsed'],1),p95=v['intervals'][int(v['frames']*.95)],frames=v['frames']) for v in entry['results']]
    rows.append(row)
print(json.dumps(rows,ensure_ascii=False,indent=2))
