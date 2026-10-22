"""Freeze/build one external native Sand lifecycle document, no injected Sand state."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
TRAVEL=ROOT/'experimental/recovery-early-sandy-native'
sys.path.insert(0,str(TRAVEL))
from native_inputs import verify_tools,sandy_input,audit,host_input,CANDIDATE,HOST,installation
ENTRY='SandyHoldNativeTestDoc'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {v.relative_to(p).as_posix():sha(v) for v in sorted(p.rglob('*')) if v.is_file()}
def check():
    verify_tools();pins=read(HERE/'inputs.json')
    for name,digest in pins['sources'].items():assert sha(HERE/name)==digest,name
    for name,digest in pins['originals'].items():assert sha(name)==digest,name
    audit(CANDIDATE);sandy_input('bridge')
    return pins
def verify(out):
    check();meta=read(out/'prepared.json')
    assert meta['kind']=='sandy-hold-native-lifecycle-driver' and meta['entry']==ENTRY
    for name,digest in meta['source_inputs'].items():assert sha(name)==digest,name
    for name,digest in {**meta['inputs'],**meta.get('files',{})}.items():assert sha(out/name)==digest,name
    return meta
def freeze(out):
    pins=check();assert out.parent==M52.resolve() and not out.exists()
    (out/'tests').mkdir(parents=True);(out/'external').mkdir();(out/'lifecycle').mkdir()
    shutil.copyfile(HERE/'tests'/f'{ENTRY}.as',out/'tests'/f'{ENTRY}.as')
    for target,source in pins['external'].items():shutil.copyfile(source,out/target)
    shutil.copyfile(HERE/'inputs.json',out/'recipe-inputs.json')
    meta=dict(kind='sandy-hold-native-lifecycle-driver',entry=ENTRY,compiled=False,air_started=False,
        source_inputs={str(v):sha(v) for v in HERE.rglob('*') if v.is_file()},
        inputs=inventory(out),toolchain=pins['toolchain'],function_only=True,performance_qualified=False)
    save(out/'prepared.json',meta);return verify(out)
def build(out,wait):
    meta=verify(out);assert not meta['compiled'] and not (out/'compile.log').exists()
    sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'))
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot,wait_owned
    installed=installation();assert len(installed)==22
    with Registration(owner='RConnect / A时停真实生命周期',resource='game',purpose='Compile one external lifecycle fixture; no AIR',run_dir=out,evidence=out/'prepared.json',wait=wait) as record:
        verify(out);assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
        java,sdk=Path(meta['toolchain']['java']),Path(meta['toolchain']['sdk'])
        command=[str(java),'-Xmx384m','-jar',str(sdk/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(sdk/'frameworks'),
            '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
            '-external-library-path+='+str(out/'external/ProductionDeclarations.swc'),
            '-external-library-path+='+str(out/'external/GameCombatStubs.swc'),
            '-output='+str(out/'lifecycle/EffectsDriver.swf'),str(out/'tests'/f'{ENTRY}.as')]
        save(out/'command.json',command)
        with (out/'compile.log').open('x',encoding='utf-8') as log:
            record.before_launch('Native Sand lifecycle external document')
            process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,
                env=dict(os.environ,AIR_HOME=str(sdk)),creationflags=subprocess.CREATE_NO_WINDOW)
            record.child(process.pid)
            try:code=wait_owned(process,240,out/'compile-memory.json')
            finally:
                if process.poll() is None:process.kill()
                process.wait();record.child_stopped()
        verify(out);assert installation()==installed
        meta['compile_exit']=code;meta['installation_unchanged']=True
        if code!=0:save(out/'prepared.json',meta);raise RuntimeError('Compiler failed; keep evidence, use a new output')
        meta['compiled']=True;assert (out/'lifecycle/EffectsDriver.swf').is_file()
        record.outcome='passed';record.note='Compile only; not native or performance qualification'
    meta['files']=inventory(out);meta['files'].pop('prepared.json',None);save(out/'prepared.json',meta)
    return verify(out)
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=int,default=900)
    a=ap.parse_args();out=(ROOT/a.output).resolve();assert out.parent==M52.resolve()
    meta=verify(out) if out.exists() else freeze(out)
    if a.build:meta=build(out,a.registry_wait)
    print(json.dumps(dict(output=str(out),compiled=meta['compiled'],air_started=False)))
if __name__=='__main__':main()
