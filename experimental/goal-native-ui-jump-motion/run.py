"""Exact existing only-RConnect motion fixtures with the nativeui2 bundle."""
from pathlib import Path
import ast,difflib,hashlib,importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.with_name('goal-rconnect-only-motion')
LOADING=HERE.with_name('goal-native-ui-jump-loading')
OLD_PINS={'run.py':'48ac67625a3e5d2dd107dda658e6fea66134f5845ccd8038256bf7dedf60f945',
 'source-manifest.json':'782d19b8f2aa59d8b18968de7c8961c9023ec4d27a7720361a129ca9937f26f5'}
LOADING_PINS={'run.py':'2e74195a952852eed6d1008cfb21aa837f8fcbb8d7e4ff863d90a03d8f42d73e',
 'runtime-manifest.json':'78860996247a5560257c7dc2c3f8c9051ad268d39716ecf8c8ed6b3d5d43dac1'}
MAIN_EDITS=(
 ('pins=inputs();parent,original=legacy();text,_=expanded(original)',
  'pins=inputs();parent,original=legacy();text,_=bundle_expanded(original)'),
 ('value=parent.selected_product(path,original,build,environment)',
  'value=bundle_product(path,original,build,environment)'),
 ("scope['RUNNER']=HERE/'selector.py'","scope['RUNNER']=bundle_selector_path"))
RUN_EDITS=(
 ("command=[str(RUNNER),'--candidate',str(product_path/'RConnectMod.swf'),'--effects'",
  "command=[str(RUNNER),'--candidate',str(product_path/'RConnectMod.swf'),'--game-candidate',selected['game_path'],'--effects'"),
 ('     assets={}\n',
  "     private_game=output/role/'pfe.swf'\n"
  "     assert sha(private_game)==selected['game_sha256']\n"
  "     assets={str(private_game):selected['game_sha256']}\n"),
 ("assert values['game']==build.HOST_SHA and values['production']==candidate",
  "assert values['game']==selected['game_sha256'] and values['production']==candidate"))

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
 s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def original():
 for n,h in OLD_PINS.items():assert sha(OLD/n)==h,n
 m=load(OLD/'run.py','nativeui2_motion_original');m.inputs();return m
def replace(old,edits):
 new=old
 for before,after in edits:
  assert new.count(before)==1 and after not in new
  new=new.replace(before,after)
 restored=new
 for before,after in reversed(edits):
  assert restored.count(after)==1;restored=restored.replace(after,before)
 assert restored==old;ast.parse(new);return new
def sources():
 m=original();_,base=m.legacy()
 old_main=(OLD/'run.py').read_text('utf8');old_run=m.expanded(base)[0]
 main=replace(old_main,MAIN_EDITS);run=replace(old_run,RUN_EDITS)
 diff=''.join(difflib.unified_diff(old_main.splitlines(True),main.splitlines(True),
  fromfile='frozen/only-rc-run.py',tofile='nativeui2/only-rc-run.py'))
 diff+=''.join(difflib.unified_diff(old_run.splitlines(True),run.splitlines(True),
  fromfile='frozen/only-rc-expanded.py',tofile='nativeui2/only-rc-expanded.py'))
 selector=load(HERE/'selector.py','nativeui2_motion_selector_source');selector.check()
 old_selector,selector_text=selector.source();old_text=old_selector.source()[0]
 diff+=''.join(difflib.unified_diff(old_text.splitlines(True),selector_text.splitlines(True),
  fromfile='frozen/only-rc-selector.py',tofile='nativeui2/only-rc-selector.py'))
 return {'adapted-main.py.txt':main,'adapted-run.py.txt':run,'adapted-selector.py.txt':selector_text,'source.diff':diff}
