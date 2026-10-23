"""Scene adapter for roomfix3 and the explicitly verified current RV runtime."""
from pathlib import Path
import argparse,importlib.util,json,sys,traceback
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import current_rv_verifier as scene
HERE=Path(__file__).resolve().parent;BASE=HERE/'run_native_v3.py';LAUNCHER=HERE/'scene_v2_launcher.py'
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--drivers',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--mode',choices=['dual','solo'],default='dual');ap.add_argument('--product',choices=['aura1','roomfix3'],default='roomfix3')
 ap.add_argument('--registry-wait',type=float,default=900)
 a=ap.parse_args();out=(scene.ROOT/a.output).resolve();drivers=(scene.ROOT/a.drivers).resolve()
 assert out.parent==scene.M52 and not out.exists()
 assert scene.sha(BASE)=='511b0c64286742af371bb30e6368abd1f3f8712039e439d516c6de5b1dea8a8f'
 scene.verify(drivers)
 pins={str(p):scene.sha(p) for p in (Path(__file__),BASE,LAUNCHER,HERE/'current_rv_verifier.py',drivers/'prepared.json',scene.RUNNER,scene.RECEIPT)}
 spec=importlib.util.spec_from_file_location('scene_v2_existing_wrapper',BASE)
 base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
 # These are real verifier and executable substitutions, not a claim that the
 # old driver verifier or the old runner input fingerprint accepted new bytes.
 base.verify=scene.verify;base.RUNNER=LAUNCHER
 saved_argv=sys.argv;result=dict(passed=False,installed=False,performance_qualified=False,inputs=pins)
 try:
  sys.argv=[str(BASE),'--drivers',str(drivers),'--output',str(out),'--mode',a.mode,'--scenario','scene',
   '--product',a.product,'--registry-wait',str(a.registry_wait)]
  code=base.main();old=scene.read(out/'result.json');result['functional_pass']=old['passed']
  run=Path(old['run']);receipt=scene.read(run/'scene-preference-input.json');after=scene.read(run/'scene-preference-after.json')
  roles=['host'] if a.mode=='solo' else ['host','join']
  assert receipt['before_any_air'] is True and receipt['expected'] is True and set(receipt['roles'])==set(roles)
  assert receipt['launcher_sha256']==scene.sha(LAUNCHER) and receipt['original_runner_sha256']==pins[str(scene.RUNNER)]
  assert receipt['input_manifest_sha256']==scene.sha(run/'input.json')
  assert after['input_receipt_sha256']==scene.sha(run/'scene-preference-input.json') and after['unchanged'] is True
  for role in roles:
   row=receipt['roles'][role];assert row['absent_before'] is True and after['roles'][role]['unchanged'] is True
   assert row['app_id']=='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
   assert row['sha256']==after['roles'][role]['sha256']
   text=(run/(role+'.log')).read_text(encoding='utf-8-sig')
   observations=[json.loads(line.split('SCENE PREFERENCE BASELINE ',1)[1]) for line in text.splitlines() if line.startswith('SCENE PREFERENCE BASELINE ')]
   assert len(observations)==1 and observations[0]['expected'] is True
   assert Path(observations[0]['file']).resolve()==Path(row['path']).resolve()
   assert 'COOP PASS scene preconnection preference file is true' in text
  result.update(passed=code==0 and old['passed'],preference_evidence_complete=True,run=str(run),
   original_result_sha256=scene.sha(out/'result.json'),preference_input_sha256=scene.sha(run/'scene-preference-input.json'),
   preference_after_sha256=scene.sha(run/'scene-preference-after.json'))
 except Exception as error:result.update(passed=False,error=str(error),traceback=traceback.format_exc())
 finally:
  sys.argv=saved_argv
  for path,digest in pins.items():
   if scene.sha(path)!=digest:result.update(passed=False,input_drift=path)
  if out.exists():scene.save(out/'scene-result.json',result)
 print(json.dumps(result,ensure_ascii=False));return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
