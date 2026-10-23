"""Thin receive-pump candidate binding with unchanged native four-round checks."""
from pathlib import Path
import hashlib
import importlib.util
import inspect
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'experimental/recovery-ordinary-wall-rx-native/run_native.py'
PINS = {
    OLD: 'f8b9b248ba7f819a32e03e9850b2ce5272b7a5a600c98f744e2e6e9a84c06f32',
    OLD.parent / 'private_runner.py': '94c3c51cbb42c0e1891303bf267978fb0cd8908efb451eee58697a6333418b29',
    OLD.parent / 'README.md': '3bb9eab1569efa237259172b971bb16e6c939cbff1657e5d5964964d0a8bf395',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def prepared_source(old):
    source = old.prepared_source()
    changes = [
        ("PRODUCT = M52 / 'recovery-ordinary-wall-rx-timing-01'", "PRODUCT = M52 / 'recovery-ordinary-receive-pump-01'"),
        ("OVERLAY = ROOT / 'experimental/recovery-ordinary-wall-rx-timing/src'", "OVERLAY = ROOT / 'experimental/recovery-ordinary-receive-pump/src'"),
        ("VERSION = '0.2.24-wallrxtime1'", "VERSION = '0.2.24-receivepump1'"),
        ("r'recovery-ordinary-wall-rx-native-\\d{2,}'", "r'recovery-ordinary-receive-pump-native-\\d{2,}'"),
    ]
    for before, after in changes:
        assert source.count(before) == 1 and after not in source, before
        source = source.replace(before, after, 1)
    return source


def receiver_qualification(out, collection, scalar_check):
    checked = scalar_check(out, collection)
    coverage, failures = [], []
    for row in collection['files']:
        try:
            role, n = row['role'], row['round']
            data = json.loads((out / row['file']).read_text(encoding='utf-8-sig'))
            proof = json.loads((out / 'wall-proof' / role / f'round-{n}-proof.json').read_text(encoding='utf-8-sig'))
            source_role = 'host' if n in (0, 2) else 'join'
            assert proof['source'] is (role == source_role)
            expected = (set() if source_role == 'host' else {'rx-report'}) if role == 'host' else (
                {'rx-paint'} if source_role == 'host' else {'rx-paint', 'rx-ack'})
            actual = {e['kind'] for e in data['events'] if e.get('kind', '').startswith('rx-')}
            assert actual == expected, (actual, expected)
            assert type(data['rxProbeCalls']) is int and data['rxProbeCalls'] > 0
            coverage.append(dict(role=role, round=n, source_role=source_role,
                required_rx_kinds=sorted(expected), actual_rx_kinds=sorted(actual)))
        except Exception as exc:
            failures.append(dict(role=row['role'], round=row['round'], error=str(exc)))
    pairs = {(row['role'], row['round']) for row in coverage}
    ready = checked['rx_samples_ready'] and not failures and len(coverage) == 8 and pairs == {
        (role, n) for role in ('host', 'join') for n in range(4)}
    return dict(rx_samples_ready=bool(ready), rx_evidence_complete=checked['rx_evidence_complete'],
                rx_scalar_validation=checked, rx_direction_coverage=coverage, rx_direction_failures=failures)


def pump_qualification(out, collection):
    rows, failures = [], []
    totals = {role: dict(calls=0, readCalls=0, readBytes=0, relatedTickPollEvents=0) for role in ('host', 'join')}
    for item in collection['files']:
        try:
            data = json.loads((out / item['file']).read_text(encoding='utf-8-sig'))
            for name in ('rxPollCalls', 'rxPollReadCalls', 'rxPollReadBytes'):
                assert type(data[name]) is int and data[name] >= 0, name
            assert data['rxPollReadCalls'] <= data['rxPollCalls']
            counts = {'socket-data': 0, 'tick-poll': 0}
            for event in data['events']:
                if event.get('kind') not in ('rx-report', 'rx-ack', 'rx-paint'):
                    continue
                reason = event['rxEntryReason']
                assert reason in counts, 'Unknown receiver entry reason'
                counts[reason] += 1
            total = totals[item['role']]
            total['calls'] += data['rxPollCalls']
            total['readCalls'] += data['rxPollReadCalls']
            total['readBytes'] += data['rxPollReadBytes']
            total['relatedTickPollEvents'] += counts['tick-poll']
            rows.append(dict(role=item['role'], round=item['round'], rxPollCalls=data['rxPollCalls'],
                rxPollReadCalls=data['rxPollReadCalls'], rxPollReadBytes=data['rxPollReadBytes'], relatedEvents=counts))
        except Exception as exc:
            failures.append(dict(role=item['role'], round=item['round'], error=str(exc)))
    for role, total in totals.items():
        if not (total['readCalls'] > 0 and total['readBytes'] > 0 and total['relatedTickPollEvents'] > 0):
            failures.append(dict(role=role, error='Actual nonempty poll and related tick-poll event not both covered'))
    pairs = {(row['role'], row['round']) for row in rows}
    ready = not failures and len(rows) == 8 and pairs == {(role, n) for role in ('host', 'join') for n in range(4)}
    return dict(pump_samples_ready=bool(ready), pump_evidence=rows, pump_role_totals=totals, pump_failures=failures,
        pump_coverage_scope='Each role across all four rounds; no requirement that polling wins each round')


def prepared_module():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    old = load(OLD, 'pump_frozen_rx_wrapper')
    prior_module = old.prepared_module()
    source = prepared_source(old)
    private = load(HERE / 'private_runner.py', 'pump_private_candidate_only')
    private_source = private.prepared_source()
    scalar_source = inspect.getsource(old.rx_proof)
    before = "            assert received and data['rxProbeCalls'] > 0, 'No receiver diagnostic coverage'"
    after = "            assert data['rxProbeCalls'] > 0, 'No receiver callback coverage'"
    assert scalar_source.count(before) == 1 and after not in scalar_source
    scalar_source = scalar_source.replace(before, after, 1)
    scalar_scope = dict(old.__dict__)
    exec(compile(scalar_source, '<pump direction-qualified original rx validator>', 'exec'), scalar_scope)
    scope = dict(__name__='pump_adapted_ack_native_entry', __file__=str(Path(__file__).resolve()))
    exec(compile(source, '<pump frozen rx entry narrow adaptation>', 'exec'), scope)
    new_preflight, original_collect = scope['preflight'], scope['collect']

    def preflight():
        # This real old-rx check includes the original real 5771 check. New
        # candidate/build inputs are then independently verified below.
        *_, prior, _ = prior_module['preflight']()
        wall, shared, run, driver, admission, private_runtime = new_preflight()
        assert prior['candidate_sha256'] == '36c5ad5c3967f27657c5316115fd4a707eb9a770d417d5f6a5306aaa47b7297c'
        assert prior['prior_ack_candidate_sha256'] == '57713116a7f4c70e47bed655d9ed80490fb32ecb75f14e7bf964e75db0122c06'
        assert admission['current_installation'] == prior['current_installation']
        assert admission['native_host'] == prior['native_host']
        with (scope['PRODUCT'] / 'RConnectMod.swf').open('rb') as stream:
            header = stream.read(4)
        assert header[:3] in (b'FWS', b'CWS', b'ZWS') and header[3] == 38
        assert private_runtime.count('http://ns.adobe.com/air/application/30.0') == 1
        assert 'http://ns.adobe.com/air/application/51.0' not in private_runtime
        assert 'socketNoDelayTrial' not in private_runtime
        pins = admission['inputs']
        for name, digest in prior['inputs'].items():
            assert name not in pins or pins[name] == digest
            pins[name] = digest
        for path, digest in PINS.items():
            assert sha(path) == digest
            pins[str(path)] = digest
        admission.update(prior_rx_candidate_sha256=prior['candidate_sha256'],
            prior_ack_candidate_sha256=prior['prior_ack_candidate_sha256'],
            host_swf_version=41, product_swf_version=38, namespace='30.0',
            adapter_source_sha256=hashlib.sha256(source.encode('utf-8')).hexdigest(),
            private_adapter_source_sha256=hashlib.sha256(private_source.encode('utf-8')).hexdigest(),
            scalar_validator_sha256=hashlib.sha256(scalar_source.encode('utf-8')).hexdigest())
        scope['check_pins'](pins)
        return wall, shared, run, driver, admission, private_runtime

    def collect(out, framework, wall, driver, admission):
        value = original_collect(out, framework, wall, driver, admission)
        value['ack_timing_samples_ready'] = value['diagnostic_samples_ready']
        value.update(receiver_qualification(out, value, scalar_scope['rx_proof']))
        value.update(pump_qualification(out, value))
        value['diagnostic_samples_ready'] = bool(value['ack_timing_samples_ready'] and value['rx_samples_ready'] and value['pump_samples_ready'])
        return value

    def save_sources(out):
        for name, text in (('pump-expanded-entry.py', source), ('pump-expanded-private-entry.py', private_source),
                           ('pump-scalar-validator.py', scalar_source)):
            with (out / name).open('x', encoding='utf-8', newline='\n') as stream:
                stream.write(text)

    scope.update(preflight=preflight, collect=collect, _save_adapter_sources=save_sources)
    return scope


if __name__ == '__main__':
    raise SystemExit(prepared_module()['main']())
