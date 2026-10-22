"""Prepare a new external paint driver. Compilation is explicit and root-owned."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,sys
from binding import HERE,ROOT,KIND,original,verify_tools,sha,read,installation
M52=ROOT/'build/m52'
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',required=True)
    ap.add_argument('--build',action='store_true',help='Root must explicitly approve compilation; default only prepares')
    ap.add_argument('--registry-wait',type=float,default=900)
    a=ap.parse_args();out=(ROOT/a.output).resolve()
    assert out.parent==M52 and not out.exists()
    own=verify_tools();before=installation();assert len(before)==22
    base,old=original.verify_original_driver();original.sandy_input('bridge')
    copied=[n for n in old['files'] if n.startswith('tests/') and n!='tests/FirstRasterSceneProbe.as']
    copied+=['GameCombatStubs.swc','ProductionDeclarations.swc','scene/EffectsHarness.swf']
    (out/'tests').mkdir(parents=True);(out/'scene').mkdir()
    for n in copied:shutil.copyfile(base/n,out/n)
    shutil.copyfile(base/'prepared.json',out/'original-prepared.json')
    for n in ('FirstRasterSceneProbe.as','PaintTimingBuffer.as'):
        shutil.copyfile(HERE/'tests'/n,out/'tests'/n)
    shutil.copyfile(Path(__file__),out/'paint-prepare.py')
    shutil.copyfile(HERE/'inputs.json',out/'paint-inputs.json')
    pins={str(p):sha(p) for p in [HERE/'inputs.json',*[HERE/n for n in own['sources']],*[Path(n) for n in own['originals']]]}
    frozen={str(p):sha(p) for p in out.rglob('*') if p.is_file()}
    def verify():
        verify_tools()
        for n,h in {**pins,**frozen}.items():assert sha(n)==h,n
        assert installation()==before
    compiled=False
    if a.build:
        sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
        sys.path.insert(0,str(ROOT/'tools/validation'));from runtime_memory import snapshot,wait_owned
        sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'));from test_registry import Registration
        command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
            '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
            '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),
            '-output='+str(out/'scene/EffectsDriver.swf'),str(out/'tests/RoomTravelSceneTestDoc.as')]
        save(out/'paint-compile-command.json',command)
        with Registration(owner='RConnect / 原生绘图有界诊断',resource='game',purpose='Compile external paint observer; no AIR',
                          run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as record:
            verify();process=None
            try:
                with (out/'compile.log').open('x',encoding='utf-8') as log:
                    assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
                    record.before_launch('External paint observer compile')
                    process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,
                        env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)
                    record.child(process.pid)
                    code=wait_owned(process,240,out/'compile-memory.json');assert code==0,code
            finally:
                if process is not None and process.poll() is None:process.kill();process.wait()
                record.child_stopped()
            verify();compiled=(out/'scene/EffectsDriver.swf').is_file();assert compiled
            record.outcome='passed';record.note='Compilation only; diagnostic has no performance qualification'
    verify()
    save(out/'prepared.json',dict(kind=KIND,compiled=compiled,external=True,diagnostic_only=True,
        diagnostic_kind='ensure-work',sand_mode='bridge',installation_before=before,installation_unchanged=True,
        source_inputs={**old['source_inputs'],**pins},original_scene_driver_manifest=old['original_scene_driver_manifest'],
        original_early_driver_manifest=sha(out/'original-prepared.json'),copied_original_files=copied,
        unchanged_assertion_sources=['RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as'],
        paint_contract_sha256=sha(own['paint_contract']),paint_host_source_sha256=sha(own['paint_source']),
        runtime_tested=False,performance_qualified=False,
        files={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file()}))
    print(out)
if __name__=='__main__':main()
