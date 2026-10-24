"""Existing four-window held-object regression; exact 78C or jumppose1 only."""
from pathlib import Path
import ast,hashlib,importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.with_name('goal-self-echo-native')
RECIPE=HERE.with_name('goal-jump-pose-product')
CANDIDATE=M52/'goal-jump-pose-product-01'
CANDIDATE_SHA='52d4723c1cf43e9ed2949c2e20debf7beda0b6068767c0bbaf83e83eb6a56e88'
PINS={
 OLD/'run.py':'8f0ee63334966456c618aee14f862d3f94ecb75baf8bc65636f3b01f95097c48',
 OLD/'source-manifest.json':'cfc69dd83d953cf28f732965852bc18f73ed5dfafd469c9556e8caa6d59c7f4d',
 RECIPE/'build.py':'ff10e4e5351b559264c58de389068ba9f4e386508afbab8c646c181c08cc7b77',
 RECIPE/'source-manifest.json':'394611c2b205e18f307f9586ace201fb30a898f3c47d04ccfe341753d30b23ec',
}
COMPILED_PINS={'prepared.json':'bb3c119487bf76d2267b2394324f427ac042f3893735a654a297792ae17de4f0',
 'compile.json':'2bdc27070ce01eaf9275646d354561b530210c7a22e0a75be2516a1679404750',
 'RConnectMod.swf':CANDIDATE_SHA}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,name):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def legacy():
 for p,h in PINS.items():assert sha(p)==h,str(p)
 m=load(OLD/'run.py','jumppose_held_original_binding');m.inputs();return m
def expanded_run(original):
 return original.once(original.expanded_run(),"out.name.startswith('goal-self-echo-native-')",
                      "out.name.startswith('goal-jump-pose-held-')")
def inputs(original=None):
 original=original or legacy();m=read(HERE/'source-manifest.json')
 assert m['kind']=='jump-pose-held-existing-driver-v1' and m['run_replacements']==1
 assert m['inputs']=={str(p):h for p,h in PINS.items()} and m['candidate_build']==COMPILED_PINS
 for n,h in m['files'].items():assert sha(HERE/n)==h,n
 assert (HERE/'adapted-run.py.txt').read_text('utf8')==expanded_run(original)
 pins=original.inputs();pins.update(m['inputs']);pins.update({str(HERE/n):h for n,h in m['files'].items()})
 pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
 return pins
def selected_product(path,original,build,environment):
 path=Path(path).resolve();assert path in (original.BASELINE,CANDIDATE)
 pins=inputs(original)
 if path==original.BASELINE:
  result=original.product(path,build,environment);result['pins'].update(pins);return result
 missing=[str(path/n) for n in COMPILED_PINS if not (path/n).is_file()]
 if missing:raise original.NotReady('Missing actual jumppose1 build: '+json.dumps(missing))
 for n,h in COMPILED_PINS.items():assert sha(path/n)==h,n
 builder=load(RECIPE/'build.py','jumppose_held_actual_product_verifier');receipt=builder.verify(path)
 meta=read(path/'prepared.json');current=build.installed()
 transition=environment.verify_environment_change(read(original.OLD/'environment.json')['installation'],current)
 assert meta['version']=='0.2.24-jumppose1' and meta['base_sha256']==build.PRODUCT_SHA
 assert receipt['candidate_sha256']==CANDIDATE_SHA and receipt['compiled'] is True
 assert meta['installation_before']==receipt['installation_before']==receipt['installation_after']==current
 pins.update({str(path/n):h for n,h in COMPILED_PINS.items()})
 return dict(path=str(path),sha256=CANDIDATE_SHA,version='0.2.24-jumppose1',receipt=receipt,pins=pins,
  build_environment=meta['installation_before'],driver_build_environment=transition['build_environment'],
  runtime_environment=transition['runtime_environment'],runtime_transition=transition)
def main():
 original=legacy();pins=inputs(original);text=expanded_run(original);ast.parse(text)
 if sys.argv[1:]==['--source-check']:
  print(json.dumps(dict(source_checked=True,compiled=False,air_started=False)));return 0
 assert '--case' in sys.argv and sys.argv[sys.argv.index('--case')+1]=='fast-held','Only the existing fast-held fixture is selected'
 base,environment=original.binding();analyzer=load(original.OLD/'analyze.py','jumppose_held_original_analyzer')
 def verify(out):
  proof=base.verify(out);proof['inputs']=proof['inputs']|inputs(original);return proof
 public=dict(vars(base));public['verify']=verify;build=types.SimpleNamespace(**public)
 namespace={'__file__':str(original.OLD/'run.py'),'__name__':'jumppose_held_bound_original',
  'CURRENT_BUILD':build,'ORIGINAL_SUMMARIZE':analyzer.summarize,
  'selfecho_product':lambda path:selected_product(path,original,build,environment)}
 exec(compile(text,str(HERE/'adapted-run.py.txt'),'exec'),namespace)
 assert namespace['CASES']['fast-held']==dict(seconds=360,done='tele-motion',rounds=[0,1,2,3],checks={'host':43,'join':42})
 try:return namespace['main']()
 except original.NotReady as error:
  print(json.dumps(dict(ready=False,checked=False,air_started=False,reason=str(error))));return 2
if __name__=='__main__':raise SystemExit(main())
