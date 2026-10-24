"""Freeze only the unchanged eight-case mask driver; root alone builds/runs it."""
import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import types

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT, M52 = HERE.parents[1], HERE.parents[1]/'build/m52'
GAME = ROOT.parents[1]
SOURCE = M52/'recovery-room-production-05/src'
ORIGIN = ROOT/'experimental/recovery-tests/prepare.py'
ORIGINAL_RUN = ROOT/'experimental/recovery-tests/run.py'
OVERLAY = ROOT/'experimental/recovery-room-production-v5/source-manifest.json'
CURRENT = HERE/'current_tint_verifier.py'
ENTRY = 'MirrorMaskRestoreTestDoc'
ENTRIES = {ENTRY: (8, 180, 'unchanged native RV mask restoration, both fields, real weapon and renderer takeover')}
COMPONENTS = {}
BASE = M52/'coop-bundle-04/RConnectMod.swf'
BASE_SHA = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
PINS = {
    ORIGIN: '57adca102a8ecbb0c1996dcee405782eced622fea63917d27238d27e81539ac3',
    ORIGINAL_RUN: '1beca86ca91f5346f56136afd58e071646a57506570ed4b58d857c48270301da',
    OVERLAY: 'a097e1b67cb4e2d711c897a7d7da04e055075394435fcb9495723ae3b957ead7',
    CURRENT: '5be11d45db193e22205ff302a8e94f016b4096eb335cb33d72faea12ea45e988',
    OVERLAY.parent/'build.py': '1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
    ROOT/'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT/'tools/run_coop_regression.py': '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
    ROOT/'tools/verify_mask_png.py': 'fd51bc13eef3d49022b037951d9788a08bb2ef587ebe1e67c020b9f49f3cbcab',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_inputs():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    manifest = read(HERE/'source-manifest.json')
    for name, digest in manifest['files'].items():
        assert sha(HERE/name) == digest, name
    assert set(inventory(HERE/'tests')) == {'MirrorMaskRestoreTestDoc.as', 'TestRoomReadiness.as'}
    assert set(inventory(HERE/'harness')) == {'RConnectDoc.as', 'RConnectMod.as'}
    return manifest


def current_runtime():
    sys.path.insert(0, str(CURRENT.parent))
    module = load('mask_native_current_tint', CURRENT)
    return module.installation()


def compilation_runtime():
    return load('mask_native_compile_environment', CURRENT).build_environment()


def product():
    source_inputs()
    overlay = read(OVERLAY)
    folder = SOURCE.parent
    assert (folder/'compile.json').is_file(), 'Root must finish roomfix5 production compilation first'
    prepared, compiled = read(folder/'prepared.json'), read(folder/'compile.json')
    assert prepared['version'] == overlay['version'] == '0.2.24-roomfix5'
    assert prepared['kind'] == 'room-repair-overlay'
    assert prepared['base_sha256'] == overlay['base_sha256']
    assert prepared['overlay_manifest_sha256'] == sha(OVERLAY)
    assert prepared['recipe_sha256'] == overlay['build_recipe_sha256'] == sha(OVERLAY.parent/'build.py')
    assert inventory(SOURCE) == prepared['source'] == overlay['candidate_source']
    assert inventory(folder/'tools') == prepared['inputs']
    assert compiled['compiled'] is True and compiled['sources_unchanged'] is True
    assert compiled['installation_unchanged'] is True
    assert compiled['installation_before'] == compiled['installation_after'] == prepared['installation_before']
    assert compiled['installation_before'] == compilation_runtime()
    current_runtime()  # The verified new runtime is a separate prerequisite.
    assert len(compiled['commands']) == 2 and all(c['exit_code'] == 0 for c in compiled['commands'])
    assert sha(folder/'RConnectMod.swf') == compiled['candidate_sha256']
    assert (folder/'build/GameCombatStubs.swc').is_file() and sha(BASE) == BASE_SHA
    return compiled['candidate_sha256']


def recipe():
    value = load('mask_native_original_prepare', ORIGIN)
    value.ENTRIES, value.COMPONENTS = ENTRIES, COMPONENTS
    return value


def freeze(out):
    candidate = product()
    original = recipe()
    # A shared registry edit is neither imported nor pinned during preparation
    # of this wrapper. Only the root's later freeze reads its complete source.
    registry = ROOT.parent/'ModLoader/tools/test_registry.py'
    registry_bytes = registry.read_bytes()
    ast.parse(registry_bytes.decode('utf-8-sig'))
    out.mkdir()
    originals = {}

    def copy(path, target):
        dest = out/target
        dest.parent.mkdir(parents=True, exist_ok=True)
        originals[str(path)] = sha(path)
        shutil.copyfile(path, dest)
        assert sha(dest) == originals[str(path)]

    for path in sorted(SOURCE.rglob('*.as')):
        copy(path, Path('production')/path.relative_to(SOURCE))
    for group in ('tests', 'harness'):
        for path in sorted((HERE/group).rglob('*.as')):
            copy(path, Path(group)/path.relative_to(HERE/group))
    copy(SOURCE.parent/'build/GameCombatStubs.swc', Path('inputs/GameCombatStubs.swc'))
    for name in ('prepared.json', 'compile.json'):
        copy(SOURCE.parent/name, Path('inputs')/('candidate-'+name))
    copy(OVERLAY, Path('inputs/overlay.json'))
    copy(HERE/'source-manifest.json', Path('inputs/wrapper-sources.json'))
    tools = [*PINS, Path(__file__), HERE/'run.py', HERE/'source-manifest.json',
             ROOT/'tools/host_authority/common.py', registry,
             ROOT.parent/'ModLoader/tools/air_test_process.py', original.JAVA,
             original.SDK/'lib/mxmlc.jar', original.SDK/'lib/compc.jar',
             original.SDK/'frameworks/air-config.xml', original.SDK/'frameworks/libs/air/airglobal.swc']
    pins = {str(p): sha(p) for p in tools}
    assert registry.read_bytes() == registry_bytes, 'Shared registry changed while freezing; use a fresh output'
    originals.update(pins)
    originals[str(SOURCE.parent/'RConnectMod.swf')] = candidate
    originals[str(BASE)] = BASE_SHA
    manifest = dict(kind='recovery-external-drivers', source_root=str(SOURCE), candidate_sha256=candidate,
        control_sha256=BASE_SHA, recipe_sha256=sha(ORIGIN), inputs=inventory(out), originals=originals,
        entries={ENTRY:dict(scenarios=8, seconds=180, purpose=ENTRIES[ENTRY][2], land='random_mane',
                           functional_only=True, performance_qualified=False)}, components={},
        compiled=False, air_started=False, native_qualified=False,
        mask_native=dict(tools=pins, installation=current_runtime(), wrapper_sha256=sha(__file__),
                         product_compile_installation=compilation_runtime(),
                         product_prepared_sha256=sha(SOURCE.parent/'prepared.json'),
                         product_compile_sha256=sha(SOURCE.parent/'compile.json')))
    save(out/'prepared.json', manifest)
    return manifest


def verify(out, source=SOURCE, runtime=False):
    out, source = Path(out).resolve(), Path(source).resolve()
    assert source == SOURCE and out.parent == M52
    candidate = product()
    value = recipe().verify(out, SOURCE, runtime=runtime)
    assert value['candidate_sha256'] == candidate and list(value['entries']) == [ENTRY] and value['components'] == {}
    bound = value['mask_native']
    assert current_runtime() == bound['installation'] and sha(__file__) == bound['wrapper_sha256']
    assert compilation_runtime() == bound['product_compile_installation']
    assert sha(SOURCE.parent/'prepared.json') == bound['product_prepared_sha256']
    assert sha(SOURCE.parent/'compile.json') == bound['product_compile_sha256']
    for path, digest in bound['tools'].items():
        assert sha(path) == digest, path
    return value


def build(out, registry_wait):
    value = verify(out)
    assert not value['compiled'] and not (out/'bounded-compiler.json').exists()
    original = recipe()
    sys.path.insert(0, str(ROOT/'tools/validation'))
    sys.path.insert(0, str(ROOT.parent/'ModLoader/tools'))
    from runtime_memory import snapshot, wait_owned
    import test_registry
    base_registration, active, commands = test_registry.Registration, [], []

    class BoundedRegistration(base_registration):
        def __enter__(self):
            record = super().__enter__()
            active.append(record)
            return record

        def __exit__(self, *exc):
            try:
                return super().__exit__(*exc)
            finally:
                active.clear()

    def owned(command, stdout=None, stderr=None, check=False, env=None):
        index = len(commands)
        assert index < 3 and len(active) == 1
        verify(out)
        expected = original.SDK/('lib/compc.jar' if index == 0 else 'lib/mxmlc.jar')
        assert command[0] == str(original.JAVA) and '-Xmx384m' in command
        assert Path(command[command.index('-jar')+1]).resolve() == expected.resolve()
        assert stdout is not None and stderr == subprocess.STDOUT
        memory = snapshot()
        save(out/('compiler-start-'+str(index+1)+'.json'), memory)
        assert memory['free_commit_bytes'] >= 1024**3, 'Compiler requires 1 GiB free commit'
        row = dict(command=command, pid=None, exit_code=None, reaped=False)
        commands.append(row)
        process = None
        try:
            active[0].before_launch(expected.name)
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=env,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = process.pid
            active[0].child(process.pid)
            row['exit_code'] = wait_owned(process, 300, out/('compiler-memory-'+str(index+1)+'.json'))
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                process.wait()
                row['reaped'] = process.poll() is not None
                active[0].child_stopped()
        if check and row['exit_code']:
            raise subprocess.CalledProcessError(row['exit_code'], command)
        return subprocess.CompletedProcess(command, row['exit_code'])

    original.subprocess = types.SimpleNamespace(run=owned, STDOUT=subprocess.STDOUT)
    error = None
    try:
        test_registry.Registration = BoundedRegistration
        original.build(SOURCE, out, registry_wait)
        assert len(commands) == 3 and all(c['exit_code'] == 0 and c['reaped'] for c in commands)
        verify(out, runtime=True)
    except BaseException as exc:
        error = str(exc)
        raise
    finally:
        test_registry.Registration = base_registration
        save(out/'bounded-compiler.json', dict(wrapper_sha256=sha(__file__), candidate_sha256=value['candidate_sha256'],
            tools=value['mask_native']['tools'], commands=commands, error=error, air_started=False, installed=False))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=M52/'recovery-room-mask-native-drivers-02')
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == M52 and re.fullmatch(r'recovery-room-mask-native-drivers-\d{2,}', out.name)
    assert args.registry_wait >= 0 and not (args.check and args.build)
    candidate = product()
    if args.check:
        if out.exists():
            verify(out, runtime=True)
        print(json.dumps(dict(admitted=True, candidate_sha256=candidate, compiler_started=False, air_started=False)))
        return 0
    if out.exists():
        assert args.build, 'Never overwrite a frozen output'
        verify(out)
    else:
        freeze(out)
    if args.build:
        build(out, args.registry_wait)
    print(json.dumps(dict(output=str(out), compiled=read(out/'prepared.json')['compiled'], air_started=False)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
