"""Freeze only an external density fixture. --build registers and compiles; never runs AIR."""
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
BASE = M52 / 'motion-drivers-01'
BASE_MANIFEST = 'fee33fab5ac5b87ae953545a88c1ccbe99c195f36544549cc57e8812925a54a4'
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def check_source():
    assert sha(BASE / 'prepared.json') == BASE_MANIFEST
    old = read(BASE / 'prepared.json')
    required = ['tests/SustainedDensityTestDoc.as', 'tests/NativeTestGun.as',
                'tests/BeforeIntegerMessageCodec.as', 'tests/fe/unit/CombatStateProbe.as', 'density/EffectsHarness.swf']
    for name in required:
        assert sha(BASE / name) == old['files'][name], name
    before = (BASE / 'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8-sig')
    after = (HERE / 'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8-sig')
    # The whole actual frame stimulus and timing sampler is byte-for-byte text
    # identical. Also keep every original assertion and seven-window condition.
    anchor = '      private function frame(e:Event):void {'
    assert before[before.index(anchor):] == after[after.index(anchor):], 'Measured frame method changed'
    for line in before.splitlines():
        if 'check(' in line and not line.strip().startswith('private function'):
            assert line in after, 'Original assertion changed: ' + line
    for literal in ['getTimer()-at>8000', 'if(densityProbe<6)', 'frames>=80&&p95<200',
                    'packets>=20&&maxPacket<900', 'count>packets', 'renderedProjectiles>0 && movingProjectiles>0']:
        assert before.count(literal) == after.count(literal) == 1, literal
    original_render = before.split('      private function renderProjectiles(e:Event):void {', 1)[1].split('      private function find(', 1)[0]
    new_render = after.split('      private function renderProjectiles(e:Event):void {', 1)[1].split('      private function find(', 1)[0]
    new_render = '\n'.join(line for line in new_render.split('\n') if 'trajectoryDiag' not in line)
    assert new_render == original_render, 'Original final-render detector changed'
    assert 'super(true);' in (HERE / 'tests/ProjectileLoadTestDoc.as').read_text()
    assert 'trajectoryTotals:Boolean=false' in after
    assert 'tr:GameBridge.probe(u,"tr")' in after
    assert 'u.tr' not in after, 'Native UnitBat.tr is internal, not an external public field'
    message = after.split('      private function message(e:NetMessageEvent):void {', 1)[1].split('      private function handleMessage(', 1)[0]
    assert 'try {handleMessage(e);}' in message and 'catch(error:*)' in message
    assert 'check(false,"message error ' in message and 'try {send("done");}' in message and 'finish();' in message
    readiness = after.split('      private function arenaReadiness():Object {', 1)[1].split('      private function prepareDensityTick()', 1)[0]
    assert 'peerIds:Array=host?[]:[0]' in readiness
    assert 'in mod.session.peers)peerIds.push(int(peer.id))' in readiness
    assert 'if(peerId==mod.session.myId)continue;' in readiness and 'ghosts.indexOf(ghost)<0' in readiness
    assert 'var peerOK:Boolean=ghosts.length==1' in readiness
    assert 'getTimer()-at>45000' in after
    return required


def verify(out):
    meta = read(out / 'prepared.json')
    assert meta['kind'] == 'external-fixed-density'
    for name, digest in meta['inputs'].items():
        path = (out / name).resolve()
        assert path.is_relative_to(out) and sha(path) == digest, name
    for name, digest in meta['originals'].items():
        assert sha(Path(name)) == digest, 'Original changed: ' + name
    if meta['compiled']:
        for name, digest in meta['files'].items():
            assert sha(out / name) == digest, name
    return meta


