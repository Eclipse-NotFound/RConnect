"""B-only environment transaction; no games launched or stopped.
Stage is reviewable and does not install. Check/install verify exact functional
and performance evidence. Only two named B preferences may be reset. Player
IDs, saves, A and other projects are never write targets.
"""
from pathlib import Path
import argparse, importlib.util, json, os, shutil, subprocess, sys, uuid
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
d=load('b_release_common',ROOT/'experimental/b-field8-validation/transaction.py')
q=load('b_release_performance',HERE/'qualify-environment.py')
P=d.PLAYABLE; G=P/'game'; require=d.require
BASE_MANUAL='cccc90f4cf31bf97ec229467d62050a4d180f2a12d37dbbd3b432d17118a6581'
BASE_SWF='92ea5ec83aa1ab5a412581ba80ebbc49b16fb93a01c180df239b88a4f59b1af7'
PREFS={'SandevistanMod_config.txt':b'# B uses compiled default settings.\r\n','WallBlend.preferences.json':b'{"version":1,"mode":"current"}\r\n'}
REQUIRED={'addiction','injury','attachments','loading','horseshoe','textmotion','visualfield'}

def stamp(p):return d.sha(p) if p.is_file() else None
def folder(value,new=False):
 p=d.path(value);require(p.parent==ROOT/'build/ab' and p.name.startswith('b-clientenv-deploy-'),'Named B transaction directory required')
 if new:require(not p.exists(),'Keep previous transaction immutable')
 return p
def targets(key):
 if key.startswith('package/'):
  return d.member(P,key[len('package/'):])
 parts=key.split('/')
 require(len(parts)==3 and parts[0]=='preference' and parts[1] in ('1','2') and parts[2] in PREFS,'Unapproved personal target')
 return Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-b-player-'+parts[1])/'Local Store'/parts[2]
def atomic(target,data,expected):
 require(stamp(target)==expected,'Concurrent change: '+str(target));target.parent.mkdir(parents=True,exist_ok=True)
 if expected is not None:d.atomic_write(target,data,expected);return
 # New files use an exclusive create instead of replacing a concurrent file.
 with target.open('xb') as f:f.write(data);f.flush();os.fsync(f.fileno())
 require(d.sha(target)==d.digest(data),'New file readback mismatch')
def persist(out,r):d.atomic_write(out/'deployment.json',d.encode(r))
def selection(path,expected):
 selected=set()
 for line in path.read_text(encoding='utf-8-sig').splitlines():
  if line.strip() and not line.startswith('#'):
   parts=line.split('|');require(len(parts)==5,'Invalid loader row')
   if parts[2]=='1':selected.add(parts[1])
 require(selected==set(expected),'Wrong actual 1.02 selection')

