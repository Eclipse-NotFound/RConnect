"""Read-only qualification of rx01's direction-specific coverage; no AIR rerun."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import inspect
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Qualification requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
SOURCE = M52 / 'recovery-ordinary-wall-rx-native-01'
RUNNER = HERE / 'run_native.py'
RUNNER_SHA = 'f8b9b248ba7f819a32e03e9850b2ce5272b7a5a600c98f744e2e6e9a84c06f32'
CANDIDATE = '36c5ad5c3967f27657c5316115fd4a707eb9a770d417d5f6a5306aaa47b7297c'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def qualify():
    assert sha(RUNNER) == RUNNER_SHA
    result = read(SOURCE / 'ack-timing-result.json')
    assert result['passed'] is False and result['rx_samples_ready'] is False
    assert result['functional_pass'] is True and result['framework_passed'] is True and result['pixel_passed'] is True
    assert result['ack_timing_samples_ready'] is True and result['diagnostic_evidence_complete'] is True
    assert result['inputs_unchanged'] is True and result['admission']['candidate_sha256'] == CANDIDATE
    assert result['admission']['native_host']['candidate_sha256'] == '6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b'
    assert result['installation_after'] == result['admission']['current_installation']
    assert result['missing'] == result['aborts'] == result['diagnostic_output_errors'] == []
    assert result['rx_failures'] == [dict(role='host', round=n, error='No receiver diagnostic coverage') for n in (0, 2)]
    assert sha(SOURCE / 'result.json') == result['framework_sha256']
    framework = read(SOURCE / 'result.json')
    assert framework['passed'] is True and framework['frozen_inputs_unchanged'] is True
    assert framework['run'] == result['run'] == result['native_run']
    assert Path(result['run']).name == 'a3ded11cae'
    assert sha(SOURCE / 'wall-surface-analysis.json') == result['pixel_analysis_sha256']
    assert read(SOURCE / 'wall-surface-analysis.json')['passed'] is True
    pins = dict(result['admission']['inputs'])
    pins.update({str(RUNNER): RUNNER_SHA, str(Path(__file__).resolve()): sha(__file__)})
    for name in ('ack-timing-result.json', 'result.json', 'wall-surface-analysis.json'):
        pins[str(SOURCE / name)] = sha(SOURCE / name)
    assert {(row['role'], row['round']) for row in result['files']} == {(role, n) for role in ('host', 'join') for n in range(4)}
    assert len(result['files']) == 8
    coverage = []
    for row in result['files']:
        role, n = row['role'], row['round']
        path = SOURCE / row['file']
        assert path.resolve() == (SOURCE / 'wall-ack-timing' / role / f'round-{n}.json').resolve()
        assert sha(path) == row['sha256']
        data = read(path)
        assert data['role'] == role and data['round'] == n
        assert data['appId'] == 'pfe-modsettings-rconnect-coop-' + role + '-a3ded11cae'
        assert data['kind'] == 'ordinary-wall-ack-timing-v1'
        assert data['complete'] is True and data['termination'] == 'analyze' and data['bothSampled'] is True
        assert data['overflow'] is False and type(data['dropped']) is int and data['dropped'] == 0
        assert type(data['faultCount']) is int and data['faultCount'] == 0 and data['faults'] == []
        proof_path = SOURCE / 'wall-proof' / role / f'round-{n}-proof.json'
        proof = read(proof_path)
        source_role = 'host' if n in (0, 2) else 'join'
        assert proof['source'] is (role == source_role)
        if role == 'host':
            expected = set() if source_role == 'host' else {'rx-report'}
        else:
            expected = {'rx-paint'} if source_role == 'host' else {'rx-paint', 'rx-ack'}
        actual = {e['kind'] for e in data['events'] if e.get('kind', '').startswith('rx-')}
        assert actual == expected, (role, n, actual, expected)
        assert type(data['rxProbeCalls']) is int and data['rxProbeCalls'] > 0
        pins[str(path)] = sha(path)
        pins[str(proof_path)] = sha(proof_path)
        coverage.append(dict(role=role, round=n, source_role=source_role,
            required_rx_kinds=sorted(expected), actual_rx_kinds=sorted(actual),
            rxProbeCalls=data['rxProbeCalls'], zero_wall_rx_is_expected=not expected))
    for name, digest in pins.items():
        assert sha(name) == digest, name
    spec = importlib.util.spec_from_file_location('rx_frozen_original_scalar_validator', RUNNER)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    source = inspect.getsource(old.rx_proof)
    before = "            assert received and data['rxProbeCalls'] > 0, 'No receiver diagnostic coverage'"
    after = "            assert data['rxProbeCalls'] > 0, 'No receiver callback coverage'"
    assert source.count(before) == 1 and after not in source
    adapted = source.replace(before, after, 1)
    scope = dict(old.__dict__)
    exec(compile(adapted, '<rx direction-qualified original scalar validator>', 'exec'), scope)
    checked = scope['rx_proof'](SOURCE, result)
    assert checked['rx_evidence_complete'] is True and checked['rx_samples_ready'] is True and checked['rx_failures'] == []
    receipt = dict(kind='ordinary-rx-direction-supplemental-qualification',
        scope='existing-rx01-diagnostic-evidence-only', passed=True,
        original_result_path=str(SOURCE / 'ack-timing-result.json'), original_result_passed=False,
        original_result_unchanged=True, functional_pass=result['functional_pass'], framework_passed=result['framework_passed'],
        pixel_passed=result['pixel_passed'], diagnostic_evidence_complete=True, diagnostic_samples_ready=True,
        correction='Host-source rounds 0/2 legitimately have no host rx-wall events; exact per-round direction required.',
        all_original_scalar_checks_preserved=True, coverage=coverage, scalar_validation=checked,
        adapted_validator_sha256=hashlib.sha256(adapted.encode('utf-8')).hexdigest(),
        inputs=pins, candidate_sha256=CANDIDATE, run=result['run'],
        air_started=False, installed=False, performance_qualified=False, gameplay_qualified=False)
    return receipt, adapted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and out.name == 'recovery-ordinary-wall-rx-supplemental-01'
    assert not out.exists(), 'Never replace earlier evidence'
    receipt, source = qualify()
    out.mkdir()
    (out / 'scalar-validator.py').write_text(source, encoding='utf-8', newline='\n')
    with (out / 'receipt.json').open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(receipt, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    for name, digest in receipt['inputs'].items():
        assert sha(name) == digest, name
    print(json.dumps(dict(passed=True, diagnostic_samples_ready=True, original_result_unchanged=True,
        output=str(out), air_started=False, performance_qualified=False)))


if __name__ == '__main__':
    main()
