"""Run one frozen recovery-flight-timing08 build; never compile/deploy.

Keeps original native flight assertions separate from diagnostic completeness.
The existing cooperative runner owns registration, hidden AIR children, memory
guards and process cleanup. This wrapper audits all 22 files before removing
only that runner's own retained copies. No performance qualification is given.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
import traceback

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
ENTRY = 'NativeFlightContinuityTestDoc'
SUITE = 'native-flight-continuity'


def module_at(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# The generic helper imports `prepare`. Bind only during its import, because
# its native_inputs/errors/cleanup functions use shared ROOT/sha/read but its
# own generic verify/native/schema must never be called for this diagnostic.
prepare = module_at(HERE / 'prepare.py', 'flight_diagnostic_prepare')
previous_prepare = sys.modules.get('prepare')
sys.modules['prepare'] = prepare
try:
    helpers = module_at(ROOT / 'experimental/recovery-tests/run.py', 'flight_diagnostic_runtime_helpers')
finally:
    if previous_prepare is None:
        del sys.modules['prepare']
    else:
        sys.modules['prepare'] = previous_prepare

sha, read, save = prepare.sha, prepare.read, prepare.save
require, contents = helpers.require, helpers.contents


def verify(build, prepared_sha):
    require(sha(build / 'prepared.json') == prepared_sha, 'Diagnostic build manifest changed')
    meta = prepare.verify(build)
    require(meta['compiled'] is True and meta['diagnostic_only'] is True, 'A compiled diagnostic build is required')
    require(meta['performance_qualified'] is False and meta['baseline_sha256'] == prepare.BASE_SHA,
            'Unexpected diagnostic scope or baseline')
    return meta


def runtime_tools():
    tools = helpers.runtime_tools()
    for path in [Path(__file__).resolve(), HERE / 'prepare.py', ROOT / 'tools/host_authority/common.py']:
        tools[str(path)] = sha(path)
    return tools


def roles(run, info, version, result):
    for role in ('host', 'join'):
        logs = [run / (role + '.log'), run / (role + '.stdout.log')]
        logs += sorted((run / 'module-logs' / role).rglob('*.log'))
        text = contents(logs[0])
        pass_lines = re.findall(r'^COOP PASS ' + SUITE + r' .+$', text, re.M)
        fail_lines = re.findall(r'^COOP FAIL ' + SUITE + r' .+$', text, re.M)
        observed = sorted({int(n) for line in pass_lines + fail_lines for n in re.findall(r'\bcase=(\d+)\b', line)})
        errors = helpers.errors_in(logs)
        if any('continuousscene' in name.lower() for name in info.get('inputs', {}).get(role, {}).get('modules', {})):
            if '[ContinuousScene] registered ' not in contents(run / 'module-logs' / role / 'ContinuousScene.log'):
                errors.append(dict(file='ContinuousScene.log', text='Module registration missing'))
        result[role] = dict(passed_checks=len(pass_lines), failed_checks=len(fail_lines), observed_rounds=observed,
                            expected_rounds=8, missing_rounds=sorted(set(range(8)) - set(observed)),
                            unexpected_rounds=sorted(set(observed) - set(range(8))),
                            done=bool(re.search(r'^COOP EFFECTS DONE ' + SUITE + ' ' + role + r'\s*$', text, re.M)),
                            version_loaded='v' + version + ' initialized' in text,
                            connected=role == 'host' or ('welcome id=' in text and 'unitsync matched' in text),
                            errors=errors, log_hashes={str(p.relative_to(run)): sha(p) for p in logs if p.is_file()})


def analyze(build, run, out, result):
    # Run BOTH independent analyzers even if original assertions already fail.
    # Their outputs/exit codes are never edited into a passing result.
    for label, script, target in [('flight', 'native_flight.py', 'flight-summary.json'),
                                   ('diagnostic', 'diagnostics.py', 'diagnostic-summary.json')]:
        try:
            path = build / 'analysis' / script
            require(path.is_file(), 'Frozen analyzer missing: ' + script)
            with (out / (label + '-analysis.log')).open('w', encoding='utf-8') as log:
                proc = subprocess.run([sys.executable, '-B', '-X', 'utf8', str(path),
                                       '--host-log', str(run / 'host.log'), '--join-log', str(run / 'join.log'),
                                       '--output', str(out / target)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
            result[label + '_analysis_exit'] = proc.returncode
            if (out / target).is_file():
                data = read(out / target)
                result[label + '_summary_sha256'] = sha(out / target)
                key = 'sampled_flight_checks_passed' if label == 'flight' else 'diagnostic_complete'
                result[label + '_checks_passed'] = proc.returncode == 0 and data.get(key) is True
            else:
                result[label + '_checks_passed'] = False
        except Exception as error:
            result[label + '_checks_passed'] = False
            result[label + '_analysis_exception'] = str(error)


def run(args, build, out, meta, intent, result):
    spec = meta['entries'][ENTRY]
    require(spec['scenarios'] == 8 and spec['land'] == 'random_mane' and spec['seconds'] == 360,
            'Original trial count/land/deadline changed')
    candidate = build / 'RConnectMod.swf'
    driver = build / 'drivers' / ENTRY
    binding = read(driver / 'driver-input.json')
    digest = meta['candidate_sha256']
    require(binding['diagnostic_only'] is True and binding['performance_qualified'] is False,
            'Wrong driver qualification metadata')
    require(binding['candidate_sha256'] == digest == sha(candidate) and binding['entry'] == ENTRY,
            'Driver/candidate binding mismatch')
    require(binding['driver_sha256'] == sha(driver / 'EffectsDriver.swf') and
            binding['harness_sha256'] == sha(driver / 'EffectsHarness.swf') == sha(build / 'EffectsHarness.swf'),
            'Driver/harness hash mismatch')
    require(binding['input_sha256'] == meta['inputs'] and binding['original_input_sha256'] == meta['originals'],
            'Driver and build input lists differ')
    version_source = build / 'src/RConnectMod.as'
    match = re.search(r'VERSION:String\s*=\s*"([^"]+)"', contents(version_source))
    require(match is not None and match[1] == meta['version'] == binding['expected_version'], 'Version binding mismatch')
    version = match[1]
    before_runs = {p.name for p in (ROOT / 'build/cooperation').iterdir()} if (ROOT / 'build/cooperation').is_dir() else set()
    command = [sys.executable, '-B', '-X', 'utf8', str(ROOT / 'tools/run_coop_regression.py'),
               '--candidate', str(candidate), '--effects', '--effects-driver', str(driver),
               '--expected-version', version, '--all-mods', '--land', spec['land'],
               '--seconds', str(spec['seconds']), '--port', str(helpers.test_port()), '--private-desktop',
               '--defer-visible', '--wait-host-world', '--require-exclusive-air',
               '--registry-wait', str(args.registry_wait), '--keep-copies']
    intent.update(command=command, entry=ENTRY, candidate=str(candidate), candidate_sha256=digest,
                  expected_version=version, version_source=str(version_source), version_source_sha256=sha(version_source),
                  driver=dict(binding=binding, driver_sha256=binding['driver_sha256'], harness_sha256=binding['harness_sha256'],
                              binding_sha256=sha(driver / 'driver-input.json')))
    save(out / 'intent.json', intent)
    verify(build, intent['prepared_sha256'])
    helpers.assert_same_tools(intent['tools'])
    require(helpers.installation() == intent['installation_before'], 'Installation changed before launch')
    result['air_started'] = None
    with (out / 'run.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    result['exit_code'] = process.returncode
    outputs = re.findall(r'^OUTPUT (.+)\s*$', contents(out / 'run.log'), re.M)
    require(len(outputs) == 1, 'Existing native runner did not return exactly one owned OUTPUT receipt')
    owned = Path(outputs[0].strip()).resolve()
    require(owned.parent == (ROOT / 'build/cooperation').resolve() and re.fullmatch('[0-9a-f]{10}', owned.name)
            and owned.name not in before_runs, 'Unexpected/reused native output directory')
    info = read(owned / 'run.json')
    require(Path(info['candidate']).resolve() == candidate.resolve(), 'Native receipt belongs to another candidate')
    result.update(run=str(owned), air_started=bool(info.get('pids')), pids=info.get('pids'),
                  run_receipt_sha256=sha(owned / 'run.json'))
    try:
        # Preserve logs and raw verdicts even when an input audit rejects the run.
        roles(owned, info, version, result)
        try:
            result['runtime_input_audit'] = helpers.native_inputs(owned, info, intent, spec)
            result['runtime_inputs_verified'] = True
        except Exception as error:
            result['runtime_inputs_verified'] = False
            result['runtime_input_exception'] = str(error)
        analyze(build, owned, out, result)
        result['registry_result'] = read(owned / 'registry-result.json') if (owned / 'registry-result.json').is_file() else None
        result['native_roles_passed'] = all(result[r]['passed_checks'] > 0 and result[r]['failed_checks'] == 0
            and result[r]['done'] and result[r]['version_loaded'] and result[r]['connected'] and not result[r]['errors']
            and not result[r]['missing_rounds'] and not result[r]['unexpected_rounds'] for r in ('host', 'join'))
        result['diagnostic_data_complete'] = result.get('diagnostic_checks_passed') is True
        result['native_game_pass'] = (process.returncode == 0 and result['runtime_inputs_verified'] and
            result.get('flight_checks_passed') is True and result['native_roles_passed'] and
            result['registry_result'] is not None and result['registry_result'].get('passed') is True)
        require(sha(version_source) == intent['version_source_sha256'], 'Version source changed during run')
    finally:
        # The delegated runner has returned and owns child shutdown. This only
        # removes its freshly validated copies, never another run/user process.
        helpers.clean_native_copies(owned, result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', dest='build_dir', type=Path, required=True, help='Already compiled diagnostic prepare.py output')
    parser.add_argument('--output', type=Path, required=True, help='New direct child of build/m52')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    require(0 <= args.registry_wait <= 3600, 'Invalid registry wait')
    build, out = (ROOT / args.build_dir).resolve(), (ROOT / args.output).resolve()
    require(build.parent == (ROOT / 'build/m52').resolve(), 'Diagnostic build must be a direct build/m52 child')
    require(out.parent == (ROOT / 'build/m52').resolve() and not out.exists(), 'Use a new direct build/m52 output')
    out.mkdir()
    intent = None
    result = dict(mode='native-diagnostic', passed=False, diagnostic_only=True, functional_only=True,
                  performance_qualified=False, native_game_pass=False, diagnostic_data_complete=False,
                  diagnostic_complete=False, installed=False, air_started=False)
    try:
        prepared_hash = sha(build / 'prepared.json')
        meta = verify(build, prepared_hash)
        before = helpers.installation()
        require(len(before) == 22, 'Full installation inventory must contain all 22 files')
        loader = (GAME / 'mods/loader-manifest.txt').read_text(encoding='utf-8-sig')
        isolated = '\n'.join(line for line in loader.splitlines() if '|' in line and not line.startswith('#')) + '\n'
        tools = runtime_tools()
        # Preserve the exact orchestration and imported helper source without
        # changing the already frozen/compiled diagnostic package's inputs.
        snapshots = out / 'runner-inputs'
        snapshots.mkdir()
        for source, name in [(Path(__file__).resolve(), 'run.py'), (Path(helpers.__file__), 'recovery-tests-run.py'),
                             (HERE / 'prepare.py', 'diagnostic-prepare.py')]:
            shutil.copyfile(source, snapshots / name)
            require(sha(snapshots / name) == tools[str(source)], 'Runner source changed while freezing')
        intent = dict(mode='native-diagnostic', build=str(build), prepared_sha256=prepared_hash,
                      installation_before=before, installation_count=22, tools=tools,
                      runner_input_sha256={p.name: sha(p) for p in sorted(snapshots.iterdir())},
                      isolated_loader_manifest=isolated, diagnostic_only=True, functional_only=True,
                      performance_qualified=False)
        save(out / 'intent.json', intent)
        run(args, build, out, meta, intent, result)
    except (Exception, SystemExit) as error:
        result['exception'] = str(error)
        (out / 'exception.txt').write_text(traceback.format_exc(), encoding='utf-8')
    finally:
        if intent is not None:
            try:
                after = helpers.installation()
                result['installation_after'] = after
                result['installation_changes'] = helpers.changes(intent['installation_before'], after)
                require(len(after) == 22 and not result['installation_changes'], 'Installation changed during diagnostic run')
                verify(build, intent['prepared_sha256'])
                helpers.assert_same_tools(intent['tools'])
                for name, digest in intent['runner_input_sha256'].items():
                    require(sha(out / 'runner-inputs' / name) == digest, 'Frozen runtime helper changed')
                result['frozen_inputs_unchanged'] = True
            except Exception as error:
                result['frozen_inputs_unchanged'] = False
                result['final_verification_error'] = str(error)
        verified = result.get('frozen_inputs_unchanged') is True and result.get('runtime_inputs_verified') is True
        result['native_game_pass'] = result['native_game_pass'] and verified and 'exception' not in result
        roles_done = all(result.get(r, {}).get('done') is True and result.get(r, {}).get('version_loaded') is True
                         and not result.get(r, {}).get('missing_rounds', [0]) for r in ('host', 'join'))
        result['diagnostic_complete'] = result['diagnostic_data_complete'] and verified and roles_done and 'exception' not in result
        # A complete diagnosis never makes an original COOP/trajectory failure green.
        result['passed'] = result['native_game_pass'] and result['diagnostic_complete']
        save(out / 'result.json', result)
    print(json.dumps(dict(output=str(out), passed=result['passed'], native_game_pass=result['native_game_pass'],
                          diagnostic_complete=result['diagnostic_complete'], diagnostic_only=True,
                          performance_qualified=False, run=result.get('run'), error=result.get('exception')), ensure_ascii=False), flush=True)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