def stage(a):
 out=folder(a.transaction,True);old=d.package();require(d.sha(P/'manual-input.json')==BASE_MANUAL and old['candidate_sha256']==BASE_SWF,'Installed B baseline changed')
 overlay=d.path(a.overlay);assembly=d.read(overlay/'assembly.json');d.verify(overlay,assembly['files'])
 pins={};build=d.build_info(a.candidate,pins)
 native_build=ROOT/'experimental/b-field-env-refresh/injury-native-sources-02/native-01/build.json'
 native_review=ROOT/'experimental/b-field-env-refresh/native-readback-review.json'
 nb=d.read(native_build);nr=d.read(native_review)
 require(nb['compiled'] and nb['installation_unchanged'] and nb['inputs_unchanged'] and nr['passed'],'Native patch verification failed')
 require(nb['candidate_sha256']==nr['compiled_candidate_sha256']==assembly['files']['pfe.swf'],'Native proof/binary differs')
 pins[d.rel(native_build)]=d.sha(native_build);pins[d.rel(native_review)]=d.sha(native_review)
 require(assembly['files']['mods/Rconnect/release/RConnectMod.swf']==build['candidate_sha256'],'Overlay/body differs')
 prepared_path=d.path(a.preparation);prep=d.read(prepared_path)
 require(prep['environment_sha256']==d.sha(overlay/'assembly.json'),'Functional preparation belongs to another overlay')
 require(set(assembly['disabled'])=={'ContinuousSceneMod','RealisticVisionMod','LightAndDarknessMod'},'Wrong disabled defaults')
 out.mkdir();staged=out/'staged';game=staged/'game'
 for name,h in assembly['files'].items():
  dst=d.member(game,name);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(overlay/name,dst);require(d.sha(dst)==h,'Staging copy differs')
 # The official launcher reads the descriptor to determine its 1.02 column.
 # This read-only baseline copy is staging context, not an installation change.
 shutil.copy2(G/'application.xml',game/'application.xml')
 # Keep a disabled selection for the legacy settings module still present in
 # the installed package, so a later launcher rescan cannot rediscover it on.
 legacy='mods/ModSettings/release/ModSettingsMod.swf'
 if (G/legacy).is_file():
  dest=game/legacy;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(G/legacy,dest)
 cmd=[str(game/'mods/ModLoader/RemainsModLauncher.exe'),'--root',str(game),'--only',','.join(assembly['enabled']),'--no-ui','--report',str(out/'selection.json')]
 selected=subprocess.run(cmd,capture_output=True,timeout=90);(out/'selection.log').write_bytes(selected.stdout+selected.stderr)
 require(selected.returncode==0,'Launcher failed; see staging selection.log');selection(game/'mods/loader-manifest.txt',assembly['enabled'])
 config=dict(old['config']);config.pop('rv',None)
 for key in ('tdfc','msw','sandy','injury','fa','addiction','environment'):config[key]=prep['test_config'][key]
 require(config['role']=='' and config['autoGame'] is False and config['probe'] is False,'Manual entry must stay manual')
 (game/'mods/Rconnect/release/config.txt').write_bytes(d.encode(config))
 notes=d.path(a.notes);require(notes.read_text(encoding='utf-8-sig').strip(),'Release notes required')
 readme=notes.read_bytes();(staged/'README.txt').write_bytes(readme)
 # Older historical manifests remain in the before copy rather than claiming
 # their old bridge-build receipts describe the new environment.
 updated=json.loads(json.dumps(old))
 for key in ('tdfc_manifest_sha256','extension_manifests','native_manifest_sha256'):updated.pop(key,None)
 updated.update(source_id=build['source_id'],candidate_sha256=build['candidate_sha256'],candidate_manifest_sha256=build['manifest_sha256'],
  readme_sha256=d.digest(readme),config=config,native_files={'pfe.swf':assembly['files']['pfe.swf']},
  environment_manifest=dict(path=d.rel(overlay/'assembly.json'),sha256=d.sha(overlay/'assembly.json')),
  local_field_gate_complete=False,parent_manifest=dict(path=d.rel(out/'before/package/manual-input.json'),sha256=BASE_MANUAL))
 for name in [*assembly['files'],'mods/loader-manifest.txt','mods/Rconnect/release/config.txt']:
  key=next((k for k in updated['files'] if k.lower()==name.lower()),name);updated['files'][key]=d.sha(game/name)
 deletes=[]
 for name in assembly['clear_only_in_isolated_test']:
  # Explicitly selected defaults permit clearing only these named active B
  # override files, with backup; never the user's source mod or save folder.
  require(name.startswith('mods/RModifier/config/') and Path(name).name in ('active.json','active.previous.json','map-pools.json'),'Unexpected reset path')
  if (G/name).is_file():deletes.append('package/game/'+name)
  for key in list(updated['files']):
   if key.lower()==name.lower():del updated['files'][key]
 (staged/'manual-input.json').write_bytes(d.encode(updated))
 validation=dict(experimental_only=True,candidate_ready_for_manual_testing=False,formal_release_gate_complete=False,local_field_gate_complete=False,
  source_id=build['source_id'],candidate_sha256=build['candidate_sha256'],environment=updated['environment_manifest'],manual_manifest_sha256=d.sha(staged/'manual-input.json'))
 (staged/'playable-validation.json').write_bytes(d.encode(validation))
 writes={}
 for f in game.rglob('*'):
  if f.is_file() and ('/work/' not in f.as_posix()):
   name=f.relative_to(staged).as_posix()
   # Only reviewed assembly files + the explicitly generated manifest/config.
   if f.relative_to(game).as_posix().lower() in {x.lower() for x in [*assembly['files'],'mods/loader-manifest.txt','mods/Rconnect/release/config.txt']}:
    writes['package/'+name]=dict(source=str(f),after=d.sha(f))
 for name in ('README.txt','manual-input.json','playable-validation.json'):writes['package/'+name]=dict(source=str(staged/name),after=d.sha(staged/name))
 for role in ('1','2'):
  for name,data in PREFS.items():
   key='preference/'+role+'/'+name;target=targets(key)
   if target.exists():
    f=out/'staged-preferences'/role/name;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data);writes[key]=dict(source=str(f),after=d.sha(f))
 for key in deletes:writes[key]=dict(source=None,after=None)
 for key,v in writes.items():v['before']=stamp(targets(key))
 original=d.canonical(old['files']);changed={key[len('package/game/'):].lower() for key in writes if key.startswith('package/game/')}
 preserved={d.rel(G/name):h for name,h in original.items() if name not in changed}
 for item in old['launchers']:
  for key in ('descriptor','launcher'):preserved[d.rel(P/item[key])]=item[key+'_sha256']
 for name,h in pins.items():require(d.sha(ROOT/name)==h,'Build changed')
 plan=dict(schema='b-client-environment-transaction-1',created=d.utc(),status='staged',target=d.rel(P),candidate=build,
  overlay=d.rel(overlay),overlay_sha256=d.sha(overlay/'assembly.json'),preparation=d.rel(prepared_path),preparation_sha256=d.sha(prepared_path),
  baseline_manifest_sha256=BASE_MANUAL,writes=writes,preserved=preserved,build_pins=pins,script_sha256=d.sha(__file__),applied=[])
 shutil.copy2(__file__,out/'release-executed.py');persist(out,plan)
 return dict(status='staged_not_installed',transaction=d.rel(out),changes=len(writes))

