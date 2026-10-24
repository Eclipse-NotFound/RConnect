"""Unchanged three-trip scene run; independently retain the first terrain refusal."""
from pathlib import Path
import argparse, json, sys, traceback, types
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
# Loading by path avoids confusing this preparation module with the historical one.
import importlib.util
spec=importlib.util.spec_from_file_location('terrain_reason_preparation',HERE/'prepare.py')
prepared=importlib.util.module_from_spec(spec); spec.loader.exec_module(prepared)
ROOT=prepared.ROOT; REVIEW=prepared.REVIEW; sha=prepared.sha; read=prepared.read; save=prepared.save
NATIVE=REVIEW/'run_native_v4.py'; LAUNCHER=REVIEW/'scene_v2_launcher.py'
PREFERENCES=HERE.parent/'recovery-room-loading-counters/run.py'
FIXED={NATIVE:'23819bb8c279d20a94a1a377f3ca838ff268e121911680b49b50758c373fc7ae',
 LAUNCHER:'7b0ad823735d081b4df8d770efc61f9ff590e3f4022aaf946658bb17ac05b3d9',
 PREFERENCES:'70173838c73b06f01f961c7fb08be278128cbfdf258328c56c738acbe53f8c42'}

def preflight(product=None):
 pins=prepared.inputs(); prepared.verify_driver()
 for path,digest in FIXED.items(): assert sha(path)==digest,str(path)
 source=NATIVE.read_text(encoding='utf-8-sig')
 assert source.count("'roomfix4'")==2 and source.count("'0.2.24-roomfix4'")==1
 source=source.replace("'roomfix4'","'roomreason1'").replace("'0.2.24-roomfix4'","'"+prepared.VERSION+"'")
 pins.update({str(path):sha(path) for path in (Path(__file__),HERE/'prepare.py',NATIVE,LAUNCHER,PREFERENCES)})
 if product is not None:
  candidate=prepared.verify(product); assert candidate['compiled'] is True
  pins.update(candidate['inputs']); pins.update({str(product/name):digest for name,digest in candidate['files'].items()})
  for name in ('prepared.json','compile.json','RConnectMod.swf'): pins[str(product/name)]=sha(product/name)
  pins.update({str(product/name):digest for name,digest in read(product/'compile.json')['artifacts'].items()})
 return source,pins

def review_reason(out,run,raw):
 log=run/'join.log'; lines=log.read_text(encoding='utf-8-sig').splitlines()
 rows=[]
 for index,line in enumerate(lines):
  if line.startswith('RConnectRoomTiming restore '):
   value=json.loads(line.split('RConnectRoomTiming restore ',1)[1])
   if 'terrainReuseReason' in value: rows.append((index+1,value))
 assert len(rows)==1,'Expected exactly one first-large-room diagnostic on join'
 line,value=rows[0]; reason=value['terrainReuseReason']; first=raw['roles']['join']['rows'][0]
 assert first['round']==0 and first['target']=='random_mane'
 assert value['key']==first['key'] and reason['width']==first['width'] and reason['height']==first['height']
 assert reason['schema']=='first-terrain-reuse-reason-v1' and reason['complete'] is True
 assert reason['performanceQualified'] is False and reason['faultCount']==0 and reason['faults']==[]
 for name in ('viewCreated','constructorValid','unchangedCalled','reused','reuseGuardDirty'): assert type(reason[name]) is bool,name
 order=['retained','dirty','incomingWallPaint','localWallPaint']; observed=reason['admission']; size=len(observed)
 assert 1<=size<=4 and set(observed)==set(order[:size])
 assert all(type(observed[name]) is bool for name in observed)
 assert all(observed[name] is True for name in order[:size-1])
 if observed[order[size-1]] is False:
  assert reason['viewCreated'] is False
  assert reason['first']['stage']=='admission' and reason['first']['field']==order[size-1]
  assert reason['first']['expected'] is True and reason['first']['actual'] is False
 else: assert size==4 and reason['viewCreated'] is True
 if reason['reused']:
  assert reason['first'] is None and reason['viewCreated'] and reason['constructorValid'] and reason['unchangedCalled'] and reason['reuseGuardDirty']
 elif reason['first'] is None:
  assert reason['reuseGuardDirty'] is False and reason['viewCreated'] and reason['constructorValid'] and not reason['unchangedCalled']
 else:
  refusal=reason['first']; assert isinstance(refusal,dict) and set(refusal)=={'stage','field','expected','actual','x','y','index'}
  assert refusal['stage'] in ('admission','constructor','unchanged','style','backdrop','tile')
  assert isinstance(refusal['field'],str) and bool(refusal['field'])
  assert all(type(refusal[name]) is int for name in ('x','y','index'))
  if refusal['stage']=='tile': assert 0<=refusal['x']<reason['width'] and 0<=refusal['y']<reason['height']
 assert reason['reused']==(value.get('terrainReused') is True)
 assert all(type(value[name]) is int for name in ('beforeRole','role','total'))
 assert 0<=value['beforeRole']<=value['role']<=value['total']
 # Ensure this belongs before the first trip result, not an unlabelled revisit.
 first_result=next(i+1 for i,text in enumerate(lines) if text.startswith('TRAVEL RESULT '))
 assert line<first_result
 result=dict(complete=True,non_reuse_observed=reason['reuseGuardDirty'] and not reason['reused'],
  no_redraw_needed=not reason['reuseGuardDirty'],source_log=str(log),source_log_sha256=sha(log),
  line=line,restore=value,pre_role_ms=value['beforeRole'],room_role_ms=value['role']-value['beforeRole'],performance_qualified=False)
 save(out/'join-terrain-reason.json',result); return result

