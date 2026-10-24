"""One external native round-trip driver; product and shared runner are read-only."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, shutil, subprocess, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]; M52=ROOT/'build/m52'; GAME=ROOT.parents[1]
PRODUCT=M52/'recovery-room-terrain-reason-product-01'; BASE=M52/'recovery-room-scene-driver-02'
RUNNER=ROOT/'tools/run_coop_regression.py'; TEMPLATE=M52/'littlepip-save-replay-01/host/PFEgame0.sol'
TELEMETRY=GAME/'mods/ModLoader/release/telemetry.json'; DEPLOY=M52/'recovery-room-user-deploy-01/deployment.json'
VERSION='0.2.24-roomreason1'; PRODUCT_SHA='9a128737ce470127db16ff903fe0bcbdd8280daead0f714c983515c52a14b1ef'
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'
FIXED={RUNNER:'7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
 TEMPLATE:'2c0fe1d16138797b5914a7e1a0adb12e7438c0b0fba88e594490bba30f42c9f4',
 DEPLOY:'16ef10ba4f2a5393fd41efe0648ea55a051dd9d5dd7c9efeab722ee66d4eabe4',
 TELEMETRY:'a050ef06ea542b8fd8781f1e945f9adcd03c7ae5190719e66ba826e2059fce12',
 PRODUCT/'RConnectMod.swf':PRODUCT_SHA,
 PRODUCT/'prepared.json':'9650b504612a8a279d477f06a6ceceb5ebfc9896d58cdf168f0c2268aeadfb21',
 PRODUCT/'compile.json':'2402bbca756801456adf4431661a60cdb80bca6e812055d2f3260cf9676a856c',
 BASE/'ProductionDeclarations.swc':'598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7',
 BASE/'GameCombatStubs.swc':'8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a',
 BASE/'scene/EffectsHarness.swf':'d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086'}

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path,value):
 with Path(path).open('x',encoding='utf-8') as stream: json.dump(value,stream,ensure_ascii=False,indent=2)
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path); module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def inventory(folder): return {p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}

def installation():
 assert sha(DEPLOY)==FIXED[DEPLOY]
 actual=actual_installation();assert len(actual)==22
 # Freeze actual non-RConnect modules at preparation; do not impersonate an old environment.
 assert actual['pfe.swf']=='a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
 assert actual['mods/Rconnect/release/RConnectMod.swf']=='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
 assert sha(TELEMETRY)==FIXED[TELEMETRY] and read(TELEMETRY)=={'enabled':True}
 return actual

def actual_installation():
 return {name:sha(GAME/name) for name in read(DEPLOY)['installation_after']}

def product_evidence():
 for path,digest in FIXED.items(): assert sha(path)==digest,str(path)
 meta=read(PRODUCT/'prepared.json'); built=read(PRODUCT/'compile.json')
 assert meta['diagnostic_only'] is True and meta['version']==VERSION and built['compiled'] is True
 assert built['prepared_sha256']==sha(PRODUCT/'prepared.json') and built['candidate_sha256']==PRODUCT_SHA
 assert built['installation_before']==built['installation_after'] and built['installation_unchanged'] is True
 assert built['sources_unchanged'] is True and all(r['exit_code']==0 and r['reaped'] for r in built['commands'])
 assert inventory(PRODUCT/'src')==meta['source'] and inventory(PRODUCT/'tools')==meta['tools']
 for name,digest in meta['inputs'].items(): assert sha(name)==digest,name
 for table in (meta['files'],built['artifacts']):
  for name,digest in table.items(): assert sha(PRODUCT/name)==digest,name
 return dict(candidate_sha256=PRODUCT_SHA,historical_installation=meta['installation_before'],
  prepared_sha256=sha(PRODUCT/'prepared.json'),compile_sha256=sha(PRODUCT/'compile.json'))

def inputs():
 product_evidence()
 paths=list(FIXED)+[Path(__file__),HERE/'tests/TerrainRoundTripTestDoc.as',JAVA,SDK/'lib/mxmlc.jar',
  SDK/'frameworks/air-config.xml',SDK/'frameworks/libs/air/airglobal.swc',
  ROOT/'tools/validation/runtime_memory.py',ROOT/'tools/validation/air_test_inventory.py',
  ROOT/'tools/validation/native_runtime_assets.py',GAME/'mods/ModLoader/tools/test_registry.py',
  GAME/'mods/ModLoader/tools/air_test_process.py']
 return {str(p):sha(p) for p in paths}

def verify(out):
 out=Path(out).resolve(); assert out.parent==M52
 meta=read(out/'prepared.json'); assert meta['kind']=='terrain-solo-roundtrip-driver'
 assert meta['mechanism_only'] is True and meta['performance_qualified'] is False
 assert meta['inputs']==inputs() and meta['installation_before']==installation()
 for name,digest in meta['files'].items(): assert sha(out/name)==digest,name
 compiled=False
 if (out/'compile.json').exists():
  built=read(out/'compile.json'); assert built['compiled'] is True
  assert built['prepared_sha256']==sha(out/'prepared.json')
  assert built['installation_before']==built['installation_after']==installation()
  assert built['inputs_unchanged'] is True and built.get('validation_error') is None
  assert len(built['commands'])==1 and built['commands'][0]['exit_code']==0 and built['commands'][0]['reaped']
  for name,digest in built['artifacts'].items(): assert sha(out/name)==digest,name
  assert read(out/'driver-input.json')['candidate_sha256']==PRODUCT_SHA; compiled=True
 return dict(meta,compiled=compiled)

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path);ap.add_argument('--verify',type=Path)
 ap.add_argument('--check',action='store_true');ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900)
 args=ap.parse_args();assert args.registry_wait>=0
 if args.verify:
  assert not args.build and args.output is None; print(json.dumps({'verified':True,'compiled':verify(ROOT/args.verify)['compiled']}));return
 pins=inputs(); before=installation()
 if args.check:
  assert not args.build and args.output is None;print(json.dumps({'checked':True,'air_started':False,'installation_items':len(before)}));return
 assert args.output is not None
 out=(ROOT/args.output).resolve();assert out.parent==M52 and not out.exists();(out/'tests').mkdir(parents=True)
 shutil.copyfile(HERE/'tests/TerrainRoundTripTestDoc.as',out/'tests/TerrainRoundTripTestDoc.as')
 for name in ('ProductionDeclarations.swc','GameCombatStubs.swc'):shutil.copyfile(BASE/name,out/name)
 shutil.copyfile(BASE/'scene/EffectsHarness.swf',out/'EffectsHarness.swf')
 save(out/'prepared.json',dict(kind='terrain-solo-roundtrip-driver',mechanism_only=True,performance_qualified=False,
  inputs=pins,installation_before=before,telemetry_sha256=sha(TELEMETRY),product=product_evidence(),files=inventory(out),
  installation_diff_from_deployment={name:dict(deployed=read(DEPLOY)['installation_after'][name],current=digest)
   for name,digest in before.items() if read(DEPLOY)['installation_after'][name]!=digest}))
 verify(out)
 if not args.build:print(out);return
 sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
 sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
 command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
  '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
  '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
  '-output='+str(out/'EffectsDriver.swf'),str(out/'tests/TerrainRoundTripTestDoc.as')]
 row=dict(command=command,pid=None,exit_code=None,reaped=False);compiled=False;error=None
 try:
  with Registration(owner='RConnect / 地形单实例往返取证',resource='game',purpose='Compile one external native fixture; no AIR',run_dir=out,evidence=out/'compile.log',wait=args.registry_wait) as record:
   process=None
   try:
    assert snapshot()['free_commit_bytes']>=1024**3 and installation()==before
    assert inputs()==pins;record.before_launch('Terrain native round-trip driver compilation')
    with (out/'compile.log').open('x',encoding='utf-8') as log:
     process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
     record.child(process.pid);row.update(pid=process.pid,exit_code=wait_owned(process,240,out/'compile-memory.json'))
     assert row['exit_code']==0;assert (out/'EffectsDriver.swf').is_file()
    save(out/'driver-input.json',dict(candidate_sha256=PRODUCT_SHA,driver_sha256=sha(out/'EffectsDriver.swf'),mechanism_only=True))
    compiled=True;record.outcome='passed';record.note='External driver compiled; no runtime qualification'
   finally:
    if process is not None:
     if process.poll() is None:process.kill()
     process.wait();row['reaped']=process.poll() is not None
    record.child_stopped()
 except BaseException as exc:error=repr(exc);raise
 finally:
  after=None;unchanged=False;validation_error=None
  try:
   after=actual_installation();unchanged=after==before and inputs()==pins
   if not unchanged:validation_error='Installed files or frozen inputs changed'
  except BaseException as validation:validation_error=repr(validation)
  save(out/'compile.json',dict(compiled=compiled,commands=[row],error=error,prepared_sha256=sha(out/'prepared.json'),
   installation_before=before,installation_after=after,inputs_unchanged=unchanged,validation_error=validation_error,air_started=False,
   artifacts={n:sha(out/n) for n in ('EffectsDriver.swf','driver-input.json') if (out/n).is_file()}))
  if not unchanged and error is None:raise RuntimeError(validation_error)
 verify(out);print(out)
if __name__=='__main__':main()
