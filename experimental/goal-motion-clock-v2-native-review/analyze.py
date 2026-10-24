"""Read three completed 14-mod native jump runs; never starts a process.

Only compact derived metrics are saved. The frozen original measurement and
analysis recipes are not modified. No absolute cross-process clock alignment.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import statistics

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNS = {
    'baseline': ('goal-three-issues-native-jump-baseline-01', '74932502cf',
                 '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'),
    'v1_rejected': ('goal-three-issues-native-jump-candidate-01', '99eea9cf09',
                    '89f1b9235b809c1595559ede873b763dc15f9ca7c393c82231c48981b1d78215'),
    'v2': ('goal-motion-clock-v2-native-jump-01', 'e7f61547df',
           'b25e477a58093587da8c734c1b6eedb861433b3336a447f1cc113d5d1d66cbd3')}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distribution(values):
    ordered = sorted(values)
    return dict(count=len(ordered), mean=statistics.mean(ordered) if ordered else None,
                p95=ordered[math.ceil(.95 * len(ordered)) - 1] if ordered else None,
                maximum=max(ordered) if ordered else None)


def strict_movement(rows):
    pairs, repeated = [], []
    for a, b in zip(rows, rows[1:]):
        x, y = a['peer'], b['peer']
        if x['pose'] == 'die' or y['pose'] == 'die' or x['stay'] is not False or y['stay'] is not False:
            continue
        if min(abs(x['dy']), abs(y['dy'])) < 3 or x['dy'] * y['dy'] <= 0 or max(x['vy'], y['vy']) >= 620:
            continue
        pairs.append((a, b))
        if math.hypot(y['vx'] - x['vx'], y['vy'] - x['vy']) < .01:
            repeated.append((a, b))
    return dict(pairs=len(pairs), repeated_pairs=len(repeated),
                repeated_ms=sum(b['at'] - a['at'] for a, b in repeated))


def extract(folder, run_id, product):
    out, run = ROOT / 'build/m52' / folder, ROOT / 'build/cooperation' / run_id
    result, intent, native = read(out / 'result.json'), read(out / 'intent.json'), read(run / 'run.json')
    assert result['passed'] and result['installation_unchanged'] and result['inputs_unchanged']
    assert result['candidate_sha256'] == product and result['exit_code'] == 0
    assert not result['smoothnessQualified'] and not result['performanceQualified']
    assert sha(run / 'run.json') == result['run_sha256']
    assert sha(run / 'input.json') == result['input_sha256'] == native['input_manifest_sha256']
    assert read(run / 'registry-result.json')['passed'] is True
    environment = dict(installation=intent['installation'],
        roles={role: {k: v for k, v in native['inputs'][role].items() if k != 'production'}
               for role in ('host', 'join')})
    assert len(environment['installation']) == 22
    report = dict(run=run_id, output=folder, product_sha256=product,
                  result_sha256=sha(out / 'result.json'), input_sha256=sha(run / 'input.json'), roles={})
    for role in ('host', 'join'):
        raw_path, summary_path = out / (role + '-measurements.json'), out / (role + '-summary.json')
        assert sha(raw_path) == result['roles'][role]['measurements_sha256']
        assert sha(summary_path) == result['roles'][role]['summary_sha256']
        assert sha(run / (role + '.log')) == result['roles'][role]['log_sha256']
        p, s = read(raw_path)[0], read(summary_path)[0]
        assert p['timingOwned'] and p['timingRestored'] and p['dropped'] == 0
        assert p['reason'] == 'measurement-complete' and result['roles'][role]['checks'] == 6
        assert s['enter_without_final_render'] == 0
        assert s['local_enter']['unknown_focus_samples'] == 0
        assert s['local_enter']['foreground']['intervals']['count'] == 0
        incoming = [dict(at=packet['at'], **snap) for packet in p['incoming'] for snap in packet['snapshots']]
        unique = []
        for row in incoming:
            if not unique or row['sampleTime'] != unique[-1]['sampleTime']:
                unique.append(row)
        assert all(b['sampleTime'] > a['sampleTime'] for a, b in zip(unique, unique[1:]))
        old = [v for v in p['render'] if v['peer']['pose'] == 'die' or v['peer']['vy'] > 640.01]
        first_received = next(v for v in unique if v['y'] <= 604 and v['dy'] < 0)
        first_displayed = next(v for v in p['render']
            if v['peer']['pose'] != 'die' and v['peer']['vy'] <= 604 and v['peer']['dy'] < 0)
        stalls = [dict(at_ms=b['at'] - p['startedAt'], render_gap_ms=b['at'] - a['at'],
                       frameAt_gap_ms=b['frameAt'] - a['frameAt'])
                  for a, b in zip(p['render'], p['render'][1:]) if b['at'] - a['at'] > 100]
        report['roles'][role] = dict(raw_sha256=sha(raw_path), summary_sha256=sha(summary_path),
            functional_checks=6, enter_fps=s['local_enter']['background']['fps'],
            enter_intervals=s['local_enter']['all'], render_intervals=s['final_render']['all'],
            initial_peer=p['render'][0]['peer'], old_pose_count=len(old),
            old_pose_last_ms=old[-1]['at'] - p['startedAt'] if old else None,
            strict_air=strict_movement(p['render']), remote_step=s['remote']['step_pixels'],
            local_step=s['local']['step_pixels'], received_snapshots=len(incoming), distinct_stamps=len(unique),
            repeated_stamps=len(incoming) - len(unique),
            unique_receive_intervals=distribution([b['at'] - a['at'] for a, b in zip(unique, unique[1:])]),
            source_intervals=distribution([b['sampleTime'] - a['sampleTime'] for a, b in zip(unique, unique[1:])]),
            first_jump=dict(received_ms=first_received['at'] - p['startedAt'], received_y=first_received['y'],
                shown_ms=first_displayed['at'] - p['startedAt'], shown_y=first_displayed['peer']['vy'],
                receiver_observed_wait_ms=first_displayed['at'] - first_received['at']),
            render_stalls=stalls, presentation_timing=s['presentation_timing'])
    memory = read(run / 'memory-timeline.json')
    assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
    assert memory['minimum_commit_bytes'] == 512 * 1024 ** 2
    assert all(not (run / name).exists() for name in ('host', 'join', 'frozen'))
    report['minimum_commit_gib'] = min(row['free_commit_bytes'] for row in memory['rows']) / 2 ** 30
    report['copies_cleaned'] = True
    return environment, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    reports, baseline = {}, None
    for label, inputs in RUNS.items():
        environment, report = extract(*inputs)
        if baseline is None:
            baseline = environment
        assert environment == baseline, 'This comparison requires the same 22 inputs, driver, host and 14 mods'
        reports[label] = report
    result = dict(runs=reports, identical_actual_inputs_except_product=True, actual_module_count=14,
        strict_air_filter='Both adjacent frames: stay===false, vy<620 on floor640, same sign dy, |dy|>=3, no die pose; repeated if displacement<0.01px.',
        limits=['No pre-window motion queue/cursor/offset; startup histories are not identical.',
                'Receiver observed threshold interval is not network RTT or cross-process latency.',
                'One native pair per product; foreground, dense scene and full performance not qualified.',
                '11-mod baseline c783ed51d1 is a separate configuration, excluded from these comparisons.',
                'viewMs/motionMs have partial, potentially overlapping coverage; not total CPU.'],
        performanceQualified=False, smoothnessQualified=False)
    if args.write:
        with (HERE / 'metrics.json').open('x', encoding='utf-8') as stream:
            json.dump(result, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    for label, report in reports.items():
        print(label, json.dumps({role: dict(fps=values['enter_fps'], strict=values['strict_air'],
            old_pose_count=values['old_pose_count'], first_jump=values['first_jump'])
            for role, values in report['roles'].items()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
