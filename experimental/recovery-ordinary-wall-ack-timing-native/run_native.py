"""Isolated ACK timing overlay, exact host02 and unchanged ordinary four-round test."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import inspect
import json
import os
import re
import shutil
import sys
import traceback

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
MASK = ROOT / 'experimental/recovery-ordinary-mask-native/run_native.py'
BUILDER = ROOT / 'experimental/recovery-isolated-overlay/build.py'
PRODUCT = M52 / 'recovery-ordinary-wall-ack-timing-01'
OVERLAY = ROOT / 'experimental/recovery-ordinary-wall-ack-timing/src'
VERSION = '0.2.24-wallacktime1'
PINS = {
    MASK: '0418da528c4330493af2aa7ee4a7703de2baced1b139ab675ea77cb494175f0e',
    MASK.parent / 'README.md': '41ced3bd430eb137ba86d841a37cf3ad7b1d59ca4f26b7739e431d7548935d9e',
    BUILDER: '6c6d3ed0cc659f4a6742eca0a2b56898c7361eff7f4d18900afa6dee5c468cee',
    ROOT / 'tools/run_coop_regression.py': '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
    M52 / 'recovery-ordinary-mask-host-02/pfe.swf': '6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b',
    M52 / 'recovery-ordinary-mask-host-02/runtime-admission.json': '542d59fb6db55cad9891cb2beaf946921290790df7900112f1038995c7f7044d',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_pins(pins):
    for path, digest in pins.items():
        assert sha(path) == digest, str(path)


def preflight():
    check_pins(PINS)
    mask = load(MASK, 'ack_timing_unchanged_mask_admission')
    rooms, wall, _, _, historical = mask.preflight()
    # Never rewrite wall.PRODUCT/CANDIDATE or its historical audit callbacks.
    builder = load(BUILDER, 'ack_timing_existing_overlay_builder')
    meta = builder.verify(PRODUCT)
    compiled = read(PRODUCT / 'compile.json')
    assert Path(meta['base']) == wall.PRODUCT and meta['base_sha256'] == wall.CANDIDATE
    assert Path(meta['overlay']) == OVERLAY and meta['version'] == VERSION
    assert meta['diagnostic_only'] is True and compiled['diagnostic_only'] is True
    assert 0 < len(meta['overlay_inputs']) <= 6
    base = read(wall.PRODUCT / 'prepared.json')
    assert all('src/' + name in base['source'] for name in meta['overlay_inputs'])
    assert compiled['compiled'] is True and compiled['compile_exit'] == 0
    assert compiled['air_started'] is False and compiled['installed'] is False
    assert compiled['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf')
    assert meta['installation_before'] == compiled['installation_before'] == compiled['installation_after'] == historical['current_installation']
    shared, run, driver = wall.driver_modules()
    private = load(HERE / 'private_runner.py', 'ack_timing_private_config_adapter')
    _, private_source = private.adapted_runner()  # Prepare only; never calls main.
    pins = dict(historical['inputs'])
    pins.update({str(p): h for p, h in PINS.items()})
    pins.update(meta['dependencies'])
    for path in (Path(__file__), HERE / 'README.md', HERE / 'private_runner.py',
                 PRODUCT / 'prepared.json', PRODUCT / 'compile.json', PRODUCT / 'source.diff'):
        pins[str(path.resolve())] = sha(path)
    for prefix, values in ((PRODUCT / 'src', meta['source']), (PRODUCT / 'tools', meta['inputs']),
                           (OVERLAY, meta['overlay_inputs']), (PRODUCT, compiled['artifacts'])):
        for rel, digest in values.items():
            pins[str((prefix / rel).resolve())] = digest
    check_pins(pins)
    admission = dict(candidate_sha256=compiled['candidate_sha256'], base_sha256=wall.CANDIDATE,
        prepared_sha256=sha(PRODUCT / 'prepared.json'), compile_sha256=sha(PRODUCT / 'compile.json'),
        native_host=historical['native_host'], current_installation=historical['current_installation'],
        historical_build_installation=historical['historical_build_installation'], inputs=pins,
        version=VERSION, diagnostic_only=True, driver_recompiled=False,
        private_runner_source_sha256=hashlib.sha256(private_source.encode('utf-8')).hexdigest())
    return wall, shared, run, driver, admission, private_source


def execute(out, wait, wall, shared, run, meta, admission):
    run.SUITES[wall.ENTRY] = 'large-wall-surfaces'
    _, source, scope = shared.adapted_native(run)
    anchor = "str(ROOT / 'tools/run_coop_regression.py')"
    assert source.count(anchor) == 1
    source = source.replace(anchor, '_ack_private_runner', 1)
    scope.update(_wall_candidate=PRODUCT, _wall_binding=shared.bind,
        _wall_host=Path(admission['native_host']['receipt_path']).parent,
        _wall_host_evidence=dict(admission['native_host'], installation=admission['current_installation']),
        _ack_private_runner=str(HERE / 'private_runner.py'))
    # Only extend the *expected* private config by this exact one field. Real
    # bytes, preserved hashes, all other settings and every input gate remain.
    input_source = inspect.getsource(run.native_inputs)
    anchor = "                require(cfg == expected_cfg, role + ' unexpected generated test config')"
    assert input_source.count(anchor) == 1
    input_source = input_source.replace(anchor,
        "                expected_cfg['wallAckTiming'] = '1'\n" + anchor, 1)
    input_scope = dict(run.__dict__)
    exec(compile(input_source, '<ack-timing exact extra-config expectation>', 'exec'), input_scope)
    original_inputs = input_scope['native_inputs']

    def native_inputs(folder, info, intent, spec):
        assert intent['installation_before'] == admission['current_installation']
        adjusted = dict(intent, installation_before=dict(intent['installation_before']))
        adjusted['installation_before']['pfe.swf'] = admission['native_host']['candidate_sha256']
        value = original_inputs(folder, info, adjusted, spec)
        for role in ('host', 'join'):
            value[role]['pfe.swf']['installed'] = intent['installation_before']['pfe.swf']
            value[role]['pfe.swf']['override'] = 'Exact admitted isolated host02, ordinaryMaskBounds fix only'
        return value

    run.native_inputs = native_inputs
    scope['native_inputs'] = native_inputs
    exec(compile(source, '<ack-timing original five-anchor adapter plus runner path>', 'exec'), scope)
    run.native = scope['native']
    run.installation = lambda: wall.actual_installation(admission['historical_build_installation'])
    original_tools = run.runtime_tools
    run.runtime_tools = lambda: dict(original_tools(), **admission['inputs'])
    previous = sys.argv
    try:
        sys.argv = [str(__file__), 'native', '--drivers', str(wall.DRIVERS), '--output', str(out),
                    '--entry', wall.ENTRY, '--registry-wait', str(wait)]
        return run.main(), source, input_source
    finally:
        sys.argv = previous


def collect(out, framework, wall, driver, admission):
    folder = Path(framework['run']).resolve()
    assert folder.parent == (ROOT / 'build/cooperation').resolve() and re.fullmatch(r'[0-9a-f]{10}', folder.name)
    actual = read(folder / 'run.json')
    assert actual['sha256'] == admission['candidate_sha256']
    copied = []
    missing = []
    aborts = []
    output_errors = []
    for role in ('host', 'join'):
        assert actual['inputs'][role]['production'] == admission['candidate_sha256']
        assert actual['inputs'][role]['game'] == admission['native_host']['candidate_sha256']
        appid = 'pfe-modsettings-rconnect-coop-' + role + '-' + folder.name
        storage = Path(os.environ['APPDATA']) / appid / 'Local Store'
        abort = storage / 'wall-ack-timing/abort.json'
        if abort.exists():
            row = dict(role=role, source=str(abort))
            try:
                assert abort.is_file() and abort.stat().st_size <= 8 * 1024**2
                target = out / 'wall-ack-timing' / role / 'abort.json'
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(abort, target)
                row.update(file=str(target.relative_to(out)), sha256=sha(target))
            except Exception as exc:
                row['copy_error'] = str(exc)
            aborts.append(row)
        logs = [folder / (role + '.log'), folder / (role + '.stdout.log')]
        logs += sorted((folder / 'module-logs' / role).rglob('*.log'))
        for path in logs:
            if path.is_file():
                for n, line in enumerate(path.read_text(encoding='utf-8-sig', errors='replace').splitlines(), 1):
                    if 'WALL ACK TIMING OUTPUT FAILED' in line:
                        output_errors.append(dict(role=role, file=str(path.relative_to(folder)), line=n, text=line[:4096]))
        for n in range(4):
            for suffix in ('proof.json', 'before-native.png', 'after-native.png', 'before-display.png', 'after-display.png'):
                source = storage / 'large-wall-proof' / f'round-{n}-{suffix}'
                if source.is_file():
                    assert source.stat().st_size <= 32 * 1024**2
                    target = out / 'wall-proof' / role / source.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
            source = storage / 'wall-ack-timing' / f'round-{n}.json'
            if not source.is_file():
                missing.append(dict(role=role, round=n, reason='missing'))
                continue
            try:
                assert source.stat().st_size <= 8 * 1024**2, 'Oversized bounded timing evidence'
                target = out / 'wall-ack-timing' / role / source.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                data = read(target)
                assert data['kind'] == 'ordinary-wall-ack-timing-v1'
                assert data['appId'] == appid and data['role'] == role and data['round'] == n
                ready = (data.get('complete') is True and data.get('termination') == 'analyze'
                    and data.get('bothSampled') is True and data.get('overflow') is False
                    and type(data.get('dropped')) is int and data['dropped'] == 0
                    and type(data.get('faultCount')) is int and data['faultCount'] == 0
                    and data.get('faults') == [])
                copied.append(dict(role=role, round=n, file=str(target.relative_to(out)), sha256=sha(target),
                    sample_ready=ready, complete=data.get('complete'), termination=data.get('termination'),
                    bothSampled=data.get('bothSampled'), overflow=data.get('overflow'),
                    dropped=data.get('dropped'), faultCount=data.get('faultCount'), eventCount=data.get('eventCount')))
            except Exception as exc:
                # An invalid diagnostic never suppresses the original pixel
                # analyzer or rewrites its functional result below.
                missing.append(dict(role=role, round=n, reason='invalid diagnostic', error=str(exc)))
    # Exact original pixel analyzer; do not substitute timing data for pixels.
    analyzer = wall.DRIVERS / 'inputs/large-wall/verify_results.py'
    assert sha(analyzer) == driver['inputs']['inputs/large-wall/verify_results.py']
    measured = load(analyzer, 'ack_timing_original_pixel_analyzer').analyze(
        out / 'wall-proof', {role: folder / (role + '.log') for role in ('host', 'join')})
    save(out / 'wall-surface-analysis.json', measured)
    return dict(files=copied, missing=missing, aborts=aborts, diagnostic_output_errors=output_errors,
        diagnostic_evidence_complete=len(copied) == 8 and not missing,
        diagnostic_samples_ready=bool(len(copied) == 8 and not missing and not aborts and not output_errors
                                     and all(row['sample_ready'] for row in copied)),
        pixel_analysis_sha256=sha(out / 'wall-surface-analysis.json'), pixel_passed=measured['passed'],
        source_analyzer_sha256=sha(analyzer), native_run=str(folder))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.check:
        assert not args.output
        *_, admission, _ = preflight()
        print(json.dumps(dict(checked=True, candidate_sha256=admission['candidate_sha256'],
            host_sha256=admission['native_host']['candidate_sha256'], diagnostic_only=True,
            air_started=False, compiled=False, installed=False)))
        return 0
    assert args.output
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-ack-timing-native-\d{2,}', out.name)
    assert not out.exists(), 'Use a fresh output; preserve all prior evidence'
    result = dict(passed=False, functional_pass=False, diagnostic_only=True, diagnostic_evidence_complete=False,
        diagnostic_samples_ready=False,
        performance_qualified=False, gameplay_qualified=False, installed=False, driver_recompiled=False)
    code = 1
    try:
        wall, shared, run, driver, admission, private_source = preflight()
        result['admission'] = admission
        code, source, input_source = execute(out, args.registry_wait, wall, shared, run, driver, admission)
        (out / 'framework-adapted-native.py').write_text(source, encoding='utf-8')
        (out / 'framework-config-input-audit.py').write_text(input_source, encoding='utf-8')
        (out / 'private-run-registered.py').write_text(private_source, encoding='utf-8')
        framework = read(out / 'result.json')
        result.update(framework_sha256=sha(out / 'result.json'), framework_passed=framework['passed'], run=framework.get('run'))
        if framework.get('run'):
            result.update(collect(out, framework, wall, driver, admission))
        result['functional_pass'] = bool(code == 0 and framework['passed'] and result.get('pixel_passed'))
        result['passed'] = bool(result['functional_pass'] and result['diagnostic_samples_ready'])
        code = 0 if result['passed'] else 1
    except (Exception, SystemExit) as exc:
        result.update(passed=False, error_type=type(exc).__name__, error=str(exc), traceback=traceback.format_exc())
        code = 1
    finally:
        try:
            *_, after, _ = preflight()
            if 'admission' in locals():
                assert after == admission
                check_pins(admission['inputs'])
            result.update(inputs_unchanged=True, installation_after=after['current_installation'])
        except Exception as exc:
            result.update(passed=False, final_verification_error=str(exc))
            code = 1
        out.mkdir(exist_ok=True)
        save(out / 'ack-timing-result.json', result)
    print(json.dumps(dict(passed=result['passed'], functional_pass=result['functional_pass'],
        diagnostic_evidence_complete=result['diagnostic_evidence_complete'],
        diagnostic_samples_ready=result['diagnostic_samples_ready'], output=str(out),
        run=result.get('run'), performance_qualified=False, error=result.get('error')), ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