def main():
 parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--product',type=Path)
 parser.add_argument('--output',type=Path); parser.add_argument('--check',action='store_true')
 parser.add_argument('--registry-wait',type=float,default=900); args=parser.parse_args()
 assert args.registry_wait>=0
 product=None if args.product is None else (ROOT/args.product).resolve()
 source,pins=preflight(product); before=prepared.installation()
 if args.check:
  assert args.output is None
  print(json.dumps(dict(checked=True,diagnostic_only=True,candidate_compiled=product is not None,air_started=False))); return 0
 assert product is not None and args.output is not None
 out=(ROOT/args.output).resolve(); assert out.parent==prepared.M52 and not out.exists()
 native=types.ModuleType('terrain_reason_native'); native.__file__=str(NATIVE)
 exec(compile(source,str(NATIVE),'exec'),native.__dict__)
 native.verify=prepared.verify_driver; native.PRODUCT=product; native.RUNNER=LAUNCHER
 native.installation=prepared.installation; native.proof_inputs=prepared.current.proof_inputs
 def evidence():
  return dict(historical_driver_build=read(prepared.DRIVER/'prepared.json')['installation_before'],
   current_runtime=prepared.current.evidence(),historical_verifier_used_as_current_admission=False)
 def verify_product(path):
  assert Path(path).resolve()==product
  meta=prepared.verify(product); assert meta['compiled'] is True
  return read(product/'compile.json')
 native.evidence=evidence; native.verify_product=verify_product
 prefs=prepared.load('terrain_reason_scene_preferences',PREFERENCES)
 saved_argv=sys.argv; result=dict(passed=False,functional_pass=False,diagnostic_complete=False,non_reuse_observed=False,
  diagnostic_only=True,performance_qualified=False,installed=False,inputs=pins,candidate_sha256=sha(product/'RConnectMod.swf'))
 try:
  sys.argv=[str(NATIVE),'--drivers',str(prepared.DRIVER),'--output',str(out),'--mode','dual','--scenario','scene',
   '--product','roomreason1','--registry-wait',str(args.registry_wait)]
  code=native.main(); raw=read(out/'result.json')
  result.update(functional_pass=bool(code==0 and raw['passed']),original_result_sha256=sha(out/'result.json'))
  run=Path(raw['run']).resolve(strict=True); assert run.parent==(ROOT/'build/cooperation').resolve(strict=True)
  result.update(run=str(run),run_sha256=sha(run/'run.json')); result['preferences']=prefs.preferences(run)
  result['reason']=review_reason(out,run,raw); result['diagnostic_complete']=True
  result['non_reuse_observed']=result['reason']['non_reuse_observed']
  result['passed']=result['functional_pass'] and result['diagnostic_complete']
 except Exception as error: result.update(passed=False,error=str(error),traceback=traceback.format_exc())
 finally:
  sys.argv=saved_argv
  try:
   assert prepared.installation()==before
   for path,digest in pins.items(): assert sha(path)==digest,path
   result.update(installation_unchanged=True,inputs_unchanged=True)
  except Exception as error: result.update(passed=False,final_error=str(error))
  if out.exists():
   (out/'native-adapted.py').write_text(source,encoding='utf-8')
   save(out/'adaptation.json',dict(original_sha256=sha(NATIVE),adapted_sha256=sha(out/'native-adapted.py'),
    replacements={'product_token':2,'version':1},driver_recompiled=False,original_assertions_unchanged=True,
    explicit_callbacks=['verify_driver','verify_product','installation','proof_inputs','evidence'],
    product_path=str(product),launcher=str(LAUNCHER),environment=prepared.current.evidence()))
   save(out/'terrain-reason-result.json',result)
 print(json.dumps(dict(passed=result['passed'],functional_pass=result['functional_pass'],diagnostic_complete=result['diagnostic_complete'],
  non_reuse_observed=result['non_reuse_observed'],output=str(out),error=result.get('error')),ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__': raise SystemExit(main())