def inputs():
 m=read(HERE/'source-manifest.json')
 assert m['kind']=='native-ui-jump-motion-v1' and m['main_replacements']==3 and m['run_replacements']==3 and m['selector_replacements']==1
 assert m['inputs']==({str(OLD/n):h for n,h in OLD_PINS.items()}|{str(LOADING/n):h for n,h in LOADING_PINS.items()})
 for p,h in m['inputs'].items():assert sha(p)==h,p
 for n,h in m['files'].items():assert sha(HERE/n)==h,n
 for n,text in sources().items():assert (HERE/n).read_text('utf8')==text,n
 pins=original().inputs()
 loading=load(LOADING/'run.py','nativeui2_motion_loading_inputs');pins.update(loading.source_check())
 pins.update(m['inputs']);pins.update({str(HERE/n):h for n,h in m['files'].items()})
 pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
 return pins
def prepare():
 for n,text in sources().items():
  with (HERE/n).open('w',encoding='utf8',newline='\n') as f:f.write(text)
 pins={str(OLD/n):h for n,h in OLD_PINS.items()}
 for n,h in LOADING_PINS.items():assert sha(LOADING/n)==h,n;pins[str(LOADING/n)]=h
 files={n:sha(HERE/n) for n in ('run.py','selector.py','README.md','adapted-main.py.txt','adapted-run.py.txt','adapted-selector.py.txt','source.diff')}
 with (HERE/'source-manifest.json').open('w',encoding='utf8') as f:
  json.dump(dict(kind='native-ui-jump-motion-v1',main_replacements=3,run_replacements=3,selector_replacements=1,files=files,inputs=pins,
   enabled=['RConnectMod'],compiled=False,air_started=False,performanceQualified=False,smoothnessQualified=False),
   f,ensure_ascii=False,indent=2);f.write('\n')
 inputs();print('Prepared source only; no Java/AIR')
def main():
 if sys.argv[1:]==['--prepare']:prepare();return 0
 pins=inputs();loading=load(LOADING/'run.py','nativeui2_motion_bundle')
 old=original();_,base=old.legacy()
 if sys.argv[1:]==['--source-check']:
  print(json.dumps(dict(source_checked=True,enabled=['RConnectMod'],main_replacements=3,run_replacements=3,selector_replacements=1,host_argument_checks=4,
   compiled=False,air_started=False)));return 0
 def bundle_expanded(original_module):return replace(old.expanded(original_module)[0],RUN_EDITS),''
 def bundle_product(path,original_module,build,environment):
  assert Path(path).resolve()==loading.PRODUCT
  value=loading.candidate_bundle();assert value['installation']==build.installed()
  assert value['compile']['candidate_sha256']==loading.PRODUCT_SHA
  assert value['bridge']['host_sha256']=='2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
  product_pins=dict(value['pins']);product_pins.update(inputs())
  return dict(path=str(value['product']),sha256=loading.PRODUCT_SHA,version=value['meta']['version'],
   receipt=value['compile'],pins=product_pins,build_environment=value['meta']['installation_before'],
   runtime_environment=value['installation'],runtime_transition=value['environment'],
   game_path=value['bridge']['host'],game_sha256=value['bridge']['host_sha256'],
   host_proof=value['bridge'],loading_driver_proof=value['driver_proof'])
 module=types.ModuleType('nativeui2_motion_bound_only_rc');module.__file__=str(OLD/'run.py')
 module.bundle_expanded=bundle_expanded;module.bundle_product=bundle_product
 module.bundle_selector_path=HERE/'selector.py'
 exec(compile((HERE/'adapted-main.py.txt').read_text('utf8'),str(HERE/'adapted-main.py.txt'),'exec'),module.__dict__)
 if '--output' in sys.argv:
  output=(ROOT/Path(sys.argv[sys.argv.index('--output')+1])).resolve()
  assert output.parent==ROOT/'build/m52' and output.name.startswith('goal-rconnect-only-motion-nativeui2-')
 try:return module.main()
 except (loading.parent.builder.base.NotReady,base.NotReady) as e:
  print(json.dumps(dict(ready=False,checked=False,air_started=False,reason=str(e))));return 2
 finally:assert inputs()==pins
if __name__=='__main__':raise SystemExit(main())
