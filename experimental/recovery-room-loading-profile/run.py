"""Original scene/native assertions plus separate bounded CPU evidence review."""
from pathlib import Path
import argparse,importlib.util,json,os,shutil,sys,traceback,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];REVIEW=HERE.parent/'recovery-room-repair-review'

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path)
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

prepared=load('room_loading_profile_preparation',HERE/'prepare.py')
sha,read,save=prepared.sha,prepared.read,prepared.save
SCENE=REVIEW/'run_scene_v3.py'
NATIVE=REVIEW/'run_native_v3.py'
PRODUCT=prepared.M52/'recovery-room-production-03'
CANDIDATE='43277b92dc5e556702d64754c6976dd10a032008719851b71bbeb566d3104011'

def preflight(drivers):
 meta=prepared.verify(drivers)
 assert sha(HERE/'prepare.py')=='8adc7275773f5f2f56932bd2f7d9ad405988020a0622713a6d3d767872c44dab'
 assert sha(SCENE)=='2dc491e41c17b6f17052e229d2a0c07f44771a4f933f3a4c6e2d33b21de20b67'
 assert sha(NATIVE)=='511b0c64286742af371bb30e6368abd1f3f8712039e439d516c6de5b1dea8a8f'
 assert sha(REVIEW/'scene_v2_launcher.py')=='7b0ad823735d081b4df8d770efc61f9ff590e3f4022aaf946658bb17ac05b3d9'
 assert sha(PRODUCT/'RConnectMod.swf')==CANDIDATE
 assert sha(PRODUCT/'prepared.json')=='8fcf0337facd5fdb7cf328edc5382c4c32dae3846003ec7b5b3a5ee565ddb1ea'
 assert sha(PRODUCT/'compile.json')=='9bdc15536e5ae3d0db2206d2f0286a441086cc94023e119b9f99dfaf998ecfa7'
 pins={str(p):sha(p) for p in (Path(__file__),SCENE,NATIVE,REVIEW/'scene_v2_launcher.py',drivers/'prepared.json',
  prepared.BASE/'prepared.json',PRODUCT/'prepared.json',PRODUCT/'compile.json',PRODUCT/'RConnectMod.swf')}
 pins.update(meta['inputs'])
 for n,h in meta['files'].items():pins[str(drivers/n)]=h
 return meta,pins

