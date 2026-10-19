"""Install a proven Q-sight candidate and roll back a failed ordinary-loader smoke.

This extends the explicitly requested fix39 test candidate. Its pre-existing
dense-scene failures remain open; this is not a full-version qualification.
"""
import argparse
import datetime
import json
import re
import shutil
import subprocess
import sys
from release_a22_map import ROOT, GAME, read, save, sha, require, replace, verify_install


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('candidate')
    ap.add_argument('--attempt', default='01')
    ap.add_argument('--audit-only', action='store_true', help='Read-only evidence and installation check')
    args = ap.parse_args()
    require(re.fullmatch(r'[0-9]{2}', args.attempt), 'Invalid attempt')
    candidate = (ROOT / args.candidate).resolve()
    require(candidate.parent == ROOT / 'build/m52', 'Not a frozen candidate')
    built = read(candidate / 'compiled.json')
    require(sha(candidate / 'source.json') == built['source_sha256'], 'Source manifest changed')
    for name, digest in built['files'].items():
        require(sha(candidate / name) == digest, 'Frozen input changed: ' + name)
    tested = read(candidate / 'result.json')
    require(tested['exit'] == 0 and not tested['installation_changes'], 'Native test not passed')
    require(tested['compiled_sha256'] == sha(candidate / 'compiled.json'), 'Wrong tested build')
    require(tested['runner_sha256'] == sha(ROOT / 'tools/run_coop_regression.py'), 'Runner changed')
    require(tested['runtime_before_sha256'] == sha(candidate / 'runtime-before.json'),
            'Test installation snapshot changed')
    folder = ROOT / 'build/cooperation' / tested['run']
    require(sha(folder / 'run.json') == tested['run_sha256'], 'Test run changed')
    run = read(folder / 'run.json')
    require(sha(folder / 'input.json') == run['input_manifest_sha256'], 'Test inputs changed')
    current = {'files': read(candidate / 'runtime-before.json')}
    expected_modules = {name.lower(): value for name, value in current['files'].items()}
    digest = built['files']['RConnectMod.swf']
    require(run['sha256'] == digest and not run['solo'], 'Wrong binary or test mode')
    for role, parity in (('host', 0), ('join', 1)):
        result = tested[role]
        require(result['done'] and result['failed'] == 0 and not result['exceptions']
                and not result['production_errors'], 'Incomplete native test: ' + role)
        log = (folder / (role + '.log')).read_text(encoding='utf-8-sig')
        require(sha(folder / (role + '.log')) == result['log_sha256'], 'Test log changed')
        rows = [json.loads(line.split('PEER PORT RESULT ', 1)[1]) for line in log.splitlines()
                if 'PEER PORT RESULT ' in line]
        require(sorted(row['round'] for row in rows) == list(range(parity, 26, 2)),
                'Not all thirteen native Q cases completed: ' + role)
        require(log.count('peer observed authoritative spell position ') == 13,
                'Missing opposite-side observations: ' + role)
        require('v' + built['version'] + ' initialized' in log, 'Version absent')
        require(run['inputs'][role]['production'] == digest, 'Test did not load production bytes')
        require(run['inputs'][role]['game'] == current['files']['pfe.swf'], 'Test native game mismatch')
        require(run['inputs'][role]['driver'] == built['files']['driver/EffectsDriver.swf'],
                'Test driver mismatch')
        for name, value in run['inputs'][role]['modules'].items():
            name = name.replace('\\', '/').lower()
            expected = (built['files']['driver/EffectsHarness.swf']
                        if name == 'mods/rconnect/release/rconnectmod.swf' else expected_modules.get(name))
            require(value == expected, 'Test dependency mismatch: ' + name)
    target = ROOT / 'release/RConnectMod.swf'
    previous = 'a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60'
    require(sha(target) == previous, 'Installation changed since fix39 handoff')
    verify_install(current)
    if args.audit_only:
        print(json.dumps(dict(q_feature_qualified=True, full_release_qualified=False,
                              candidate_sha256=digest, native_run=tested['run'],
                              assertions=sum(tested[role]['passed'] for role in ('host', 'join')),
                              scenarios=26, installed_sha256=previous,
                              deployment_performed=False), ensure_ascii=False), flush=True)
        return
    output = candidate / ('installation-' + args.attempt)
    output.mkdir(exist_ok=False)
    save(output / 'installation-before.json', current)
    backup = output / 'RConnectMod.before.swf'
    shutil.copy2(target, backup)
    require(sha(backup) == previous, 'Backup mismatch')
    receipt = dict(status='prepared', full_release_qualified=False,
                   authorization='User requested new-version deployment and the Q teammate-sight switch.',
                   at=datetime.datetime.now().astimezone().isoformat(), version=built['version'],
                   candidate_sha256=digest, previous_sha256=previous, backup=str(backup),
                   test_result_sha256=sha(candidate / 'result.json'), test_run=tested['run'],
                   known_failures=['Inherited fix39 dense-scene frame-rate gate remains red',
                                   'Earlier loot first-pause and full-version regression remain incomplete'],
                   script_sha256=sha(__file__))
    save(output / 'deployment.json', receipt)
    overrides = {target.relative_to(GAME).as_posix().lower(): digest}
    replaced = False
    try:
        verify_install(current)
        replace(candidate / 'RConnectMod.swf', target, digest)
        replaced = True
        verify_install(current, overrides)
        receipt['status'] = 'installed-awaiting-ordinary-loader-smoke'
        save(output / 'deployment.json', receipt)
        command = [sys.executable, '-B', '-X', 'utf8', str(ROOT / 'tools/run_coop_regression.py'),
                   '--candidate', str(target), '--smoke', '--all-mods', '--visible-windows',
                   '--seconds', '180', '--expected-version', built['version']]
        with (output / 'smoke.log').open('w', encoding='utf-8') as stream:
            completed = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        text = (output / 'smoke.log').read_text(encoding='utf-8')
        match = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$', text, re.M)
        require(completed.returncode == 0 and match is not None, 'Ordinary-loader smoke failed')
        folder = ROOT / 'build/cooperation' / match[1]
        run = read(folder / 'run.json')
        require(run['sha256'] == digest and not run['solo'], 'Wrong smoke binary/mode')
        for role in ('host', 'join'):
            inputs = run['inputs'][role]
            require('production' not in inputs and inputs['game'] == current['files']['pfe.swf'],
                    'Smoke bypassed ordinary loader')
            for name, value in inputs['modules'].items():
                name = name.replace('\\', '/')
                require(value == overrides.get(name.lower(), current['files'].get(name)),
                        'Smoke module changed: ' + name)
            log = (folder / (role + '.log')).read_text(encoding='utf-8-sig')
            require('v' + built['version'] + ' initialized' in log and 'tick 200' in log,
                    'Smoke version/heartbeat absent')
            native = (folder / (role + '.stdout.log')).read_text(encoding='utf-8', errors='replace')
            require(re.search(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught|out of memory)\b',
                              native, re.I) is None, 'Native exception')
        verify_install(current, overrides)
        receipt.update(status='installed-user-candidate-smoke-passed', smoke_run=match[1],
                       smoke_run_sha256=sha(folder / 'run.json'))
    except BaseException as error:
        receipt.update(status='failed', error=str(error))
        save(output / 'deployment.json', receipt)
        if replaced:
            require(sha(target) == digest, 'External replacement prevents rollback')
            replace(backup, target, previous)
        receipt['status'] = 'rolled-back'
        save(output / 'deployment.json', receipt)
        raise
    save(output / 'deployment.json', receipt)
    print(receipt['status'] + ' ' + str(output), flush=True)


if __name__ == '__main__':
    main()
