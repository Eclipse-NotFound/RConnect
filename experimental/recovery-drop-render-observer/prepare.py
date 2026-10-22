"""Freeze and optionally compile the bounded external drop observer; no AIR runner."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
M52=ROOT/'build/m52'
SOURCE=M52/'motion2-continuity-drivers-01'
CASE,ENTRY='continuity','PresentationContinuityTestDoc'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(root):return {p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*')) if p.is_file()}

def check(binary_inputs=False):
    pins=read(HERE/'inputs.json')
    assert pins['kind']=='recovery-drop-render-observer'
    for name,digest in pins['local'].items():assert sha(HERE/name)==digest,name
    for name,digest in pins['originals'].items():
        if not binary_inputs and Path(name).suffix.lower() in ('.swf','.swc','.jar','.exe'):continue
        assert sha(Path(name))==digest,'Original input changed: '+name
    from materialize import expected
    before,after=expected()
    assert (HERE/'tests/PresentationContinuityTestDoc.as').read_bytes()==after.encode()
    assert 'new NativeTestGun' not in after
    assert 'gun=w.invent.addWeapon("lmg")' in after and 'g.changeWeapon("lmg",true)' in after
    assert set(p.name for p in (HERE/'tests').glob('*.as'))=={
        'PresentationContinuityTestDoc.as','MotionCadenceRegression.as','DropMotionBurstRegression.as'}
    for name,digest in pins['tests'].items():assert sha(HERE/name)==digest,name
    for name in ('MotionCadenceRegression.as','DropMotionBurstRegression.as'):
        assert (HERE/'tests'/name).read_bytes()==(SOURCE/'tests'/name).read_bytes()
    return pins

def verify(out):
    check(True)
    meta=read(out/'prepared.json')
    assert meta['kind']=='recovery-drop-render-observer' and meta['entry']==ENTRY
    for name,digest in meta['originals'].items():assert sha(Path(name))==digest,name
    for name,digest in {**meta['inputs'],**meta.get('files',{})}.items():assert sha(out/name)==digest,name
    return meta

def freeze(out):
    pins=check(True)
    assert out.parent==M52.resolve() and not out.exists()
    out.mkdir()
    for name in pins['tests']:
        target=out/name;target.parent.mkdir(exist_ok=True);shutil.copyfile(HERE/name,target)
    for dest,origin in pins['external'].items():
        target=out/dest;target.parent.mkdir(exist_ok=True);shutil.copyfile(origin,target)
    for source in HERE.iterdir():
        if source.is_file():
            (out/'recipe').mkdir(exist_ok=True);shutil.copyfile(source,out/'recipe'/source.name)
    originals=dict(pins['originals'])
    originals.update({str(p):sha(p) for p in HERE.rglob('*') if p.is_file()})
    meta=dict(kind='recovery-drop-render-observer',entry=ENTRY,case=CASE,
        source_manifest_sha256=sha(SOURCE/'prepared.json'),inputs=inventory(out),originals=originals,
        toolchain=pins['toolchain'],compiled=False,air_started=False,
        diagnostic_only=True,performance_qualified=False,native_qualified=False,
        original_assertions_unchanged=True,original_trace_dedup_unchanged=True,
        observation=dict(round=0,duration_ms=2000,total_rows_cap=256,export='one log line at original finish'))
    save(out/'prepared.json',meta)
    return verify(out)

def build(out,wait):
    meta=verify(out)
    assert not meta['compiled'] and not (out/'compile.log').exists(),'Use a new output after any compile attempt'
    sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'))
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot,wait_owned
    with Registration(owner='RConnect / 掉落绘制回调观察',purpose='仅编译有界外部记录驱动，不运行AIR',
                      resource='game',run_dir=out,evidence=out/'compile.log',wait=wait) as record:
        verify(out)
        java,sdk=Path(meta['toolchain']['java']),Path(meta['toolchain']['sdk'])
        command=[str(java),'-Xmx384m','-jar',str(sdk/'lib/mxmlc.jar'),'+configname=air',
            '+flexlib='+str(sdk/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
            '-source-path='+str(out/'tests'),'-external-library-path+='+str(out/'external/ProductionDeclarations.swc'),
            '-external-library-path+='+str(out/'external/GameCombatStubs.swc'),
            '-output='+str(out/CASE/'EffectsDriver.swf'),str(out/'tests'/f'{ENTRY}.as')]
        save(out/'command.json',command)
        assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            record.before_launch('external continuity observer compiler')
            process=subprocess.Popen(command,cwd=out,env=dict(os.environ,AIR_HOME=str(sdk)),
                stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            record.child(process.pid)
            try:code=wait_owned(process,180,out/'compile-memory.json')
            finally:
                if process.poll() is None:process.kill()
                process.wait();record.child_stopped()
        verify(out)
        meta['compile_exit']=code;meta['compile_exits']={CASE:code}
        if code!=0:
            save(out/'prepared.json',meta)
            raise RuntimeError('Compiler failed; preserve this output and use a new directory')
        save(out/CASE/'driver-input.json',dict(entry=ENTRY,external_only=True,diagnostic_only=True,
            driver_sha256=sha(out/CASE/'EffectsDriver.swf'),harness_sha256=sha(out/CASE/'EffectsHarness.swf'),
            source_manifest=meta['source_manifest_sha256'],original_assertions_unchanged=True,
            performance_qualified=False,
            production_binding='Existing formal motion wrapper binds these same external bytes to the selected candidate'))
        record.outcome='passed';record.note='外部观察驱动编译完成；无AIR或性能合格结论'
    verify(out)
    meta['compiled']=True
    meta['files']=inventory(out);meta['files'].pop('prepared.json',None)
    save(out/'prepared.json',meta)
    return verify(out)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check',action='store_true');ap.add_argument('--output',type=Path)
    ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=int,default=900)
    args=ap.parse_args()
    if args.check:
        assert args.output is None and not args.build
        check(False);print(json.dumps(dict(static_passed=True,binary_inputs_verified=False,compiled=False,air_started=False)));return
    assert args.output is not None and 0<=args.registry_wait<=3600
    out=(ROOT/args.output).resolve();assert out.parent==M52.resolve()
    meta=verify(out) if out.exists() else freeze(out)
    if args.build:meta=build(out,args.registry_wait)
    print(json.dumps(dict(output=str(out),compiled=meta['compiled'],entry=ENTRY,air_started=False)))
if __name__=='__main__':main()
