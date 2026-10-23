"""Exact BF6 entry-room suite with roomfix2 and the actual installed 80CF host."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,sys,traceback
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
from prepare import ROOT,M52,GAME,RUNNER,sha,read,save,installation
HERE=Path(__file__).resolve().parent
PRODUCT=M52/'recovery-room-production-02'
DRIVERS=M52/'recovery-entry-observer-driver-01'
FRAMEWORK=ROOT/'experimental/recovery-first-raster-native/run_native.py'
OBSERVER=ROOT/'experimental/recovery-room-entry-observer/prepare.py'
PRODUCT_SHA='c26b1aa7dccf6e96c4027f551332a2b55d413467b24311426a20c8d341058cc0'
PINS={FRAMEWORK:'69d6e237b642821479f6d05c9af9a74f7cd62a4884578d4072fbeb7b7402ea6a',
 OBSERVER:'7188e9c0fb06b80020b50cea6d7f1d5df8eb3aca2506643bf4e0a35f8597f5e2',
 RUNNER:'7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
 DRIVERS/'prepared.json':'ae5c4035054e4474baa94a1003b0d9a32261bc8df82be0edd09255bdc69abc55',
 DRIVERS/'entry-room/EffectsDriver.swf':'bf6c9567010d93dd20b334df3da7ed069e168583a2f45868a8d4352bc0e553ba'}
def load(path,name):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def product_audit(path):
 assert path.resolve()==PRODUCT.resolve()
 built=read(path/'compile.json');prepared=read(path/'prepared.json');current=installation()
 assert built['compiled'] is True and built['sources_unchanged'] is True
 assert built['installation_unchanged'] is True and built['installation_before']==built['installation_after']==current
 assert all(c['exit_code']==0 for c in built['commands'])
 assert sha(path/'RConnectMod.swf')==built['candidate_sha256']==PRODUCT_SHA
 assert prepared['kind']=='room-repair-overlay' and prepared['version']=='0.2.24-roomfix2'
 for n,h in prepared['source'].items():assert sha(path/'src'/n)==h,n
 return built
def preflight():
 for p,h in PINS.items():assert sha(p)==h,str(p)
 product_audit(PRODUCT)
 sys.path.insert(0,str(OBSERVER.parent));observer=load(OBSERVER,'current_room_observer_exact_preparation')
 observer.verify_driver(DRIVERS,read(DRIVERS/'prepared.json'),'entry-room')
 return observer
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path);ap.add_argument('--check',action='store_true')
 ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args();assert a.registry_wait>=0
 observer=preflight();before=installation()
 if a.check:
  assert a.output is None;print(json.dumps(dict(passed=True,read_only=True,driver_sha256=PINS[DRIVERS/'entry-room/EffectsDriver.swf'],candidate_sha256=PRODUCT_SHA,host_sha256=before['pfe.swf'])));return 0
 assert a.output is not None
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists()
 pins={str(p):sha(p) for p in [*PINS,Path(__file__),HERE/'prepare.py',PRODUCT/'prepared.json',PRODUCT/'compile.json',PRODUCT/'RConnectMod.swf']}
 sys.path.insert(0,str(FRAMEWORK.parent));sys.path.insert(0,str(ROOT/'tools/validation'))
 framework=load(FRAMEWORK,'current_installed_entry_room_framework')
 framework.audit=product_audit;framework.verify_driver=observer.verify_driver
 # This existing optional branch selects the real installed host. It does not
 # call old host_input or assign a historical isolated-host qualification.
 argv=[str(FRAMEWORK),'--candidate',str(PRODUCT),'--drivers',str(DRIVERS),'--game-candidate','',
  '--scenario','entry-room','--output',str(out),'--registry-wait',str(a.registry_wait)]
 previous=sys.argv;result=dict(passed=False,performance_qualified=False,installed=False,air_started=False,
  candidate_sha256=PRODUCT_SHA,host_sha256=before['pfe.swf'],driver_sha256=PINS[DRIVERS/'entry-room/EffectsDriver.swf'],
  native_host_override=False,original_assertions_unchanged=True,inputs=pins,framework_argv=argv)
 try:
  sys.argv=argv;framework.main()
  original=read(out/'result.json');assert original['passed'] is True and original['exit_code']==0
  run=ROOT/'build/cooperation'/original['run'];assert run.parent==(ROOT/'build/cooperation')
  native=read(run/'run.json');result.update(run=str(run),air_started=bool(native['pids']),original_result_sha256=sha(out/'result.json'),run_sha256=sha(run/'run.json'))
  assert native['sha256']==PRODUCT_SHA and native['private_desktop'] is True and native['defer_visible'] is True and native['solo'] is False
  assert sha(run/'input.json')==native['input_manifest_sha256'] and set(native['inputs'])=={'host','join'}
  installed={n.lower():h for n,h in before.items()};harness=sha(DRIVERS/'entry-room/EffectsHarness.swf')
  for role,values in native['inputs'].items():
   assert values['game']==before['pfe.swf'] and values['production']==PRODUCT_SHA
   assert values['driver']==PINS[DRIVERS/'entry-room/EffectsDriver.swf'] and values['harness']==harness
   for n,h in values['modules'].items():
    key=n.replace('\\','/').lower();assert h==(harness if key=='mods/rconnect/release/rconnectmod.swf' else installed[key]),n
   for n,h in values.get('mod_assets',{}).items():assert h==installed[n.replace('\\','/').lower()],n
   text=(run/(role+'.log')).read_text(encoding='utf-8-sig')
   assert 'COOP EFFECTS DONE rooms '+role in text
  memory=read(run/'memory-timeline.json');assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
  assert memory['minimum_commit_bytes']==512*1024**2 and read(run/'memory-before.json')['free_commit_bytes']>=6*1024**3
  assert not read(run/'air-before.json') and all(not (run/n).exists() for n in ('host','join','frozen'))
  result['passed']=True
 except BaseException as e:result.update(error=str(e),traceback=traceback.format_exc())
 finally:
  sys.argv=previous
  try:
   preflight();assert installation()==before
   for n,h in pins.items():assert sha(n)==h,n
   result.update(inputs_unchanged=True,installation_unchanged=True)
  except Exception as e:result.update(passed=False,final_verification_error=str(e))
  if out.is_dir():save(out/'adapter-result.json',result)
 print(json.dumps({k:v for k,v in result.items() if k not in ('inputs','framework_argv','traceback')},ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