def test_record(result,preparation,plan,installed=False):
 result=d.path(result);prep_path=d.path(preparation);r=d.read(result);prep=d.read(prep_path);folder=result.parent
 require(r.get('passed') and r.get('complete') and r.get('runtime_unchanged') and r.get('private_desktop') and not r.get('error'),'Test failed or incomplete: '+str(result))
 require(d.sha(prep_path)==r['preparation_sha256'] and prep['environment_sha256']==plan['overlay_sha256'],'Wrong preparation/environment')
 require(r['candidate_sha256']==plan['candidate']['candidate_sha256'],'Wrong tested B binary')
 assembly=d.read(ROOT/plan['overlay']/'assembly.json');runtime=d.canonical(r['runtime_files'])
 for name,h in assembly['files'].items():require(runtime.get(name.lower())==h,'Wrong runtime environment file: '+name)
 for name,h in d.canonical(prep['files']).items():
  if name not in d.RUNTIME_MUTABLE:require(runtime.get(name)==h,'Unrelated test dependency differs')
 require(set(r['roles'])=={'host','join'},'Two test roles required')
 require(r['seed_hashes']=={role:v['sha256'] for role,v in prep['seeds'].items()},'Copied seed differs')
 for role,v in prep['seeds'].items():require(d.sha(prep_path.parent/(role+'-save0.sol'))==v['sha256'],'Frozen test seed changed')
 source=d.path(prep['compiler_command'][-1]);require(d.sha(source)==prep['driver'],'Observer changed');d.verify(source.parent,prep['helpers'])
 require(d.sha(folder/'runner.py')==r['runner_sha256'],'Runner changed')
 counts={}
 for role,e in r['roles'].items():
  require(e['done'] and e['passed']>0 and e['failed']==0 and not e['fatal'],'Failed test role')
  require(e['appid'].startswith('pfe-modsettings-rconnect-b-startup-'+role+'-'),'Not isolated test')
  d.verify(folder,e['logs']);rows=d.events(folder/(role+'.BStartupDriver.log'));game=d.events(folder/(role+'.RConnect-B.log'))
  require(not any(v['kind'] in ('FAIL','FATAL','ERROR') for v in rows+game),'Error in retained logs')
  identity=d.one(rows,'installed');require(identity==dict(scenario=r['scenario'],role=role,source=plan['candidate']['source_id'],version=plan['candidate']['version']),'Loaded identity differs')
  require(d.one(rows,'DONE')==dict(passed=e['passed'],failed=0) and rows[-1]['kind']=='DONE' and sum(v['kind']=='PASS' for v in rows)==e['passed'],'Incomplete assertions')
  counts[role]=e['passed']
 if installed:
  require(d.path(r['candidate_path'])==G/'mods/Rconnect/release/RConnectMod.swf' and d.path(r['native_source'])==G/'pfe.swf','Smoke must use installed bytes')
  require(prep.get('installed_transaction')==d.rel(d.path(plan['transaction'])),'Smoke environment was not copied from installation')
 return dict(result=d.rel(result),sha256=d.sha(result),preparation=d.rel(prep_path),preparation_sha256=d.sha(prep_path),scenario=r['scenario'],checks=counts)

