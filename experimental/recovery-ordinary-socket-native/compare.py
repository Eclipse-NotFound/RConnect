"""Summarize the completed first off/on pair; never grant performance acceptance."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[2]
M52 = ROOT / 'build/m52'


def read(path, inputs):
    raw = path.read_bytes()
    inputs[str(path)] = hashlib.sha256(raw).hexdigest()
    return json.loads(raw)


def stats(values):
    return dict(count=len(values), median_ms=statistics.median(values) if values else None,
                max_ms=max(values) if values else None, values_ms=values)


def main():
    inputs = {str(Path(__file__).resolve()): hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    groups = []
    for mode in ('off', 'on'):
        folder = M52 / ('recovery-ordinary-socket-' + mode + '-native-01')
        result = read(folder / 'ack-timing-result.json', inputs)
        analysis = read(folder / 'timing-analysis.json', inputs)
        pixels = read(folder / 'wall-surface-analysis.json', inputs)
        assert all(result[k] is True for k in ('passed', 'functional_pass', 'framework_passed',
            'diagnostic_samples_ready', 'diagnostic_evidence_complete', 'socket_verified', 'inputs_unchanged'))
        assert result['socket_mode'] == mode and pixels['passed'] is True
        assert result['installed'] is False and result['performance_qualified'] is False
        assert len(analysis['rounds']) == len(pixels['rows']) == 4
        rows = []
        for r, p in zip(analysis['rounds'], pixels['rows']):
            assert r['round'] == p['round'] and not r['unmatched_transport']
            assert p['native_equal'] is True and p['display_equal'] is True
            phases = r['phases']
            assert all(x['remote_phase_observed'] is True and
                x['repeated_source_pattern_ambiguous'] is False for x in phases)
            assert all(x['complete_pairing'] is True and x['accepted'] is True for x in r['ack_cycles'])
            rows.append(dict(round=r['round'], source=r['source'], weapon=r['weapon'],
                native_expected=p['native_expected'],
                transport={kind: stats([x['flush_to_decoded_dispatch_ms'] for x in r['transport'] if x['kind'] == kind])
                           for kind in ('paint', 'report', 'ack')},
                render_to_render=stats([x['render_to_render_ms'] for x in phases]),
                first_hit_to_remote_ms=phases[0]['hit_to_remote_ms'],
                report_to_ack_same_process=stats([x['report_to_ack_received_same_process_ms'] for x in r['ack_cycles']]),
                observation_gap=r['max_observation_gap_ms']))
        groups.append(dict(mode=mode, run=result['run'], variables=result['comparison_variables'],
            installation=result['installation_after'], rows=rows))
    before, after = groups
    assert before['installation'] == after['installation']
    variables = ('candidate_sha256', 'host_sha256', 'namespace', 'host_swf_version',
                 'product_swf_version', 'tickMs', 'seconds', 'wallAckTiming')
    assert all(before['variables'][k] == after['variables'][k] for k in variables)
    result = dict(kind='socket-first-pair-comparison', inputs=inputs, groups=groups,
        performance_qualified=False, deployment_qualified=False,
        conclusion='No consistent timing improvement observed in this single off/on pair; do not adopt as the fix.',
        limitations=[
            'A single sequential pair is not a randomized or production performance benchmark.',
            'Successful flush to decoded dispatch includes runtime scheduling and decoding, not pure network time.',
            'The original bounded pixel observations themselves can take time; no sampling or gates were changed.',
            'Actual impact patterns differ between runs; each run is compared to its own exact native pixels.',
            'Both arms share header51/namespace51; neither establishes broad compatibility of that context.',
        ])
    target = M52 / 'recovery-ordinary-socket-first-pair.json'
    with target.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps(dict(output=str(target), performance_qualified=False, deployment_qualified=False)))


if __name__ == '__main__':
    main()
