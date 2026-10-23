"""Audit or deploy only exact offline1 RC bytes, then smoke the installed file.

From mods/RConnect:
  python -B -X utf8 experimental/recovery-offline-production/deploy.py --audit \
    --first-connect build/m52/recovery-offline-first-connect-native-08 \
    --output build/m52/recovery-offline-deploy-audit-01
Use a NEW output and explicit --deploy to install. No host/config/source edits.
This is the never-networked offline collection optimization, NOT the four
loading/telekinesis/impact/continuity fixes or a multiplayer performance claim.
"""
from pathlib import Path
import argparse
import contextlib
import hashlib
import importlib.util
import json
import os
import re
import sys
import uuid

if sys.flags.optimize:
    raise RuntimeError('Do not disable validation assertions')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
CANDIDATE = M52 / 'recovery-offline-production-01'
RELEASE = ROOT / 'release/RConnectMod.swf'
RC = 'mods/Rconnect/release/RConnectMod.swf'
VERSION = '0.2.24-offline1'
BASE = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
NEW = 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
PREPARE = HERE / 'prepare.py'
DRIVER = ROOT / 'experimental/recovery-offline-first-connect/driver.py'
RUNNER = ROOT / 'tools/run_coop_regression.py'
PINS = {
    PREPARE: '4dbb2b4f88fcd1b59ec924d8467dfb9fbe966153afd8340ab002f0b8b139dda9',
    DRIVER: '24db5e87a5f8bbcca41fa5cbe72f608e4c61c3936832eb9543572999c484c56c',
    DRIVER.parent / 'tests/OfflineFirstConnectTestDoc.as': 'f6f006b6fe25efe9cca7a7b9c531c3db2d953bef4bdc0b3fecb9cd40b77eb24a',
    CANDIDATE / 'prepared.json': 'c15ee493fdfeb804a2dd39c9710b3127c7ba7f458efd238f6fab8443eea6d5e7',
    CANDIDATE / 'compile.json': 'da37c6c00d922df3b900b9b3e4ac4e086a4dd3309989b49d28eaaf8772ae671d',
    RUNNER: '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
    ROOT / 'tools/validation/run_security_terminals.py': '4e4ad73dd0f8df69db5c0c11f6c2c1c94c96fb1235dbaa1aad18caaf9877b9cb',
    ROOT / 'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT / 'tools/validation/air_test_inventory.py': '3d4c6160cfb8ee766ad77463da9e5e7a67b10af30170b4ca5a876af1d4a9cd4c',
    ROOT / 'tools/validation/native_runtime_assets.py': 'a8e15e4065a7b68647f24ef39832450cd5811d450c0ac33f23cea06f2d65706f',
    GAME / 'mods/ModLoader/tools/test_registry.py': '58db3a594f34e9906d55992f769b3e154970d8fa37fda1c2f43ae1f6751b0033',
    GAME / 'mods/ModLoader/tools/air_test_process.py': '628ffed886db293abe0177fd42c61ac09482e04aee6aae358cf2e3d6deb0d1f9',
}
OLD = (
    ('recovery-offline-lifecycle-native-03', 'f97729db4fab9a37406887847691374351597e359f149665d9fbc5356997d4f1',
     'OFFLINE LIFECYCLE RESULT ', 'offline-lifecycle', 56),
    ('recovery-offline-collector-native-01', 'fad44385d4cb3f4f309582f85fb613227fbc179c4d51923de981b909113270a9',
     'OFFLINE COLLECTOR RESULT ', 'offline-collector', 86),
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def beneath(base, name):
    path = (base / name).resolve()
    assert path.is_relative_to(base.resolve()), str(path)
    return path


def record(files, path, expected=None):
    path = Path(path).resolve()
    value = sha(path)
    assert expected is None or value == expected, str(path)
    if str(path) in files:
        assert files[str(path)] == value, 'Input changed during audit: ' + str(path)
    files[str(path)] = value
    return value


def recorded_run(folder, baseline, files, *, drivers=None, solo=False, smoke=False):
    """Validate preserved raw input/config/log bytes, not only wrapper booleans."""
    assert folder.parent == ROOT / 'build/cooperation' and re.fullmatch('[0-9a-f]{10}', folder.name)
    raw = read(folder / 'run.json'); inp = read(folder / 'input.json')
    record(files, folder / 'run.json'); record(files, folder / 'input.json', raw['input_manifest_sha256'])
    roles = {'host'} if solo else {'host', 'join'}
    assert raw['sha256'] == inp['candidate_sha256'] == NEW
    assert raw['solo'] is inp['solo'] is solo and set(raw['inputs']) == set(inp['inputs']) == roles
    assert raw['inputs'] == inp['inputs'] and len(raw['pids']) == len(roles)
    assert raw['private_desktop'] is inp['private_desktop'] is True
    assert inp['require_exclusive_air'] is True and inp['minimum_start_gib'] == (3 if solo else 6)
    assert inp['memory_reader_sha256'] == PINS[ROOT / 'tools/validation/runtime_memory.py']
    assert inp['air_inventory_sha256'] == PINS[ROOT / 'tools/validation/air_test_inventory.py']
    assert inp['desktop_helper_sha256'] == PINS[GAME / 'mods/ModLoader/tools/air_test_process.py']
    if not solo:
        assert raw['inputs']['host'] == raw['inputs']['join']
    timeline = read(folder / 'memory-timeline.json'); initial = read(folder / 'memory-before.json')
    assert initial['free_commit_bytes'] >= inp['minimum_start_gib'] * 1024**3
    assert timeline['stopped_for_pressure'] is False and timeline['stopped_for_overlap'] is False
    assert timeline['minimum_commit_bytes'] == 512 * 1024**2 and timeline['rows']
    assert min(row['free_commit_bytes'] for row in timeline['rows']) >= 512 * 1024**2
    for name in ('memory-before.json', 'memory-timeline.json', 'air-before.json'):
        record(files, folder / name)
    assert read(folder / 'air-before.json') == []
    result = {}
    for role in sorted(roles):
        values = raw['inputs'][role]
        assert values['game'] == baseline['pfe.swf']
        if drivers is not None:
            assert values['production'] == NEW
            assert values['driver'] == record(files, drivers / 'EffectsDriver.swf')
            assert values['harness'] == record(files, drivers / 'EffectsHarness.swf')
        else:
            assert smoke and 'production' not in values and 'driver' not in values and 'harness' not in values
        expected_modules = {n.lower(): h for n, h in baseline.items() if n.startswith('mods/') and n.endswith('.swf')}
        expected_modules[RC.lower()] = NEW if smoke else values['harness']
        assert {n.replace('\\', '/').lower(): h for n, h in values['modules'].items()} == expected_modules
        for name, digest in values['assets'].items():
            record(files, beneath(GAME, name), digest)
        for name, digest in values['mod_assets'].items():
            assert baseline[name] == digest
        assert raw['configuration_files'][role] == inp['configuration_files'][role]
        for name, digest in raw['configuration_files'][role].items():
            record(files, beneath(folder / 'configuration' / role, name), digest)
            if name.lower() != 'mods/rconnect/release/config.txt':
                assert baseline[name] == digest
        assert raw['descriptors'][role] == inp['descriptors'][role]
        record(files, folder / 'descriptors' / (role + '.xml'), raw['descriptors'][role])
        log = folder / (role + '.log'); record(files, log)
        record(files, folder / (role + '.stdout.log'))
        for path in sorted((folder / 'module-logs' / role).glob('*.log')):
            record(files, path)
        result[role] = log.read_text(encoding='utf-8-sig', errors='replace')
    return raw, result


def rows(text, prefix):
    return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]