def readplan(out):
 r=d.read(out/'deployment.json');require(r['schema']=='b-client-environment-transaction-1' and r['target']==d.rel(P),'Wrong transaction')
 require(r['script_sha256']==d.sha(__file__)==d.sha(out/'release-executed.py'),'Use original transaction script')
 return r
def checks(out,a):
 p=readplan(out);require(p['status']=='staged','Not an uninstalled staged transaction')
 require(d.sha(P/'manual-input.json')==p['baseline_manifest_sha256'],'Installed package changed');d.package()
 for key,v in p['writes'].items():
  require(stamp(targets(key))==v['before'],'Concurrent target change: '+key)
  if v['source']:require(d.sha(v['source'])==v['after'],'Staged source changed')
 d.verify(ROOT,p['preserved']);d.verify(ROOT,p['build_pins'])
 require(d.sha(ROOT/p['overlay']/'assembly.json')==p['overlay_sha256'],'Overlay receipt changed')
 spec=d.read(d.path(a.tests));tests=[test_record(x['result'],x['preparation'],p) for x in spec]
 require(REQUIRED<={x['scenario'] for x in tests},'Missing changed-feature checks')
 performance=d.read(d.path(a.performance));require(performance==q.evaluate(performance['series']) and performance['qualified'],'Performance comparison failed or cannot be reproduced')
 require(performance['candidate_sha256']==p['candidate']['candidate_sha256'],'Performance candidate differs')
 return p,dict(tests=tests,performance=dict(path=d.rel(d.path(a.performance)),sha256=d.sha(d.path(a.performance))),checked=d.utc())

def rollback(out,p):
 for key,v in p['writes'].items():
  require(stamp(targets(key)) in {v['before'],v['after'],*v.get('final',[])},'Concurrent edit prevents rollback: '+key)
  if v['before'] is not None:require(d.sha(out/'before'/key)==v['before'],'Backup changed')
 for key,v in reversed(list(p['writes'].items())):
  target=targets(key);now=stamp(target)
  if now==v['before']:continue
  if v['before'] is None:
   # A single transaction-created file, never a recursive directory removal.
   require(now==v['after'],'Unexpected new file');target.unlink()
  else:atomic(target,(out/'before'/key).read_bytes(),now)
 d.package();p['status']='rolled_back';persist(out,p)

