"""Build external driver and muted harness, not the product; no AIR launch."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
RC=HERE.parents[1]; GAME=RC.parents[1]
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'
ABI=RC/'build/m52/recovery-room-scene-driver-02'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--wait',type=int,default=300)
 p.add_argument('--entry',choices=('StutterProbe','FocusedBlastProbe'),default='StutterProbe');a=p.parse_args()
 out=a.output.resolve();assert out.is_relative_to(RC/'build') and not out.exists()
 out.mkdir(parents=True);(out/'driver').mkdir();(out/'harness').mkdir()
 source=HERE/(a.entry+'.as');shutil.copyfile(source,out/'driver'/source.name)
 shutil.copyfile(HERE/'RConnectMod.as',out/'harness/RConnectMod.as')
 for name in ('ProductionDeclarations.swc','GameCombatStubs.swc'):shutil.copyfile(ABI/name,out/name)
 inputs={str(p):sha(p) for p in [source,HERE/'RConnectMod.as',Path(__file__),JAVA,SDK/'lib/mxmlc.jar',ABI/'ProductionDeclarations.swc',ABI/'GameCombatStubs.swc']}
 common=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
 commands=[common+['-source-path='+str(out/'harness'),'-output='+str(out/'EffectsHarness.swf'),str(out/'harness/RConnectMod.as')],
 common+['-source-path='+str(out/'driver'),'-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),'-output='+str(out/'EffectsDriver.swf'),str(out/'driver'/source.name)]]
 result={'inputs':inputs,'commands':commands,'entry':a.entry,'compiled':False}
 (out/'prepared.json').write_text(json.dumps(result,indent=2),encoding='utf8')
 try:
  with Registration(owner='RConnect / 卡顿历史对照',purpose='Compile isolated player fire driver and mute harness only',run_dir=out,evidence=out/'compile.json',wait=a.wait) as reg:
   with (out/'compile.log').open('w',encoding='utf8') as log:
    for command in commands:
     proc=None
     try:
      reg.before_launch('Compile external test SWF; no AIR')
      proc=subprocess.Popen(command,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);reg.child(proc.pid)
      assert proc.wait(timeout=300)==0,'Read compile.log'
     finally:
      if proc is not None:
       if proc.poll() is None:proc.kill()
       proc.wait();reg.child_stopped()
   result.update(compiled=True,driver_sha256=sha(out/'EffectsDriver.swf'),harness_sha256=sha(out/'EffectsHarness.swf'))
   reg.outcome='passed';reg.note='External tests compiled, no game run'
 finally:(out/'compile.json').write_text(json.dumps(result,indent=2),encoding='utf8')
 print(json.dumps(result))
if __name__=='__main__':main()
