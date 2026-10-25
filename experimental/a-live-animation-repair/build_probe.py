"""Compile one external native probe. Never compile or deploy production code."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
sys.path.insert(0,str(ROOT/'tools/validation'));sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from run_security_terminals import installation
from runtime_memory import snapshot,wait_owned
from test_registry import Registration
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'
ABI=ROOT/'build/m52/recovery-room-scene-driver-02'
PINS={'ProductionDeclarations.swc':'598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7',
 'GameCombatStubs.swc':'8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a',
 'scene/EffectsHarness.swf':'d52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):
 with p.open('x',encoding='utf8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('output',type=Path);ap.add_argument('--entry',default='AnimationRepairProbe');a=ap.parse_args()
 out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
 source=HERE/(a.entry+'.as');assert source.is_file() and source.parent==HERE
 for n,h in PINS.items():assert sha(ABI/n)==h,n
 before=installation();pins={str(source):sha(source),str(Path(__file__)):sha(__file__)}
 out.mkdir();shutil.copyfile(source,out/source.name)
 for n in ('ProductionDeclarations.swc','GameCombatStubs.swc'):shutil.copyfile(ABI/n,out/n)
 shutil.copyfile(ABI/'scene/EffectsHarness.swf',out/'EffectsHarness.swf')
 command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
  '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out),
  '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
  '-output='+str(out/'EffectsDriver.swf'),str(out/source.name)]
 receipt=dict(compiled=False,command=command,inputs=pins,installation_before=before,pid=None,exit_code=None,reaped=False)
 save(out/'prepared.json',receipt)
 try:
  with Registration(owner='RConnect / 动画缺口',purpose='External native animation probe compile',run_dir=out,evidence=out/'compile.json',wait=900) as reg:
   assert snapshot()['free_commit_bytes']>=1024**3
   proc=None
   try:
    reg.before_launch('Compile external driver; no AIR')
    with (out/'compile.log').open('x',encoding='utf8') as log:
     proc=subprocess.Popen(command,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
     receipt['pid']=proc.pid;reg.child(proc.pid);receipt['exit_code']=wait_owned(proc,300,out/'compile-memory.json')
    assert receipt['exit_code']==0,'Read compile.log'
   finally:
    if proc is not None:
     if proc.poll() is None:proc.kill()
     proc.wait();receipt['reaped']=True;reg.child_stopped()
   assert installation()==before and all(sha(n)==h for n,h in pins.items())
   receipt['compiled']=True;receipt['driver_sha256']=sha(out/'EffectsDriver.swf')
   save(out/'driver-input.json',dict(candidate_sha256=sha(ROOT/'release/RConnectMod.swf'),entry=a.entry))
   reg.outcome='passed';reg.note='External probe compiled only; no native result'
 finally:
  receipt['installation_after']=installation();receipt['installation_unchanged']=receipt['installation_after']==before
  save(out/'compile.json',receipt)
 print(json.dumps({k:receipt[k] for k in ('compiled','pid','exit_code','reaped','installation_unchanged')}))
if __name__=='__main__':main()
