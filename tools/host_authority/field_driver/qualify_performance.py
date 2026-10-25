"""Repeat exact final bytes and original B under the same AB007 workload."""
import argparse
import json
from pathlib import Path
import statistics
import subprocess
import sys
from run import ROOT, read, save, sha, inside_build

def workload(run):
    checks=[]
    for role,entry in run['roles'].items():
        for phase,v in enumerate(entry['results']):
            expected=8 if phase==0 else 80
            samples=v['samples']
            if v['expectedEnemies']!=expected or len(samples)<45:raise ValueError('Incomplete workload sampling')
            for sample in samples+[v]:
                population=sample['enemies']
                if population['count']!=expected or population['attached']!=expected:raise ValueError('Enemy population or attachment changed')
            if role=='host':
                for before,after in zip(samples,samples[1:]):
                    for player in (0,1):
                        if before['ammo'][player]-after['ammo'][player]!=after['shots'][player]-before['shots'][player]:
                            raise ValueError('Native ammo consumption differs from actual projectile generation')
                windows={}
                for sample in samples:windows.setdefault(int(sample['ms']/10000),[]).append(sample)
                for window,rows in windows.items():
                    if rows[-1]['ms']-rows[0]['ms']<8000:continue
                    if any(rows[-1]['shots'][i]<=rows[0]['shots'][i] for i in (0,1)):raise ValueError('A player stopped firing in a measured ten-second window')
            checks.append(dict(role=role,enemies=expected,samples=len(samples)))
    return checks

ap=argparse.ArgumentParser();ap.add_argument('--candidate',required=True);ap.add_argument('--tag',required=True);ap.add_argument('--baseline-tag',default='baseline');ap.add_argument('--evaluate-only',action='store_true');ap.add_argument('--resume',action='store_true');a=ap.parse_args()
baseline_names=[a.baseline_tag+'-02',a.baseline_tag+'-03']
plan=[] if a.evaluate_only else [(baseline_names[0],'build/ab/b190-startup2-build'),(a.tag+'-01',a.candidate),(baseline_names[1],'build/ab/b190-startup2-build'),(a.tag+'-02',a.candidate)]
for name,build in plan:
    output='build/ab/b-field-clean-'+name
    prior=ROOT/output/'result.json'
    if a.resume and prior.exists():
        completed=read(prior)
        if not completed.get('passed') or completed['candidate_sha256']!=read(ROOT/build/'build-input.json')['candidate_sha256'] or completed['seconds']!=60 or completed['profile']:
            raise ValueError('Cannot resume from incomplete or different timing run: '+str(prior))
        continue
    command=[sys.executable,str(Path(__file__).with_name('bench.py')),'--workspace','build/ab/b-field-bench-20261025-01','--candidate',build,'--result',output,'--seconds','60']
    p=subprocess.run(command)
    if p.returncode:raise SystemExit(p.returncode)
names=baseline_names+[a.tag+'-01',a.tag+'-02'];runs={}
baseline_sha=read(ROOT/'build/ab/b190-startup2-build/build-input.json')['candidate_sha256']
candidate_sha=read(ROOT/a.candidate/'build-input.json')['candidate_sha256']
for name in names:
    path=ROOT/'build/ab'/('b-field-clean-'+name)/'result.json';r=read(path)
    if not r.get('passed') or r['seconds']!=60 or r['profile']:raise ValueError('Unqualified timing input')
    if r['candidate_sha256']!=(baseline_sha if name in baseline_names else candidate_sha):raise ValueError('Different benchmark build')
    runs[name]=dict(path=str(path.relative_to(ROOT)),sha256=sha(path),workload=workload(r),data=r)
source=read(ROOT/a.candidate/'build-input.json');comparisons=[]
for role in ('host','join'):
    for phase in (0,1):
        values={}
        for group,names_group in [('baseline',baseline_names),('candidate',[a.tag+'-01',a.tag+'-02'])]:
            mean=[];p95=[]
            for name in names_group:
                run=runs[name]['data']
                if group=='candidate' and run['candidate_sha256']!=source['candidate_sha256']:raise ValueError('Different candidate bytes')
                v=run['roles'][role]['results'][phase];mean.append(v['elapsed']/v['frames']);p95.append(v['intervals'][int(v['frames']*.95)])
            values[group]=dict(mean_ms=statistics.median(mean),p95_ms=statistics.median(p95),repeat_ratio=max(mean)/min(mean))
        b,c=values['baseline'],values['candidate']
        comparisons.append(dict(role=role,enemies=8 if phase==0 else 80,**values,
            no_material_regression=c['mean_ms']<=b['mean_ms']*1.05 and c['p95_ms']<=b['p95_ms']*1.05,
            repeatable=c['repeat_ratio']<=1.2 and b['repeat_ratio']<=1.2))
out=ROOT/'build/ab'/('b-field-performance-'+a.tag+'.json')
save(out,dict(candidate_sha256=source['candidate_sha256'],source=source['source_id'],comparisons=comparisons,
    no_material_regression=all(c['no_material_regression'] and c['repeatable'] for c in comparisons),
    inputs={k:{f:v[f] for f in ('path','sha256','workload')} for k,v in runs.items()},
    scope='Stage frame intervals, not GPU presentation or end-to-end latency; 8/80 native enemies and two LMGs; normal OS scheduling'))
print(out,flush=True)
