"""Reuse the frozen terrain diagnostic after the exact roomfix5 user deployment."""
from pathlib import Path
import hashlib, importlib.util, json, sys, types
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]; M52=ROOT/'build/m52'; GAME=ROOT.parents[1]
PRODUCT=M52/'recovery-room-terrain-reason-product-01'; DEPLOY=M52/'recovery-room-user-deploy-01'
RC='mods/Rconnect/release/RConnectMod.swf'
OLD='df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
NEW='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
DIAGNOSTIC='9a128737ce470127db16ff903fe0bcbdd8280daead0f714c983515c52a14b1ef'
PINS={
 HERE/'prepare.py':'52057ec735ef7ae4fdb7d61a2e40f6d538d298b6c41de543dab9d0123cea4ef6',
 HERE/'run.py':'d15e9722bfbddb2b41c65b0a097a9d7685046f013309ba3d2ada755407f69d0e',
 PRODUCT/'prepared.json':'9650b504612a8a279d477f06a6ceceb5ebfc9896d58cdf168f0c2268aeadfb21',
 PRODUCT/'compile.json':'2402bbca756801456adf4431661a60cdb80bca6e812055d2f3260cf9676a856c',
 PRODUCT/'RConnectMod.swf':DIAGNOSTIC,
 DEPLOY/'deployment.json':'16ef10ba4f2a5393fd41efe0648ea55a051dd9d5dd7c9efeab722ee66d4eabe4',
 DEPLOY/'audit.json':'fed182e8c1bb957632c76f0489c46cdd11315ed54d3aba521a61321abdd7dc35',
 DEPLOY/'deployment-intent.json':'6787a5dc2a43bb3efd5b1fd3e7c4b0b07596b9ebbb8a5bb0f673062da0da5039',
 DEPLOY/'deploy-executed.py':'639166db3744a8834432724b3a615900f073671136d9c5bf43fe019b9fb7d01f',
 DEPLOY/'RConnectMod.before.swf':OLD}
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path); module=importlib.util.module_from_spec(spec)
 spec.loader.exec_module(module); return module
for _path in (HERE/'prepare.py',HERE/'run.py'): assert sha(_path)==PINS[_path]
original=load('terrain_reason_before_deploy',HERE/'prepare.py')

def historical_environment():
 value=original.current.build_environment(); value['pfe.swf']=original.current.NEW_HOST
 assert len(value)==22 and value[RC]==OLD
 return value

def deployment():
 for path,digest in PINS.items(): assert sha(path)==digest,str(path)
 receipt=read(DEPLOY/'deployment.json'); audit=read(DEPLOY/'audit.json')
 before=historical_environment(); after=dict(before); after[RC]=NEW
 assert receipt['status']=='user-requested-installed' and receipt['version']=='0.2.24-roomfix5'
 assert receipt['before_sha256']==receipt['backup_sha256']==OLD
 assert receipt['candidate_sha256']==receipt['release_sha256']==receipt['release_sha256_final']==NEW
 assert receipt['installation_before']==before
 assert receipt['installation_after']==receipt['expected_installation_after']==after
 assert {key for key in before if before[key]!=after[key]}=={RC}
 for field,path in [('release',GAME/RC),('candidate',original.BASE/'RConnectMod.swf'),('backup',DEPLOY/'RConnectMod.before.swf')]:
  assert Path(receipt[field]).resolve()==path.resolve(),field
 assert receipt['audit_sha256']==PINS[DEPLOY/'audit.json']
 assert receipt['user_requested_deploy_before_final_validation'] is True and receipt['performance_qualified'] is False
 assert receipt['native_mask_regression_passed'] is False and receipt['smoke_status']=='pending'
 assert audit['deployment_script_sha256']==PINS[DEPLOY/'deploy-executed.py']
 assert audit['candidate_sha256']==NEW and Path(audit['candidate']).resolve()==(original.BASE/'RConnectMod.swf').resolve()
 assert audit['prepared_sha256']==sha(original.BASE/'prepared.json') and audit['compile_sha256']==sha(original.BASE/'compile.json')
 assert audit['source']==read(original.BASE/'prepared.json')['source']
 assert audit['historical_build_environment']==original.current.build_environment()
 assert audit['current_host_transition_proof']==original.current.proof_inputs()
 intent=read(DEPLOY/'deployment-intent.json'); assert intent['status']=='not-installed'
 for key,value in intent.items():
  if key!='status': assert receipt[key]==value,key
 return receipt

def installation():
 receipt=deployment()
 sys.path.insert(0,str(ROOT/'tools/validation'))
 from run_security_terminals import installation as actual
 value=actual(); assert value==receipt['installation_after'],'Runtime differs beyond the exact deployed RC replacement'
 return value

