"""Exact existing dual motion fixtures with only RConnect enabled in copies."""
from pathlib import Path
import argparse,ast,difflib,hashlib,importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
PARENT=HERE.with_name('goal-jump-pose-held-regression')
PINS={PARENT/'run.py':'0a18bbef761340e78e37cfe16a514e33d3522240a403ed7ffec187ddc2e101e6',
 PARENT/'source-manifest.json':'0ed0714e15f3203ded5be9a5ed5657fcda98e5dfff52f67dcea4eccdd25cb397'}
SHARED=ROOT/'tools/run_coop_regression.py'
EDITS=(
 ("out.name.startswith('goal-self-echo-native-')","out.name.startswith('goal-rconnect-only-motion-')"),
 (" assert sha(RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'\n",
  " assert sha(SHARED_RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'\n only_rc_inputs()\n"),
 ('   if not settings:\n',"   if not settings and detail != 'Private module selection only; no AIR':\n"),
 ('    assert not record.children and not record.launching;verify_inputs()\n',
  "    selection_process=read(output/'selection/launcher-process.json')\n"
  "    assert selection_process['air_launch'] is False and selection_process['exit_code']==0\n"
  "    assert type(selection_process['pid']) is int and selection_process['pid']>0\n"
  "    assert len(record.children)==1 and record.children[0]['pid']==selection_process['pid']\n"
  "    from test_registry import gone\n"
  "    assert not record.launching and gone(record.children[0]);verify_inputs()\n"),
 ("{n.lower() for n in before if n.lower().startswith('mods/') and n.lower().endswith('.swf')}",
  "ONLY_RC_PATHS"))

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def save(p,v):
 with Path(p).open('x',encoding='utf8') as f:json.dump(v,f,ensure_ascii=False,indent=2);f.write('\n')
def load(p,name):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def legacy():
 for p,h in PINS.items():assert sha(p)==h,str(p)
 parent=load(PARENT/'run.py','only_rc_existing_product_binding')
 original=parent.legacy();parent.inputs(original)
 return parent,original
def expanded(original):
 old=original.expanded_run();new=old
 for before,after in EDITS:
  assert new.count(before)==1 and after not in new
  new=new.replace(before,after)
 restored=new
 for before,after in reversed(EDITS):restored=restored.replace(after,before)
 assert restored==old;ast.parse(new)
 return new,''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
  fromfile='frozen/native-motion.py',tofile='only-rc/native-motion.py'))
def inputs():
 parent,original=legacy();m=read(HERE/'source-manifest.json')
 assert m['kind']=='rconnect-only-dual-motion-v1' and m['run_replacements']==5 and m['selector_replacements']==4
 assert m['inputs']=={str(p):h for p,h in PINS.items()}
 for n,h in m['files'].items():assert sha(HERE/n)==h,n
 text,diff=expanded(original);assert (HERE/'expanded-run.py.txt').read_text('utf8')==text
 selector=load(HERE/'selector.py','only_rc_selector_preflight');st,sd=selector.source()
 assert (HERE/'expanded-selector.py.txt').read_text('utf8')==st
 sm=selector.load();sm.source()
 rows=sm.manifest_rows(ROOT.parents[1]/'mods/loader-manifest.txt')
 assert len(rows)==14 and set(rows)-sm.DISABLED=={'RConnectMod'}
 assert all(r['flags'][0]=='1' for r in rows.values()),'Unexpected installed selection'
 assert rows['RConnectMod']['path'].lower()=='mods/rconnect/release/rconnectmod.swf'
 pins=parent.inputs(original)|m['inputs']|{str(HERE/n):h for n,h in m['files'].items()}
 pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
 pins.update({str(p):h for p,h in sm.PINS.items()})
 return pins
def prepare():
 _,original=legacy();text,diff=expanded(original)
 selector=load(HERE/'selector.py','only_rc_selector_prepare');st,sd=selector.source()
 for n,t in {'expanded-run.py.txt':text,'run.diff':diff,'expanded-selector.py.txt':st,'selector.diff':sd}.items():
  with (HERE/n).open('x',encoding='utf8',newline='\n') as f:f.write(t)
 save(HERE/'source-manifest.json',dict(kind='rconnect-only-dual-motion-v1',run_replacements=5,selector_replacements=4,
  files={n:sha(HERE/n) for n in ('run.py','selector.py','README.md','expanded-run.py.txt','run.diff','expanded-selector.py.txt','selector.diff')},
  inputs={str(p):h for p,h in PINS.items()},enabled=['RConnectMod'],compiled=False,air_started=False,solo_supported=False,
  performanceQualified=False,smoothnessQualified=False))
 inputs();print('Prepared text only; no Java or AIR')
