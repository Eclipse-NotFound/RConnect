"""Build and run one bounded first-connection check against exact offline1 bytes.

All saves are old private replay templates. The original shared runner retains
its error classification, memory limits, test registration and owned cleanup.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
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
ENTRY = 'OfflineFirstConnectTestDoc'
VERSION = '0.2.24-offline1'
RUNNER = ROOT / 'tools/run_coop_regression.py'
RUNNER_SHA = '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
VERIFIER = ROOT / 'experimental/recovery-offline-production/prepare.py'
EXTERNAL = {
    'ProductionDeclarations.swc': (M52 / 'room-travel-driver-12/ProductionDeclarations.swc', '598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7'),
    'GameCombatStubs.swc': (M52 / 'coop-bundle-04/build/GameCombatStubs.swc', '8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a'),
    'EffectsHarness.swf': (M52 / 'room-travel-driver-12/scene/EffectsHarness.swf', 'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086'),
}
TEMPLATES = M52 / 'littlepip-save-replay-01'
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from run_security_terminals import installation, test_port
from runtime_memory import snapshot, wait_owned
from common import JAVA, SDK
from test_registry import Registration


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def candidate(folder):
    spec = importlib.util.spec_from_file_location('first_connect_candidate_verifier', VERIFIER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.verify(folder)
    assert read(folder / 'prepared.json')['version'] == VERSION
    return dict(path=str(folder), sha256=sha(folder / 'RConnectMod.swf'),
                manifest_sha256=sha(folder / 'prepared.json'), verifier_sha256=sha(VERIFIER))


def verify_driver(folder):
    meta = read(folder / 'prepared.json')
    assert meta['kind'] == 'offline-first-connect-driver' and meta['compiled'] is True
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
    assert sha(RUNNER) == RUNNER_SHA
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
    templates = {}
    for role in ('host', 'join'):
        original = TEMPLATES / role / 'PFEgame0.sol'
        data = original.read_bytes()
        assert data[:2] == b'\x00\xbf' and data[6:10] == b'TCSO' and data[16:26] == b'\x00\x08PFEgame0'
        dest = folder / 'saves' / role / 'PFEgame0.sol'
        dest.parent.mkdir(parents=True)
        dest.write_bytes(data)
        templates[role] = dict(source=str(original), sha256=sha(original), frozen=dest.relative_to(folder).as_posix())
    tool_paths = (JAVA, SDK / 'lib/mxmlc.jar', SDK / 'frameworks/air-config.xml',
                  SDK / 'frameworks/libs/air/airglobal.swc', RUNNER, VERIFIER,
                  ROOT / 'tools/validation/runtime_memory.py', GAME / 'mods/ModLoader/tools/test_registry.py')
    tools = {str(path): sha(path) for path in tool_paths}
    meta = dict(kind='offline-first-connect-driver', compiled=False, candidate=pinned,
                source_sha256=sha(source), wrapper_sha256=sha(__file__), tools=tools, templates=templates,
                installation_before=before, function_only=True, performance_qualified=False)
    save(folder / 'prepared.json', meta)
    with Registration(owner='RConnect / 首次双人接入', resource='game',
                      purpose='Compile first-connection driver; no AIR', run_dir=folder,
                      evidence=folder / 'prepared.json', wait=wait) as record:
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
        assert meta['installation_unchanged'] and candidate(production) == pinned
        assert sha(source) == meta['source_sha256']
        for info in templates.values():
            assert sha(info['source']) == info['sha256']
        save(folder / 'driver-input.json', dict(candidate_sha256=pinned['sha256'], entry=ENTRY))
        meta['compiled'] = True
        meta['files'] = {path.relative_to(folder).as_posix(): sha(path) for path in folder.rglob('*')
                         if path.is_file() and path.name != 'prepared.json'}
        save(folder / 'prepared.json', meta)
        verify_driver(folder)
        record.outcome = 'passed'
        record.note = 'External first-connection driver compiled; no native or performance qualification'
    print(json.dumps(dict(output=str(folder), compiled=True, driver_sha256=sha(folder / 'EffectsDriver.swf'))))


def passed_row(row, role):
    # Final coverage is frozen with the AS entry before compilation.
    required = {'virgin', 'offlineShot', 'offlineBody', 'offlineClear', 'firstConnection',
                'quietNoReplay', 'hostFire', 'joinFire', 'bodyApplied', 'bodyCleared'}
    if not isinstance(row, dict):
        return False
    clean = row.get('cleanup', {})
    coverage = row.get('coverage', {})
    handshake = row.get('firstHandshake', {})
    if not all(isinstance(value, dict) for value in (clean, coverage, handshake)):
        return False
    return (row.get('version') == VERSION and row.get('role') == role
            and row.get('phase') == 'done' and row.get('passed') is True
            and row.get('failed') == 0 and row.get('abortReason') == '' and row.get('attempts') == 1
            and set(coverage) == required and all(value is True for value in coverage.values())
            and handshake.get('hello' if role == 'host' else 'welcome') is True
            and row.get('sameGunFirstConnectQualified') is True
            and row.get('performanceQualified') is False
            and clean.get('errors') == [] and clean.get('sessionReleased') is True
            and all(clean.get(key) is True for key in ('equipmentRestored', 'configRestored',
                    'bodyCleared', 'hookUnchanged', 'flagsRemoved')))


def run(out, drivers, wait):
    assert out.parent == M52 and not out.exists()
    meta = verify_driver(drivers)
    before = installation()
    out.mkdir()
    cmd = [sys.executable, '-B', '-X', 'utf8', str(RUNNER), '--candidate',
           str(Path(meta['candidate']['path']) / 'RConnectMod.swf'), '--all-mods', '--effects',
           '--effects-driver', str(drivers), '--seconds', '360', '--connect-after-load',
           '--host-save-template', str(drivers / meta['templates']['host']['frozen']),
           '--join-save-template', str(drivers / meta['templates']['join']['frozen']),
           '--expected-version', VERSION, '--port', str(test_port()), '--private-desktop',
           '--defer-visible', '--require-exclusive-air', '--registry-wait', str(wait)]
    intent = dict(command=cmd, candidate=meta['candidate'], installation_before=before,
                  driver_manifest_sha256=sha(drivers / 'prepared.json'), wrapper_sha256=sha(__file__),
                  runner_sha256=sha(RUNNER), function_only=True, performance_qualified=False)
    save(out / 'intent.json', intent)
    with (out / 'runner.log').open('x', encoding='utf-8') as log:
        process = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    text = (out / 'runner.log').read_text(encoding='utf-8', errors='replace')
    match = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$', text, re.M)
    result = dict(passed=False, exit_code=process.returncode, run=match[1] if match else None,
                  installation_unchanged=installation() == before, function_only=True, performance_qualified=False)
    if match:
        actual = ROOT / 'build/cooperation' / match[1]
        run_data = read(actual / 'run.json')
        assert set(run_data['inputs']) == {'host', 'join'}
        result['roles'] = {}
        for role, inputs in run_data['inputs'].items():
            assert inputs['production'] == meta['candidate']['sha256']
            assert inputs['driver'] == sha(drivers / 'EffectsDriver.swf')
            assert inputs['harness'] == sha(drivers / 'EffectsHarness.swf')
            assert inputs['game'] == before['pfe.swf']
            assert run_data['save_templates'][role]['source_sha256'] == meta['templates'][role]['sha256']
            log = (actual / (role + '.log')).read_text(encoding='utf-8-sig', errors='replace')
            rows = [json.loads(line.split('OFFLINE FIRST CONNECT RESULT ', 1)[1]) for line in log.splitlines()
                    if line.startswith('OFFLINE FIRST CONNECT RESULT ')]
            done = 'COOP EFFECTS DONE offline-first-connect' in log
            result['roles'][role] = dict(rows=rows, done=done, passed=done and len(rows) == 1 and passed_row(rows[0], role))
        result['passed'] = (process.returncode == 0 and 'RESULT PASS' in text and result['installation_unchanged']
                            and all(row['passed'] for row in result['roles'].values()))
    verify_driver(drivers)
    assert sha(drivers / 'prepared.json') == intent['driver_manifest_sha256'] and sha(RUNNER) == intent['runner_sha256']
    save(out / 'result.json', result)
    print(json.dumps({key: value for key, value in result.items() if key != 'roles'}, ensure_ascii=False))
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
