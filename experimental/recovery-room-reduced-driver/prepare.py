"""Ordinary three-travel fixture with ContinuousScene explicitly unloaded."""
from pathlib import Path
import argparse,importlib.util,json,os,shutil,subprocess,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52';GAME=ROOT.parents[1]
REVIEW=HERE.parent/'recovery-room-repair-review';BASE=M52/'recovery-room-current-driver-01'
sys.path.insert(0,str(REVIEW))
spec=importlib.util.spec_from_file_location('reduced_room_current_host',REVIEW/'current_host_verifier.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha,read,save,installation=original.sha,original.read,original.save,original.installation
RUNNER=original.RUNNER
SOURCE_PINS={'RoomTravelTimingTestDoc.as':'cdd6fe15b2c49fb65c1d4ace65f2264a5265a3b227d33aab0d4b0262645bc967',
 'A22RoomMetrics.as':'314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e'}

def inputs():
 assert sha(REVIEW/'current_host_verifier.py')=='3abcd73d2dee5a47c4c5b94f549fd5106f8ebefb10ad7f71479f9269f5b321e8'
 original.verify(BASE)
 assert sha(HERE/'source.diff')=='d0d40ab07e2399f1313ab9a53b351f39da39c4e5fa6d1e5c11edadcec42ee7f4'
 for n,h in SOURCE_PINS.items():assert sha(HERE/'tests'/n)==h,n
 assert sha(HERE/'tests/A22RoomMetrics.as')==sha(BASE/'tests/A22RoomMetrics.as')
 assert sha(BASE/'tests/RoomTravelTimingTestDoc.as')=='226001bfb880363615c98d697ef0b1ea224545f749123b14987160f91e0998e3'
 paths=[Path(__file__),REVIEW/'prepare.py',REVIEW/'current_host_verifier.py',BASE/'prepared.json',HERE/'source.diff',RUNNER]
 paths+=[HERE/'tests'/n for n in SOURCE_PINS]
 paths+=[BASE/n for n in ('tests/RoomTravelTimingTestDoc.as','tests/A22RoomMetrics.as','ProductionDeclarations.swc','GameCombatStubs.swc','timing/EffectsHarness.swf')]
 pins={str(p):sha(p) for p in paths};pins.update(original.proof_inputs());return pins

def verify(out):
 out=Path(out).resolve();m=read(out/'prepared.json')
 assert out.parent==M52 and m['kind']=='room-reduced-unloaded-scene-driver' and m['external'] is True
 assert m['installation_before']==installation() and m['installation_unchanged'] is True
 inputs()
 for n,h in m['inputs'].items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 for n,h in SOURCE_PINS.items():assert sha(out/'tests'/n)==h,n
 assert sha(out/'timing/EffectsHarness.swf')==sha(BASE/'timing/EffectsHarness.swf')
 if m['compiled']:
  assert len(m['commands'])==1 and m['commands'][0]['exit_code']==0 and m['commands'][0]['reaped'] is True
  assert sha(out/'timing/EffectsDriver.swf')==m['driver_sha256']
 return m

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path)
 ap.add_argument('--build',action='store_true');ap.add_argument('--check',action='store_true')
 ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args();pins=inputs();before=installation()
 if a.check:print(json.dumps(dict(checked=True,source_only=True,air_started=False)));return
 assert a.output is not None and a.registry_wait>=0
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists()
 (out/'tests').mkdir(parents=True);(out/'timing').mkdir()
 for n in SOURCE_PINS:shutil.copyfile(HERE/'tests'/n,out/'tests'/n)
 shutil.copyfile(HERE/'source.diff',out/'source.diff')
 for n in ('ProductionDeclarations.swc','GameCombatStubs.swc','timing/EffectsHarness.swf'):shutil.copyfile(BASE/n,out/n)
 commands=[];compiled=False;error=None
 try:
  if a.build:
   sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
   sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
   sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
   command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
    '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
    '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
    '-output='+str(out/'timing/EffectsDriver.swf'),str(out/'tests/RoomTravelTimingTestDoc.as')]
   with Registration(owner='RConnect / 普通房关闭场景模组夹具',resource='game',purpose='Compile ordinary timing entry only; no AIR',run_dir=out,evidence=out/'compile.log',wait=a.registry_wait) as record:
    process=None;row=dict(command=command,pid=None,exit_code=None,reaped=False);commands.append(row)
    try:
     assert snapshot()['free_commit_bytes']>=1024**3 and installation()==before
     for n,h in pins.items():assert sha(n)==h,n
     record.before_launch('Ordinary room timing external fixture')
     with (out/'compile.log').open('x',encoding='utf-8') as log:
      process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
      record.child(process.pid);row.update(pid=process.pid,exit_code=wait_owned(process,240,out/'compile-memory.json'))
      assert row['exit_code']==0
     compiled=(out/'timing/EffectsDriver.swf').is_file();assert compiled
     record.outcome='passed';record.note='Reduced fixture compiled; no runtime qualification'
    finally:
     if process is not None:
      if process.poll() is None:process.kill()
      process.wait();row['reaped']=process.poll() is not None
     record.child_stopped()
 except BaseException as exc:error=repr(exc);raise
 finally:
  unchanged=installation()==before
  for n,h in pins.items():assert sha(n)==h,n
  save(out/'prepared.json',dict(kind='room-reduced-unloaded-scene-driver',compiled=compiled,external=True,
   inputs=pins,installation_before=before,installation_unchanged=unchanged,commands=commands,error=error,
   source_driver_manifest_sha256=sha(BASE/'prepared.json'),metrics_byte_exact=True,cs_explicitly_unloaded=True,
   original_compare_and_travel_assertions_preserved=True,air_started=False,installed=False,
   driver_sha256=sha(out/'timing/EffectsDriver.swf') if compiled else None,
   files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}))
  assert unchanged
 if compiled:verify(out)
 print(out)
if __name__=='__main__':main()