def main():
 if sys.argv[1:]==['--prepare']:prepare();return 0
 pins=inputs();parent,original=legacy();text,_=expanded(original)
 if sys.argv[1:]==['--source-check']:
  print(json.dumps(dict(source_checked=True,enabled=['RConnectMod'],solo_supported=False,air_started=False)));return 0
 peek=argparse.ArgumentParser(add_help=False);peek.add_argument('--output',type=Path);peek.add_argument('--check',action='store_true')
 peek.add_argument('--case',choices=('native-jump','fast-held'),required=True);args,_=peek.parse_known_args()
 base,environment=original.binding();analyzer=load(original.OLD/'analyze.py','only_rc_original_analyzer')
 def verify(out):
  proof=base.verify(out);proof['inputs']=proof['inputs']|inputs();return proof
 public=dict(vars(base));public['verify']=verify;build=types.SimpleNamespace(**public)
 def product(path):
  value=parent.selected_product(path,original,build,environment);value['pins'].update(inputs());return value
 scope={'__file__':str(original.OLD/'run.py'),'__name__':'only_rc_motion_bound_original',
  'CURRENT_BUILD':build,'ORIGINAL_SUMMARIZE':analyzer.summarize,'selfecho_product':product,
  'SHARED_RUNNER':SHARED,'only_rc_inputs':inputs,'ONLY_RC_PATHS':{'mods/rconnect/release/rconnectmod.swf'}}
 exec(compile(text,str(HERE/'expanded-run.py.txt'),'exec'),scope)
 scope['RUNNER']=HERE/'selector.py'
 assert scope['CASES']=={'native-jump':dict(seconds=300,done='native-jump',rounds=[0],checks={'host':6,'join':6}),
  'fast-held':dict(seconds=360,done='tele-motion',rounds=[0,1,2,3],checks={'host':43,'join':42})}
 if args.check:return scope['main']()
 assert args.output is not None;out=(ROOT/args.output).resolve()
 assert out.parent==ROOT/'build/m52' and out.name.startswith('goal-rconnect-only-motion-') and not out.exists()
 result=dict(passed=False,enabled=['RConnectMod'],solo_supported=False,performanceQualified=False,smoothnessQualified=False,installed=False)
 try:
  code=scope['main']();native=read(out/'result.json');result.update(original_exit_code=code,original_result_sha256=sha(out/'result.json'))
  assert code==0 and native['passed'] is True
  run=Path(native['run']);selection=read(run/'reduced-selection-result.json')
  assert selection['passed'] is True and selection['original_framework_passed'] is True
  assert selection['enabled']==['RConnectMod'] and set(selection['disabled'])==load(HERE/'selector.py','only_rc_expected').DISABLED
  assert set(selection['roles'])=={'host','join'}
  for role,row in selection['roles'].items():
   assert row['passed'] is True and row['err']==[] and row['requested']==row['ok']==['RConnectMod']
   assert sha(run/'selection'/(role+'-ModLoader.sol'))==row['status_sha256']
  receipt=read(run/'selection/selection-input.json')
  assert receipt['physical_files_retained'] is True and len(receipt['physical_modules'])==14
  assert receipt['enabled_paths']==['mods/rconnect/release/rconnectmod.swf']
  assert read(run/'reduced-installation-after.json')['unchanged'] is True
  result.update(passed=True,run=str(run),selection_sha256=sha(run/'reduced-selection-result.json'),
   physical_installation_entries=22,actual_enabled_count=1,roles=selection['roles'])
 except BaseException as e:result['error']=repr(e)
 finally:
  try:assert inputs()==pins;result['source_inputs_unchanged']=True
  except BaseException as e:result.update(passed=False,final_error=repr(e))
  if out.is_dir():save(out/'only-rc-result.json',result)
 print(json.dumps({k:result.get(k) for k in ('passed','run','error')},ensure_ascii=False));return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
