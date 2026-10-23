"""Freeze scene preference evidence; preserve ordinary timing and all travel assertions."""
from pathlib import Path
import argparse,difflib,json,os,shutil,subprocess,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import prepare as original
ROOT,M52,GAME=original.ROOT,original.M52,original.GAME
HERE=Path(__file__).resolve().parent;BASE=M52/'recovery-room-current-driver-01'
sha,read,save,installation=original.sha,original.read,original.save,original.installation
def inputs():
 assert sha(HERE/'prepare.py')=='eb0c7c560724244619fa9996d5fbecf7bb353c964aced4e89bfe009f0b4c0e80'
 original.verify(BASE)
 paths=[Path(__file__),HERE/'prepare.py',BASE/'prepared.json',HERE/'scene-v2/tests/RoomTravelSceneTestDoc.as']
 paths += [BASE/n for n in ('tests/RoomTravelTimingTestDoc.as','tests/A22RoomMetrics.as','ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf')]
 return {str(p):sha(p) for p in paths}
def verify(out):
 m=read(out/'prepared.json');assert m['kind']=='room-scene-preconnection-preference-driver' and m['compiled'] is True
 assert m['installation_before']==installation()
 inputs()
 for n,h in m['inputs'].items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 for n in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):assert sha(out/'tests'/n)==sha(BASE/'tests'/n)
 assert sha(out/'timing/EffectsDriver.swf')==sha(BASE/'timing/EffectsDriver.swf')
 return m
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists() and a.registry_wait>=0
 before=installation();pins=inputs();out.mkdir();(out/'tests').mkdir();(out/'scene').mkdir();(out/'timing').mkdir()
 for n in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):shutil.copyfile(BASE/'tests'/n,out/'tests'/n)
 shutil.copyfile(HERE/'scene-v2/tests/RoomTravelSceneTestDoc.as',out/'tests/RoomTravelSceneTestDoc.as')
 for n in ('ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf'):shutil.copyfile(BASE/n,out/n)
 (out/'source.diff').write_text(''.join(difflib.unified_diff((BASE/'tests/RoomTravelSceneTestDoc.as').read_text().splitlines(True),(out/'tests/RoomTravelSceneTestDoc.as').read_text().splitlines(True),fromfile='driver01/RoomTravelSceneTestDoc.as',tofile='scene-v2/RoomTravelSceneTestDoc.as')),encoding='utf-8')
 commands=[];compiled=False
 if a.build:
  sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
  sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
  sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
  command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),'-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),'-output='+str(out/'scene/EffectsDriver.swf'),str(out/'tests/RoomTravelSceneTestDoc.as')]
  with Registration(owner='RConnect / 场景连接前偏好夹具',resource='game',purpose='Compile scene subclass only; ordinary timing unchanged',run_dir=out,evidence=out/'compile.log',wait=a.registry_wait) as record:
   process=None;row={'command':command};commands.append(row)
   try:
    assert snapshot()['free_commit_bytes']>=1024**3
    record.before_launch('Scene preference external driver')
    with (out/'compile.log').open('x',encoding='utf-8') as log:
     process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
     record.child(process.pid);row.update(pid=process.pid,exit_code=wait_owned(process,240,out/'compile-memory.json'))
     assert row['exit_code']==0
    compiled=(out/'scene/EffectsDriver.swf').is_file();assert compiled
    record.outcome='passed';record.note='Scene subclass compiled; no AIR'
   finally:
    if process is not None and process.poll() is None:process.kill();process.wait()
    record.child_stopped()
 assert installation()==before
 for n,h in pins.items():assert sha(n)==h,n
 save(out/'prepared.json',dict(kind='room-scene-preconnection-preference-driver',compiled=compiled,external=True,inputs=pins,installation_before=before,commands=commands,ordinary_timing_byte_exact=True,air_started=False,installed=False,files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}))
 if compiled:verify(out)
 print(out)
if __name__=='__main__':main()
