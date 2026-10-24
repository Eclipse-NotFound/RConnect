"""Freeze/check five roomfix5 overlays; source preparation only."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-room-production-05'
BASE_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
VERSION='0.2.24-roomperf1'
DELEGATE=ROOT/'experimental/recovery-room-production-v5/build.py'
ALLOCATION=ROOT/'experimental/recovery-room-restore-allocation'
LOOP=ROOT/'experimental/recovery-terrain-loop'
CAPTURE=ROOT/'experimental/recovery-terrain-capture'
PINS={
 BASE/'prepared.json':'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
 BASE/'compile.json':'68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
 BASE/'RConnectMod.swf':BASE_SHA,
 DELEGATE:'1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
 ALLOCATION/'source-manifest.json':'16c992a03cd3f681423a69ff17001b851a266580aa07dfee3d3b40cf4f0b5886',
 LOOP/'src/rconnect/game/NativeTileState.as':'eec001f4de8bdfc5ad892c2de2e892c07cceac15ebe7c5cf10fda4a1047592dc',
 CAPTURE/'src/rconnect/game/TerrainSync.as':'3bb4ac4a9ab4ca6a045d2376e3b18025d48db409bc6ad72cb62cdece02f5ebfa'}
PROOFS=[
 ('recovery-terrain-loop-component-03',67,'122778424511b8bf6d988a2dac44f93f0cf379129bc4ce31a81fd5a5a2c0d86b',
  '8fa17bbccdfdfb42b51cec0d3530ed10853c43fc23845996e02eb61bd51b4d17',
  '370ee7602d38f0cbfb27c43ab47e937d4322fd5c23dffba64d5c782e07bdd622'),
 ('recovery-terrain-capture-component-01',154,'4631c58b540449f75d3ced18a51b705d72f0bfbde343ed851127b7c16966ae71',
  'db60fc5e3953b82ddcbdea1fbf390674e17cdc2af7f9a9cb389bd7600973f1db',
  'c8e831088dac012095fce9d624fa9804a0f364b35ffb3139836ef53207424c19'),
 ('recovery-room-restore-allocation-component-01',55,'fd182a717b88ee7b958a5951adfea44653e445c98e30b67ccc8cabefa67501d3',
  'e5978db0d5000da8692dc2163cde4766a27157127e3ed5e76a207eb2c9477add',
  '42952a5b5619380aef7401e220f3d071520d4b66f856a925d9252143f2bda509')]

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def inventory(path): return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*')) if p.is_file()}

def historical_components():
 evidence=[]
 for name,count,receipt_sha,result_sha,intent_sha in PROOFS:
  out=ROOT/'build/m52'/name
  for file,digest in [('receipt.json',receipt_sha),('component-result.json',result_sha),('intent.json',intent_sha)]:
   assert sha(out/file)==digest,str(out/file)
  receipt,result,intent=read(out/'receipt.json'),read(out/'component-result.json'),read(out/'intent.json')
  assert all(receipt[k] is True for k in ['passed','compiled','air_started','installation_unchanged','source_unchanged'])
  assert receipt['compile_exit']==receipt['exit_code']==receipt['checks_failed']==result['failed']==0
  assert intent['expected']==receipt['observed_checks']==len(result['assertions'])==count
  assert result['passed'] is True and all(row['passed'] is True for row in result['assertions'])
  assert inventory(out/'src')==intent['sources'] and sha(out/'Checks.swf')==receipt['component_sha256']
  evidence.append(dict(path=str(out),assertions=count,receipt_sha256=receipt_sha,result_sha256=result_sha,
   intent_sha256=intent_sha,component_sha256=receipt['component_sha256'],native_game=False,performance_qualified=False))
 return evidence

def expected():
 for path,digest in PINS.items(): assert sha(path)==digest,str(path)
 meta,compiled=read(BASE/'prepared.json'),read(BASE/'compile.json')
 assert meta['version']=='0.2.24-roomfix5' and len(meta['source'])==81
 assert inventory(BASE/'src')==meta['source'] and inventory(BASE/'tools')==meta['inputs']
 assert compiled['compiled'] is True and compiled['candidate_sha256']==BASE_SHA
 assert compiled['sources_unchanged'] is True and compiled['installation_unchanged'] is True
 assert meta['installation_before']==compiled['installation_before']==compiled['installation_after']
 assert len(compiled['commands'])==2 and all(c['exit_code']==0 for c in compiled['commands'])
 allocation=read(ALLOCATION/'source-manifest.json')
 assert allocation['base_sha256']==BASE_SHA and allocation['production_overlays']==2
 for name,digest in allocation['outputs'].items(): assert sha(ALLOCATION/name)==digest,name
 evidence=historical_components()
 origins={'rconnect/game/NativeTileState.as':LOOP/'src/rconnect/game/NativeTileState.as',
  'rconnect/game/TerrainSync.as':CAPTURE/'src/rconnect/game/TerrainSync.as',
  'rconnect/game/GameBridge.as':ALLOCATION/'src/rconnect/game/GameBridge.as',
  'rconnect/game/RoomTerrainView.as':ALLOCATION/'src/rconnect/game/RoomTerrainView.as'}
 files={name:path.read_bytes() for name,path in origins.items()}
 loop=ROOT/'build/m52/recovery-terrain-loop-component-03/src/rconnect/game'
 capture=ROOT/'build/m52/recovery-terrain-capture-component-01/src/rconnect/game'
 checks=ROOT/'build/m52/recovery-room-restore-allocation-component-01/src/rconnect/game'
 assert (loop/'ControlNativeTileState.as').read_bytes().replace(b'ControlNativeTileState',b'NativeTileState')==(BASE/'src/rconnect/game/NativeTileState.as').read_bytes()
 assert (capture/'ControlTerrainSync.as').read_bytes().replace(b'ControlTerrainSync',b'TerrainSync')==(BASE/'src/rconnect/game/TerrainSync.as').read_bytes()
 assert files['rconnect/game/NativeTileState.as']==(loop/'NativeTileState.as').read_bytes()==(capture/'NativeTileState.as').read_bytes()
 assert files['rconnect/game/TerrainSync.as']==(capture/'TerrainSync.as').read_bytes()
 assert files['rconnect/game/RoomTerrainView.as']==(checks/'RoomTerrainView.as').read_bytes()
 assert (BASE/'src/rconnect/game/NativeRoomState.as').read_bytes()==(loop/'NativeRoomState.as').read_bytes()==(capture/'NativeRoomState.as').read_bytes()
 entry=(BASE/'src/RConnectMod.as').read_bytes();assert entry.count(b'0.2.24-roomfix5')==1
 files['RConnectMod.as']=entry.replace(b'0.2.24-roomfix5',VERSION.encode())
 changes={};diff=[];candidate=dict(meta['source'])
 for name,data in sorted(files.items()):
  digest=hashlib.sha256(data).hexdigest();assert digest!=meta['source'][name]
  changes[name]=dict(base_sha256=meta['source'][name],candidate_sha256=digest)
  candidate[name]=digest
  diff+=difflib.unified_diff((BASE/'src'/name).read_bytes().decode('utf-8').splitlines(True),
   data.decode('utf-8').splitlines(True),fromfile='roomfix5/'+name,tofile='roomperf1/'+name)
 assert len(changes)==5 and sum(candidate[n]==h for n,h in meta['source'].items())==76
 outputs={'src/'+name:data for name,data in files.items()};outputs['source.diff']=''.join(diff).encode()
 for file in ['prepare.py','build.py']: ast.parse((HERE/file).read_text(encoding='utf-8'))
 manifest=dict(kind='room-perf-current-overlay',version=VERSION,base=str(BASE),base_sha256=BASE_SHA,
  base_prepared_sha256=PINS[BASE/'prepared.json'],base_compile_sha256=PINS[BASE/'compile.json'],
  changes=changes,candidate_source=candidate,unchanged_source_count=76,
  origins={name:dict(path=str(path),sha256=sha(path)) for name,path in origins.items()},
  pins={str(path):digest for path,digest in PINS.items()},historical_components=evidence,
  source_diff_sha256=hashlib.sha256(outputs['source.diff']).hexdigest(),
  recipe_sha256=sha(HERE/'prepare.py'),build_wrapper_sha256=sha(HERE/'build.py'),
  build_delegate=dict(path=str(DELEGATE),sha256=PINS[DELEGATE]),readme_sha256=sha(HERE/'README.md'),
  compiled=False,native_tested=False,installed=False,performance_qualified=False)
 return outputs,manifest

def verify():
 outputs,manifest=expected();assert read(HERE/'source-manifest.json')==manifest
 for name,data in outputs.items(): assert (HERE/name).read_bytes()==data,name
 assert inventory(HERE/'src')=={name:row['candidate_sha256'] for name,row in manifest['changes'].items()}
 assert {p.relative_to(HERE).as_posix() for p in HERE.rglob('*') if p.is_file()}==set(outputs)|{'prepare.py','build.py','README.md','source-manifest.json'}
 return manifest

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare',action='store_true');p.add_argument('--check',action='store_true');a=p.parse_args()
 assert a.prepare!=a.check
 if a.prepare:
  assert not (HERE/'src').exists() and not (HERE/'source-manifest.json').exists()
  outputs,manifest=expected()
  for name,data in outputs.items():
   path=HERE/name;path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as f:f.write(data)
  with (HERE/'source-manifest.json').open('x',encoding='utf-8') as f:json.dump(manifest,f,ensure_ascii=False,indent=2)
 manifest=verify()
 print(json.dumps(dict(passed=True,version=VERSION,overlay_classes=len(manifest['changes']),unchanged_source_count=76,
  manifest_sha256=sha(HERE/'source-manifest.json'),compiled=False,air_started=False,installed=False)))
if __name__=='__main__':main()