def audit(first):
    files = {}
    for path, digest in PINS.items():
        record(files, path, digest)
    record(files, __file__)
    for path in (ROOT / 'tools', ROOT / 'tools/validation', ROOT / 'tools/host_authority', GAME / 'mods/ModLoader/tools'):
        sys.path.insert(0, str(path))
    prep = load('offline_deploy_prepare', PREPARE)
    meta = prep.verify(CANDIDATE)
    baseline = meta['installation_before']
    assert len(baseline) == 22 and baseline[RC] == BASE and prep.installation() == baseline
    record(files, CANDIDATE / 'RConnectMod.swf', NEW)
    for section in ('source', 'inputs'):
        for name, digest in meta[section].items():
            record(files, beneath(CANDIDATE, name), digest)
    record(files, HERE / 'README.md', meta['readme_sha256'])
    assert first.parent == M52 and re.fullmatch(r'recovery-offline-first-connect-native-\d+', first.name)
    intent = read(first / 'intent.json'); receipt = read(first / 'result.json')
    for name in ('intent.json', 'result.json', 'runner.log'):
        record(files, first / name)
    assert receipt['passed'] is True and receipt['exit_code'] == 0 and receipt['installation_unchanged'] is True
    assert receipt['performance_qualified'] is False and intent['installation_before'] == baseline
    assert intent['runner_sha256'] == PINS[RUNNER] and intent['wrapper_sha256'] == PINS[DRIVER]
    command = intent['command']
    assert Path(command[4]).resolve() == RUNNER
    # Exact flags; no optional host/mod replacement or hidden alternate world.
    drivers = Path(command[command.index('--effects-driver') + 1]).resolve()
    assert drivers.parent == M52 and re.fullmatch(r'recovery-offline-first-connect-driver-\d+', drivers.name)
    first_driver = load('offline_deploy_first_driver', DRIVER)
    dm = first_driver.verify_driver(drivers)
    assert dm['candidate'] == intent['candidate'] and dm['candidate']['sha256'] == NEW
    assert dm['candidate']['path'] == str(CANDIDATE)
    record(files, drivers / 'prepared.json', intent['driver_manifest_sha256'])
    for name, digest in dm['files'].items():
        record(files, beneath(drivers, name), digest)
    for name, digest in dm['tools'].items():
        record(files, name, digest)
    port = command[command.index('--port') + 1]; wait = command[command.index('--registry-wait') + 1]
    assert 1 <= int(port) <= 65535 and 0 <= float(wait) <= 3600
    expected_command = [command[0], '-B', '-X', 'utf8', str(RUNNER), '--candidate', str(CANDIDATE / 'RConnectMod.swf'),
        '--all-mods', '--effects', '--effects-driver', str(drivers), '--seconds', '360', '--connect-after-load',
        '--host-save-template', str(drivers / dm['templates']['host']['frozen']),
        '--join-save-template', str(drivers / dm['templates']['join']['frozen']), '--expected-version', VERSION,
        '--port', port, '--private-desktop', '--defer-visible', '--require-exclusive-air', '--registry-wait', wait]
    assert command == expected_command
    run = ROOT / 'build/cooperation' / receipt['run']
    raw, logs = recorded_run(run, baseline, files, drivers=drivers)
    assert Path(raw['candidate']).resolve() == CANDIDATE / 'RConnectMod.swf'
    assert set(receipt['roles']) == {'host', 'join'}
    for role in ('host', 'join'):
        entries = rows(logs[role], 'OFFLINE FIRST CONNECT RESULT ')
        assert entries == receipt['roles'][role]['rows'] and len(entries) == 1
        assert receipt['roles'][role]['done'] is True and receipt['roles'][role]['passed'] is True
        assert 'COOP EFFECTS DONE offline-first-connect' in logs[role] and first_driver.passed_row(entries[0], role)
        assert entries[0]['endedFrom'] == 'finishing'
        if role == 'host':
            assert entries[0]['finishAckReceived'] is True
        assert raw['save_templates'][role]['source_sha256'] == dm['templates'][role]['sha256']
        record(files, dm['templates'][role]['source'], dm['templates'][role]['sha256'])
    assert re.search(r'^RESULT PASS\s*$', (first / 'runner.log').read_text(encoding='utf-8'), re.M)
    registry = read(run / 'registry-result.json')
    assert registry['passed'] is True and registry['cancelled'] is False
    record(files, run / 'registry-result.json')
    retained = []
    for name, digest, prefix, label, count in OLD:
        folder = M52 / name; old = read(folder / 'result.json'); oi = read(folder / 'intent.json')
        record(files, folder / 'result.json', digest); record(files, folder / 'intent.json'); record(files, folder / 'runner.log')
        assert old['passed'] is True and old['exit_code'] == 0 and old['installation_unchanged'] is True and old['done'] is True
        assert oi['candidate'] == dm['candidate'] and oi['installation_before'] == baseline
        oc = oi['command']; od = Path(oc[oc.index('--effects-driver') + 1]); om = read(od / 'prepared.json')
        record(files, od / 'prepared.json', oi['driver_manifest_sha256'])
        assert om['compiled'] is True and om['compile_exit'] == 0 and om['candidate'] == dm['candidate']
        for n, h in om['files'].items():
            record(files, beneath(od, n), h)
        for n, h in om['tools'].items():
            record(files, n, h)
        old_runner = Path(oc[4]); record(files, old_runner, oi['runner_sha256'])
        record(files, old_runner.parent / 'driver.py', oi['wrapper_sha256'])
        checker = load('offline_deploy_' + label.replace('-', '_'), old_runner)
        old_run = ROOT / 'build/cooperation' / old['run']
        _, old_logs = recorded_run(old_run, baseline, files, drivers=od, solo=True)
        rs = rows(old_logs['host'], prefix)
        assert rs == old['rows'] and len(rs) == 1 and checker.passed_row(rs[0]) and rs[0]['checks'] == count
        assert rs[0]['performanceQualified'] is False and 'COOP EFFECTS DONE ' + label in old_logs['host']
        assert re.search(r'^RESULT PASS\s*$', (folder / 'runner.log').read_text(encoding='utf-8'), re.M)
        rr = read(old_run / 'registry-result.json'); assert rr['passed'] is True and rr['cancelled'] is False
        record(files, old_run / 'registry-result.json')
        retained.append(dict(kind=label,run=old['run'],checks=count,coverage=rs[0]['coverage'],performance_qualified=False))
    assert prep.installation() == baseline
    return dict(candidate_sha256=NEW, baseline=baseline, version=VERSION, first_connect=str(first), first_run=receipt['run'],
        first_checks={r:receipt['roles'][r]['rows'][0]['checks'] for r in ('host', 'join')}, retained=retained,
        reviewed_files=files, qualified_scope='Never-networked offline collection optimization; first TCP connection and observed LMG/body effects retained',
        performance_qualified=False, four_reported_fixes_qualified=False)


