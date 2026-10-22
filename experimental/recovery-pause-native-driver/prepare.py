"""Freeze the already-run native-inventory continuity fixture; build only 8 pauses."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
SOURCE = M52 / 'motion2-continuity-drivers-01'
CASE, ENTRY = 'pause-timing', 'A22PauseTimingTestDoc'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def inventory(folder): return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}


def check():
    pins = read(HERE/'inputs.json')
    for name, digest in pins['originals'].items():
        assert sha(Path(name)) == digest, 'Original input changed: '+name
    source_manifest = read(SOURCE/'prepared.json')
    for name, digest in pins['tests'].items():
        assert source_manifest['files'][name] == digest
        assert sha(SOURCE/name) == sha(HERE/name) == digest, name
    entry = (HERE/'tests'/f'{ENTRY}.as').read_text(encoding='utf-8-sig')
    assert 'super(true,8);' in entry
    fixed = (HERE/'tests/PresentationContinuityTestDoc.as').read_text(encoding='utf-8-sig')
    old = (M52/'coop-bundle-drivers-04/tests/PresentationContinuityTestDoc.as').read_text(encoding='utf-8-sig')
    before, after = read(HERE/'fixture-delta.json')['before'], read(HERE/'fixture-delta.json')['after']
    assert old.count(before) == 1 and old.replace(before, after) == fixed
    assert 'new NativeTestGun' not in fixed
    assert 'gun=w.invent.addWeapon("lmg")' in fixed and 'g.changeWeapon("lmg",true)' in fixed
    assert set(p.name for p in (HERE/'tests').glob('*.as')) == {
        'A22PauseTimingTestDoc.as', 'PresentationContinuityTestDoc.as',
        'MotionCadenceRegression.as', 'DropMotionBurstRegression.as'}
    return pins


def verify(out):
    check()
    meta = read(out/'prepared.json')
    assert meta['kind'] == 'recovery-pause-native-driver' and meta['entry'] == ENTRY
    for name, digest in meta['originals'].items():
        assert sha(Path(name)) == digest, name
    for name, digest in {**meta['inputs'], **meta.get('files', {})}.items():
        assert sha(out/name) == digest, name
    return meta


def freeze(out):
    pins = check()
    assert out.parent == M52.resolve() and not out.exists()
    out.mkdir()
    for name in pins['tests']:
        dest = out/name; dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(HERE/name, dest)
    for dest, origin in pins['external'].items():
        target = out/dest; target.parent.mkdir(exist_ok=True)
        shutil.copyfile(origin, target)
    for source in HERE.iterdir():
        if source.is_file():
            (out/'recipe').mkdir(exist_ok=True)
            shutil.copyfile(source, out/'recipe'/source.name)
    originals = dict(pins['originals'])
    originals.update({str(p):sha(p) for p in HERE.rglob('*') if p.is_file()})
    meta = dict(kind='recovery-pause-native-driver', entry=ENTRY, case=CASE,
        source_manifest_sha256=sha(SOURCE/'prepared.json'), inputs=inventory(out), originals=originals,
        toolchain=pins['toolchain'], compiled=False, air_started=False,
        performance_qualified=False, native_qualified=False, original_assertions_unchanged=True,
        fixture='Exact previously-run native inventory weapon; eight original pause rounds')
    save(out/'prepared.json', meta)
    return verify(out)


def build(out, wait):
    meta = verify(out)
    assert not meta['compiled'] and not (out/'compile.log').exists(), 'Use a new directory after any compile attempt'
    sys.path.insert(0, str(ROOT.parent/'ModLoader/tools'))
    sys.path.insert(0, str(ROOT/'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    with Registration(owner='RConnect / 原生背包武器八轮暂停', purpose='只编译已跑通父驱动的八轮入口，不运行AIR',
                      resource='game', run_dir=out, evidence=out/'compile.log', wait=wait) as record:
        verify(out)
        java, sdk = Path(meta['toolchain']['java']), Path(meta['toolchain']['sdk'])
        command = [str(java), '-Xmx384m', '-jar', str(sdk/'lib/mxmlc.jar'), '+configname=air',
            '+flexlib='+str(sdk/'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
            '-source-path='+str(out/'tests'), '-external-library-path+='+str(out/'external/ProductionDeclarations.swc'),
            '-external-library-path+='+str(out/'external/GameCombatStubs.swc'),
            '-output='+str(out/CASE/'EffectsDriver.swf'), str(out/'tests'/f'{ENTRY}.as')]
        save(out/'command.json', command)
        assert snapshot()['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before compiler'
        with (out/'compile.log').open('w', encoding='utf-8') as log:
            record.before_launch('external pause-timing compiler')
            process = subprocess.Popen(command, cwd=out, env=dict(os.environ, AIR_HOME=str(sdk)),
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            record.child(process.pid)
            try:
                code = wait_owned(process, 180, out/'compile-memory.json')
            finally:
                if process.poll() is None: process.kill()
                process.wait(); record.child_stopped()
        verify(out)
        meta['compile_exit'] = code
        meta['compile_exits'] = {CASE:code}
        if code != 0:
            save(out/'prepared.json', meta)
            raise RuntimeError('Compiler failed; keep this evidence and use a new output')
        save(out/CASE/'driver-input.json', dict(entry=ENTRY, external_only=True,
            driver_sha256=sha(out/CASE/'EffectsDriver.swf'), harness_sha256=sha(out/CASE/'EffectsHarness.swf'),
            source_manifest=meta['source_manifest_sha256'], original_assertions_unchanged=True,
            production_binding='Formal run_motion_comparison binds these same external bytes to the exact candidate'))
        record.outcome = 'passed'
        record.note = '八轮外部驱动编译完成；没有运行AIR、功能或性能合格结论'
    verify(out)
    meta['compiled'] = True
    meta['files'] = inventory(out); meta['files'].pop('prepared.json', None)
    save(out/'prepared.json', meta)
    return verify(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--registry-wait', type=int, default=900)
    args = parser.parse_args()
    if args.check:
        assert args.output is None and not args.build
        check(); print(json.dumps(dict(static_passed=True, as_files=4, compiled=False, air_started=False))); return
    assert args.output is not None and 0 <= args.registry_wait <= 3600
    out = (ROOT/args.output).resolve()
    assert out.parent == M52.resolve()
    meta = verify(out) if out.exists() else freeze(out)
    if args.build: meta = build(out, args.registry_wait)
    print(json.dumps(dict(output=str(out), compiled=meta['compiled'], entry=ENTRY, air_started=False)))


if __name__ == '__main__': main()
