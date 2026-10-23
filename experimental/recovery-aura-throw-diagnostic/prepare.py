"""Freeze a read-only diagnostic addition to the old native Q/E fixture.

Reuse the original compiler recipe, declarations, runtime bindings and checks.
The new test file is overlaid before compilation and its complete bytes become
the frozen input. Existing drivers and failed evidence are never changed.
"""
import argparse
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
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
from runtime_memory import snapshot, wait_owned
import test_registry


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and re.fullmatch(r'recovery-aura-throw-diagnostic-drivers-\d+', out.name)
    assert not out.exists() and 0 <= args.registry_wait <= 3600
    admission = module('aura_driver_admission', ROOT / 'experimental/recovery-aura-offline-review/prepare_drivers.py')
    candidate = admission.inputs()
    recipe = module('aura_original_recipe', admission.ORIGIN)
    recipe.COMPONENTS = {}
    recipe.ENTRIES = {'PeerThrowDamageTestDoc': recipe.ENTRIES['PeerThrowDamageTestDoc']}
    # Complete the new frozen input before any compiler reads it.
    manifest = recipe.freeze(admission.SOURCE, out, entry_names=['PeerThrowDamageTestDoc'])
    name = 'tests/PeerThrowDamageTestDoc.as'
    overlay = HERE / 'PeerThrowDamageTestDoc.as'
    original_hash = recipe.sha(out / name)
    assert original_hash == admission.PINS[ROOT / 'experimental/recovery-aura/tests/PeerThrowDamageTestDoc.as']
    assert overlay.is_file() and recipe.sha(overlay) == 'ed115d533b2a7c1600d71ca10ae4c8a9b52b2bc33eab50b02ac47f4cf1a38898'
    (out / name).write_bytes(overlay.read_bytes())
    manifest['inputs'][name] = recipe.sha(overlay)
    manifest['originals'][str(overlay)] = recipe.sha(overlay)
    manifest['diagnostic_overlay'] = dict(original_sha256=original_hash, source=str(overlay),
        source_sha256=recipe.sha(overlay), preparation_sha256=recipe.sha(__file__), observation_only=True)
    recipe.save(out / 'prepared.json', manifest)
    recipe.verify(out, admission.SOURCE)
    commands, active = [], []
    original_registration = test_registry.Registration

    class OwnedRegistration(original_registration):
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
        assert index < 3 and len(active) == 1
        expected = recipe.SDK / ('lib/compc.jar' if index == 0 else 'lib/mxmlc.jar')
        assert command[0] == str(recipe.JAVA) and '-Xmx384m' in command
        assert Path(command[command.index('-jar') + 1]).resolve() == expected.resolve()
        assert stdout is not None and stderr == subprocess.STDOUT
        before = snapshot()
        recipe.save(out / ('compiler-start-' + str(index + 1) + '.json'), before)
        assert before['free_commit_bytes'] >= 1024**3
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
    error = None
    try:
        test_registry.Registration = OwnedRegistration
        recipe.build(admission.SOURCE, out, args.registry_wait)
        assert admission.inputs() == candidate
        assert len(commands) == 3 and all(r['exit_code'] == 0 and r['reaped'] for r in commands)
        print(json.dumps(dict(compiled=True, output=str(out), candidate_sha256=candidate)))
    except BaseException as exc:
        error = repr(exc)
        raise
    finally:
        test_registry.Registration = original_registration
        recipe.save(out / 'bounded-compiler.json', dict(wrapper_sha256=recipe.sha(__file__),
            candidate_sha256=candidate, commands=commands, error=error, air_started=False, installed=False))


if __name__ == '__main__':
    main()