def recheck(proof):
    for path, digest in proof['reviewed_files'].items():
        assert sha(path) == digest, 'Reviewed input changed: ' + path


def replace_rc(source, digest, expected):
    assert sha(source) == digest and sha(RELEASE) == expected
    temporary = RELEASE.with_name(RELEASE.name + '.offline1-' + uuid.uuid4().hex + '.tmp')
    try:
        with temporary.open('xb') as stream:
            stream.write(Path(source).read_bytes()); stream.flush(); os.fsync(stream.fileno())
        assert sha(temporary) == digest and sha(RELEASE) == expected, 'Target changed before atomic replacement'
        os.replace(temporary, RELEASE)
        assert sha(RELEASE) == digest
    finally:
        if temporary.exists():
            temporary.unlink()


def deploy(out, proof, wait):
    from run_security_terminals import installation, test_port
    from runtime_memory import snapshot
    from air_test_inventory import air_processes
    from test_registry import Registration
    baseline = proof['baseline']; expected = dict(baseline); expected[RC] = NEW
    backup = out / 'RConnectMod.before.swf'
    state = dict(status='not-installed', replacement_attempted=False, installation_before=baseline, candidate_sha256=NEW,
        backup=str(backup), source=str(CANDIDATE / 'RConnectMod.swf'), target=str(RELEASE), performance_qualified=False,
        four_reported_fixes_qualified=False, defer_visible_omitted='Original runner restricts deferred visibility to effects harness; production smoke has no harness')
    argv = [str(RUNNER), '--candidate', str(RELEASE), '--smoke', '--all-mods', '--land', 'random_mane', '--seconds', '180',
        '--expected-version', VERSION, '--port', str(test_port()), '--private-desktop', '--require-exclusive-air', '--registry-wait', str(wait)]
    save(out / 'smoke-command.json', [sys.executable, '-B', '-X', 'utf8'] + argv)
    runner = load('offline_deploy_original_runner', RUNNER)
    original = runner.run_registered
    calls = 0

    def rollback():
        current = sha(RELEASE)
        if current == NEW:
            assert sha(backup) == BASE
            replace_rc(backup, BASE, NEW)
            state['status'] = 'rolled-back'
        elif current == BASE:
            state['status'] = 'baseline-present'
        else:
            state['status'] = 'rollback-refused-third-party-change'
            raise RuntimeError('RC no longer matches this deployment; another writer must not be overwritten')
        state['installation_after_rollback'] = installation()
        save(out / 'rollback.json', dict(state))

    def registered(args, parser, actual, registration):
        nonlocal calls
        calls += 1; assert calls == 1
        try:
            # Original main has acquired its game registration; no second lock or unreserved gap.
            runner.check_cancel_requested(actual, 'deployment before install')
            assert audit(Path(proof['first_connect'])) == proof
            assert installation() == baseline and snapshot()['free_commit_bytes'] >= 6 * 1024**3
            assert air_processes() == [], 'Other AIR process; leave installation unchanged'
            with backup.open('xb') as stream:
                stream.write(RELEASE.read_bytes()); stream.flush(); os.fsync(stream.fileno())
            assert sha(backup) == BASE
            save(out / 'deployment-intent.json', dict(state, registry_id=registration.id, smoke_output=str(actual)))
            state['replacement_attempted'] = True
            replace_rc(CANDIDATE / 'RConnectMod.swf', NEW, BASE)
            state['status'] = 'installed-awaiting-smoke'; save(out / 'installed.json', dict(state))
            assert installation() == expected
            ok = original(args, parser, actual, registration)
            assert ok is True, 'Original installed-production smoke failed'
            files = {}; raw, logs = recorded_run(actual, expected, files, smoke=True)
            assert Path(raw['candidate']).resolve() == RELEASE
            for role, text in logs.items():
                assert 'v' + VERSION + ' initialized' in text and 'tick 200' in text
                if role == 'join':
                    assert 'welcome id=' in text and 'unitsync matched' in text
            assert installation() == expected; recheck(proof)
            state.update(status='deployed-smoke-passed',smoke_run=actual.name,smoke_files=files,installation_after=installation())
            save(out / 'smoke-proof.json', dict(state))
            return True
        except BaseException as error:
            state['error'] = repr(error)
            if state['replacement_attempted']:
                rollback()
            raise

    runner.run_registered = registered  # Local loaded module only; original file/main/registration/checks remain intact.
    old_argv = sys.argv; code = None
    try:
        sys.argv = argv
        with (out / 'installed-smoke.log').open('x', encoding='utf-8') as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
            try:
                runner.main()
            except SystemExit as exit_error:
                code = exit_error.code
        assert code == 0 and state['status'] == 'deployed-smoke-passed' and calls == 1
        actual = ROOT / 'build/cooperation' / state['smoke_run']
        registry = read(actual / 'registry-result.json')
        assert registry['passed'] is True and registry['cancelled'] is False
        state['smoke_registry_sha256'] = sha(actual / 'registry-result.json')
    except BaseException as error:
        state['error'] = repr(error)
        # Also cover errors after the registered callback, e.g. final registry-result persistence.
        if state['replacement_attempted'] and state['status'] in ('installed-awaiting-smoke', 'deployed-smoke-passed'):
            with Registration(owner='RConnect / offline1 rollback', purpose='Rollback this failed RC deployment only',
                    resource='game', run_dir=out, evidence=out / 'rollback.json', wait=wait) as registration:
                rollback(); registration.outcome='completed'; registration.note='Only own RC candidate reverted'
        raise
    finally:
        sys.argv = old_argv; runner.run_registered = original
        state['exit_code'] = code
        state['release_sha256_final'] = sha(RELEASE)
        save(out / 'deployment.json', state)
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--audit', action='store_true'); modes.add_argument('--deploy', action='store_true')
    parser.add_argument('--first-connect', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve(); first = (ROOT / args.first_connect).resolve()
    assert out.parent == M52 and re.fullmatch(r'recovery-offline-deploy-(?:audit-)?\d+', out.name)
    assert not out.exists(), 'Preserve every prior proof/receipt; choose a new output'
    assert 0 <= args.registry_wait <= 3600
    out.mkdir()
    try:
        proof = audit(first); save(out / 'audit.json', proof)
        state = deploy(out, proof, args.registry_wait) if args.deploy else {'status':'audit-passed-not-installed'}
        save(out / 'result.json', dict(passed=True,mode='deploy' if args.deploy else 'audit',**state))
        print(json.dumps(dict(output=str(out),status=state['status'],performance_qualified=False)))
    except BaseException as error:
        save(out / 'result.json', dict(passed=False,error=repr(error),mode='deploy' if args.deploy else 'audit',release_sha256=sha(RELEASE)))
        raise


if __name__ == '__main__':
    main()
