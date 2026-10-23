"""Prepare the unchanged aura/throw drivers; root alone invokes compilation.

The original recipe still owns freezing, declarations, registry and all checks.
Only its optional entry/component selection and owned Java wait are adapted.
No AIR or deployment is performed here.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import types

sys.dont_write_bytecode = True
if sys.flags.optimize:
    raise RuntimeError('Validation requires ordinary Python')
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ORIGIN = ROOT / 'experimental/recovery-tests/prepare.py'
SOURCE = ROOT / 'build/m52/recovery-aura-offline-01/src'
PINS = {
    ORIGIN: '57adca102a8ecbb0c1996dcee405782eced622fea63917d27238d27e81539ac3',
    ROOT / 'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT.parent / 'ModLoader/tools/test_registry.py': '58db3a594f34e9906d55992f769b3e154970d8fa37fda1c2f43ae1f6751b0033',
    ROOT / 'experimental/recovery-aura-followup/tests/PeerGripTestDoc.as': '9cf5f556abbb8053a3221375c420a2b8f34566c3ba859687cee7bca4b31da598',
    ROOT / 'experimental/recovery-aura-followup/tests/PeerAuraFixture.as': '39f0fec0b90fdcf5afb6388cf55fd476f4092ccaf0ae1d97e36fc9d28fffda4c',
    ROOT / 'experimental/recovery-aura/tests/PeerThrowDamageTestDoc.as': '950fce4ada12525760b5c55c861b9b4188d2b4b5a5c5adf21c2cdcbdb4a52e9e',
    ROOT / 'tests/fe/unit/EnemyGrabProbe.as': 'c80bacf3d0d300309440488e9f3bd7c3682654ecf9e7ad57124784344f7c2f46',
    ROOT / 'experimental/recovery-aura-followup/component/PlayerAuraChecks.as': 'f51e49e54e2fd3eb7708b14282b59465e2e7f6bf36c189b8a29af00404ff16a7',
    ROOT / 'experimental/recovery-aura-followup/component/rconnect/game/GameBridge.as': '975e4434cc3901a7cfb56b7af8dcad16a7396b2896d4d043bf8ad97fd6927987',
}
CLASS_PINS = {
    'rconnect/core/PeerGrip.as': 'e85e81da3c318e9163592ffdaae84e067fda6f8d3af93cd66c7dc043905d8840',
    'rconnect/game/TelekinesisVisuals.as': '2a98e2d94bf6d0cfcf62f64e830845a3919a9cb461719b81ae5f152031be30b1',
    'rconnect/game/PlayerBodyEffects.as': '11260028854167d8bd0c9f7e806e23081204dd0386902fdf746ba8e10485ccbd',
    'rconnect/game/GameBridge.as': 'df23182fdd362fba529b962220329bd60499efca0ee7c8ea8f2033372e84e192',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inputs():
    for path, digest in PINS.items():
        assert sha(path) == digest, 'Reviewed input changed: ' + str(path)
    for name, digest in CLASS_PINS.items():
        assert sha(SOURCE / name) == digest, 'Unexpected aura production class: ' + name
    product = SOURCE.parent
    prepared, compiled = load(product / 'prepared.json'), load(product / 'compile.json')
    assert prepared['base_sha256'] == 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
    assert prepared['version'] == '0.2.24-aura1' and prepared['diagnostic_only'] is False
    assert compiled['compiled'] is True and compiled['compile_exit'] == 0
    assert compiled['candidate_sha256'] == sha(product / 'RConnectMod.swf')
    assert compiled['prepared_sha256'] == sha(product / 'prepared.json')
    assert compiled['sources_unchanged'] and compiled['installation_unchanged']
    assert {p.relative_to(SOURCE).as_posix(): sha(p) for p in SOURCE.rglob('*') if p.is_file()} == prepared['source']
    assert (product / 'build/GameCombatStubs.swc').is_file()
    return compiled['candidate_sha256']


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, default=SOURCE)
    ap.add_argument('--output', type=Path, default=ROOT / 'build/m52/recovery-aura-offline-drivers-01')
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--check', action='store_true', help='Read-only admission check; no output or compiler')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    assert (ROOT / args.source).resolve() == SOURCE.resolve()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and re.fullmatch(r'recovery-aura-offline-drivers-\d{2,}', out.name)
    assert args.registry_wait >= 0 and not (args.check and args.build)
    candidate = inputs()
    if args.check:
        print(json.dumps(dict(admitted=True, candidate_sha256=candidate, air_started=False, compiler_started=False)))
        return 0
    spec = importlib.util.spec_from_file_location('aura_original_prepare', ORIGIN)
    recipe = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(recipe)
    recipe.COMPONENTS = {'aura': recipe.COMPONENTS['aura']}
    recipe.ENTRIES = {name: recipe.ENTRIES[name] for name in ('PeerGripTestDoc', 'PeerThrowDamageTestDoc')}
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    from runtime_memory import snapshot, wait_owned
    import test_registry
    original_registration = test_registry.Registration
    active = []
    commands = []

    class BoundedRegistration(original_registration):
        def __enter__(self):
            record = super().__enter__()
            assert not active
            active.append(record)
            return record

        def __exit__(self, *exc):
            try:
                return super().__exit__(*exc)
            finally:
                active.clear()

    def owned(command, stdout=None, stderr=None, check=False, env=None):
        index = len(commands)
        assert index < 5 and len(active) == 1
        expected = recipe.SDK / ('lib/compc.jar' if index == 0 else 'lib/mxmlc.jar')
        assert command[0] == str(recipe.JAVA) and '-Xmx384m' in command
        assert Path(command[command.index('-jar') + 1]).resolve() == expected.resolve()
        assert stdout is not None and stderr == subprocess.STDOUT
        before = snapshot()
        recipe.save(out / ('compiler-start-' + str(index + 1) + '.json'), before)
        assert before['free_commit_bytes'] >= 1024 ** 3, 'Compiler needs 1 GiB free commit'
        row = dict(command=command, pid=None, exit_code=None, reaped=False)
        commands.append(row)
        process = None
        try:
            active[0].before_launch(expected.name)
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=env,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            row['pid'] = process.pid
            active[0].child(process.pid)
            row['exit_code'] = wait_owned(process, 300, out / ('compiler-memory-' + str(index + 1) + '.json'))
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

    recipe.subprocess = types.SimpleNamespace(run=owned, STDOUT=subprocess.STDOUT)
    old_argv = sys.argv
    failed = None
    try:
        test_registry.Registration = BoundedRegistration
        sys.argv = [str(ORIGIN), '--source', str(SOURCE), '--output', str(out), '--entries',
                    'PeerGripTestDoc', 'PeerThrowDamageTestDoc', '--registry-wait', str(args.registry_wait)]
        if args.build:
            sys.argv.append('--build')
        recipe.main()
        assert inputs() == candidate
        if args.build:
            assert len(commands) == 5 and all(r['exit_code'] == 0 and r['reaped'] for r in commands)
    except BaseException as exc:
        failed = str(exc)
        raise
    finally:
        sys.argv = old_argv
        test_registry.Registration = original_registration
        # This extra receipt cannot alter the original manifest or any verdict.
        if out.is_dir() and not (out / 'bounded-compiler.json').exists():
            recipe.save(out / 'bounded-compiler.json', dict(wrapper_sha256=sha(__file__), candidate_sha256=candidate,
                origin_sha256=sha(ORIGIN), input_pins={str(p): h for p, h in PINS.items()},
                commands=commands, error=failed, air_started=False, installed=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
