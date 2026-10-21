"""Run one frozen recovery component or native entry; never compile or deploy.

Every invocation needs a new output folder. A passing result is functional_only,
never a performance qualification. The native runner owns its shared game lock;
components use the same lock directly and only stop their own HiddenProcess.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import traceback
import uuid
import xml.etree.ElementTree as ET

import prepare

ROOT, GAME = prepare.ROOT, prepare.ROOT.parents[1]
sha, read, save = prepare.sha, prepare.read, prepare.save
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from run_security_terminals import installation, test_port

EXPECTED_INSTALLATION_FILES = 22
ERROR = re.compile(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|'
                   r'VerifyError|RangeError|SecurityError|out of memory)\b|'
                   r'COOP FAIL|game error dialog|handoff timed out|RConnect[^\r\n]*\bfailed\b', re.I)
SUITES = {
    'PeerGripTestDoc': 'peer-grip', 'PeerThrowDamageTestDoc': 'peer-throw-damage',
    'WallBallisticTestDoc': 'energy-impact', 'WallEnergyTestDoc': 'energy-impact',
    'WallMagicTestDoc': 'energy-impact', 'RecoveryWallMaterialsTestDoc': 'energy-impact',
    'ExplosiveVisualTestDoc': 'explosive-visual', 'SpecialWeaponTestDoc': 'explosive-visual',
    'MagicExplosionTestDoc': 'explosive-visual', 'HeavyProjectileTestDoc': 'heavy-projectile',
    'NativeFlightContinuityTestDoc': 'native-flight-continuity',
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def contents(path):
    return path.read_text(encoding='utf-8-sig', errors='replace') if path.is_file() else ''


def normalized(values):
    return {k.replace('\\', '/').lower(): v for k, v in values.items()}


def changes(before, after):
    return {n: dict(before=before.get(n), after=after.get(n)) for n in sorted(set(before) | set(after))
            if before.get(n) != after.get(n)}


def verify(drivers, prepared_hash):
    require(sha(drivers / 'prepared.json') == prepared_hash, 'Frozen driver manifest changed')
    manifest = read(drivers / 'prepared.json')
    require(manifest.get('compiled') is True, 'Compile the frozen drivers before running')
    return prepare.verify(drivers, Path(manifest['source_root']), runtime=True)


def errors_in(paths):
    return [dict(file=str(p), line=n, text=line) for p in paths
            for n, line in enumerate(contents(p).splitlines(), 1) if ERROR.search(line)]


def runtime_tools():
    names = [Path(__file__).resolve(), Path(prepare.__file__).resolve(),
             ROOT / 'tools/run_coop_regression.py', ROOT / 'tools/validation/runtime_memory.py',
             ROOT / 'tools/validation/native_runtime_assets.py', ROOT / 'tools/validation/air_test_inventory.py',
             ROOT / 'tools/validation/run_security_terminals.py',
             GAME / 'mods/ModLoader/tools/test_registry.py', GAME / 'mods/ModLoader/tools/air_test_process.py',
             GAME / 'adl64.exe']
    return {str(p): sha(p) for p in names}


def assert_same_tools(tools):
    for name, digest in tools.items():
        require(sha(name) == digest, 'Runtime tool changed: ' + name)


def component(args, drivers, out, manifest, intent, result):
    from air_test_process import HiddenProcess
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned

    spec = manifest['components'][args.component]
    source = drivers / 'components' / args.component / 'Checks.swf'
    runtime = out / 'runtime'
    runtime.mkdir()
    shutil.copyfile(source, runtime / 'Checks.swf')
    appid = 'rconnect-recovery-run-' + args.component + '-' + uuid.uuid4().hex
    storage = Path(os.environ['APPDATA']) / appid / 'Local Store'
    require(not storage.parent.exists(), 'Unique component application storage already exists')
    descriptor = runtime / 'application.xml'
    descriptor.write_text(
        '<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid +
        '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>'
        '<content>Checks.swf</content><visible>false</visible><width>120</width><height>120</height>'
        '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
    command = [str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)]
    intent.update(command=command, appid=appid, storage=str(storage), component=args.component,
                  entry=spec['entry'], component_sha256=sha(source), descriptor_sha256=sha(descriptor),
                  expected_checks=spec['expected_checks'], minimum_start_bytes=1024**3,
                  minimum_runtime_bytes=512*1024**2, private_desktop=True)
    save(out / 'intent.json', intent)
    with Registration(owner='RConnect / 恢复整合版组件验证', purpose=args.component + ' functional only',
                      resource='game', run_dir=out, evidence=out / 'result.json',
                      wait=args.registry_wait) as record:
        verify(drivers, intent['prepared_sha256'])
        assert_same_tools(intent['tools'])
        require(installation() == intent['installation_before'], 'Installation changed while waiting')
        require(sha(runtime / 'Checks.swf') == intent['component_sha256'], 'Copied component changed')
        require(sha(descriptor) == intent['descriptor_sha256'], 'Component descriptor changed')
        memory = snapshot()
        save(out / 'memory-before.json', memory)
        require(memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB commit headroom; AIR not started')
        process = None
        with (out / 'stdout.log').open('w', encoding='utf-8') as log:
            try:
                record.before_launch(args.component + ' / ' + appid)
                process = HiddenProcess(command, cwd=runtime, stdout=log, stderr=log)
                record.child(process.pid)
                result.update(air_started=True, pid=process.pid, desktop=process.desktop)
                result['exit_code'] = wait_owned(process, 60, out / 'memory-timeline.json')
            finally:
                if process is not None:
                    if process.poll() is None:
                        process.kill()
                        process.wait(15)
                    process.close()
                    record.child_stopped()
        require((storage / 'result.json').is_file(), 'Component did not write its unique result')
        shutil.copyfile(storage / 'result.json', out / 'component-result.json')
        raw = read(out / 'component-result.json')
        rows = raw.get('checks')
        require(isinstance(rows, list) and rows and all(isinstance(r, dict) and
                type(r.get('pass')) is bool and isinstance(r.get('label'), str) for r in rows),
                'Malformed component check rows')
        passed = sum(r['pass'] for r in rows)
        failed = len(rows) - passed
        result.update(observed_checks=len(rows), expected_checks=spec['expected_checks'],
                      expected_count_matches=len(rows) == spec['expected_checks'],
                      checks_passed=passed, checks_failed=failed, errors=errors_in([out / 'stdout.log']),
                      raw_result_sha256=sha(out / 'component-result.json'), game_loaded=raw.get('gameLoaded'))
        # The 26/41 figures are declared expectations, never substituted for
        # AIR's actual rows or used to rewrite a failed assertion.
        require(type(raw.get('pass')) is int and type(raw.get('fail')) is int and
                raw['pass'] == passed and raw['fail'] == failed, 'Component totals disagree with actual rows')
        require(raw.get('gameLoaded') is False, 'Unexpected game-loaded component')
        require(result['exit_code'] == 0 and failed == 0 and not result['errors'], 'Component checks failed')
        verify(drivers, intent['prepared_sha256'])
        assert_same_tools(intent['tools'])
        require(installation() == intent['installation_before'], 'Installation changed during component')
        result['passed'] = True
        record.outcome = 'passed'
        record.note = str(passed) + ' actual component assertions passed; functional_only, no native/performance claim'


def native_inputs(run, info, intent, spec):
    """Check every installed input, with explicit isolated harness/config overrides."""
    before = normalized(intent['installation_before'])
    driver = intent['driver']
    evidence = read(run / 'input.json')
    require(info['input_manifest_sha256'] == sha(run / 'input.json'), 'Native input receipt hash mismatch')
    require(info['sha256'] == intent['candidate_sha256'] == evidence['candidate_sha256'], 'Wrong candidate bytes')
    require(evidence['minimum_start_gib'] == 6 and evidence['require_exclusive_air'] is True,
            'Native startup/exclusive policy missing')
    for key in ('private_desktop', 'defer_visible'):
        require(info[key] is True and evidence[key] is True, key + ' policy missing')
    require(info['wait_host_world'] is True and not info['solo'] and not info['visible_windows'], 'Wrong native launch mode')
    require(info['inputs'] == evidence['inputs'] and info['configuration_files'] == evidence['configuration_files'],
            'Native prelaunch inputs disagree with final receipt')
    require(info['inputs']['host'] == info['inputs']['join'], 'Host and join loaded different frozen assets')
    require(sha(run / 'candidate.swf') == intent['candidate_sha256'], 'Frozen candidate hash mismatch')
    timeline = read(run / 'memory-timeline.json')
    require(timeline['minimum_commit_bytes'] == 512*1024**2 and not timeline['stopped_for_pressure']
            and not timeline['stopped_for_overlap'], 'Native memory pressure or foreign AIR overlap')
    require(not read(run / 'air-before.json'), 'Foreign AIR existed at startup')
    require(read(run / 'memory-before.json')['free_commit_bytes'] >= 6*1024**3, 'Native initial memory below 6 GiB')
    # The existing runner uses Path.write_text with native newline translation.
    # Its exact bytes on Windows are CRLF, although read_text returns LF.
    loader_hash = hashlib.sha256(intent['isolated_loader_manifest'].replace('\n', os.linesep).encode('utf-8')).hexdigest()
    audits, appids = {}, []
    for role in ('host', 'join'):
        values = info['inputs'][role]
        require(values['production'] == intent['candidate_sha256'], role + ' production mismatch')
        require(values['driver'] == driver['driver_sha256'] and values['harness'] == driver['harness_sha256'],
                role + ' external driver/harness mismatch')
        require(values['game'] == before['pfe.swf'], role + ' game SWF mismatch')
        configs = normalized(info['configuration_files'][role])
        modules = normalized(values['modules'])
        assets = normalized(values['mod_assets'])
        actual = {}
        for name, installed_digest in before.items():
            p = run / role / name
            require(p.is_file(), role + ' missing runtime input: ' + name)
            digest = sha(p)
            expected = installed_digest
            override = None
            if name == 'mods/loader-manifest.txt':
                expected, override = loader_hash, 'active manifest rows; comments removed by existing runner'
            elif name == 'mods/rconnect/release/rconnectmod.swf':
                expected, override = driver['harness_sha256'], 'external harness; exact production in tests/RConnectProduction.swf'
            elif name == 'mods/rconnect/release/config.txt':
                cfg = read(p)
                expected_cfg = dict(nickname=role, hostIp='127.0.0.1', port=info['port'], tickMs=50,
                                    autoRole=role, autoGame='1', autoFollow='1', freezeAI='1',
                                    worldInject='1', ghostCombat='1', autoHeal='1')
                if role == 'host':
                    expected_cfg['autoTravelLand'] = spec['land']
                require(cfg == expected_cfg, role + ' unexpected generated test config')
                expected, override = configs[name], 'isolated role/port/mission test settings'
            require(digest == expected, role + ' runtime input mismatch: ' + name)
            if name in modules:
                require(modules[name] == digest, role + ' module receipt mismatch: ' + name)
            if name in assets:
                require(assets[name] == digest, role + ' asset receipt mismatch: ' + name)
            if name in configs:
                require(configs[name] == digest and sha(run / 'configuration' / role / name) == digest,
                        role + ' preserved config mismatch: ' + name)
            actual[name] = dict(installed=installed_digest, runtime=digest, override=override)
        expected_modules = {n for n in before if n.startswith('mods/') and n.endswith('.swf')}
        require(set(modules) == expected_modules, role + ' incomplete/extra module set')
        for name, digest in values['assets'].items():
            require(sha(run / role / name) == digest, role + ' native asset mismatch: ' + name)
        for name, digest in {'tests/RConnectProduction.swf': intent['candidate_sha256'],
                             'tests/EffectsDriver.swf': driver['driver_sha256']}.items():
            require(sha(run / role / name) == digest, role + ' copied external artifact mismatch')
        descriptor = run / 'descriptors' / (role + '.xml')
        require(sha(descriptor) == info['descriptors'][role] == evidence['descriptors'][role], 'Descriptor hash mismatch')
        appid = ET.parse(descriptor).find('{*}id').text
        require(appid == 'pfe-modsettings-rconnect-coop-' + role + '-' + run.name, 'Unexpected native AppID')
        appids.append(appid)
        require((run / role / 'tests/show-window-when-ready.flag').is_file(), 'Deferred display flag missing')
        audits[role] = actual
    require(len(set(appids)) == 2, 'Native application IDs are not independent')
    return audits


def clean_native_copies(run, result):
    """The parent runner already stopped its children; remove only this run's copies."""
    removed = []
    for name in ('host', 'join', 'frozen'):
        folder = (run / name).resolve()
        require(folder.parent == run.resolve() and folder.name == name, 'Unsafe owned-copy cleanup path')
        if folder.exists():
            shutil.rmtree(folder)
            removed.append(name)
    result['removed_owned_runtime_copies'] = removed