def review_profile(out,run):
 receipt=read(run/'scene-preference-input.json');role=receipt['roles']['join']
 app_id='pfe-modsettings-rconnect-coop-join-'+run.name
 assert role['app_id']==app_id
 expected=(Path(os.environ['APPDATA'])/app_id/'Local Store').resolve(strict=True)
 observed=Path(role['path']).resolve(strict=True).parent
 assert observed==expected,'Private profile path differs from the exact join application storage'
 source=expected/'room-loading-profile.json';assert source.is_file()
 destination=out/'join-room-loading-profile.json';assert not destination.exists()
 shutil.copyfile(source,destination);assert sha(source)==sha(destination)
 value=read(destination);identity=value['identity'];windows=value['windows']
 assert value['kind']=='room-loading-cpu-v1' and value['complete'] is True
 assert value['errors']==[] and value['performanceQualified'] is False
 assert value['sampleInternalAllocs'] is False and value['collectionOutsideSampling'] is True
 assert (value['sampleLimit'],value['keyLimit'],value['stackDepthLimit'])==(32768,2048,64)
 assert identity['appId']==app_id and identity['role']=='join' and identity['version']=='0.2.24-roomfix3'
 assert identity['land']=='random_mane' and identity['curLand']=='random_mane'
 assert identity['key']==identity['room'] and isinstance(identity['barrier'],int) and identity['barrier']>0
 assert [(w['kind'],w['index'],w['termination']) for w in windows]==[
  ('grant',0,'handler-returned'),('enter-to-render',1,'render'),('enter-to-render',2,'render')]
 prior=None
 for w in windows:
  assert w['complete'] is True and w['windowComplete'] is True and w['truncated'] is False
  assert 0<=w['begin']<=w['startReturned']<=w['end']<=w['pausedAt']<=w['collectionEnd']
  assert w['beginUtc']<=w['endUtc'] and w['collectionMs']==w['collectionEnd']-w['end']
  if prior is not None:assert prior<=w['begin']
  prior=w['collectionEnd']
  if w['kind']=='enter-to-render':assert w['startReturned']<=w['enterTail']<=w['end']
  assert isinstance(w['samples'],int) and 0<w['samples']==w['visited']<=32768
  assert isinstance(w['cpu'],int) and w['cpu']>0 and isinstance(w['deleted'],int) and w['deleted']>=0
  assert len(w['stacks'])<=2048 and len(w['allocations'])<=2048
  assert all(isinstance(n,int) and n>0 for n in w['stacks'].values())
  assert sum(w['stacks'].values())==w['cpu']
  allocated=0
  for a in w['allocations'].values():
   assert isinstance(a['count'],int) and a['count']>0 and a['bytes']>=0
   allocated+=a['count']
  assert allocated+w['cpu']+w['deleted']==w['visited']
 return dict(complete=True,source=str(source),copied=str(destination),sha256=sha(destination),app_id=app_id,
  windows=[dict(kind=w['kind'],index=w['index'],milliseconds=w['end']-w['begin'],cpu=w['cpu'],samples=w['samples'],collection_ms=w['collectionMs']) for w in windows])

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--drivers',type=Path,required=True)
 ap.add_argument('--output',type=Path);ap.add_argument('--check',action='store_true');ap.add_argument('--registry-wait',type=float,default=900)
 a=ap.parse_args();drivers=(ROOT/a.drivers).resolve();meta,pins=preflight(drivers);before=prepared.installation()
 if a.check:print(json.dumps(dict(checked=True,compiled=meta['compiled'],candidate_sha256=CANDIDATE,air_started=False)));return 0
 assert a.output is not None and a.registry_wait>=0
 out=(ROOT/a.output).resolve();assert out.parent==prepared.M52 and not out.exists()
 wrapper=load('room_loading_original_scene_wrapper',SCENE)
 # Only this freshly loaded wrapper sees the new driver verifier. No shared
 # module/function is changed; historical scene02 remains a separate input.
 original_scene=wrapper.scene
 wrapper.scene=types.SimpleNamespace(**{n:getattr(original_scene,n) for n in ('ROOT','M52','sha','RUNNER','RECEIPT','read','save')},verify=prepared.verify)
 saved_argv=sys.argv;result=dict(passed=False,functional_pass=False,profile_complete=False,diagnostic_only=True,
  performance_qualified=False,installed=False,inputs=pins,candidate_sha256=CANDIDATE)
 try:
  sys.argv=[str(SCENE),'--drivers',str(drivers),'--output',str(out),'--mode','dual','--product','roomfix3','--registry-wait',str(a.registry_wait)]
  code=wrapper.main()
  native=read(out/'result.json');scene=read(out/'scene-result.json')
  result.update(functional_pass=bool(code==0 and native['passed'] and scene['passed']),
   original_result_sha256=sha(out/'result.json'),scene_result_sha256=sha(out/'scene-result.json'))
  run=Path(native['run']).resolve(strict=True);assert run.parent==(ROOT/'build/cooperation').resolve(strict=True)
  assert Path(scene['run']).resolve(strict=True)==run
  actual=read(run/'run.json');assert actual['sha256']==CANDIDATE and actual['solo'] is False
  assert actual['inputs']['join']['driver']==sha(drivers/'scene/EffectsDriver.swf')
  result.update(run=str(run),run_sha256=sha(run/'run.json'))
  result['profile']=review_profile(out,run);result['profile_complete']=True
  result['passed']=result['functional_pass'] and result['profile_complete']
 except Exception as error:result.update(passed=False,error=str(error),traceback=traceback.format_exc())
 finally:
  sys.argv=saved_argv;wrapper.scene=original_scene
  try:
   assert prepared.installation()==before
   for path,digest in pins.items():assert sha(path)==digest,path
   result.update(installation_unchanged=True,inputs_unchanged=True)
  except Exception as error:result.update(passed=False,final_error=str(error))
  if out.exists():save(out/'profile-result.json',result)
 print(json.dumps(dict(passed=result['passed'],functional_pass=result['functional_pass'],profile_complete=result['profile_complete'],output=str(out),error=result.get('error')),ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
