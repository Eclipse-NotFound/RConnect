"""External document against the exact offline candidate; never deploys.

The shared native runner owns storage, desktop, memory gates and cleanup.
This wrapper preserves candidate/driver/installation identity and checks the
specific lifecycle result in addition to the runner's general error checks.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from run_security_terminals import installation, test_port
from runtime_memory import snapshot, wait_owned
from common import JAVA, SDK
from test_registry import Registration

ENTRY = 'OfflineLifecycleTestDoc'
VERSION = '0.2.24-offline1'
RUNNER = HERE / 'native_runner.py'
SHARED_RUNNER = ROOT / 'tools/run_coop_regression.py'
from native_runner import passed_row, ORIGINAL_SHA
EXTERNAL = {
    'ProductionDeclarations.swc': (M52 / 'room-travel-driver-12/ProductionDeclarations.swc', '598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7'),
    'GameCombatStubs.swc': (M52 / 'coop-bundle-04/build/GameCombatStubs.swc', '8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a'),
    'EffectsHarness.swf': (M52 / 'room-travel-driver-12/scene/EffectsHarness.swf', 'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086'),
}


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def read(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))


def save(p, value):
    Path(p).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def candidate(folder):
    # Use the proposal freezer's authoritative verifier; it performs no build.
    import importlib.util
    path = ROOT / 'experimental/recovery-offline-production/prepare.py'
    spec = importlib.util.spec_from_file_location('offline_candidate_freezer', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.verify(folder)
    assert (folder / 'RConnectMod.swf').is_file()
    source = (folder / 'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    assert re.search(r'VERSION:String\s*=\s*"' + re.escape(VERSION) + '"', source)
    return {'path': str(folder), 'sha256': sha(folder / 'RConnectMod.swf'),
            'manifest_sha256': sha(folder / 'prepared.json'), 'verifier_sha256': sha(path)}


def verify_driver(folder):
    meta = read(folder / 'prepared.json')
    assert meta['kind'] == 'offline-lifecycle-external-driver' and meta['compiled']
    assert sha(__file__) == meta['wrapper_sha256']
    assert sha(HERE / 'tests' / (ENTRY + '.as')) == meta['source_sha256']
    assert candidate(Path(meta['candidate']['path'])) == meta['candidate']
    for name, digest in meta['files'].items():
        assert sha(folder / name) == digest, name
    for name, digest in meta['tools'].items():
        assert sha(name) == digest, name
    return meta


def build(folder, production, wait):
    assert folder.parent == M52 and not folder.exists()
    pinned = candidate(production)
    for path, digest in EXTERNAL.values():
        assert sha(path) == digest, path
    before = installation()
    folder.mkdir()
    (folder / 'tests').mkdir()
    (folder / 'external').mkdir()
    source = HERE / 'tests' / (ENTRY + '.as')
    shutil.copyfile(source, folder / 'tests' / source.name)
    for name, (path, _) in EXTERNAL.items():
        shutil.copyfile(path, folder / (name if name.endswith('.swf') else 'external/' + name))
    tools = {str(p): sha(p) for p in (JAVA, SDK / 'lib/mxmlc.jar',
        SDK / 'frameworks/air-config.xml', SDK / 'frameworks/libs/air/airglobal.swc',
        ROOT / 'tools/validation/runtime_memory.py', GAME / 'mods/ModLoader/tools/test_registry.py')}
    meta = dict(kind='offline-lifecycle-external-driver', compiled=False, candidate=pinned,
        source_sha256=sha(source), wrapper_sha256=sha(__file__), tools=tools,
        installation_before=before, function_only=True, performance_qualified=False)
    assert sha(SHARED_RUNNER) == ORIGINAL_SHA
    meta['tools'][str(RUNNER)] = sha(RUNNER)
    meta['tools'][str(SHARED_RUNNER)] = ORIGINAL_SHA
    save(folder / 'prepared.json', meta)
    with Registration(owner='RConnect / 离线采集生命周期', resource='game', purpose='Compile external lifecycle driver; no AIR',
            run_dir=folder, evidence=folder / 'prepared.json', wait=wait) as record:
        assert snapshot()['free_commit_bytes'] >= 1024**3
        cmd = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
            '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
            '-source-path=' + str(folder / 'tests'),
            '-external-library-path+=' + str(folder / 'external/ProductionDeclarations.swc'),
            '-external-library-path+=' + str(folder / 'external/GameCombatStubs.swc'),
            '-output=' + str(folder / 'EffectsDriver.swf'), str(folder / 'tests' / source.name)]
        save(folder / 'command.json', cmd)
        with (folder / 'compile.log').open('x', encoding='utf-8') as log:
            record.before_launch(ENTRY)
            process = subprocess.Popen(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                env=dict(os.environ, AIR_HOME=str(SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
            record.child(process.pid)
            try:
                code = wait_owned(process, 240, folder / 'compile-memory.json')
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                record.child_stopped()
        meta['compile_exit'] = code
        meta['installation_unchanged'] = installation() == before
        save(folder / 'prepared.json', meta)
        assert code == 0, 'Keep failed build; see compile.log'
        assert meta['installation_unchanged']
        assert candidate(production) == pinned and sha(source) == meta['source_sha256']
        meta['compiled'] = True
        save(folder / 'driver-input.json', {'candidate_sha256': pinned['sha256']})
        meta['files'] = {p.relative_to(folder).as_posix(): sha(p) for p in folder.rglob('*')
                         if p.is_file() and p.name != 'prepared.json'}
        save(folder / 'prepared.json', meta)
        verify_driver(folder)
        record.outcome = 'passed'
        record.note = 'External driver compiled; no native lifecycle or performance qualification'
    print(json.dumps({'output': str(folder), 'compiled': True, 'driver_sha256': sha(folder / 'EffectsDriver.swf')}))


def run(out, drivers, wait):
    assert out.parent == M52 and not out.exists()
    meta = verify_driver(drivers)
    before = installation()
    out.mkdir()
    command = [sys.executable, '-B', '-X', 'utf8', str(RUNNER), '--candidate',
        str(Path(meta['candidate']['path']) / 'RConnectMod.swf'), '--all-mods', '--effects',
        '--effects-driver', str(drivers), '--solo', '--land', 'rbl', '--seconds', '300',
        '--expected-version', VERSION, '--port', str(test_port()), '--private-desktop',
        '--defer-visible', '--require-exclusive-air', '--registry-wait', str(wait)]
    intent = dict(command=command, driver_manifest_sha256=sha(drivers / 'prepared.json'),
        runner_sha256=sha(RUNNER), wrapper_sha256=sha(__file__), installation_before=before,
        candidate=meta['candidate'], function_only=True, performance_qualified=False)
    save(out / 'intent.json', intent)
    with (out / 'runner.log').open('x', encoding='utf-8') as log:
        process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    text = (out / 'runner.log').read_text(encoding='utf-8', errors='replace')
    match = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$', text, re.M)
    result = dict(passed=False, exit_code=process.returncode, run=match[1] if match else None,
        installation_unchanged=installation() == before, function_only=True, performance_qualified=False)
    if match:
        actual = ROOT / 'build/cooperation' / match[1]
        inputs = read(actual / 'run.json')['inputs']
        assert set(inputs) == {'host'}
        assert inputs['host']['production'] == meta['candidate']['sha256']
        assert inputs['host']['driver'] == sha(drivers / 'EffectsDriver.swf')
        assert inputs['host']['harness'] == sha(drivers / 'EffectsHarness.swf')
        assert inputs['host']['game'] == before['pfe.swf']
        log = (actual / 'host.log').read_text(encoding='utf-8-sig', errors='replace')
        rows = [json.loads(line.split('OFFLINE LIFECYCLE RESULT ', 1)[1]) for line in log.splitlines()
                if line.startswith('OFFLINE LIFECYCLE RESULT ')]
        result['rows'] = rows
        result['done'] = 'COOP EFFECTS DONE offline-lifecycle' in log
        result['passed'] = (process.returncode == 0 and 'RESULT PASS' in text and result['installation_unchanged']
            and result['done'] and len(rows) == 1 and passed_row(rows[0]))
    verify_driver(drivers)
    assert sha(drivers / 'prepared.json') == intent['driver_manifest_sha256'] and sha(RUNNER) == intent['runner_sha256']
    save(out / 'result.json', result)
    print(json.dumps({k:v for k,v in result.items() if k != 'rows'}, ensure_ascii=False))
    if not result['passed']:
        raise SystemExit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('operation', choices=['build', 'run'])
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--candidate', type=Path)
    ap.add_argument('--drivers', type=Path)
    ap.add_argument('--registry-wait', type=int, default=900)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    if args.operation == 'build':
        assert args.candidate is not None
        build(out, (ROOT / args.candidate).resolve(), args.registry_wait)
    else:
        assert args.drivers is not None
        run(out, (ROOT / args.drivers).resolve(), args.registry_wait)


if __name__ == '__main__':
    main()
