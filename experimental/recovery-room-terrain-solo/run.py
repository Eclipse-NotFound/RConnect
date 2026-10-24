"""Single-process mechanism evidence through the unchanged shared AIR runner."""
from pathlib import Path
import argparse, contextlib, importlib.util, json, os, re, shutil, sys, traceback, xml.etree.ElementTree as ET
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('terrain_solo_prepare',HERE/'prepare.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
PREFERENCE=b'{"nativeEnabled":true}'

def review_reason(lines,result):
 rows=[json.loads(line.split('RConnectRoomTiming restore ',1)[1]) for line in lines if line.startswith('RConnectRoomTiming restore ')]
 rows=[value for value in rows if 'terrainReuseReason' in value]
 assert len(rows)==1,'Expected one first-large restore diagnostic'
 value=rows[0];reason=value['terrainReuseReason'];target=result['target']
 assert value['key']==target['key'] and (reason['width'],reason['height'])==(target['width'],target['height'])
 assert reason['schema']=='first-terrain-reuse-reason-v1' and reason['complete'] is True
 assert reason['performanceQualified'] is False and reason['faultCount']==0 and reason['faults']==[]
 for name in ('viewCreated','constructorValid','unchangedCalled','reused','reuseGuardDirty'):assert type(reason[name]) is bool
 order=['retained','dirty','incomingWallPaint','localWallPaint'];seen=reason['admission'];size=len(seen)
 assert 1<=size<=4 and set(seen)==set(order[:size]) and all(type(v) is bool for v in seen.values())
 assert all(seen[name] for name in order[:size-1])
 if not seen[order[size-1]]:
  assert not reason['viewCreated'] and reason['first']['stage']=='admission' and reason['first']['field']==order[size-1]
  assert reason['first']['expected'] is True and reason['first']['actual'] is False
 else:assert size==4 and reason['viewCreated']
 if reason['reused']:
  assert reason['first'] is None and all(reason[n] for n in ('viewCreated','constructorValid','unchangedCalled','reuseGuardDirty'))
 elif reason['first'] is None:
  assert not reason['reuseGuardDirty'] and reason['viewCreated'] and reason['constructorValid'] and not reason['unchangedCalled']
 else:
  first=reason['first'];assert set(first)=={'stage','field','expected','actual','x','y','index'}
  assert first['stage'] in ('admission','constructor','unchanged','style','backdrop','tile') and first['field']
  if first['stage']=='tile':assert 0<=first['x']<reason['width'] and 0<=first['y']<reason['height']
 assert reason['reused']==(value.get('terrainReused') is True)
 assert 0<=value['beforeRole']<=value['role']<=value['total']
 return value

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--driver',type=Path);ap.add_argument('--output',type=Path)
 ap.add_argument('--check',action='store_true');ap.add_argument('--registry-wait',type=float,default=900)
 args=ap.parse_args();assert args.registry_wait>=0
 rejected_output=None
 if not args.check:
  assert args.output is not None and args.driver is not None
  rejected_output=(p.ROOT/args.output).resolve();assert rejected_output.parent==p.M52 and not rejected_output.exists()
 try:
  base_pins=p.inputs();pins=dict(base_pins);pins.update({str(Path(__file__)):p.sha(__file__)})
  before=p.installation();driver=None if args.driver is None else (p.ROOT/args.driver).resolve()
  if driver is not None:
   assert p.verify(driver)['compiled'] is True
   pins.update({str(driver/name):p.sha(driver/name) for name in ('prepared.json','compile.json','EffectsDriver.swf','EffectsHarness.swf','driver-input.json')})
 except BaseException as exc:
  if rejected_output is not None:
   rejected_output.mkdir();p.save(rejected_output/'result.json',dict(passed=False,stage='preflight',air_started=False,
    mechanism_only=True,multiplayer_qualified=False,performance_qualified=False,error=str(exc),traceback=traceback.format_exc()))
  raise
 if args.check:
  assert args.output is None;print(json.dumps(dict(checked=True,driver_compiled=driver is not None,air_started=False)));return 0
 assert driver is not None and args.output is not None
 out=(p.ROOT/args.output).resolve();assert out.parent==p.M52 and not out.exists();out.mkdir()
 result=dict(passed=False,mechanism_only=True,multiplayer_qualified=False,performance_qualified=False,run=None,inputs=pins,
  installation_before=before,candidate_sha256=p.PRODUCT_SHA,runner_success=False,diagnostic_complete=False)
 p.save(out/'intent.json',dict(result,driver=str(driver),telemetry_source=str(p.TELEMETRY),telemetry_sha256=p.sha(p.TELEMETRY)))
 sys.path.insert(0,str(p.ROOT/'tools'));runner=p.load('terrain_solo_shared_runner',p.RUNNER)
 original_run=runner.run_registered;run_path=None;extra={};extra_errors=[]
 def registered(native,parser,output,record):
  nonlocal run_path
  run_path=output.resolve();result['run']=str(run_path)
  assert run_path.parent==(p.ROOT/'build/cooperation').resolve() and re.fullmatch('[0-9a-f]{10}',run_path.name)
  assert native.solo and native.all_mods and native.effects and native.private_desktop and native.require_exclusive_air
  assert not native.keep_copies and not native.connect_after_load and native.land==''
  assert Path(native.candidate).resolve()==p.PRODUCT/'RConnectMod.swf' and Path(native.effects_driver).resolve()==driver
  assert Path(native.host_save_template).resolve()==p.TEMPLATE and native.join_save_template is None
  before_launch=record.before_launch;child_stopped=record.child_stopped;prepared=False;after_saved=False
  def launch(detail):
   nonlocal prepared
   assert not prepared and not record.children and not record.launching
   assert p.installation()==before and p.inputs()==base_pins
   descriptor=output/'host/coop.xml';xml=ET.fromstring(descriptor.read_bytes());ns='{http://ns.adobe.com/air/application/30.0}'
   appid='pfe-modsettings-rconnect-coop-host-'+output.name
   assert xml.tag==ns+'application' and xml.findtext(ns+'id')==appid and xml.findtext(ns+'initialWindow/'+ns+'content')=='pfe.swf'
   original_input=p.read(output/'input.json');assert p.sha(descriptor)==original_input['descriptors']['host']
   assert original_input['solo'] is True and original_input['minimum_start_gib']==3
   inputs=original_input['inputs'];assert set(inputs)=={'host'} and inputs['host']['production']==p.PRODUCT_SHA
   assert inputs['host']['game']==before['pfe.swf'] and inputs['host']['driver']==p.sha(driver/'EffectsDriver.swf')
   modules={k.replace('\\','/').lower():v for k,v in inputs['host']['modules'].items()}
   for name,digest in before.items():
    if name.endswith('.swf') and name!='pfe.swf' and '/Rconnect/' not in name:assert modules[name.lower()]==digest,name
   app_root=Path(os.environ['APPDATA']).resolve()/appid;storage=app_root/'Local Store'
   preference=storage/'ContinuousScene.preferences.json';target=output/'host/mods/ModLoader/release/telemetry.json'
   assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()
   assert target.resolve().is_relative_to((output/'host').resolve()) and not target.exists()
   telemetry=p.TELEMETRY.read_bytes();assert p.sha(p.TELEMETRY)==p.FIXED[p.TELEMETRY]
   storage.mkdir(parents=True,exist_ok=True);preference.write_bytes(PREFERENCE)
   with target.open('xb') as stream:stream.write(telemetry)
   extra.update(app_id=appid,storage=str(storage),preference=str(preference),telemetry_copy=str(target),
    before_any_air=True,preference_sha256=p.sha(preference),telemetry_sha256=p.sha(target),
    telemetry_source_sha256=p.sha(p.TELEMETRY),original_input_sha256=p.sha(output/'input.json'))
   p.save(out/'supplemental-input.json',extra);prepared=True;before_launch(detail)
  def stopped():
   nonlocal after_saved
   try:
    if prepared and not after_saved:
     after_saved=True
     # Original runner has reaped its processes; copies still exist until this callback returns.
     copy=Path(extra['telemetry_copy']);preference=Path(extra['preference'])
     after=dict(telemetry_copy_sha256=p.sha(copy),telemetry_source_sha256=p.sha(p.TELEMETRY),
      preference_sha256=p.sha(preference),before_owned_copy_cleanup=True)
     raw_files={};store=Path(extra['storage']).resolve(strict=True)
     expected=(Path(os.environ['APPDATA'])/extra['app_id']/'Local Store').resolve(strict=True);assert store==expected
     for name in ('terrain-roundtrip-result.json','terrain-roundtrip-snapshot.txt'):
      source=store/name
      if source.exists():
       assert source.resolve(strict=True).parent==store;shutil.copyfile(source,out/name);raw_files[name]=p.sha(out/name)
     after['raw_files']=raw_files
     after['unchanged']=(after['telemetry_copy_sha256']==after['telemetry_source_sha256']==extra['telemetry_sha256']
      and preference.read_bytes()==PREFERENCE)
     p.save(out/'supplemental-after.json',after)
     if not after['unchanged']:extra_errors.append('Supplemental configuration changed')
   except Exception as exc:extra_errors.append(repr(exc))
   finally:child_stopped()
  record.before_launch=launch;record.child_stopped=stopped
  try:return original_run(native,parser,output,record)
  finally:
   record.before_launch=before_launch;record.child_stopped=child_stopped
   if prepared and not after_saved:extra_errors.append('Missing post-process supplemental observation')
 runner.run_registered=registered;old_argv=sys.argv
 try:
  sys.argv=[str(p.RUNNER),'--candidate',str(p.PRODUCT/'RConnectMod.swf'),'--solo','--all-mods','--effects',
   '--effects-driver',str(driver),'--host-save-template',str(p.TEMPLATE),'--seconds','360','--expected-version',p.VERSION,
   '--private-desktop','--defer-visible','--require-exclusive-air','--registry-wait',str(args.registry_wait)]
  p.save(out/'command.json',dict(argv=sys.argv,original_runner_sha256=p.sha(p.RUNNER),overrides=['before_launch','child_stopped evidence only']))
  class Tee:
   def __init__(self,log,console):self.log=log;self.console=console
   def write(self,text):self.log.write(text);self.console.write(text);return len(text)
   def flush(self):self.log.flush();self.console.flush()
  with (out/'runner.log').open('x',encoding='utf-8') as log,contextlib.redirect_stdout(Tee(log,sys.stdout)):
   try:runner.main()
   except SystemExit as exc:result['exit_code']=exc.code if type(exc.code) is int else 1;result['runner_exit_detail']=str(exc.code)
  assert result.get('exit_code')==0,'Original shared runner did not pass'
  assert run_path is not None and p.read(run_path/'registry-result.json')['passed'] is True
  assert not extra_errors and p.read(out/'supplemental-after.json')['unchanged'] is True
  result['runner_success']=True
  for name in ('terrain-roundtrip-result.json','terrain-roundtrip-snapshot.txt'):
   assert p.sha(out/name)==p.read(out/'supplemental-after.json')['raw_files'][name]
  row=p.read(out/'terrain-roundtrip-result.json');lines=(run_path/'host.log').read_text(encoding='utf-8-sig').splitlines()
  raw=[json.loads(line.split('TERRAIN ROUNDTRIP RESULT ',1)[1]) for line in lines if line.startswith('TERRAIN ROUNDTRIP RESULT ')]
  assert len(raw)==1 and raw[0]==row and row['passed'] is True and row['failed']==0 and row['problem']==''
  assert row['phase']=='done' and row['lastPhase']=='render' and row['reloads']==row['restores']==1 and row['renderFrames']==2
  assert row['mechanismOnly'] is True and row['multiplayerQualified'] is False and row['performanceQualified'] is False
  assert row['cleanup']['errors']==[] and all(row['cleanup'][key] is True for key in ('seedRestored','sceneRestored','slotUnchanged'))
  assert len(row['constructors'])==2 and row['source']['seed']==row['target']['seed']==1380142925
  assert row['source']['merged'] and row['target']['merged']
  assert all(row['source'][key]==row['target'][key] for key in ('key','width','height','seed'))
  reason=review_reason(lines,row);p.save(out/'terrain-reason.json',reason)
  for name in ('host','join','frozen'):assert not (run_path/name).exists(),'Owned copy retained'
  result.update(passed=True,diagnostic_complete=True,driver_result=row,restore=reason,
   original_run_sha256=p.sha(run_path/'run.json'),original_input_sha256=p.sha(run_path/'input.json'),
   original_log_sha256=p.sha(run_path/'host.log'),snapshot_sha256=p.sha(out/'terrain-roundtrip-snapshot.txt'))
 except BaseException as exc:result.update(passed=False,error=str(exc),traceback=traceback.format_exc())
 finally:
  sys.argv=old_argv;runner.run_registered=original_run;result['supplemental_errors']=extra_errors
  try:
   assert p.installation()==before
   for path,digest in pins.items():assert p.sha(path)==digest,path
   result.update(installation_unchanged=True,inputs_unchanged=True)
  except Exception as exc:result.update(passed=False,final_error=str(exc))
  p.save(out/'result.json',result)
 print(json.dumps(dict(passed=result['passed'],mechanism_only=True,performance_qualified=False,run=result['run'],error=result.get('error')),ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
