import argparse
from pathlib import Path
import subprocess
import sys
from run import ROOT, inside_build, read, save, sha

ap=argparse.ArgumentParser();ap.add_argument('--workspace',required=True);ap.add_argument('--candidate',required=True)
ap.add_argument('--preparation',required=True);ap.add_argument('--output',required=True);ap.add_argument('--scenarios',default='boundary,hover,enemies');a=ap.parse_args()
out=inside_build(ROOT/a.output)
if out.exists():raise FileExistsError(out)
out.mkdir();results=[]
for scenario in a.scenarios.split(','):
    result=a.output+'/'+scenario
    cmd=[sys.executable,str(Path(__file__).with_name('run.py')),'--workspace',a.workspace,'--preparation',a.preparation,'--scenario',scenario,'--candidate',a.candidate,'--result',result]
    with (out/(scenario+'.runner.log')).open('x',encoding='utf-8') as log:
        code=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT).returncode
    path=ROOT/result/'result.json';data=read(path) if path.exists() else {}
    entry=dict(scenario=scenario,code=code,passed=data.get('passed',False),result_sha256=sha(path) if path.exists() else None)
    results.append(entry);save(out/'suite.json',dict(candidate=a.candidate,results=results,complete=len(results)==len(a.scenarios.split(','))))
    print(entry,flush=True)
    if code:raise SystemExit(code)
