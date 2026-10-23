"""Prepare isolated method counters or unchanged scene assertions with external counters."""
from pathlib import Path
import argparse,difflib,importlib.util,json,os,re,shutil,subprocess,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52';GAME=ROOT.parents[1]
REVIEW=HERE.parent/'recovery-room-repair-review';BASE=M52/'recovery-room-scene-driver-02'
PRODUCT_BASE=M52/'recovery-room-production-04';VERSION='0.2.24-roomtime1'
sys.path.insert(0,str(REVIEW))
spec=importlib.util.spec_from_file_location('loading_counter_current_host',REVIEW/'current_host_verifier.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha,read,save,installation=original.sha,original.read,original.save,original.installation
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=ROOT.parent/'Sandevistan/build/tools/flexsdk'
OVERLAYS=('rconnect/game/GameBridge.as','rconnect/game/MirrorMasks.as','rconnect/game/LoadingCounters.as')

def inventory(folder):return {p.relative_to(folder).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}

def source_check():
 # Remove only exact inserted observation wrappers and recover the original source.
 for name,count in [('GameBridge',4),('MirrorMasks',4)]:
  s=(HERE/'src/rconnect/game'/str(name+'.as')).read_text()
  if name=='MirrorMasks':
   sentinel='         return ""; // Compiler-only unreachable fallback after the preserved try/finally.\n'
   assert s.count(sentinel)==1
   s=s.replace(sentinel,'')
  assert s.count('         var loadingAt:int=LoadingCounters.enter();\n         try {')==count
  s=s.replace('         var loadingAt:int=LoadingCounters.enter();\n         try {','')
  s,n=re.subn(r'\n         } finally \{LoadingCounters.end\("'+name+r'\.\w+",loadingAt\);}\n      }','}',s)
  assert n==count
  if name=='GameBridge':
   s=s.replace('      /** Isolated diagnostic candidate only; no gameplay or wire state. */\n      public function beginLoadingCounters(kind:String,index:int):Boolean {return LoadingCounters.begin(kind,index);}\n      public function endLoadingCounters():Object {return LoadingCounters.finish();}\n','')
  else:
   s=s.replace('      private var loadingReferencesDepth:int=0;\n','')
   s=s.replace('         var loadingAt:int=loadingReferencesDepth++==0?LoadingCounters.enter():-1;\n         LoadingCounters.node();\n         try {','')
   s=s.replace('\n         } finally {loadingReferencesDepth--;LoadingCounters.end("MirrorMasks.maskReferences",loadingAt);}\n      }','}')
  s=s.replace('{\n\n','{\n')
  assert s==(PRODUCT_BASE/'src/rconnect/game'/str(name+'.as')).read_text(),name+' original body drift'
 for n in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as'):assert sha(HERE/'tests'/n)==sha(BASE/'tests'/n)
 assert set(inventory(HERE/'src'))==set(OVERLAYS)
 assert 'flash.sampler' not in (HERE/'tests/A22RoomMetrics.as').read_text()

def inputs():
 assert sha(REVIEW/'current_host_verifier.py')=='3abcd73d2dee5a47c4c5b94f549fd5106f8ebefb10ad7f71479f9269f5b321e8'
 assert sha(HERE.parent/'recovery-room-production-v4/build.py')=='1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9'
 original.verify(BASE);original.verify_product(PRODUCT_BASE);source_check()
 base=read(PRODUCT_BASE/'prepared.json')
 assert inventory(PRODUCT_BASE/'src')==base['source'] and inventory(PRODUCT_BASE/'tools')==base['inputs']
 paths=[Path(__file__),REVIEW/'prepare.py',REVIEW/'current_host_verifier.py',BASE/'prepared.json',
  PRODUCT_BASE/'prepared.json',PRODUCT_BASE/'compile.json',PRODUCT_BASE/'RConnectMod.swf',
  HERE.parent/'recovery-room-production-v4/build.py',JAVA,SDK/'lib/mxmlc.jar',SDK/'lib/compc.jar',
  SDK/'frameworks/air-config.xml',SDK/'frameworks/libs/air/airglobal.swc',ROOT/'tools/validation/runtime_memory.py',
  GAME/'mods/ModLoader/tools/test_registry.py']
 paths+=list((HERE/'src').rglob('*.as'))+list((HERE/'tests').glob('*.as'))
 paths+=[BASE/n for n in ('tests/RoomTravelTimingTestDoc.as','tests/RoomTravelSceneTestDoc.as','tests/A22RoomMetrics.as',
  'ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf')]
 pins={str(p):sha(p) for p in paths};pins.update(original.proof_inputs());return pins

def verify(out):
 out=Path(out).resolve();m=read(out/'prepared.json');assert out.parent==M52
 assert m['kind'] in ('room-loading-method-counter-product','room-loading-method-counter-driver')
 assert m['diagnostic_only'] is True and m['performance_qualified'] is False
 inputs();assert m['installation_before']==installation()
 for n,h in m['inputs'].items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 if m['target']=='product':
  assert inventory(out/'src')==m['source'] and inventory(out/'tools')==m['tools']
  assert m['base_sha256']==original.PRODUCT_SHA and m['version']==VERSION
 else:
  for n in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as'):assert sha(out/'tests'/n)==sha(BASE/'tests'/n)
  assert sha(out/'tests/A22RoomMetrics.as')==sha(HERE/'tests/A22RoomMetrics.as')
 if (out/'compile.json').is_file():
  result=read(out/'compile.json');assert result['compiled'] is True
  assert result['prepared_sha256']==sha(out/'prepared.json')
  assert result['installation_before']==result['installation_after']==installation() and result['installation_unchanged'] is True
  assert result['sources_unchanged'] is True
  assert len(result['commands'])==(2 if m['target']=='product' else 1)
  assert all(c['exit_code']==0 and c['reaped'] for c in result['commands'])
  binary=out/('RConnectMod.swf' if m['target']=='product' else 'scene/EffectsDriver.swf')
  assert sha(binary)==result['candidate_sha256']
  for n,h in result['artifacts'].items():assert sha(out/n)==h,n
  m=dict(m,compiled=True)
 else:m=dict(m,compiled=False)
 return m

def compile_output(out,wait):
 meta=verify(out);assert not (out/'compile.json').exists()
 before=installation();result=dict(compiled=False,commands=[],installation_before=before,diagnostic_only=True,
  prepared_sha256=sha(out/'prepared.json'),air_started=False,installed=False,performance_qualified=False)
 sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
 sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
 saved_argv=sys.argv
 try:
  with Registration(owner='RConnect / 加载短窗计时',resource='game',purpose=meta['target']+' isolated compile',run_dir=out,evidence=out/'compile.json',wait=wait) as reg:
   verify(out)
   with (out/'compile.log').open('x',encoding='utf-8') as log:
    def owned(command,env=None,check=False):
     index=len(result['commands']);expected=(SDK/'lib/compc.jar' if meta['target']=='product' and index==0 else SDK/'lib/mxmlc.jar')
     assert index<(2 if meta['target']=='product' else 1) and command[0]==str(JAVA) and '-Xmx384m' in command
     assert Path(command[command.index('-jar')+1]).resolve()==expected.resolve()
     assert snapshot()['free_commit_bytes']>=1024**3 and installation()==before
     reg.before_launch('isolated loading counters compiler')
     row=dict(command=command,pid=None,exit_code=None,reaped=False);result['commands'].append(row);process=None
     try:
      process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
      reg.child(process.pid);row['pid']=process.pid
      code=wait_owned(process,300,out/('compile-memory-'+str(index)+'.json'));row['exit_code']=code
     finally:
      if process is not None:
       if process.poll() is None:process.kill()
       process.wait();row['reaped']=process.poll() is not None
      reg.child_stopped()
     if check and code:raise subprocess.CalledProcessError(code,command)
     return subprocess.CompletedProcess(command,code)
    if meta['target']=='product':
     spec=importlib.util.spec_from_file_location('loading_counter_original_compiler',out/'tools/build_mod.py')
     module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
     module.subprocess=types.SimpleNamespace(run=owned)
     sys.argv=[str(out/'tools/build_mod.py'),'--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
     module.main();binary=out/'RConnectMod.swf'
    else:
     binary=out/'scene/EffectsDriver.swf'
     command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
      '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
      '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
      '-output='+str(binary),str(out/'tests/RoomTravelSceneTestDoc.as')]
     owned(command,env=dict(os.environ,AIR_HOME=str(SDK)),check=True)
   assert all(c['exit_code']==0 for c in result['commands']) and binary.is_file()
   result.update(compiled=True,candidate_sha256=sha(binary));reg.outcome='passed';reg.note='Diagnostic only, no AIR'
 except BaseException as error:result['error']=repr(error);raise
 finally:
  sys.argv=saved_argv
  result['installation_after']=installation();result['installation_unchanged']=before==result['installation_after']
  result['sources_unchanged']=all(sha(out/n)==h for n,h in meta['files'].items())
  result['artifacts']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.suffix in ('.swf','.swc')}
  save(out/'compile.json',result)
 if result['compiled']:verify(out)

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--target',choices=['product','driver'],default='driver')
 ap.add_argument('--output',type=Path);ap.add_argument('--check',action='store_true');ap.add_argument('--build',action='store_true')
 ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args();pins=inputs();before=installation()
 if a.check:print(json.dumps(dict(checked=True,source_only=True,air_started=False)));return
 assert a.output is not None and a.registry_wait>=0
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists();out.mkdir()
 if a.target=='product':
  shutil.copytree(PRODUCT_BASE/'src',out/'src');shutil.copytree(PRODUCT_BASE/'tools',out/'tools')
  for rel in OVERLAYS:shutil.copyfile(HERE/'src'/rel,out/'src'/rel)
  entry=out/'src/RConnectMod.as';data=entry.read_bytes();assert data.count(b'0.2.24-roomfix4')==1
  entry.write_bytes(data.replace(b'0.2.24-roomfix4',VERSION.encode()))
  meta=dict(kind='room-loading-method-counter-product',base_sha256=original.PRODUCT_SHA,version=VERSION,source=inventory(out/'src'),tools=inventory(out/'tools'))
  diffs=[]
  for rel in ('RConnectMod.as',)+OVERLAYS:
   old=PRODUCT_BASE/'src'/rel;new=out/'src'/rel
   diffs+=list(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],new.read_text().splitlines(True),fromfile='roomfix4/'+rel,tofile='roomtime1/'+rel))
 else:
  shutil.copytree(HERE/'tests',out/'tests');(out/'scene').mkdir();(out/'timing').mkdir()
  for n in ('ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf'):shutil.copyfile(BASE/n,out/n)
  meta=dict(kind='room-loading-method-counter-driver',external=True,scene_and_timing_assertions_byte_exact=True)
  diffs=difflib.unified_diff((BASE/'tests/A22RoomMetrics.as').read_text().splitlines(True),(out/'tests/A22RoomMetrics.as').read_text().splitlines(True),fromfile='scene02/A22RoomMetrics.as',tofile='counters/A22RoomMetrics.as')
 (out/'source.diff').write_text(''.join(diffs),encoding='utf-8')
 meta.update(target=a.target,inputs=pins,installation_before=before,diagnostic_only=True,performance_qualified=False,
  air_started=False,installed=False,files=inventory(out))
 save(out/'prepared.json',meta);verify(out)
 if a.build:compile_output(out,a.registry_wait)
 print(out)
if __name__=='__main__':main()
