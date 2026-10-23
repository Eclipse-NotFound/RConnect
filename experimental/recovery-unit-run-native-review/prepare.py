"""External user-seed Unit.run observation driver; no production changes."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]; M52=ROOT/'build/m52'; GAME=ROOT.parents[1]
BASE=M52/'room-travel-driver-12'
RUNNER=ROOT/'tools/run_coop_regression.py'
PINNED={
 'pfe.swf':'80cfd8cf3138ee59cbf6eda0a1824a9ec960f413bd95e4b90d41dd0322b4fd3d',
 'mods/RConnect/release/RConnectMod.swf':'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7',
 'mods/RealisticVision/release/RealisticVisionMod.swf':'6dbbae60eb09ff8f42d34e31edc92fb9f83009ba918e9145980c6d289723d8ba',
 'mods/Sandevistan/release/SandevistanMod.swf':'cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942'}
SOURCES={'RoomTravelTimingTestDoc.as': '41203e838205bac14ab3f5ba386b47c9707c3708f79833279683a1cb1a6a8edd', 'RoomTravelSceneTestDoc.as': '55e2caa583fc5f14c1844e10fd46506b9d681b889fb9b94ab82053b02df2547b', 'A22RoomMetrics.as': '314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e', 'UnitRunGenerationProbe.as': '02e9a931e9f94f31fea5a6285598d1f5b49e26206912f61f4b1b840bd222e248'}
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):
 with Path(p).open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def installation():
 sys.path.insert(0,str(ROOT/'tools/validation'))
 from run_security_terminals import installation as inventory
 value=inventory();assert len(value)==22
 for n,h in PINNED.items():assert sha(GAME/n)==h,n
 return value
def inputs():
 assert sha(BASE/'prepared.json')=='3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784'
 assert sha(RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
 pins={str(BASE/'prepared.json'):sha(BASE/'prepared.json'),str(RUNNER):sha(RUNNER),str(Path(__file__)):sha(__file__)}
 for n,h in read(BASE/'prepared.json')['files'].items():assert sha(BASE/n)==h,n
 for n,h in SOURCES.items():assert sha(HERE/'tests'/n)==h,n
 for p in [BASE/'ProductionDeclarations.swc',BASE/'scene/EffectsHarness.swf',
           M52/'coop-bundle-04/build/GameCombatStubs.swc',HERE/'source.diff',*[HERE/'tests'/n for n in SOURCES]]:
  pins[str(p)]=sha(p)
 return pins
def verify(out):
 m=read(out/'prepared.json');assert m['kind']=='user-seed-unit-run-observation-driver'
 assert m['installation_before']==installation()
 for n,h in {**inputs(),**m['inputs']}.items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 return m
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists() and a.registry_wait>=0
 pins=inputs();before=installation();out.mkdir();(out/'tests').mkdir()
 for n in SOURCES:shutil.copyfile(HERE/'tests'/n,out/'tests'/n)
 shutil.copyfile(BASE/'ProductionDeclarations.swc',out/'ProductionDeclarations.swc')
 shutil.copyfile(M52/'coop-bundle-04/build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
 commands=[];compiled=False
 if a.build:
  sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
  sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
  sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
  with Registration(owner='RConnect / 用户地图首错取证驱动',resource='game',purpose='Compile external scene/timing only; no AIR',run_dir=out,evidence=out/'compile.log',wait=a.registry_wait) as record:
   with (out/'compile.log').open('x',encoding='utf-8') as log:
    for scenario,entry in [('scene','RoomTravelSceneTestDoc'),('timing','RoomTravelTimingTestDoc')]:
     target=out/scenario;target.mkdir();shutil.copyfile(BASE/'scene/EffectsHarness.swf',target/'EffectsHarness.swf')
     cmd=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
      '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
      '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
      '-output='+str(target/'EffectsDriver.swf'),str(out/'tests'/(entry+'.as'))]
     process=None;row={'command':cmd};commands.append(row)
     try:
      assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
      record.before_launch('Room baseline '+scenario)
      process=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
      record.child(process.pid);row.update(pid=process.pid,exit_code=wait_owned(process,240,out/(scenario+'-compile-memory.json')))
      assert row['exit_code']==0,row
     finally:
      if process is not None and process.poll() is None:process.kill();process.wait()
      record.child_stopped()
     assert (target/'EffectsDriver.swf').is_file()
   record.outcome='passed';record.note='External driver compiled; not runtime qualification'
  compiled=True
 assert installation()==before
 for n,h in pins.items():assert sha(n)==h,n
 save(out/'prepared.json',dict(kind='user-seed-unit-run-observation-driver',compiled=compiled,external=True,
  inputs=pins,source_driver_manifest=sha(BASE/'prepared.json'),installation_before=before,
  commands=commands,air_started=False,installed=False,
  files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}))
 verify(out);print(out)
if __name__=='__main__':main()
