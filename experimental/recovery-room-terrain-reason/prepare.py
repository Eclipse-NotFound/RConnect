"""Isolated terrain-reuse reason product; reuse the completed scene driver."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, re, shutil, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]; M52=ROOT/'build/m52'; GAME=ROOT.parents[1]
REVIEW=HERE.parent/'recovery-room-repair-review'; BASE=M52/'recovery-room-production-05'
DRIVER=M52/'recovery-room-scene-driver-02'; VERSION='0.2.24-roomreason1'
COMPILER=HERE.parent/'recovery-room-loading-counters/prepare.py'
TINT=HERE.parent/'recovery-room-mask-native/current_tint_verifier.py'
DIFF_SHA='5a81d51f7552f0067e472b16ebbf466ef0569925bfea55ea56550c6ef4a3b49b'
EXPECTED={
 'rconnect/game/RoomTerrainView.as':'d97df7bd1482fc099194b650d7eebee581521ee575375ca9c6d7524bbaa6f0df',
 'rconnect/game/GameBridge.as':'be39fd4d4f94179d3e1632b8113c3c6e584c3486d65bc794315b9a3aca0a4fc3'}
BASE_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
FIXED={COMPILER:'05de903519d99e9f5e5c1e66c80a37b683bef8a5a37d6cbbdc9abdac6c41258e',
 TINT:'5be11d45db193e22205ff302a8e94f016b4096eb335cb33d72faea12ea45e988',
 REVIEW/'prepare.py':'eb0c7c560724244619fa9996d5fbecf7bb353c964aced4e89bfe009f0b4c0e80',
 REVIEW/'current_rv_verifier.py':'a12bd5788bfb3ddf7634c9115fe9784934bc7880d24748222de1b533b9df4c8b',
 REVIEW/'current_host_verifier.py':'3abcd73d2dee5a47c4c5b94f549fd5106f8ebefb10ad7f71479f9269f5b321e8',
 BASE/'prepared.json':'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
 BASE/'compile.json':'68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
 BASE/'RConnectMod.swf':BASE_SHA}

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path,value):
 with Path(path).open('x',encoding='utf-8') as f: json.dump(value,f,ensure_ascii=False,indent=2)
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path); module=importlib.util.module_from_spec(spec)
 spec.loader.exec_module(module); return module
def inventory(folder): return {p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}

sys.path.insert(0,str(REVIEW))
assert sha(TINT)==FIXED[TINT]
current=load('terrain_reason_current_tint',TINT)
installation=current.installation

def apply_diff(text):
 """Apply exact unified contexts in memory, rejecting unknown files or hunks."""
 lines=text.splitlines(True); i=0; outputs={}
 while i<len(lines):
  assert lines[i].startswith('--- a/src/'); rel=lines[i][10:].rstrip('\r\n'); i+=1
  assert rel in EXPECTED and rel not in outputs
  assert lines[i].rstrip('\r\n')=='+++ b/src/'+rel; i+=1
  original=(BASE/'src'/rel).read_bytes().decode('utf-8').splitlines(True); pos=0; result=[]
  while i<len(lines) and lines[i].startswith('@@ '):
   match=re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\n]*\n',lines[i]); assert match
   old_at=int(match[1])-1; old_count=int(match[2] or '1'); new_count=int(match[4] or '1'); i+=1
   assert pos<=old_at; result.extend(original[pos:old_at]); pos=old_at; consumed=added=0
   assert len(result)==int(match[3])-1
   while i<len(lines) and not lines[i].startswith(('@@ ','--- ')):
    row=lines[i]; i+=1; assert row[0] in ' +-'
    if row[0] in ' -': assert original[pos]==row[1:]; pos+=1; consumed+=1
    if row[0] in ' +': result.append(row[1:]); added+=1
   assert (consumed,added)==(old_count,new_count)
  result.extend(original[pos:]); outputs[rel]=''.join(result).encode('utf-8')
 assert set(outputs)==set(EXPECTED); return outputs

def source_check():
 for path,digest in FIXED.items(): assert sha(path)==digest,str(path)
 current.build_environment(); meta=read(BASE/'prepared.json'); built=read(BASE/'compile.json')
 assert inventory(BASE/'src')==meta['source'] and inventory(BASE/'tools')==meta['inputs']
 assert built['candidate_sha256']==BASE_SHA and sha(BASE/'RConnectMod.swf')==BASE_SHA
 assert sha(HERE/'source.diff')==DIFF_SHA
 proposed=apply_diff((HERE/'source.diff').read_text(encoding='utf-8'))
 for rel,data in proposed.items(): assert hashlib.sha256(data).hexdigest()==EXPECTED[rel],rel
 # The only admission checkpoint remains in its original fourth short-circuit operand.
 old=(BASE/'src/rconnect/game/GameBridge.as').read_text(encoding='utf-8')
 new=proposed['rconnect/game/GameBridge.as'].decode('utf-8')
 assert new.count('_wall.checkpoint(loc)')==old.count('_wall.checkpoint(loc)')
 assert new.count('RoomTerrainView.diagnosticFinish(')==1
 # Strip only these four wrappers. Their arguments are evaluated by the original && order.
 admission='''         if(RoomTerrainView.diagnosticAdmission("retained",!retained) && RoomTerrainView.diagnosticAdmission("dirty",!_terrain.dirty)
            && RoomTerrainView.diagnosticAdmission("incomingWallPaint",s.wallPaint==null || s.wallPaint.length==0)
            && RoomTerrainView.diagnosticAdmission("localWallPaint",_wall.checkpoint(loc).length==0))terrainView=new RoomTerrainView(loc);'''
 original='''         if(!retained && !_terrain.dirty && (s.wallPaint==null || s.wallPaint.length==0)
            && _wall.checkpoint(loc).length==0)terrainView=new RoomTerrainView(loc);'''
 assert new.count(admission)==old.count(original)==1
 stripped=new.replace(admission,original)
 stripped=re.sub(r'         // TERRAIN-REASON BEGIN (arm|admission|result)\.\n.*?         // TERRAIN-REASON END \1\.\n','',stripped,flags=re.S)
 stripped=stripped.replace('         timing.beforeRole=getTimer()-timingStart; // TERRAIN-REASON: pre-role boundary only.\n','')
 stripped=stripped.replace('         if(terrainReason)RoomTerrainView.diagnosticReuseGuard(_terrain.dirty); // TERRAIN-REASON: original reuse gate.\n','')
 assert stripped==old,'GameBridge diagnostic stripping did not recover original bytes'
 return proposed

def verify_driver(folder=DRIVER):
 """Historical build evidence, then an independent actual-runtime admission."""
 assert Path(folder).resolve()==DRIVER.resolve()
 for path in (REVIEW/'prepare.py',REVIEW/'current_rv_verifier.py'): assert sha(path)==FIXED[path]
 rv=load('terrain_reason_historical_driver',REVIEW/'current_rv_verifier.py')
 for name,digest in rv.old.inputs().items(): assert sha(name)==digest,name
 rv.artifacts(rv.BASE,rv.BASE_SHA,'current-installed-room12-compatible-driver',2)
 meta=rv.artifacts(rv.SCENE,rv.SCENE_SHA,'room-scene-preconnection-preference-driver',1)
 assert meta['ordinary_timing_byte_exact'] is True
 assert sha(REVIEW/'prepare_scene_v2.py')=='1b644d79fffa7fbbdc4573b8e94374df7311fbe790036b5bd38f73cd55afae91'
 for name in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):
  assert sha(rv.SCENE/'tests'/name)==sha(rv.BASE/'tests'/name)
 assert sha(rv.SCENE/'timing/EffectsDriver.swf')==sha(rv.BASE/'timing/EffectsDriver.swf')
 expected=dict(rv.historical()); expected['pfe.swf']=current.NEW_HOST; expected[rv.RV]=rv.NEW_RV
 assert installation()==expected,'Current runtime differs outside the two exact historical driver changes'
 return meta

def inputs():
 source_check(); driver=verify_driver()
 paths=[Path(__file__),HERE/'source.diff',HERE/'README.md',COMPILER,TINT,
  REVIEW/'prepare.py',REVIEW/'current_rv_verifier.py',REVIEW/'current_host_verifier.py',REVIEW/'prepare_scene_v2.py',
  BASE/'prepared.json',BASE/'compile.json',BASE/'RConnectMod.swf',DRIVER/'prepared.json',
  ROOT/'tools/validation/runtime_memory.py',ROOT/'tools/validation/run_security_terminals.py',
  GAME/'mods/ModLoader/tools/test_registry.py']
 compiler=load('terrain_reason_compiler_inputs',COMPILER)
 paths += [compiler.JAVA,compiler.SDK/'lib/mxmlc.jar',compiler.SDK/'lib/compc.jar',
  compiler.SDK/'frameworks/air-config.xml',compiler.SDK/'frameworks/libs/air/airglobal.swc']
 pins={str(path):sha(path) for path in paths}; pins.update(current.proof_inputs()); pins.update(driver['inputs'])
 for folder,table in ((BASE/'src',read(BASE/'prepared.json')['source']),(BASE/'tools',read(BASE/'prepared.json')['inputs']),
                      (DRIVER,driver['files'])):
  pins.update({str(folder/name):digest for name,digest in table.items()})
 return pins

def verify(folder):
 folder=Path(folder).resolve(); assert folder.parent==M52
 meta=read(folder/'prepared.json'); assert meta['kind']=='room-terrain-reason-product' and meta['target']=='product'
 assert meta['diagnostic_only'] is True and meta['performance_qualified'] is False
 assert meta['base_sha256']==BASE_SHA and meta['version']==VERSION
 source_check(); assert meta['inputs']==inputs() and meta['installation_before']==installation()
 for name,digest in meta['files'].items(): assert sha(folder/name)==digest,name
 assert inventory(folder/'src')==meta['source'] and inventory(folder/'tools')==meta['tools']
 expected=dict(read(BASE/'prepared.json')['source']); expected.update(EXPECTED)
 entry=(BASE/'src/RConnectMod.as').read_bytes(); assert entry.count(b'0.2.24-roomfix5')==1
 expected['RConnectMod.as']=hashlib.sha256(entry.replace(b'0.2.24-roomfix5',VERSION.encode())).hexdigest()
 assert meta['source']==expected and meta['tools']==read(BASE/'prepared.json')['inputs']
 compiled=False
 if (folder/'compile.json').exists():
  result=read(folder/'compile.json'); assert result['compiled'] is True
  assert result['prepared_sha256']==sha(folder/'prepared.json') and result['sources_unchanged'] is True
  assert result['installation_before']==result['installation_after']==installation() and result['installation_unchanged'] is True
  assert len(result['commands'])==2 and all(row['exit_code']==0 and row['reaped'] for row in result['commands'])
  assert sha(folder/'RConnectMod.swf')==result['candidate_sha256']
  for name,digest in result['artifacts'].items(): assert sha(folder/name)==digest,name
  compiled=True
 return dict(meta,compiled=compiled)

def main():
 parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path)
 parser.add_argument('--check',action='store_true'); parser.add_argument('--verify',type=Path)
 parser.add_argument('--build',action='store_true'); parser.add_argument('--registry-wait',type=float,default=900)
 args=parser.parse_args(); assert args.registry_wait>=0
 if args.verify:
  assert not args.build and args.output is None; print(json.dumps(dict(verified=True,compiled=verify(ROOT/args.verify)['compiled']))); return
 pins=inputs(); before=installation()
 if args.check:
  assert not args.build and args.output is None; print(json.dumps(dict(checked=True,air_started=False,source_only=True))); return
 assert args.output is not None
 out=(ROOT/args.output).resolve(); assert out.parent==M52 and not out.exists(); out.mkdir()
 shutil.copytree(BASE/'src',out/'src'); shutil.copytree(BASE/'tools',out/'tools')
 for rel,data in source_check().items(): (out/'src'/rel).write_bytes(data)
 entry=out/'src/RConnectMod.as'; entry.write_bytes(entry.read_bytes().replace(b'0.2.24-roomfix5',VERSION.encode()))
 shutil.copyfile(HERE/'source.diff',out/'source.diff')
 save(out/'prepared.json',dict(kind='room-terrain-reason-product',target='product',base_sha256=BASE_SHA,version=VERSION,
  diagnostic_only=True,performance_qualified=False,air_started=False,installed=False,inputs=pins,
  installation_before=before,historical_build_environment=current.build_environment(),source=inventory(out/'src'),
  tools=inventory(out/'tools'),files=inventory(out)))
 verify(out)
 if args.build:
  compiler=load('terrain_reason_bounded_compiler',COMPILER)
  compiler.verify=verify; compiler.installation=installation
  compiler.compile_output(out,args.registry_wait)
 print(out)
if __name__=='__main__': main()
