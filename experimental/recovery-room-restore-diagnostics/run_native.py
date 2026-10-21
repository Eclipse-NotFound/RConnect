"""Run the exact room-restore diagnostic via the unchanged scene12 framework.

Only its candidate audit is adapted. Exit 0 means complete diagnostic evidence,
never gameplay/performance qualification. No build or installation operation.
"""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import re
import shutil
import sys
import traceback

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
CANDIDATE = M52 / 'recovery-room-restore-diag-01'
DRIVERS = M52 / 'room-travel-driver-12'
HOST = M52 / 'recovery-native-travel-host-01'
CANDIDATE_SHA = 'b9447b3dd95fe1930779c8646695d1ad43cd371d4deb607c86e8a27cb5bdcb90'
HOST_SHA = 'e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c'
DRIVER_MANIFEST_SHA = '3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784'
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(HERE))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


diagnostic_prepare = load('restore_diagnostic_prepare', HERE / 'prepare.py')
framework = load('restore_native_framework', ROOT / 'tools/validation/run_room_travel_timing.py')
sha, read, save = framework.sha, framework.read, framework.save


def audit(candidate):
    assert candidate.resolve() == CANDIDATE.resolve(), 'Only the pinned diagnostic is accepted'
    meta = diagnostic_prepare.verify(candidate)
    assert meta['kind'] == 'isolated-room-restore-diagnostic' and meta['diagnostic_only'] is True
    assert meta['compiled'] is True and meta['gameplay_qualified'] is False and meta['performance_qualified'] is False
    assert meta['sha256'] == meta['candidate_sha256'] == sha(candidate / 'RConnectMod.swf') == CANDIDATE_SHA
    assert meta['scene_driver']['manifest_sha256'] == DRIVER_MANIFEST_SHA
    return meta


def fingerprints(validate=True):
    meta = read(CANDIDATE / 'prepared.json')
    driver = read(DRIVERS / 'prepared.json')
    driver_files = {name: sha(DRIVERS / name) for name in driver['files']}
    host = read(HOST / 'prepared.json')
    host_files = {name: sha(HOST / 'sources' / name) for name in host['source_inputs']}
    names = [Path(__file__), HERE / 'prepare.py', HERE / 'generate.py', Path(framework.__file__),
        ROOT / 'tools/run_coop_regression.py', ROOT / 'tools/host_authority/common.py',
        *[ROOT / 'tools/validation' / name for name in ('check_coop_bundle.py',
            'audit_room_entry_candidate.py', 'prepare_security_terminals.py', 'run_security_terminals.py',
            'run_a22_motion_checks.py', 'runtime_memory.py', 'native_runtime_assets.py', 'air_test_inventory.py')],
        ROOT.parent / 'ModLoader/tools/test_registry.py', ROOT.parent / 'ModLoader/tools/air_test_process.py',
        ROOT.parents[1] / 'adl64.exe']
    installed = framework.installation()
    actual = dict(candidate=dict(manifest_sha256=sha(CANDIDATE / 'prepared.json'), sha256=sha(CANDIDATE / 'RConnectMod.swf'),
                source=diagnostic_prepare.inventory(CANDIDATE / 'src'), inputs=diagnostic_prepare.inventory(CANDIDATE / 'tools'),
                diagnostic_inputs=diagnostic_prepare.inventory(CANDIDATE / 'diagnostic-inputs')),
        driver=dict(manifest_sha256=sha(DRIVERS / 'prepared.json'), files=driver_files),
        host=dict(manifest_sha256=sha(HOST / 'prepared.json'), sha256=sha(HOST / 'pfe.swf'),
                  native_input_sha256=sha(HOST / 'native-input.json'), sources=host_files),
        tools={str(p.resolve()): sha(p) for p in names}, installation=installed)
    if validate:
        audit(CANDIDATE)
        assert actual['driver']['manifest_sha256'] == DRIVER_MANIFEST_SHA
        assert not driver.get('diagnostic_only'), 'Use the unchanged ordinary scene12 driver'
        assert driver_files == driver['files']
        assert actual['host']['sha256'] == host['candidate_sha256'] == HOST_SHA
        assert host_files == host['source_inputs']
        assert len(installed) == 22, 'Expected all 22 installation inputs'
    return actual


