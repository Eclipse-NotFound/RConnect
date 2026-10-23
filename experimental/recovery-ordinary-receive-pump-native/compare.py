"""Compare the two completed native runs without changing either verdict."""
from pathlib import Path
import hashlib
import importlib.util
import json
import statistics
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
ROOT = Path(__file__).resolve().parents[2]
M52 = ROOT / 'build/m52'
inputs = {}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):
    inputs[str(p)] = sha(p)
    return json.loads(p.read_text(encoding='utf-8-sig'))


def stats(values):
    return dict(count=len(values), median=statistics.median(values), maximum=max(values)) if values else dict(count=0)


def main():
    baseline = M52 / 'recovery-ordinary-wall-rx-native-01'
    candidate = M52 / 'recovery-ordinary-receive-pump-native-01'
    supplemental = read(M52 / 'recovery-ordinary-wall-rx-supplemental-01/receipt.json')
    assert supplemental['passed'] and supplemental['original_result_unchanged']
    assert supplemental['original_result_path'] == str(baseline / 'ack-timing-result.json')
    for name, digest in supplemental['inputs'].items():
        assert sha(Path(name)) == digest, name
    original_analysis = read(baseline / 'rx-stage-analysis.json')
    ap = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/analyze.py'
    assert sha(ap) == original_analysis['inputs'][str(ap)]
    inputs[str(ap)] = sha(ap)
    spec = importlib.util.spec_from_file_location('pump_original_wall_phase_analysis', ap)
    analyzer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(analyzer)
    runs = []
    for label, folder in [('baseline', baseline), ('pump', candidate)]:
        result = read(folder / 'ack-timing-result.json')
        assert result['functional_pass'] and result['framework_passed'] and result['pixel_passed']
        assert result['inputs_unchanged'] and result['ack_timing_samples_ready']
        assert read(folder / 'wall-surface-analysis.json')['passed']
        assert result['admission']['native_host']['candidate_sha256'] == '6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b'
        rounds = []
        for index in range(4):
            row = analyzer.phase_rows(folder, index, inputs)
            row.update(analyzer.trace_rows(folder, index, inputs))
            row['render_delays_ms'] = [p['render_to_render_ms'] for p in row['phases'] if 'render_to_render_ms' in p]
            row['render_summary'] = stats(row['render_delays_ms'])
            row['complete_visual_phases'] = (len(row['phases']) == row['shots'] and
                all(p['remote_phase_observed'] and not p['repeated_source_pattern_ambiguous'] for p in row['phases']))
            row['ack_rtt_ms'] = [p['report_to_ack_received_same_process_ms'] for p in row['ack_cycles'] if p['complete_pairing']]
            row['ack_summary'] = stats(row['ack_rtt_ms'])
            rounds.append(row)
        runs.append(dict(label=label, folder=str(folder), run=result['run'],
            candidate_sha256=result['admission']['candidate_sha256'],
            original_overall_passed=result['passed'],
            active_poll_covered=result.get('pump_samples_ready'),
            pump_totals=result.get('pump_role_totals'), pump_failures=result.get('pump_failures'), rounds=rounds))
    assert runs[0]['candidate_sha256'] == '36c5ad5c3967f27657c5316115fd4a707eb9a770d417d5f6a5306aaa47b7297c'
    assert runs[1]['candidate_sha256'] == 'ab61c7aaa70b6b6856f2bc2eddae969ae993c8d1c94c80e57f82afcded6b4114'
    result = dict(kind='receive-pump-first-native-pair', runs=runs, inputs=inputs,
        performance_qualified=False, installed=False, original_results_changed=False,
        limits=['One sequential pair with bounded pixel sampling, not a production performance gate.',
                'Each run has its own exact pixel oracle; random impact patterns differ.',
                'Callback spans include transport and event scheduling, not pure network latency.',
                'Missing or ambiguous visual phases remain explicit. No interpolation substitutes for them.'])
    for p, digest in inputs.items():
        assert sha(Path(p)) == digest, p
    result['inputs'][str(Path(__file__).resolve())] = sha(Path(__file__).resolve())
    out = M52 / 'recovery-ordinary-receive-pump-first-pair.json'
    with out.open('x', encoding='utf-8', newline='\n') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(json.dumps(dict(output=str(out), performance_qualified=False, rounds=[
        dict(label=r['label'], active_poll_covered=r['active_poll_covered'],
            rounds=[dict(round=x['round'], complete=x['complete_visual_phases'],
                render=x['render_delays_ms'], ack=x['ack_rtt_ms']) for x in r['rounds']]) for r in runs]), ensure_ascii=False))


if __name__ == '__main__':
    main()