def install(out,a):
 with d.package_lock():
  p,evidence=checks(out,a);p.update(evidence=evidence,root_witness=d.root_game_snapshot(),transaction=d.rel(out))
  for key,v in p['writes'].items():
   if v['before'] is not None:
    backup=out/'before'/key;backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(targets(key),backup);require(d.sha(backup)==v['before'],'Backup differs')
  p['status']='installing';persist(out,p)
  try:
   for key,v in p['writes'].items():
    target=targets(key)
    if v['source'] is None:
     require(stamp(target)==v['before'],'Concurrent deletion target change');target.unlink()
    else:atomic(target,Path(v['source']).read_bytes(),v['before'])
    p['applied'].append(key);persist(out,p)
   d.package();d.verify(ROOT,p['preserved']);d.check_root_game(p['root_witness'])
   p.update(status='installed_pending_smoke',installed_utc=d.utc());persist(out,p)
  except Exception as e:
   p['error']=str(e);persist(out,p);rollback(out,p);raise
 return dict(status=p['status'],transaction=d.rel(out))

def finalize(out,a):
 with d.package_lock():
  p=readplan(out);require(p['status']=='installed_pending_smoke','Not awaiting smoke')
  for key,v in p['writes'].items():require(stamp(targets(key))==v['after'],'Installed file changed: '+key)
  try:
   smoke=test_record(a.smoke,a.preparation,p,True);require(smoke['scenario']=='ui','Expected minimal installed UI/room smoke')
   d.verify(ROOT,p['preserved']);manual=d.package();manual['local_field_gate_complete']=True
   validation=d.read(P/'playable-validation.json');validation.update(candidate_ready_for_manual_testing=True,local_field_gate_complete=True,
    evidence=p['evidence'],installed_smoke=smoke,rollback=d.rel(out/'deployment.json'))
   content={'manual-input.json':d.encode(manual)};validation['manual_manifest_sha256']=d.digest(content['manual-input.json']);content['playable-validation.json']=d.encode(validation)
   for name,data in content.items():p['writes']['package/'+name]['final']=[d.digest(data)]
   p['status']='finalizing';persist(out,p)
   for name,data in content.items():
    v=p['writes']['package/'+name];atomic(P/name,data,v['after']);v['after']=d.digest(data)
   d.package();p.update(status='verified',finished=d.utc(),smoke=smoke,root_after=d.root_game_snapshot());persist(out,p)
  except Exception as e:p['error']=str(e);persist(out,p);rollback(out,p);raise
 return dict(status=p['status'],transaction=d.rel(out))

def main():
 ap=argparse.ArgumentParser();sub=ap.add_subparsers(dest='action',required=True)
 s=sub.add_parser('stage')
 for name in ('transaction','candidate','overlay','preparation','notes'):s.add_argument('--'+name,required=True)
 for action in ('check','install'):
  s=sub.add_parser(action)
  for name in ('transaction','tests','performance'):s.add_argument('--'+name,required=True)
 s=sub.add_parser('finalize')
 for name in ('transaction','smoke','preparation'):s.add_argument('--'+name,required=True)
 s=sub.add_parser('rollback');s.add_argument('--transaction',required=True)
 a=ap.parse_args()
 if a.action=='stage':result=stage(a)
 elif a.action=='check':p,e=checks(folder(a.transaction),a);result=dict(status='ready',evidence=e)
 elif a.action=='install':result=install(folder(a.transaction),a)
 elif a.action=='finalize':result=finalize(folder(a.transaction),a)
 else:
  out=folder(a.transaction);p=readplan(out)
  with d.package_lock():rollback(out,p)
  result=dict(status=p['status'])
 print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
