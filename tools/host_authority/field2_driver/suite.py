"""Run isolated B field scenarios sequentially on one reusable test copy."""
import argparse,json,time
from pathlib import Path
from run import ROOT,run,inside_build,sha,save
ap=argparse.ArgumentParser()
for key in ['workspace','preparation','candidate','native','output']:ap.add_argument('--'+key,required=True)
ap.add_argument('--scenarios',required=True)
ap.add_argument('--gap-seconds',type=int,default=30)
a=ap.parse_args();out=inside_build(ROOT/a.output)
if not 0<=a.gap_seconds<=60:raise ValueError('Scenario gap must be bounded')
if out.exists():raise FileExistsError(out)
out.mkdir(parents=True)
record={'candidate':a.candidate,'native':a.native,'candidate_sha256':sha(ROOT/a.candidate),'native_sha256':sha(ROOT/a.native),'preparation_sha256':sha(ROOT/a.workspace/a.preparation),'scenarios':{}}
for index,scenario in enumerate(a.scenarios.split(',')):
 if index:
  time.sleep(a.gap_seconds)
  if (out/'stop-after-current').exists():
   record['stopped_after_completed_scenario']=True;save(out/'suite.json',record);break
 try:code=run(inside_build(ROOT/a.workspace),scenario,ROOT/a.candidate,out/scenario,a.preparation,ROOT/a.native)
 except Exception as error:record['scenarios'][scenario]={'error':str(error)}
 else:record['scenarios'][scenario]={'exit_code':code,'result':str(out/scenario/'result.json')}
 save(out/'suite.json',record)
print(json.dumps(record,ensure_ascii=False),flush=True)