def native(args, drivers, out, manifest, intent, result):
    entry, spec = args.entry, manifest['entries'][args.entry]
    require(entry in SUITES, 'No log contract for manifest entry ' + entry)
    candidate = prepare.BASE if args.control else Path(manifest['source_root']).parent / 'RConnectMod.swf'
    digest = manifest['control_sha256'] if args.control else manifest['candidate_sha256']
    require(sha(candidate) == digest, 'Native candidate hash mismatch')
    driver_path = drivers / ('controls' if args.control else 'drivers') / entry
    binding = read(driver_path / 'driver-input.json')
    require(binding['entry'] == entry and binding['candidate_sha256'] == digest and
            binding['driver_sha256'] == sha(driver_path / 'EffectsDriver.swf'), 'External driver binding mismatch')
    for name in ('EffectsDriver.swf', 'EffectsHarness.swf'):
        require(sha(driver_path / name) == sha(drivers / 'drivers' / entry / name),
                'Control and candidate must use identical external test bytes: ' + name)
    version_source = candidate.parent / 'src/RConnectMod.as' if args.control else drivers / 'production/RConnectMod.as'
    version = re.search(r'VERSION:String\s*=\s*"([^"]+)"', contents(version_source))
    require(version is not None, 'Missing exact-candidate version source')
    if args.control:
        require(digest == prepare.BASE_SHA and version[1] == '0.2.23-coop-bundle2', 'Unexpected fixed 574D control')
    before_runs = {p.name for p in (ROOT / 'build/cooperation').iterdir()} if (ROOT / 'build/cooperation').is_dir() else set()
    command = [sys.executable, '-B', '-X', 'utf8', str(ROOT / 'tools/run_coop_regression.py'),
               '--candidate', str(candidate), '--effects', '--effects-driver', str(driver_path),
               '--expected-version', version[1], '--all-mods', '--land', spec['land'],
               '--seconds', str(spec['seconds']), '--port', str(test_port()), '--private-desktop',
               '--defer-visible', '--wait-host-world', '--require-exclusive-air',
               '--registry-wait', str(args.registry_wait), '--keep-copies']
    # Kept only until all 22 runtime files are hashed, then removed by this
    # wrapper. The runner's manifest does not otherwise retain its loader file.
    intent.update(command=command, entry=entry, purpose=spec['purpose'], control=args.control,
                  candidate=str(candidate), candidate_sha256=digest, expected_version=version[1],
                  version_source=str(version_source), version_source_sha256=sha(version_source),
                  driver=dict(binding=binding, driver_sha256=binding['driver_sha256'],
                              harness_sha256=sha(driver_path / 'EffectsHarness.swf'),
                              binding_sha256=sha(driver_path / 'driver-input.json')))
    save(out / 'intent.json', intent)
    verify(drivers, intent['prepared_sha256'])
    assert_same_tools(intent['tools'])
    result['air_started'] = None  # The delegated runner may refuse before launch.
    with (out / 'run.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    result['exit_code'] = process.returncode
    outputs = re.findall(r'^OUTPUT (.+)\s*$', contents(out / 'run.log'), re.M)
    if not outputs:
        result['unconfirmed_runner_output'] = True
    require(len(outputs) == 1, 'Native runner did not return exactly one owned OUTPUT receipt')
    run = Path(outputs[0].strip()).resolve()
    require(run.parent == (ROOT / 'build/cooperation').resolve() and re.fullmatch('[0-9a-f]{10}', run.name)
            and run.name not in before_runs, 'Unexpected or reused native output folder')
    info = read(run / 'run.json')
    require(Path(info['candidate']).resolve() == candidate.resolve(), 'Native result belongs to another candidate')
    result.update(run=str(run), air_started=bool(info.get('pids')), pids=info.get('pids'),
                  run_receipt_sha256=sha(run / 'run.json'))
    try:
        # Preserve diagnostics on a failed control too; input audit errors do
        # not suppress either side's raw PASS/FAIL/DONE and all-module scans.
        suite = SUITES[entry]
        for role in ('host', 'join'):
            logs = [run / (role + '.log'), run / (role + '.stdout.log')]
            logs += sorted((run / 'module-logs' / role).rglob('*.log'))
            text = contents(logs[0])
            pass_lines = re.findall(r'^COOP PASS ' + re.escape(suite) + r' .+$', text, re.M)
            observed = sorted({int(n) for line in pass_lines for n in re.findall(r'\b(?:round|case)=(\d+)\b', line)})
            done = 'COOP EFFECTS DONE ' + suite
            if suite not in ('peer-grip', 'peer-throw-damage'):
                done += ' ' + role
            role_errors = errors_in(logs)
            if any('continuousscene' in name.lower() for name in info['inputs'][role]['modules']):
                if '[ContinuousScene] registered ' not in contents(run / 'module-logs' / role / 'ContinuousScene.log'):
                    role_errors.append(dict(file='ContinuousScene.log', text='Module registration missing'))
            result[role] = dict(passed_checks=len(pass_lines), failed_checks=len(re.findall(r'^COOP FAIL\b', text, re.M)),
                                observed_rounds=observed, expected_rounds=spec['scenarios'],
                                missing_rounds=sorted(set(range(spec['scenarios'])) - set(observed)),
                                done=bool(re.search('^' + re.escape(done) + r'\s*$', text, re.M)),
                                version_loaded='v' + version[1] + ' initialized' in text,
                                connected=(role == 'host' or ('welcome id=' in text and 'unitsync matched' in text)),
                                errors=role_errors, log_hashes={str(p.relative_to(run)): sha(p) for p in logs if p.is_file()})
        result['runtime_input_audit'] = native_inputs(run, info, intent, spec)
        if entry == 'NativeFlightContinuityTestDoc':
            analysis = drivers / 'analysis/native_flight.py'
            require(analysis.is_file(), 'Frozen trajectory analyzer missing')
            with (out / 'flight-analysis.log').open('w', encoding='utf-8') as stream:
                analyzed = subprocess.run([sys.executable, '-B', '-X', 'utf8', str(analysis),
                    '--host-log', str(run / 'host.log'), '--join-log', str(run / 'join.log'),
                    '--output', str(out / 'flight-summary.json')], stdout=stream, stderr=subprocess.STDOUT)
            result['flight_analysis_exit'] = analyzed.returncode
            require(analyzed.returncode == 0 and read(out / 'flight-summary.json')['sampled_flight_checks_passed'],
                    'Independent final-render trajectory checks failed')
        require(process.returncode == 0, 'Native runner failed; a negative control failure remains a failure')
        require(all(result[r]['passed_checks'] > 0 and result[r]['done'] and result[r]['version_loaded']
                    and result[r]['connected'] and not result[r]['errors'] and not result[r]['missing_rounds']
                    for r in ('host', 'join')), 'Native role checks/logs/coverage failed')
        require(read(run / 'registry-result.json')['passed'] is True, 'Native registry result did not pass')
        require(sha(version_source) == intent['version_source_sha256'], 'Version source changed during run')
        result['passed'] = True
    finally:
        clean_native_copies(run, result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    for mode in ('component', 'native'):
        ap = modes.add_parser(mode)
        ap.add_argument('--drivers', type=Path, required=True, help='Compiled prepare.py output')
        ap.add_argument('--output', type=Path, required=True, help='New immediate child of build/m52')
        ap.add_argument('--registry-wait', type=float, default=900)
        if mode == 'component':
            ap.add_argument('--component', choices=tuple(prepare.COMPONENTS), required=True)
        else:
            ap.add_argument('--entry', choices=tuple(SUITES), required=True)
            ap.add_argument('--control', action='store_true', help='Use fixed 574D production with identical driver bytes')
    args = parser.parse_args()
    require(args.registry_wait >= 0, 'Registry wait must be nonnegative')
    drivers, out = (ROOT / args.drivers).resolve(), (ROOT / args.output).resolve()
    require(drivers.parent == (ROOT / 'build/m52').resolve(), 'Drivers must be a frozen build/m52 child')
    require(out.parent == (ROOT / 'build/m52').resolve() and not out.exists(), 'Use a new build/m52 output')
    out.mkdir()
    result = dict(mode=args.mode, passed=False, functional_only=True, performance_qualified=False,
                  installed=False, air_started=False, native_game_pass=False)
    intent = None
    try:
        prepared_hash = sha(drivers / 'prepared.json')
        manifest = verify(drivers, prepared_hash)
        before = installation()
        require(len(before) == EXPECTED_INSTALLATION_FILES, 'Installation inventory changed; expected all 22 files')
        loader = (GAME / 'mods/loader-manifest.txt').read_text(encoding='utf-8-sig')
        isolated = '\n'.join(line for line in loader.splitlines() if '|' in line and not line.startswith('#')) + '\n'
        intent = dict(mode=args.mode, drivers=str(drivers), prepared_sha256=prepared_hash,
                      installation_before=before, installation_count=len(before), tools=runtime_tools(),
                      isolated_loader_manifest=isolated, functional_only=True, performance_qualified=False)
        save(out / 'intent.json', intent)
        (component if args.mode == 'component' else native)(args, drivers, out, manifest, intent, result)
    except (Exception, SystemExit) as error:
        result['passed'] = False
        result['exception'] = str(error)
        (out / 'exception.txt').write_text(traceback.format_exc(), encoding='utf-8')
    finally:
        if intent:
            try:
                after = installation()
                result['installation_after'] = after
                result['installation_changes'] = changes(intent['installation_before'], after)
                verify(drivers, intent['prepared_sha256'])
                assert_same_tools(intent['tools'])
                result['frozen_inputs_unchanged'] = True
                if result['installation_changes']:
                    result['passed'] = False
            except Exception as error:
                result['passed'] = False
                result['final_verification_error'] = str(error)
        result['native_game_pass'] = result['passed'] and args.mode == 'native'
        save(out / 'result.json', result)
    print(json.dumps(dict(output=str(out), passed=result['passed'], functional_only=True,
                          performance_qualified=False, run=result.get('run'), error=result.get('exception')),
                     ensure_ascii=False), flush=True)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
