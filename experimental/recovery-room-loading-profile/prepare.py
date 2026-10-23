"""Compile the existing scene fixture with bounded external grant/frame sampling."""
from pathlib import Path
import argparse,difflib,importlib.util,json,os,shutil,subprocess,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52';GAME=ROOT.parents[1]
REVIEW=HERE.parent/'recovery-room-repair-review';BASE=M52/'recovery-room-scene-driver-02'
sys.path.insert(0,str(REVIEW))
spec=importlib.util.spec_from_file_location('loading_profile_current_runtime',REVIEW/'current_rv_verifier.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha,read,save,installation=original.sha,original.read,original.save,original.installation

def inputs():
 assert sha(REVIEW/'current_rv_verifier.py')=='a12bd5788bfb3ddf7634c9115fe9784934bc7880d24748222de1b533b9df4c8b'
 original.verify(BASE)
 for n in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as'):assert sha(HERE/'tests'/n)==sha(BASE/'tests'/n)
 paths=[Path(__file__),REVIEW/'prepare.py',REVIEW/'current_rv_verifier.py',BASE/'prepared.json',original.RECEIPT,
  HERE.parent/'recovery-density-corridor-readyfix/tests/SustainedDensityTestDoc.as']
 paths += list((HERE/'tests').glob('*.as'))
 paths += [BASE/n for n in ('tests/RoomTravelTimingTestDoc.as','tests/RoomTravelSceneTestDoc.as','tests/A22RoomMetrics.as',
  'ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf')]
 return {str(p):sha(p) for p in paths}

def verify(out):
 out=Path(out).resolve();m=read(out/'prepared.json')
 assert m['kind']=='room-loading-bounded-external-cpu-driver' and m['compiled'] is True and m['external'] is True
 assert m['installation_before']==installation() and m['installation_unchanged'] is True
 inputs()
 assert len(m['commands'])==1 and all(c['exit_code']==0 for c in m['commands'])
 for n,h in m['inputs'].items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 for n in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as'):assert sha(out/'tests'/n)==sha(BASE/'tests'/n)
 assert sha(out/'tests/A22RoomMetrics.as')==sha(HERE/'tests/A22RoomMetrics.as')
 assert sha(out/'scene/EffectsHarness.swf')==sha(BASE/'scene/EffectsHarness.swf')
 return m

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path);ap.add_argument('--build',action='store_true')
 ap.add_argument('--check',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 pins=inputs();before=installation()
 if a.check:print(json.dumps(dict(checked=True,source_count=3,air_started=False)));return
 assert a.output is not None and a.registry_wait>=0
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists()
 out.mkdir();(out/'tests').mkdir();(out/'scene').mkdir();(out/'timing').mkdir()
 for p in (HERE/'tests').glob('*.as'):shutil.copyfile(p,out/'tests'/p.name)
 for n in ('ProductionDeclarations.swc','GameCombatStubs.swc','scene/EffectsHarness.swf','timing/EffectsDriver.swf','timing/EffectsHarness.swf'):shutil.copyfile(BASE/n,out/n)
 (out/'source.diff').write_text(''.join(difflib.unified_diff((BASE/'tests/A22RoomMetrics.as').read_text().splitlines(True),
  (out/'tests/A22RoomMetrics.as').read_text().splitlines(True),fromfile='scene02/A22RoomMetrics.as',tofile='loading-profile/A22RoomMetrics.as')),encoding='utf-8')
 commands=[];compiled=False;error=None
 try:
  if a.build:
   sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
   sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
   sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
   command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
    '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
    '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
    '-output='+str(out/'scene/EffectsDriver.swf'),str(out/'tests/RoomTravelSceneTestDoc.as')]
   with Registration(owner='RConnect / 加入房间有界采样',resource='game',purpose='Compile external metrics only; no AIR',run_dir=out,evidence=out/'compile.log',wait=a.registry_wait) as record:
    process=None;row={'command':command};commands.append(row)
    try:
     assert snapshot()['free_commit_bytes']>=1024**3
     assert installation()==before
     for n,h in pins.items():assert sha(n)==h,n
     record.before_launch('External loading CPU metrics driver')
     with (out/'compile.log').open('x',encoding='utf-8') as log:
      process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
      record.child(process.pid);row.update(pid=process.pid,exit_code=wait_owned(process,240,out/'compile-memory.json'))
      assert row['exit_code']==0
     compiled=(out/'scene/EffectsDriver.swf').is_file();assert compiled
     record.outcome='passed';record.note='External metrics compiled; no AIR'
    finally:
     if process is not None and process.poll() is None:process.kill();process.wait()
     record.child_stopped()
 except BaseException as exc:error=repr(exc);raise
 finally:
  unchanged=installation()==before
  for n,h in pins.items():assert sha(n)==h,n
  save(out/'prepared.json',dict(kind='room-loading-bounded-external-cpu-driver',compiled=compiled,external=True,
   inputs=pins,installation_before=before,installation_unchanged=unchanged,commands=commands,error=error,
   ordinary_timing_driver_byte_exact=True,scene_and_timing_assertions_byte_exact=True,metrics_modified=True,
   air_started=False,installed=False,performance_qualified=False,files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}))
  assert unchanged
 if compiled:verify(out)
 print(out)
if __name__=='__main__':main()
