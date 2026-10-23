"""Run the existing native scene checks, separately judge three diagnostic windows."""
from pathlib import Path
import argparse,difflib,importlib.util,json,os,shutil,sys,traceback,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];REVIEW=HERE.parent/'recovery-room-repair-review'

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

prepared=load('room_counter_preparation',HERE/'prepare.py')
sha,read,save=prepared.sha,prepared.read,prepared.save
NATIVE=REVIEW/'run_native_v4.py';LAUNCHER=REVIEW/'scene_v2_launcher.py'
METHODS=['GameBridge.onPerceptionFrame','GameBridge.onMirrorFrame','GameBridge.onMirrorMaskFrame',
 'GameBridge.onVisForceFrame','MirrorMasks.capture','MirrorMasks.bitmapSignature','MirrorMasks.maskReferences',
 'MirrorMasks.restore','MirrorMasks.clean']
MARKS=[('enterFrame',n) for n in [1000000,1,-1,-99,-101,-8999,-9001,-9999,-10001,-1000000]]+[
 ('render',n) for n in [1000000,-9999,-10001,-1000000]]

def preflight(drivers,product):
 driver=prepared.verify(drivers);candidate=prepared.verify(product)
 assert driver['target']=='driver' and driver['compiled'] is True
 assert candidate['target']=='product' and candidate['compiled'] is True
 assert sha(HERE/'prepare.py')=='05de903519d99e9f5e5c1e66c80a37b683bef8a5a37d6cbbdc9abdac6c41258e'
 assert sha(NATIVE)=='23819bb8c279d20a94a1a377f3ca838ff268e121911680b49b50758c373fc7ae'
 assert sha(LAUNCHER)=='7b0ad823735d081b4df8d770efc61f9ff590e3f4022aaf946658bb17ac05b3d9'
 source=NATIVE.read_text(encoding='utf-8-sig')
 assert source.count("'roomfix4'")==2 and source.count("'0.2.24-roomfix4'")==1
 adapted=source.replace("'roomfix4'","'roomtime1'").replace("'0.2.24-roomfix4'","'0.2.24-roomtime1'")
 pins={str(p):sha(p) for p in (Path(__file__),NATIVE,LAUNCHER,prepared.BASE/'prepared.json',
  drivers/'prepared.json',drivers/'compile.json',product/'prepared.json',product/'compile.json',product/'RConnectMod.swf')}
 for folder,meta in ((drivers,driver),(product,candidate)):
  pins.update(meta['inputs'])
  for n,h in meta['files'].items():pins[str(folder/n)]=h
  for n,h in read(folder/'compile.json')['artifacts'].items():pins[str(folder/n)]=h
 return adapted,pins

def preferences(run):
 receipt=read(run/'scene-preference-input.json');after=read(run/'scene-preference-after.json')
 assert receipt['before_any_air'] is True and receipt['expected'] is True and set(receipt['roles'])=={'host','join'}
 assert receipt['launcher_sha256']==sha(LAUNCHER) and receipt['original_runner_sha256']==sha(prepared.original.RUNNER)
 assert receipt['input_manifest_sha256']==sha(run/'input.json')
 assert after['input_receipt_sha256']==sha(run/'scene-preference-input.json') and after['unchanged'] is True
 for role in ('host','join'):
  row=receipt['roles'][role];assert row['absent_before'] is True and after['roles'][role]['unchanged'] is True
  assert row['app_id']=='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
  assert row['sha256']==after['roles'][role]['sha256']
  text=(run/(role+'.log')).read_text(encoding='utf-8-sig')
  observations=[json.loads(line.split('SCENE PREFERENCE BASELINE ',1)[1]) for line in text.splitlines() if line.startswith('SCENE PREFERENCE BASELINE ')]
  assert len(observations)==1 and observations[0]['expected'] is True
  assert Path(observations[0]['file']).resolve()==Path(row['path']).resolve()
  assert 'COOP PASS scene preconnection preference file is true' in text
 return dict(complete=True,input_sha256=sha(run/'scene-preference-input.json'),after_sha256=sha(run/'scene-preference-after.json'))

def integer(value):return type(value) is int and value>=0

