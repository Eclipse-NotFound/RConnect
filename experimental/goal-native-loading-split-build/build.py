"""One bounded external split-room driver compilation; never launches AIR.

The independently authorized probe manifest must already exist. This entry
neither generates it nor accepts a prepared-only directory as compiled proof.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
PROBE = ROOT / 'experimental/goal-native-loading-split-probe'
BASE = M52 / 'recovery-entry-observer-driver-01'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = GAME / 'mods/Sandevistan/build/tools/flexsdk'
DEPENDENCIES = {
    'build/m52/room-travel-driver-12/ProductionDeclarations.swc':
        '598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7',
    'build/m52/coop-bundle-04/build/GameCombatStubs.swc':
        '8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a',
    'build/m52/room-travel-driver-12/entry-room/EffectsHarness.swf':
        'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086',
}
HELPERS = {
    PROBE / 'prepare.py': 'e2de54f5af89f025c31560d63848b5079a88d43595339aabd2279d7fb340c02a',
    ROOT / 'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT / 'tools/validation/run_security_terminals.py': '4e4ad73dd0f8df69db5c0c11f6c2c1c94c96fb1235dbaa1aad18caaf9877b9cb',
    ROOT / 'tools/validation/prepare_security_terminals.py': '5d156d663f616baf793b03ca183388951a10375a5d11e561e81c2b81ab7e13b5',
    GAME / 'mods/ModLoader/tools/test_registry.py': '8b35a6d6ca1dd94cfd5cba9a42979ebd14d9ae65497688fa859d084425922049',
}
KIND = 'native-loading-split-driver-v1'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def installation():
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from run_security_terminals import installation as actual
    value = actual()
    assert len(value) == 22, 'Installation set changed; review before compiling'
    return value


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p)
            for p in sorted(path.rglob('*')) if p.is_file()}


def inputs():
    for path, digest in HELPERS.items():
        assert sha(path) == digest, str(path)
    # Call the actual verifier, including its real manifest read. Never replace
    # this with a fabricated manifest or a cached success value.
    proof = load(PROBE / 'prepare.py', 'split_probe_source_check').verify()
    manifest = read(PROBE / 'source-manifest.json')
    assert proof['source_checked'] and proof['original_sources'] == 17
    assert proof['byte_unchanged_sources'] == 16
    assert proof['dependencies'] == DEPENDENCIES
    sources = inventory(PROBE / 'tests')
    assert len(sources) == 17 and all(n.endswith('.as') for n in sources)
    assert {'tests/' + n for n in sources} <= set(manifest['files'])
    assert (PROBE / 'source.diff').is_file(), 'Real probe source.diff required'
    paths = [HERE / 'build.py', HERE / 'README.md', PROBE / 'source-manifest.json',
             PROBE / 'source.diff', PROBE / 'README.md', BASE / 'prepared.json',
             JAVA, SDK / 'lib/mxmlc.jar', SDK / 'frameworks/air-config.xml',
             SDK / 'frameworks/libs/air/airglobal.swc']
    paths += list(HELPERS) + [ROOT / n for n in DEPENDENCIES]
    paths += [PROBE / 'tests' / n for n in sources]
    paths += [BASE / n for n in manifest['original_sources']]
    for name in manifest['files']:
        path = (PROBE / name).resolve()
        assert PROBE in path.parents, 'Probe manifest escapes its directory'
        paths.append(path)
    return {str(p.resolve()): sha(p) for p in sorted(set(paths))}, proof, sources


def command(out):
    return [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'),
            '+configname=air', '+flexlib=' + str(SDK / 'frameworks'),
            '-swf-version=38', '-debug=false', '-optimize=true',
            '-source-path=' + str(out / 'tests'),
            '-external-library-path+=' + str(out / 'ProductionDeclarations.swc'),
            '-external-library-path+=' + str(out / 'GameCombatStubs.swc'),
            '-output=' + str(out / 'entry-room/EffectsDriver.swf'),
            str(out / 'tests/A22RoomEntryTestDoc.as')]


def copied(out, files):
    assert all(sha(out / name) == digest for name, digest in files.items()), 'Copied inputs changed'


def verify(output):
    out = Path(output).resolve()
    assert out.parent == M52 and out.name.startswith('goal-native-loading-split-driver-')
    assert (out / 'compile.json').is_file(), 'Actual compile receipt required'
    pins, proof, sources = inputs()
    prepared, result = read(out / 'prepared.json'), read(out / 'compile.json')
    assert prepared['kind'] == result['kind'] == KIND
    assert prepared['inputs'] == pins and prepared['source_proof'] == proof
    assert result['compiled'] and result['inputs_unchanged']
    assert result['error'] is None and result['validation_error'] is None
    assert result['prepared_sha256'] == sha(out / 'prepared.json')
    assert prepared['installation_before'] == result['installation_before'] == result['installation_after'] == installation()
    assert inventory(out / 'tests') == sources
    copied(out, prepared['files'])
    assert len(result['commands']) == 1
    row = result['commands'][0]
    assert row['command'] == command(out) and row['exit_code'] == 0 and row['reaped']
    assert type(row['pid']) is int and row['pid'] > 0
    assert set(result['artifacts']) == {'entry-room/EffectsDriver.swf', 'entry-room/EffectsHarness.swf'}
    for name, digest in result['artifacts'].items():
        assert sha(out / name) == digest, name
    assert result['artifacts']['entry-room/EffectsHarness.swf'] == DEPENDENCIES['build/m52/room-travel-driver-12/entry-room/EffectsHarness.swf']
    assert result['compile_log_sha256'] == sha(out / 'compile.log')
    assert result['memory_sha256'] == sha(out / 'compile-memory.json')
    memory = read(out / 'compile-memory.json')
    assert memory['pid'] == row['pid'] and memory['reason'] is None
    assert memory['exit_code'] == memory['process_returncode'] == 0
    assert memory['minimum_commit_bytes'] == 512 * 1024 * 1024
    for value in (prepared, result):
        assert value['air_started'] is False and value['installed'] is False
        assert value['runtime_tested'] is False and value['performance_qualified'] is False
    return dict(verified=True, artifacts=result['artifacts'], inputs=pins,
                prepared_sha256=sha(out / 'prepared.json'), compile_sha256=sha(out / 'compile.json'),
                build_environment=result['installation_before'], runtime_tested=False,
                performance_qualified=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--build', action='store_true')
    mode.add_argument('--verify', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.verify:
        assert args.output is None
        print(json.dumps(verify(ROOT / args.verify), ensure_ascii=False)); return
    pins, proof, sources = inputs()
    before = installation()
    if args.check:
        assert args.output is None
        print(json.dumps(dict(ready=True, compiled=False, source_proof=proof,
                              current_environment=before, air_started=False), ensure_ascii=False)); return
    assert args.output is not None
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and out.name.startswith('goal-native-loading-split-driver-') and not out.exists()
    (out / 'tests').mkdir(parents=True)
    for name in sources:
        destination = out / 'tests' / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROBE / 'tests' / name, destination)
    (out / 'entry-room').mkdir()
    for name in DEPENDENCIES:
        destination = out / ('entry-room/' if name.endswith('EffectsHarness.swf') else '') / Path(name).name
        shutil.copyfile(ROOT / name, destination)
    files = inventory(out)
    copied(out, files)
    assert inputs()[0] == pins and installation() == before
    flags = dict(air_started=False, installed=False, runtime_tested=False, performance_qualified=False)
    save(out / 'prepared.json', dict(kind=KIND, inputs=pins, files=files, source_proof=proof,
                                   installation_before=before, compiled=False, **flags))
    prepared_sha = sha(out / 'prepared.json')
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from runtime_memory import snapshot, wait_owned
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from test_registry import Registration
    rows, success, error = [], False, None
    try:
        with Registration(owner='RConnect / 原生分房显示驱动', resource='game',
                          purpose='Compile one split-room observer driver; no AIR',
                          run_dir=out, evidence=out / 'compile.json', wait=args.registry_wait) as record:
            process = None
            row = dict(command=command(out), pid=None, exit_code=None, reaped=False)
            rows.append(row)
            try:
                assert inputs()[0] == pins and installation() == before
                copied(out, files)
                assert snapshot()['free_commit_bytes'] >= 1024 ** 3, 'Compilation requires 1 GiB commit headroom'
                record.before_launch('single native split-room fixture compiler')
                with (out / 'compile.log').open('x', encoding='utf8') as log:
                    process = subprocess.Popen(row['command'], cwd=out, stdout=log, stderr=subprocess.STDOUT,
                        env=dict(os.environ, AIR_HOME=str(SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
                    row['pid'] = process.pid
                    record.child(process.pid)
                    row['exit_code'] = wait_owned(process, 300, out / 'compile-memory.json')
                    assert row['exit_code'] == 0 and (out / 'entry-room/EffectsDriver.swf').is_file(), 'Driver compilation failed'
            finally:
                if process is not None:
                    if process.poll() is None:
                        process.kill()
                    process.wait()
                    row['reaped'] = process.poll() is not None
                record.child_stopped()
            assert inputs()[0] == pins and installation() == before
            copied(out, files)
            success = True
            record.outcome = 'passed'
            record.note = 'One driver compiled; no runtime or performance qualification'
    except BaseException as exc:
        error = repr(exc)
        raise
    finally:
        unchanged, after, validation_error, artifacts = False, None, None, {}
        try:
            after = installation()
            unchanged = inputs()[0] == pins and after == before
            copied(out, files)
            assert unchanged and sha(out / 'prepared.json') == prepared_sha
            for name in ('EffectsDriver.swf', 'EffectsHarness.swf'):
                path = out / 'entry-room' / name
                if path.is_file():
                    artifacts['entry-room/' + name] = sha(path)
        except BaseException as exc:
            validation_error = repr(exc)
        save(out / 'compile.json', dict(kind=KIND, compiled=success and error is None and validation_error is None,
             commands=rows, error=error, validation_error=validation_error, inputs_unchanged=unchanged,
             prepared_sha256=prepared_sha, installation_before=before, installation_after=after,
             artifacts=artifacts, compile_log_sha256=sha(out / 'compile.log') if (out / 'compile.log').is_file() else None,
             memory_sha256=sha(out / 'compile-memory.json') if (out / 'compile-memory.json').is_file() else None, **flags))
        if validation_error is not None and error is None:
            raise RuntimeError(validation_error)
    print(json.dumps(verify(out), ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except FileNotFoundError as exc:
        print(json.dumps(dict(ready=False, status='not-ready', missing=str(exc.filename),
                              error=str(exc)), ensure_ascii=False))
        raise SystemExit(2)
