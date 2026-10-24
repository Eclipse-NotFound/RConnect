"""Original native-jump runner plus passive packet/final-body qualification."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import build
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.with_name('goal-three-issues-native');RECIPE=HERE.with_name('goal-jump-pose-product')
BASELINE=M52/'recovery-room-production-05';CANDIDATE=M52/'goal-jump-pose-product-01'
PINS={'build.py':'ff10e4e5351b559264c58de389068ba9f4e386508afbab8c646c181c08cc7b77',
 'source-manifest.json':'394611c2b205e18f307f9586ace201fb30a898f3c47d04ccfe341753d30b23ec'}
sha,read,load=build.sha,build.read,build.load
class NotReady(Exception):pass
def expanded_run():
 h=load(build.HISTORY/'run.py','jump_observation_source_reader')
 assert sha(OLD/'run.py')==h.OLD_PINS['run.py']
 text=(OLD/'run.py').read_text('utf8')
 text=h.once(text,'import build\nfrom analyze import summarize','build=CURRENT_BUILD\nsummarize=ORIGINAL_SUMMARIZE')
 text=h.once(text,h.function_text(OLD/'run.py','product'),'def product(path):\n return selected_product(path)\n')
 text=h.once(text,"CASES={'native-jump':dict(seconds=300,done='native-jump',rounds=[0],checks={'host':6,'join':6}),\n 'fast-held':dict(seconds=360,done='tele-motion',rounds=[0,1,2,3],checks={'host':43,'join':42})}",
  "CASES={'native-jump':dict(seconds=300,done='native-jump',rounds=[0],checks={'host':6,'join':6})}")
 text=h.once(text,'assert out.parent==M52 and not out.exists()',
  "assert out.parent==M52 and out.name.startswith('goal-jump-pose-native-') and not out.exists()")
 return text
def product(path):
 path=Path(path).resolve();assert path in (BASELINE,CANDIDATE)
 pins=build.inputs();h,reference,environment,history=build.historical()
 current=build.installed()
 transition=environment.verify_environment_change(read(OLD/'environment.json')['installation'],current)
 if path==BASELINE:
  reference.inputs();meta,receipt=[read(path/n) for n in ('prepared.json','compile.json')]
  digest=reference.PRODUCT_SHA;version='0.2.24-roomfix5'
 else:
  missing=[str(path/n) for n in ('prepared.json','compile.json','RConnectMod.swf') if not (path/n).is_file()]
  if missing:raise NotReady('Missing complete jump-pose product: '+json.dumps(missing))
  for n,hsh in PINS.items():assert sha(RECIPE/n)==hsh,n
  builder=load(RECIPE/'build.py','actual_jump_pose_product_verifier')
  receipt=builder.verify(path);meta=read(path/'prepared.json')
  assert receipt['compiled'] is True and meta['version']=='0.2.24-jumppose1'
  assert meta['base_sha256']==reference.PRODUCT_SHA
  assert receipt['candidate_sha256']==sha(path/'RConnectMod.swf')=='52d4723c1cf43e9ed2949c2e20debf7beda0b6068767c0bbaf83e83eb6a56e88'
  assert receipt['installation_before']==receipt['installation_after']==meta['installation_before']==current
  digest=receipt['candidate_sha256'];version=meta['version']
  pins.update({str(RECIPE/n):sha(RECIPE/n) for n in ('prepare.py','build.py','source-manifest.json')})
 pins.update({str(path/n):sha(path/n) for n in ('prepared.json','compile.json','RConnectMod.swf')})
 return dict(path=str(path),sha256=digest,version=version,receipt=receipt,pins=pins,
  build_environment=meta['installation_before'],runtime_environment=current,
  historical_driver_environment=history['build_environment'],runtime_transition=transition)
def main():
 build.inputs();text=expanded_run();ast.parse(text)
 assert (HERE/'adapted-run.py.txt').read_text('utf8')==text
 if sys.argv[1:]==['--source-check']:
  print(json.dumps(dict(source_checked=True,compiled=False,air_started=False)));return 0
 if '--drivers' not in sys.argv:raise RuntimeError('Explicit compiled observation --drivers required')
 driver=(ROOT/sys.argv[sys.argv.index('--drivers')+1]).resolve()
 if not (driver/'compile.json').is_file():raise NotReady('Observation driver has not been compiled: '+str(driver))
 d=build.delegate();d.verify=build.verify
 original=load(OLD/'analyze.py','jump_observation_original_analyzer')
 scope={'__file__':str(OLD/'run.py'),'__name__':'jump_observation_bound_original',
  'CURRENT_BUILD':d,'ORIGINAL_SUMMARIZE':original.summarize,'selected_product':product}
 exec(compile(text,str(HERE/'adapted-run.py.txt'),'exec'),scope)
 assert scope['CASES']=={'native-jump':dict(seconds=300,done='native-jump',rounds=[0],checks={'host':6,'join':6})}
 code=scope['main']()
 if '--check' in sys.argv:return code
 out=(ROOT/sys.argv[sys.argv.index('--output')+1]).resolve()
 # The unchanged original result remains an independent functional result.
 analyzer=load(HERE/'analyze_pose.py','jump_passive_final_qualification')
 selected=(ROOT/sys.argv[sys.argv.index('--product')+1]).resolve()
 proof=analyzer.analyze(out,selected==CANDIDATE)
 with (out/'pose-observation-result.json').open('x',encoding='utf8') as f:json.dump(proof,f,indent=2);f.write('\n')
 print(json.dumps({k:proof[k] for k in ('functional_pass','observation_qualified','cursor_available')}))
 return 0 if code==0 and proof['observation_qualified'] else 1
if __name__=='__main__':
 try:raise SystemExit(main())
 except NotReady as e:
  print(json.dumps(dict(ready=False,air_started=False,reason=str(e))));raise SystemExit(2)
