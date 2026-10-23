"""One private-storage setup hook; execute the unchanged shared AIR runner."""
from pathlib import Path
import hashlib,importlib.util,json,os,re,sys,time,xml.etree.ElementTree as ET
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
ORIGINAL=ROOT/'tools/run_coop_regression.py'
ORIGINAL_SHA='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
PAYLOAD=b'{"nativeEnabled":true}'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,value):
 with Path(p).open('x',encoding='utf-8') as stream:json.dump(value,stream,ensure_ascii=False,indent=2)
def main():
 assert sha(ORIGINAL)==ORIGINAL_SHA
 launcher_sha=sha(__file__)
 sys.path.insert(0,str(ROOT/'tools'))
 spec=importlib.util.spec_from_file_location('scene_preference_shared_runner',ORIGINAL)
 runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
 original_run=runner.run_registered
 def registered(args,ap,output,record):
  assert args.all_mods and args.effects and args.effects_driver and args.private_desktop and args.require_exclusive_air
  assert output.resolve().parent==(ROOT/'build/cooperation').resolve() and re.fullmatch('[0-9a-f]{10}',output.name)
  original_launch=record.before_launch;prepared=False;receipt=None
  def before_launch(detail):
   nonlocal prepared,receipt
   if not prepared:
    assert not record.children and not record.launching,'Preference setup must precede every owned AIR launch'
    roles=('host',) if args.solo else ('host','join');rows={}
    native_inputs=json.loads((output/'input.json').read_text(encoding='utf-8'))
    # Validate every destination before writing any one of them.
    for role in roles:
     descriptor=output/role/'coop.xml';root=ET.fromstring(descriptor.read_bytes())
     ns='{http://ns.adobe.com/air/application/30.0}'
     appid='pfe-modsettings-rconnect-coop-'+role+'-'+output.name
     assert root.tag==ns+'application' and root.findtext(ns+'id')==appid
     assert root.findtext(ns+'initialWindow/'+ns+'content')=='pfe.swf'
     assert sha(descriptor)==native_inputs['descriptors'][role]
     app_root=Path(os.environ['APPDATA']).resolve()/appid
     target=app_root/'Local Store/ContinuousScene.preferences.json'
     assert target.resolve().is_relative_to(app_root.resolve()) and not target.exists()
     rows[role]=dict(app_id=appid,path=str(target),descriptor_sha256=sha(descriptor),absent_before=True)
    for row in rows.values():
     target=Path(row['path']);target.parent.mkdir(parents=True,exist_ok=True)
     with target.open('xb') as stream:stream.write(PAYLOAD)
     row['sha256']=sha(target);assert target.read_bytes()==PAYLOAD
    receipt=dict(kind='scene-preconnection-preferences',expected=True,roles=rows,before_any_air=True,
     prepared_at_ms=int(time.time()*1000),original_runner_sha256=ORIGINAL_SHA,launcher_sha256=launcher_sha,
     input_manifest_sha256=sha(output/'input.json'))
    save(output/'scene-preference-input.json',receipt);prepared=True
   original_launch(detail)
  record.before_launch=before_launch
  try:return original_run(args,ap,output,record)
  finally:
   record.before_launch=original_launch
   assert sha(ORIGINAL)==ORIGINAL_SHA and sha(__file__)==launcher_sha
   if receipt is not None:
    rows={role:dict(path=row['path'],sha256=sha(row['path']),unchanged=Path(row['path']).read_bytes()==PAYLOAD)
     for role,row in receipt['roles'].items()}
    save(output/'scene-preference-after.json',dict(kind='scene-preconnection-preferences-after',
     input_receipt_sha256=sha(output/'scene-preference-input.json'),roles=rows,unchanged=all(r['unchanged'] for r in rows.values())))
    assert all(r['unchanged'] for r in rows.values()),'Private initial preference changed during run'
 runner.run_registered=registered
 try:runner.main()
 finally:
  runner.run_registered=original_run
  assert sha(ORIGINAL)==ORIGINAL_SHA and sha(__file__)==launcher_sha
if __name__=='__main__':main()
