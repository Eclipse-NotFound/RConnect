"""Freeze exact scene12 + observer-only entry-room driver. --compile is opt-in."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from generate import HERE,ROOT,BASE,BASE_MANIFEST,sha,read,save,check

M52=ROOT/'build/m52'
KIND='room-entry-local-commit-observer-driver'

def verify_driver(path,meta,scenario):
    assert scenario=='entry-room' and path.parent==M52
    assert meta.get('kind')==KIND and meta.get('compiled') is True
    assert meta.get('external') is True and meta.get('diagnostic_only') is False
    assert meta.get('original_scene_driver_manifest')==BASE_MANIFEST
    assert meta.get('installation_unchanged') is True
    assert meta.get('original_probe_assertions_unchanged') is True
    assert meta.get('scenario')=='entry-room'
    check()
    for n,h in meta['source_inputs'].items():assert sha(Path(n))==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    original=read(BASE/'prepared.json')
    for n,h in original['files'].items():
        if n.startswith('tests/') and n!='tests/RoomEntryProbe.as':assert sha(path/n)==h,n
    for n in ('RoomEntryProbe.as','RoomEntryConfirmation.as'):
        assert sha(path/'tests'/n)==sha(HERE/'tests'/n)
    assert sha(path/'entry-room/EffectsHarness.swf')==original['files']['entry-room/EffectsHarness.swf']

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output');ap.add_argument('--compile',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
    check();out=(ROOT/a.output).resolve()
    assert out.parent==M52 and not out.exists(),'Use a fresh direct build/m52 folder'
    stub=M52/'coop-bundle-04/build/GameCombatStubs.swc'
    own=[p for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    source_files=[BASE/'prepared.json',BASE/'ProductionDeclarations.swc',BASE/'entry-room/EffectsHarness.swf',stub,
                  *sorted((BASE/'tests').rglob('*.as')),*own]
    pinned={str(p.resolve()):sha(p) for p in source_files}
    sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
    installed=installation();assert len(installed)==22
    shutil.copytree(BASE/'tests',out/'tests');(out/'entry-room').mkdir()
    for n in ('RoomEntryProbe.as','RoomEntryConfirmation.as'):shutil.copyfile(HERE/'tests'/n,out/'tests'/n)
    for source,dest in ((BASE/'ProductionDeclarations.swc',out/'ProductionDeclarations.swc'),
                        (stub,out/'GameCombatStubs.swc'),
                        (BASE/'entry-room/EffectsHarness.swf',out/'entry-room/EffectsHarness.swf'),
                        (Path(__file__),out/'prepare-recipe.py'),(HERE/'observer.patch',out/'observer.patch')):
        shutil.copyfile(source,dest)
    frozen={str(p):sha(p) for p in out.rglob('*') if p.is_file()}
    meta=dict(kind=KIND,compiled=False,external=True,diagnostic_only=False,scenario='entry-room',
              original_scene_driver_manifest=BASE_MANIFEST,original_probe_assertions_unchanged=True,
              source_inputs=pinned,installation_before=installed,installation_unchanged=False,
              runtime_tested=False,performance_qualified=False)
    def verify():
        for n,h in {**pinned,**frozen}.items():assert sha(Path(n))==h,n
        assert installation()==installed,'Installed runtime input changed'
    try:
        if a.compile:
            sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
            sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'));from test_registry import Registration
            command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
                     '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
                     '-external-library-path+='+str(out/'ProductionDeclarations.swc'),
                     '-external-library-path+='+str(out/'GameCombatStubs.swc'),
                     '-output='+str(out/'entry-room/EffectsDriver.swf'),str(out/'tests/A22RoomEntryTestDoc.as')]
            save(out/'compile-command.json',command)
            with Registration(owner='RConnect / 房间提交观察器',resource='game',purpose='Compile external entry-room observer; no AIR',
                              run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as record:
                verify();process=None
                try:
                    with (out/'compile.log').open('x',encoding='utf-8') as log:
                        record.before_launch('Room-entry observer driver compile');verify()
                        process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)))
                        record.child(process.pid);code=process.wait(timeout=240)
                        meta['compile_exit']=code;assert code==0,code
                finally:
                    if process is not None:
                        if process.poll() is None:process.kill()
                        process.wait()
                    record.child_stopped()
                verify();meta['compiled']=(out/'entry-room/EffectsDriver.swf').is_file();assert meta['compiled']
                record.outcome='passed';record.note='Driver compile only; native rerun still required'
        verify()
    except BaseException as error:
        meta['error']=str(error);raise
    finally:
        meta['installation_unchanged']=installation()==installed
        meta['files']={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='prepared.json'}
        save(out/'prepared.json',meta)
    print(out)

if __name__=='__main__':main()