def collect_rows(out, raw, old_runs):
    run_id = raw.get('run') if raw else None
    if not run_id and (out / 'runner.log').is_file():
        found = re.findall(r'^OUTPUT .*?([0-9a-f]{10})\s*$', (out / 'runner.log').read_text(encoding='utf-8', errors='replace'), re.M)
        if len(found) == 1: run_id = found[0]
    if not run_id: return dict(run=None, rows={}, parse_errors=[], logs={})
    assert re.fullmatch('[0-9a-f]{10}', run_id) and run_id not in old_runs, 'Unexpected/reused native receipt'
    run = ROOT / 'build/cooperation' / run_id
    rows, errors, logs = {}, [], {}
    for role in ('host', 'join'):
        path = run / (role + '.log')
        rows[role] = []
        if not path.is_file(): continue
        logs[role] = sha(path)
        for number, line in enumerate(path.read_text(encoding='utf-8-sig', errors='replace').splitlines(), 1):
            if not line.startswith('RConnectRestoreCost '): continue
            try:
                value = json.loads(line[len('RConnectRestoreCost '):])
                if not isinstance(value, dict): raise ValueError('Row must be an object')
                rows[role].append(value)
            except ValueError as error:
                errors.append(dict(role=role, line=number, text=line, error=str(error)))
    return dict(run=run_id, rows=rows, parse_errors=errors, logs=logs)


def rows_complete(evidence):
    if evidence['parse_errors']: return False
    for role in ('host', 'join'):
        rows = evidence['rows'].get(role, [])
        if len(rows) != 3: return False
        for row in rows:
            frames = row.get('frames')
            if not (row.get('role') == role and row.get('diagnosticOnly') is True
                    and row.get('performanceQualified') is False
                    and row.get('reason') == 'three-complete-enter-frames'
                    and isinstance(frames, list) and len(frames) == 3
                    and all(isinstance(frame, dict) for frame in frames)
                    and row.get('scopeMismatches') == 0 and row.get('openScopes') == {}): return False
    return True


def run(out, registry_wait):
    assert out.parent == M52 and not out.exists(), 'Use a fresh immediate build/m52 output'
    assert registry_wait >= 0
    old_runs = {p.name for p in (ROOT / 'build/cooperation').iterdir()}
    before = after = raw = None
    result = dict(diagnostic_only=True, passed=False, gameplay_qualified=False, performance_qualified=False,
                  installed=False, diagnostic_checks_passed=False)
    old_argv, old_audit = sys.argv[:], framework.audit
    console = io.StringIO()
    try:
        before = fingerprints()
        # These are the only framework substitutions. Its original host,
        # scene12, 600-second, all-mod, registry, memory and result checks run.
        framework.audit = audit
        sys.argv = [str(Path(framework.__file__)), '--candidate', str(CANDIDATE), '--drivers', str(DRIVERS),
                    '--output', str(out), '--game-candidate', str(HOST), '--scenario', 'scene',
                    '--registry-wait', str(registry_wait)]
        with contextlib.redirect_stdout(console): framework.main()
    except (Exception, SystemExit) as error:
        result['framework_exception'] = type(error).__name__ + ': ' + str(error)
        result['traceback'] = traceback.format_exc()
    finally:
        framework.audit, sys.argv = old_audit, old_argv
        out.mkdir(exist_ok=True)
        (out / 'framework-console.log').write_text(console.getvalue(), encoding='utf-8')
        try:
            # Keep the observed changed hashes too; do not erase the after
            # snapshot merely because it no longer matches the pinned input.
            after = fingerprints(validate=False)
            result['inputs_unchanged'] = before is not None and after == before
            result['input_groups_changed'] = [k for k in after if before is None or before.get(k) != after[k]]
        except Exception as error:
            result['inputs_unchanged'] = False
            result['final_verification_error'] = type(error).__name__ + ': ' + str(error)
        save(out / 'diagnostic-inputs-before.json', before)
        save(out / 'diagnostic-inputs-after.json', after)
        try:
            if (out / 'result.json').is_file():
                # Preserve exact bytes, including an original failed result.
                shutil.copyfile(out / 'result.json', out / 'framework-result.json')
                result['framework_result_sha256'] = sha(out / 'framework-result.json')
                raw = read(out / 'framework-result.json')
                result['framework_checks_passed'] = raw.get('passed') is True
            evidence = collect_rows(out, raw, old_runs)
            result.update(evidence)
            result['restore_rows_complete'] = rows_complete(evidence)
        except Exception as error:
            result['evidence_error'] = type(error).__name__ + ': ' + str(error)
        result['diagnostic_checks_passed'] = bool(result.get('framework_checks_passed')
            and result.get('inputs_unchanged') and result.get('restore_rows_complete')
            and 'framework_exception' not in result and 'evidence_error' not in result)
        save(out / 'diagnostic-result.json', result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('rows','logs','traceback')}, ensure_ascii=False))
    return 0 if result['diagnostic_checks_passed'] else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    return run((ROOT / args.output).resolve(), args.registry_wait)


if __name__ == '__main__': raise SystemExit(main())