def review_counters(out,run):
 role=read(run/'scene-preference-input.json')['roles']['join'];app='pfe-modsettings-rconnect-coop-join-'+run.name
 assert role['app_id']==app
 expected=(Path(os.environ['APPDATA'])/app/'Local Store').resolve(strict=True)
 assert Path(role['path']).resolve(strict=True).parent==expected
 source=expected/'room-loading-counters.json';destination=out/'join-room-loading-counters.json'
 assert source.is_file() and not destination.exists();shutil.copyfile(source,destination);assert sha(source)==sha(destination)
 value=read(destination);identity=value['identity'];windows=value['windows'];traffic=value['traffic']
 assert value['kind']=='room-loading-counters-v1' and value['complete'] is True and value['errors']==[]
 assert value['performanceQualified'] is False and value['inclusiveTimes'] is True and value['recursiveReferencesOuterOnly'] is True
 assert identity['appId']==app and identity['role']=='join' and identity['version']==prepared.VERSION
 assert identity['land']==identity['curLand']=='random_mane' and identity['key']==identity['room']
 assert type(identity['barrier']) is int and identity['barrier']>0
 assert [(w['kind'],w['index'],w['termination']) for w in windows]==[
  ('grant',0,'handler-returned'),('enter-to-render',1,'render'),('enter-to-render',2,'render')]
 prior=None
 for w in windows:
  c=w['counters'];assert w['complete'] is True and w['windowComplete'] is True and c['faults']==[]
  assert (c['kind'],c['index'])==(w['kind'],w['index'])
  assert 0<=w['begin']<=c['begin']<=w['armReturned']<=w['end']<=c['end']<=w['collectionEnd']
  assert w['beginUtc']<=w['endUtc'] and w['collectionMs']==w['collectionEnd']-w['end']
  if prior is not None:assert prior<=w['begin']
  prior=w['collectionEnd'];assert set(c['methods'])==set(METHODS)
  for key,row in c['methods'].items():
   assert all(integer(row[n]) for n in ('calls','totalMs','maxMs'))
   assert row['maxMs']<=row['totalMs'] and (row['calls']>0 or row['totalMs']==row['maxMs']==0)
  assert integer(c['methods']['MirrorMasks.maskReferences']['nodes'])
  if w['index']==0:assert w['marks']==[]
  else:
   assert [(m['type'],m['priority']) for m in w['marks']]==MARKS
   times=[m['at'] for m in w['marks']];assert times==sorted(times) and w['armReturned']<=times[0]<=times[-1]<=w['end']
   assert all(c['methods'][key]['calls']>0 for key in METHODS[:4])
 assert traffic['begin']<=windows[0]['begin']<=traffic['grantReturn']<=traffic['firstEnter']<=windows[1]['begin']
 assert traffic['end']==windows[2]['end'] and traffic['grantToFirstEnterMs']==traffic['firstEnter']-traffic['grantReturn']
 for name,count in [('types','typeCount'),('beforeFirstEnter','beforeFirstEnterTypeCount')]:
  rows=traffic[name];assert len(rows)==traffic[count]<=32
  for row in rows.values():
   assert all(integer(row[n]) for n in ('calls','totalMs','maxMs','first','last')) and row['calls']>0
   assert row['maxMs']<=row['totalMs'] and traffic['begin']<=row['first']<=row['last']<=traffic['end']
   if name=='beforeFirstEnter':assert traffic['grantReturn']<=row['first']<=row['last']<=traffic['firstEnter']
 return dict(complete=True,source=str(source),copied=str(destination),sha256=sha(destination),traffic=traffic,
  windows=[dict(kind=w['kind'],index=w['index'],milliseconds=w['end']-w['begin'],counters=w['counters'],marks=w['marks']) for w in windows])

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--drivers',type=Path,required=True)
 ap.add_argument('--product',type=Path,required=True);ap.add_argument('--output',type=Path)
 ap.add_argument('--check',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 drivers=(ROOT/a.drivers).resolve();product=(ROOT/a.product).resolve();source,pins=preflight(drivers,product)
 before=prepared.installation();digest=sha(product/'RConnectMod.swf')
 if a.check:print(json.dumps(dict(checked=True,diagnostic_only=True,candidate_sha256=digest,air_started=False)));return 0
 assert a.output is not None and a.registry_wait>=0;out=(ROOT/a.output).resolve()
 assert out.parent==prepared.M52 and not out.exists()
 native=types.ModuleType('room_counter_native_v4');native.__file__=str(NATIVE)
 exec(compile(source,str(NATIVE),'exec'),native.__dict__)
 native.verify=prepared.verify;native.PRODUCT=product;native.RUNNER=LAUNCHER
 def verify_product(path):
  assert Path(path).resolve()==product
  meta=prepared.verify(product);assert meta['compiled'] is True and meta['target']=='product'
  return read(product/'compile.json')
 native.verify_product=verify_product
 saved_argv=sys.argv;result=dict(passed=False,functional_pass=False,counters_complete=False,diagnostic_only=True,
  performance_qualified=False,installed=False,inputs=pins,candidate_sha256=digest)
 try:
  sys.argv=[str(NATIVE),'--drivers',str(drivers),'--output',str(out),'--mode','dual','--scenario','scene',
   '--product','roomtime1','--registry-wait',str(a.registry_wait)]
  code=native.main();raw=read(out/'result.json')
  result.update(functional_pass=bool(code==0 and raw['passed']),original_result_sha256=sha(out/'result.json'))
  run=Path(raw['run']).resolve(strict=True);assert run.parent==(ROOT/'build/cooperation').resolve(strict=True)
  actual=read(run/'run.json');assert actual['sha256']==digest and actual['solo'] is False
  result.update(run=str(run),run_sha256=sha(run/'run.json'));result['preferences']=preferences(run)
  result['counters']=review_counters(out,run);result['counters_complete']=True
  result['passed']=result['functional_pass'] and result['counters_complete']
 except Exception as error:result.update(passed=False,error=str(error),traceback=traceback.format_exc())
 finally:
  sys.argv=saved_argv
  try:
   assert prepared.installation()==before
   for path,digest in pins.items():assert sha(path)==digest,path
   result.update(installation_unchanged=True,inputs_unchanged=True)
  except Exception as error:result.update(passed=False,final_error=str(error))
  if out.exists():
   (out/'native-adapted.py').write_text(source,encoding='utf-8')
   save(out/'adaptation.json',dict(original_sha256=sha(NATIVE),adapted_sha256=sha(out/'native-adapted.py'),
    replacements={'product_token':2,'version':1},original_driver_verifier_replaced_explicitly=True,
    product_verifier_replaced_explicitly=True,product_path=str(product),launcher=str(LAUNCHER)))
   save(out/'counters-result.json',result)
 print(json.dumps(dict(passed=result['passed'],functional_pass=result['functional_pass'],counters_complete=result['counters_complete'],output=str(out),error=result.get('error')),ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
