"""Off/on socket trial on one header51 host; original four-round test unchanged."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import inspect
import json
import os
import re
import sys
import traceback

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
ACK = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/run_native.py'
BUILDER = ROOT / 'experimental/recovery-isolated-overlay/build.py'
PRODUCT = M52 / 'recovery-ordinary-socket-nodelay-02'
OVERLAY = ROOT / 'experimental/recovery-ordinary-socket-nodelay/src'
VERSION = '0.2.24-sockettrial1'
CANDIDATE = '3b6df6d9a8189001e369ecdfae4905dcb303e05614dd9ef3fc9fa5d31d681b03'
PINS = {
    ACK: '720b082c12b3a14a7abcc8388ff0e2ca83dc4ec8ff0ede82663c10bd43c6176b',
    ACK.parent / 'private_runner.py': 'ccf4941f217ca1b2054ba5cb0e2552a99e95b98da5bbdddcce0f37254cfea2fe',
    ACK.parent / 'README.md': 'b8bd4bcf3383437778c7b66f1019fb1c406f5ee1f396851e4e20209c15fe5370',
    BUILDER: '6c6d3ed0cc659f4a6742eca0a2b56898c7361eff7f4d18900afa6dee5c468cee',
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


def preflight(mode):
    assert mode in ('off', 'on')
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    ack = load(ACK, 'socket_unchanged_ack_admission')
    wall, shared, run, driver, historical, _ = ack.preflight()
    # Historical ACK/product/host checks remain real; no old globals or audit
    # callbacks are retargeted to the new input.
    builder = load(BUILDER, 'socket_existing_overlay_builder')
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
    assert compiled['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf') == CANDIDATE
    with (PRODUCT / 'RConnectMod.swf').open('rb') as stream:
        product_header = stream.read(4)
    assert product_header[:3] in (b'FWS', b'CWS', b'ZWS') and product_header[3] == 38
    assert meta['installation_before'] == compiled['installation_before'] == compiled['installation_after'] == historical['current_installation']
    host = load(HERE / 'prepare_host.py', 'socket_header_proof').verify()
    host_dir = M52 / 'recovery-ordinary-socket-host-01'
    assert host['installation_before'] == historical['current_installation']
    private = load(HERE / 'private_runner.py', 'socket_private_runner')
    _, private_source = private.adapted_runner(mode)
    pins = dict(historical['inputs'])
    pins.update({str(p): h for p, h in PINS.items()})
    pins.update(meta['dependencies'])
    pins.update(host['inputs'])
    for path in (Path(__file__), HERE / 'README.md', HERE / 'private_runner.py', HERE / 'prepare_host.py',
                 PRODUCT / 'prepared.json', PRODUCT / 'compile.json', PRODUCT / 'source.diff',
                 host_dir / 'pfe.swf', host_dir / 'receipt.json'):
        pins[str(path.resolve())] = sha(path)
    for prefix, values in ((PRODUCT / 'src', meta['source']), (PRODUCT / 'tools', meta['inputs']),
                           (OVERLAY, meta['overlay_inputs']), (PRODUCT, compiled['artifacts'])):
        for rel, digest in values.items():
            pins[str((prefix / rel).resolve())] = digest
    ack.check_pins(pins)
    admission = dict(candidate_sha256=CANDIDATE, base_sha256=wall.CANDIDATE,
        prepared_sha256=sha(PRODUCT / 'prepared.json'), compile_sha256=sha(PRODUCT / 'compile.json'),
        native_host=dict(candidate_sha256=host['candidate_sha256'], receipt_path=str(host_dir / 'receipt.json'),
            receipt_sha256=sha(host_dir / 'receipt.json'), scope=host['scope'],
            header_proof_passed=True, runtime_compatibility_verified=False,
            base_candidate_sha256=host['base_sha256']),
        current_installation=historical['current_installation'],
        historical_build_installation=historical['historical_build_installation'], inputs=pins,
        version=VERSION, mode=mode, product_swf_version=38, diagnostic_only=True, driver_recompiled=False,
        private_runner_source_sha256=hashlib.sha256(private_source.encode('utf-8')).hexdigest())
    return ack, wall, shared, run, driver, admission, private_source


def descriptor_proof(folder, role):
    appid = 'pfe-modsettings-rconnect-coop-' + role + '-' + folder.name
    original = '''<?xml version="1.0" encoding="utf-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
<id>''' + appid + '''</id><versionNumber>1.0</versionNumber><filename>RConnectTest</filename>
<initialWindow><content>pfe.swf</content><visible>false</visible><renderMode>direct</renderMode></initialWindow>
</application>'''
    old = original.replace('\n', os.linesep).encode('utf-8')
    expected = old.replace(b'application/30.0', b'application/51.0', 1)
    actual = folder / 'descriptors' / (role + '.xml')
    assert actual.read_bytes() == expected, role + ' descriptor differs beyond namespace'
    return dict(role=role, appId=appid, sha256=sha(actual), original_generated_sha256=hashlib.sha256(old).hexdigest(),
        namespace_before='30.0', namespace_after='51.0', only_namespace_changed=True, content='pfe.swf')


def execute(out, wait, mode, wall, shared, run, admission):
    run.SUITES[wall.ENTRY] = 'large-wall-surfaces'
    _, source, scope = shared.adapted_native(run)
    anchor = "str(ROOT / 'tools/run_coop_regression.py')"
    assert source.count(anchor) == 1
    source = source.replace(anchor, '_socket_private_runner', 1)
    anchor = "    command += ['--game-candidate', str(_wall_host / 'pfe.swf')]"
    assert source.count(anchor) == 1
    source = source.replace(anchor, anchor + "\n    command += ['--socket-mode', _socket_mode]", 1)
    scope.update(_wall_candidate=PRODUCT, _wall_binding=shared.bind,
        _wall_host=Path(admission['native_host']['receipt_path']).parent,
        _wall_host_evidence=dict(admission['native_host'], installation=admission['current_installation']),
        _socket_private_runner=str(HERE / 'private_runner.py'), _socket_mode=mode)
    input_source = inspect.getsource(run.native_inputs)
    anchor = "                require(cfg == expected_cfg, role + ' unexpected generated test config')"
    assert input_source.count(anchor) == 1
    input_source = input_source.replace(anchor,
        "                expected_cfg['wallAckTiming'] = '1'\n"
        "                expected_cfg['socketNoDelayTrial'] = _socket_mode\n" + anchor, 1)
    input_scope = dict(run.__dict__, _socket_mode=mode)
    exec(compile(input_source, '<socket trial exact extra-config expectation>', 'exec'), input_scope)
    original_inputs = input_scope['native_inputs']

    def native_inputs(folder, info, intent, spec):
        assert intent['installation_before'] == admission['current_installation']
        adjusted = dict(intent, installation_before=dict(intent['installation_before']))
        adjusted['installation_before']['pfe.swf'] = admission['native_host']['candidate_sha256']
        value = original_inputs(folder, info, adjusted, spec)
        for role in ('host', 'join'):
            descriptor_proof(folder, role)
            value[role]['pfe.swf']['installed'] = intent['installation_before']['pfe.swf']
            value[role]['pfe.swf']['override'] = 'Isolated FWS header41-to51, all other bytes equal admitted host02'
        return value

    run.native_inputs = native_inputs
    scope['native_inputs'] = native_inputs
    exec(compile(source, '<socket trial original adapter plus private wrapper>', 'exec'), scope)
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


def socket_proof(out, collection, mode):
    rows, failures, stable = [], [], {}
    expected = mode == 'on'
    for item in collection['files']:
        try:
            data = read(out / item['file'])
            proof = data['socketNoDelayTrial']
            role, n = item['role'], item['round']
            assert proof['requested'] == proof['mode'] == mode
            assert proof['enabled'] is True and proof['expected'] is expected and proof['qualified'] is True
            assert type(proof['connectionCount']) is int and proof['connectionCount'] == 1
            assert len(proof['connections']) == 1
            conn = proof['connections'][0]
            assert type(conn['connection']) is int and conn['connection'] == 1
            assert conn['role'] == role and conn['direction'] == ('accept' if role == 'host' else 'connect')
            for name in ('sameSocket', 'connectedAtSet', 'setSucceeded', 'readSucceeded', 'success',
                         'connectedAtCheck', 'readSucceededAtCheck', 'qualified'):
                assert conn[name] is True, name
            assert conn['expected'] is expected and conn['readback'] is expected and conn['readbackAtCheck'] is expected
            assert not conn.get('error') and not conn.get('checkError')
            for name in ('localPort', 'remotePort'):
                assert type(conn[name]) is int and 0 < conn[name] < 65536
            for name in ('localAddress', 'remoteAddress'):
                assert conn[name] == '127.0.0.1'
            for name in ('at', 'wall', 'checkedAt', 'checkedWall'):
                assert type(conn[name]) in (int, float) and conn[name] >= 0
            assert conn['checkedAt'] >= conn['at'] and conn['checkedWall'] >= conn['wall']
            identity = {key: conn[key] for key in ('connection', 'role', 'direction', 'linkIdAtSet', 'at', 'wall',
                'localAddress', 'localPort', 'remoteAddress', 'remotePort')}
            if role in stable:
                assert identity == stable[role], 'Socket changed between rounds'
            else:
                stable[role] = identity
            rows.append(dict(role=role, round=n, file=item['file'], proof=proof))
        except Exception as exc:
            failures.append(dict(role=item['role'], round=item['round'], error=str(exc)))
    if len(rows) == 8 and not failures:
        h, j = stable['host'], stable['join']
        if not (h['localPort'] == j['remotePort'] and h['remotePort'] == j['localPort']):
            failures.append(dict(error='Host/join socket endpoint pairs disagree'))
    return dict(socket_mode=mode, socket_verified=bool(len(rows) == 8 and not failures),
        socket_evidence=rows, socket_failures=failures, socket_endpoints=stable)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('off', 'on'), required=True)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.check:
        assert not args.output
        *_, admission, _ = preflight(args.mode)
        print(json.dumps(dict(checked=True, mode=args.mode, candidate_sha256=admission['candidate_sha256'],
            host_sha256=admission['native_host']['candidate_sha256'], air_started=False, compiled=False, installed=False)))
        return 0
    assert args.output
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and re.fullmatch('recovery-ordinary-socket-' + args.mode + r'-native-\d{2,}', out.name)
    assert not out.exists(), 'Preserve earlier results; use a fresh output'
    result = dict(passed=False, functional_pass=False, diagnostic_only=True, diagnostic_evidence_complete=False,
        diagnostic_samples_ready=False, socket_mode=args.mode, socket_verified=False,
        performance_qualified=False, gameplay_qualified=False, installed=False, driver_recompiled=False)
    code = 1
    try:
        ack, wall, shared, run, driver, admission, private_source = preflight(args.mode)
        result['admission'] = admission
        code, source, input_source = execute(out, args.registry_wait, args.mode, wall, shared, run, admission)
        (out / 'framework-adapted-native.py').write_text(source, encoding='utf-8')
        (out / 'framework-config-input-audit.py').write_text(input_source, encoding='utf-8')
        (out / 'private-run-registered.py').write_text(private_source, encoding='utf-8')
        framework = read(out / 'result.json')
        result.update(framework_sha256=sha(out / 'result.json'), framework_passed=framework['passed'], run=framework.get('run'))
        if framework.get('run'):
            # Old collector sees the true new host and candidate hashes. Its
            # original pixel analyzer and eight timing-file checks are unchanged.
            collected = ack.collect(out, framework, wall, driver, admission)
            result.update(collected)
            result['timing_samples_ready'] = collected['diagnostic_samples_ready']
            result.update(socket_proof(out, collected, args.mode))
            result['diagnostic_samples_ready'] = bool(collected['diagnostic_samples_ready'] and result['socket_verified'])
            folder = Path(framework['run']).resolve()
            result['descriptors'] = [descriptor_proof(folder, role) for role in ('host', 'join')]
            actual = read(folder / 'run.json')
            result['comparison_variables'] = dict(mode=args.mode, runID=folder.name, port=actual['port'],
                candidate_sha256=CANDIDATE, host_sha256=admission['native_host']['candidate_sha256'],
                namespace='51.0', host_swf_version=51, product_swf_version=38,
                tickMs=50, seconds=600, wallAckTiming='1')
        result['functional_pass'] = bool(code == 0 and framework['passed'] and result.get('pixel_passed'))
        result['passed'] = bool(result['functional_pass'] and result['diagnostic_samples_ready'])
        code = 0 if result['passed'] else 1
    except (Exception, SystemExit) as exc:
        result.update(passed=False, error_type=type(exc).__name__, error=str(exc), traceback=traceback.format_exc())
        code = 1
    finally:
        try:
            *_, after, _ = preflight(args.mode)
            if 'admission' in locals():
                assert after == admission
            result.update(inputs_unchanged=True, installation_after=after['current_installation'])
        except Exception as exc:
            result.update(passed=False, diagnostic_samples_ready=False, final_verification_error=str(exc))
            code = 1
        out.mkdir(exist_ok=True)
        save(out / 'ack-timing-result.json', result)
    print(json.dumps(dict(passed=result['passed'], functional_pass=result['functional_pass'],
        diagnostic_samples_ready=result['diagnostic_samples_ready'], socket_verified=result['socket_verified'],
        output=str(out), run=result.get('run'), error=result.get('error')), ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