def verify(folder=PRODUCT):
 """Original build evidence stays historical; actual install is checked separately."""
 assert Path(folder).resolve()==PRODUCT.resolve(); deployment(); original.source_check()
 meta=read(PRODUCT/'prepared.json'); result=read(PRODUCT/'compile.json')
 assert meta['kind']=='room-terrain-reason-product' and meta['target']=='product'
 assert meta['base_sha256']==NEW and meta['version']==original.VERSION
 assert meta['diagnostic_only'] is True and meta['performance_qualified'] is False
 assert result['diagnostic_only'] is True and result['performance_qualified'] is False
 assert result['compiled'] is True and result['prepared_sha256']==sha(PRODUCT/'prepared.json')
 assert meta['installation_before']==result['installation_before']==result['installation_after']==historical_environment()
 assert result['installation_unchanged'] is True and result['sources_unchanged'] is True
 assert len(result['commands'])==2 and all(row['exit_code']==0 and row['reaped'] for row in result['commands'])
 assert result['candidate_sha256']==DIAGNOSTIC
 for name,digest in meta['inputs'].items(): assert sha(name)==digest,name
 for table in (meta['files'],result['artifacts']):
  for name,digest in table.items(): assert sha(PRODUCT/name)==digest,name
 assert original.inventory(PRODUCT/'src')==meta['source'] and original.inventory(PRODUCT/'tools')==meta['tools']
 expected=dict(read(original.BASE/'prepared.json')['source']); expected.update(original.EXPECTED)
 entry=(original.BASE/'src/RConnectMod.as').read_bytes(); assert entry.count(b'0.2.24-roomfix5')==1
 expected['RConnectMod.as']=hashlib.sha256(entry.replace(b'0.2.24-roomfix5',original.VERSION.encode())).hexdigest()
 assert meta['source']==expected and meta['tools']==read(original.BASE/'prepared.json')['inputs']
 installation(); return dict(meta,compiled=True)

def verify_driver(folder=original.DRIVER):
 assert Path(folder).resolve()==original.DRIVER.resolve()
 for path in (original.REVIEW/'prepare.py',original.REVIEW/'current_rv_verifier.py'): assert sha(path)==original.FIXED[path]
 rv=load('terrain_reason_post_deploy_historical_driver',original.REVIEW/'current_rv_verifier.py')
 for name,digest in rv.old.inputs().items(): assert sha(name)==digest,name
 rv.artifacts(rv.BASE,rv.BASE_SHA,'current-installed-room12-compatible-driver',2)
 meta=rv.artifacts(rv.SCENE,rv.SCENE_SHA,'room-scene-preconnection-preference-driver',1)
 assert meta['ordinary_timing_byte_exact'] is True
 assert sha(original.REVIEW/'prepare_scene_v2.py')=='1b644d79fffa7fbbdc4573b8e94374df7311fbe790036b5bd38f73cd55afae91'
 for name in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):
  assert sha(rv.SCENE/'tests'/name)==sha(rv.BASE/'tests'/name)
 assert sha(rv.SCENE/'timing/EffectsDriver.swf')==sha(rv.BASE/'timing/EffectsDriver.swf')
 expected=dict(rv.historical()); expected['pfe.swf']=original.current.NEW_HOST; expected[rv.RV]=rv.NEW_RV; expected[RC]=NEW
 assert installation()==expected
 return meta

def proof_inputs():
 deployment(); pins=original.current.proof_inputs()
 pins.update({str(path):digest for path,digest in PINS.items()}); pins[str(Path(__file__))]=sha(__file__)
 return pins

def inputs():
 meta=verify(); driver=verify_driver(); pins=dict(meta['inputs']); pins.update(driver['inputs']); pins.update(proof_inputs())
 for folder,table in ((PRODUCT,meta['files']),(PRODUCT,read(PRODUCT/'compile.json')['artifacts']),(original.DRIVER,driver['files'])):
  pins.update({str(folder/name):digest for name,digest in table.items()})
 return pins

def evidence():
 receipt=deployment()
 return dict(kind='terrain-reason-historical-build-after-roomfix5-user-deployment',
  historical_driver=read(original.DRIVER/'prepared.json')['installation_before'],
  historical_diagnostic_compile=historical_environment(),runtime_installation=installation(),
  deployment_receipt=str(DEPLOY/'deployment.json'),deployment_receipt_sha256=PINS[DEPLOY/'deployment.json'],
  actual_executed_script_sha256=PINS[DEPLOY/'deploy-executed.py'],sole_deployment_change=dict(path=RC,before=OLD,after=NEW),
  deployment_status=receipt['status'],smoke_status_at_deployment=receipt['smoke_status'],
  historical_verifier_relabelled=False,diagnostic_only=True,performance_qualified=False)

def main():
 # A new module instance receives explicit adapters; no old module or file is rewritten.
 run=load('terrain_reason_after_roomfix5',HERE/'run.py')
 run.prepared=types.SimpleNamespace(ROOT=ROOT,M52=M52,GAME=GAME,REVIEW=original.REVIEW,DRIVER=original.DRIVER,
  VERSION=original.VERSION,sha=sha,read=read,save=original.save,load=original.load,inputs=inputs,verify=verify,
  verify_driver=verify_driver,installation=installation,current=types.SimpleNamespace(proof_inputs=proof_inputs,evidence=evidence))
 if '--product' not in sys.argv: sys.argv+=['--product',str(PRODUCT)]
 return run.main()
if __name__=='__main__': raise SystemExit(main())
