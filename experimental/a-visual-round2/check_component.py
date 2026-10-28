from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys,uuid
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
sys.path[:0]=[str(GAME/'mods/ModLoader/tools'),str(RC/'tools/validation')]
from test_registry import Registration
from air_test_process import HiddenProcess
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();assert out.is_relative_to(RC/'build') and not out.exists()
 (out/'src/rconnect/game').mkdir(parents=True)
 shutil.copyfile(HERE/'src/rconnect/game/ProjectilePlayback.as',out/'src/rconnect/game/ProjectilePlayback.as')
 shutil.copyfile(HERE/'ProjectileSampleChecks.as',out/'src/ProjectileSampleChecks.as')
 inputs={str(f.relative_to(out)):sha(f) for f in (out/'src').rglob('*.as')}
 command=[str(JAVA),'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'src'),'-output='+str(out/'checks.swf'),str(out/'src/ProjectileSampleChecks.as')]
 (out/'input.json').write_text(json.dumps(dict(source=inputs,command=command)),encoding='utf8')
 with Registration(owner='RConnect / 轨迹组件',purpose='Confirmed interpolation only; no native game',run_dir=out,evidence=out/'result.json',wait=300) as reg:
  with (out/'compile.log').open('w',encoding='utf8') as log:
   proc=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
   reg.child(proc.pid)
   try:assert proc.wait(timeout=120)==0,'compile.log'
   finally:
    if proc.poll() is None:proc.kill();proc.wait()
    reg.child_stopped()
  appid='pfe-modsettings-rconnect-component-'+uuid.uuid4().hex
  desc=out/'application.xml';desc.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>RConnectChecks</filename><initialWindow><content>checks.swf</content><visible>false</visible></initialWindow></application>',encoding='utf8')
  reg.before_launch('Isolated pure interpolation component')
  with (out/'runtime.log').open('w',encoding='utf8') as log:
   proc=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc)],cwd=out,stdout=log,stderr=log);reg.child(proc.pid)
   try:assert proc.wait(timeout=40)==0,'runtime.log'
   finally:
    if proc.poll() is None:proc.kill();proc.wait()
    proc.close();reg.child_stopped()
  storage=Path(os.environ['APPDATA'])/appid/'Local Store/result.json'
  shutil.copyfile(storage,out/'result.json')
  result=json.loads((out/'result.json').read_text('utf8'));assert result['passed']
  reg.outcome='passed';reg.note='Native AIR component verified; not a game performance claim'
 print(json.dumps(dict(passed=result['passed'],checks=len(result['checks']))))
if __name__=='__main__':main()