def freeze(out, diagnostic):
    required = check_source()
    assert not out.exists()
    dependencies = [JAVA, SDK / 'lib/mxmlc.jar', SDK / 'frameworks/air-config.xml',
                    SDK / 'frameworks/libs/air/airglobal.swc', Path(sys.executable),
                    ROOT / 'tools/host_authority/common.py', ROOT / 'tools/validation/runtime_memory.py',
                    ROOT / 'tools/validation/run_motion_comparison.py', ROOT / 'tools/run_coop_regression.py',
                    ROOT / 'tools/validation/air_test_inventory.py', ROOT / 'tools/validation/run_security_terminals.py',
                    ROOT.parent / 'ModLoader/tools/test_registry.py']
    originals = {str(p.resolve()): sha(p) for p in dependencies}
    out.mkdir()

    def copy(source, name):
        target = out / name
        target.parent.mkdir(parents=True, exist_ok=True)
        originals[str(source.resolve())] = sha(source)
        shutil.copyfile(source, target)
        assert sha(target) == originals[str(source.resolve())]

    for name in required[1:]:
        if name.startswith('tests/'):
            copy(BASE / name, name)
    for source in sorted((HERE / 'tests').rglob('*.as')):
        copy(source, 'tests/' + source.relative_to(HERE / 'tests').as_posix())
    copy(BASE / 'density/EffectsHarness.swf', 'density/EffectsHarness.swf')
    declarations = M52 / 'coop-bundle-drivers-04/ProductionDeclarations.swc'
    # Same declaration/stub bytes actually used to compile motion-drivers-01.
    # The older bundle-04 stub is not byte-identical to that driver input.
    stub = M52 / 'motion-fast-01/build/GameCombatStubs.swc'
    assert sha(declarations) == read(BASE / 'prepared.json')['external_declarations_sha256']
    assert sha(stub) == read(BASE / 'prepared.json')['stubs_sha256']
    copy(declarations, 'external/ProductionDeclarations.swc')
    copy(stub, 'external/GameCombatStubs.swc')
    for source in sorted(HERE.glob('*.py')):
        copy(source, 'recipe/' + source.name)
    originals[str(BASE / 'prepared.json')] = sha(BASE / 'prepared.json')
    originals[str(BASE / 'tests/SustainedDensityTestDoc.as')] = sha(BASE / 'tests/SustainedDensityTestDoc.as')
    meta = dict(kind='external-fixed-density', compiled=False, compile_exit=None, source_baseline=str(BASE),
        source_manifest=BASE_MANIFEST, diagnostic_only=diagnostic, performance_qualified=False,
        entry='DensityTotalsTestDoc' if diagnostic else 'ProjectileLoadTestDoc',
        inputs=inventory(out), originals=originals, files={},
        toolchain=dict(java=str(JAVA), sdk=str(SDK)), purpose='Fixed preparation; unchanged seven native load windows')
    save(out / 'prepared.json', meta)
    verify(out)
    return meta


def build(out, wait):
    meta = verify(out)
    assert not meta['compiled'] and not (out / 'compile.log').exists(), 'Use a new output for a failed build'
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    with Registration(owner='RConnect / 固定密集场景外部驱动', purpose='只编译外部准备夹具；不改生产、不运行AIR',
                      resource='game', run_dir=out, evidence=out / 'compile.log', wait=wait) as record:
        verify(out)
        java, sdk = Path(meta['toolchain']['java']), Path(meta['toolchain']['sdk'])
        command = [str(java), '-Xmx384m', '-jar', str(sdk / 'lib/mxmlc.jar'), '+configname=air',
            '+flexlib=' + str(sdk / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
            '-source-path=' + str(out / 'tests'), '-external-library-path+=' + str(out / 'external/ProductionDeclarations.swc'),
            '-external-library-path+=' + str(out / 'external/GameCombatStubs.swc'),
            '-output=' + str(out / 'density/EffectsDriver.swf'), str(out / 'tests' / (meta['entry'] + '.as'))]
        save(out / 'command.json', command)
        assert snapshot()['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before compiler'
        with (out / 'compile.log').open('w', encoding='utf-8') as log:
            record.before_launch('external density compiler')
            process = subprocess.Popen(command, cwd=out, env=dict(os.environ, AIR_HOME=str(sdk)),
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            record.child(process.pid)
            try:
                code = wait_owned(process, 180, out / 'compile-memory.json')
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                record.child_stopped()
        verify(out)
        meta['compile_exit'] = code
        if code != 0:
            save(out / 'prepared.json', meta)
            raise RuntimeError('Compiler failed; preserve this output and use a new directory')
        save(out / 'density/driver-input.json', dict(entry=meta['entry'], diagnostic_only=meta['diagnostic_only'],
             driver_sha256=sha(out / 'density/EffectsDriver.swf'),
             harness_sha256=sha(out / 'density/EffectsHarness.swf'), external_only=True,
             source_manifest=BASE_MANIFEST, measured_windows_unchanged=True, per_projectile_correlation='unknown',
             production_binding='run_motion_comparison binds these same external bytes to each candidate'))
        record.outcome = 'passed'
        record.note = '外部驱动编译完成；未运行游戏、不表示功能或性能合格'
    # Freeze final artifacts only after __exit__ completes its registration
    # writeback. Current registry writes the shared database, not this folder;
    # the order also remains valid if a local receipt is added in the future.
    verify(out)
    meta['compiled'] = True
    meta['files'] = inventory(out)
    meta['files'].pop('prepared.json', None)
    save(out / 'prepared.json', meta)
    verify(out)
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--diagnostic', action='store_true')
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--registry-wait', type=int, default=900)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and 0 <= args.registry_wait <= 3600
    if out.exists():
        assert args.build
        meta = verify(out)
        assert meta['diagnostic_only'] == args.diagnostic
    else:
        meta = freeze(out, args.diagnostic)
    if args.build:
        meta = build(out, args.registry_wait)
    print(json.dumps(dict(output=str(out), compiled=meta['compiled'], diagnostic_only=meta['diagnostic_only'])))


if __name__ == '__main__':
    main()
