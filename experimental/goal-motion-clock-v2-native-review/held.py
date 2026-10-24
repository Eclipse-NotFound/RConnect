"""Read the failed 78C and passed B25 held runs; no processes or source edits."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import math

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CASES = ('box-host', 'box-join', 'loot-host', 'loot-join')
RUNS = {
    'baseline_failed': ('goal-three-issues-native-held-baseline-01', 'ad378fee3a', False),
    'v2': ('goal-motion-clock-v2-native-held-01', '23ba08ed52', True),
}


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def logged(lines, prefix):
    return [json.loads(line[len(prefix):]) for line in lines if line.startswith(prefix)]


def fit(record):
    """Repeat the original 0..700/10ms least-square fit, not a new latency rule."""
    best, best_lag, best_n = math.inf, -1, 0
    ref = record['reference']
    for lag in range(0, 701, 10):
        total, count, index = 0.0, 0, 0
        for shown in record['render']:
            stamp = shown['at'] - record['sourceOffset'] - lag
            if len(ref) < 2 or stamp < ref[0]['at'] + 700 or stamp > ref[-1]['at']:
                continue
            while index + 1 < len(ref) and ref[index + 1]['at'] < stamp:
                index += 1
            if index + 1 >= len(ref):
                continue
            a, b = ref[index:index + 2]
            expected = a['x'] + (b['x'] - a['x']) * ((stamp - a['at']) / (b['at'] - a['at']))
            total += (shown['x'] - expected) ** 2
            count += 1
        error = math.sqrt(total / count) if count >= 12 else math.inf
        if error < best:
            best, best_lag, best_n = error, lag, count
    assert best_lag == record['lagMs'] and best_n == record['samples']
    assert math.isclose(best, record['rmsPixels'], abs_tol=1e-9)
    return dict(lag_ms=best_lag, rms_pixels=best, samples=best_n,
                original_threshold_ms=160, passed=best_n >= 12 and 0 <= best_lag <= 160)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    analyzer = ROOT / 'experimental/goal-three-issues-native/analyze.py'
    spec = importlib.util.spec_from_file_location('frozen_native_analyzer', analyzer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    failed_out = ROOT / 'build/m52/goal-three-issues-native-held-baseline-01'
    diagnostics = read(failed_out / 'failed-measurement-diagnostics.json')
    assert not diagnostics['originalPassed']
    assert diagnostics['originalResultSha256'] == sha(failed_out / 'result.json')
    assert diagnostics['analyzerSha256'] == sha(analyzer)
    prepared = read(ROOT / 'build/m52/goal-three-issues-native-drivers-02/prepared.json')
    source = ROOT / 'build/m52/goal-three-issues-native-drivers-02/tests/FastHeldTestDoc.as'
    assert sha(source) == prepared['files']['tests/FastHeldTestDoc.as']
    assert 'bestN>=12 && bestLag>=0 && bestLag<=160' in source.read_text(encoding='utf-8-sig')
    report = dict(runs={}, threshold_ms=160, source_sha256=sha(source), analyzer_sha256=sha(analyzer),
                  performanceQualified=False, smoothnessQualified=False)
    baseline_environment = None
    for label, (folder, run_id, passed) in RUNS.items():
        out, run = ROOT / 'build/m52' / folder, ROOT / 'build/cooperation' / run_id
        result, native, intent = read(out / 'result.json'), read(run / 'run.json'), read(out / 'intent.json')
        assert result['passed'] is passed and result['exit_code'] == (0 if passed else 1)
        assert result['inputs_unchanged'] and result['installation_unchanged']
        assert not result['performanceQualified'] and not result['smoothnessQualified']
        assert sha(run / 'input.json') == native['input_manifest_sha256']
        if passed:
            assert sha(run / 'input.json') == result['input_sha256']
            assert sha(run / 'run.json') == result['run_sha256']
        environment = dict(installation=intent['installation'], inputs={}, settings={}, preferences={})
        supplemental = read(out / 'supplemental-input.json')
        assert supplemental['before_any_air'] and supplemental['original_input_sha256'] == sha(run / 'input.json')
        item = dict(run=run_id, passed=passed, result_sha256=sha(out / 'result.json'),
                    run_sha256=sha(run / 'run.json'), input_sha256=sha(run / 'input.json'),
                    product_sha256=result['candidate_sha256'], roles={}, delay={})
        for role in ('host', 'join'):
            environment['inputs'][role] = {k: v for k, v in native['inputs'][role].items() if k != 'production'}
            assert len(native['inputs'][role]['modules']) == 14
            assert sha(out / 'driver/EffectsDriver.swf') == native['inputs'][role]['driver']
            assert sha(out / 'driver/EffectsHarness.swf') == native['inputs'][role]['harness']
            environment['settings'][role] = {}
            for name, digest in native['configuration_files'][role].items():
                path = run / 'configuration' / role / name
                assert sha(path) == digest
                if name == 'mods/Rconnect/release/config.txt':
                    config = read(path)
                    assert config.pop('port') == native['port']
                    environment['settings'][role][name] = config
                else:
                    environment['settings'][role][name] = digest
            environment['preferences'][role] = {k: supplemental['roles'][role][k]
                for k in ('preference_sha256', 'telemetry_sha256')}
            log = run / (role + '.log')
            lines = log.read_text(encoding='utf-8-sig').splitlines()
            raw = logged(lines, 'NATIVE MOTION MEASURE ')
            assert len(raw) == 4 and [r['round'] for r in raw] == [0, 1, 2, 3]
            summaries = [module.summarize(row) for row in raw]
            if passed:
                assert read(out / (role + '-measurements.json')) == raw
                assert read(out / (role + '-summary.json')) == summaries
                for key, path in [('log', log), ('measurements', out / (role + '-measurements.json')),
                                  ('summary', out / (role + '-summary.json'))]:
                    assert sha(path) == result['roles'][role][key + '_sha256']
            else:
                assert sha(log) == diagnostics['roles'][role]['logSha256']
                assert summaries == diagnostics['roles'][role]['rounds']
            failures = [s for s in lines if s.startswith('COOP FAIL ')]
            pass_count = sum(s.startswith('COOP PASS ') for s in lines)
            assert pass_count == (43 if role == 'host' and passed else 42)
            assert len(failures) == (1 if role == 'host' and not passed else 0)
            compact = []
            for probe, summary in zip(raw, summaries):
                assert probe['reason'] == 'measurement-complete' and probe['dropped'] == 0
                assert probe['timingOwned'] and probe['timingRestored']
                frames = {row['frame'] for row in probe['render']}
                missing = [row for row in probe['enter'] if row['frame'] not in frames]
                assert missing == [probe['enter'][-1]]  # Held stop is inside ENTER_FRAME.
                assert all(row['focused'] is False for row in probe['enter'] + probe['render'])
                compact.append(dict(case=CASES[probe['round']], enter_fps=summary['local_enter']['background']['fps'],
                    enter_intervals=summary['local_enter']['all'], render_intervals=summary['final_render']['all'],
                    held_step=summary['held']['step_pixels'], final_enter_without_render=1,
                    intermediate_enter_without_render=0, timing_restored=True, dropped=0))
            release = [s for s in lines if s.startswith('COOP ') and any(t in s for t in (
                'release reaches both', 'normal release clears', 'air release resumes',
                'release lands on', 'stationary release reaches', 'box release is stationary'))]
            assert all(s.startswith('COOP PASS ') for s in release)
            assert sum('release reaches both' in s for s in release) == 4
            assert sum('normal release clears' in s for s in release) == 2
            assert sum('release lands on' in s for s in release) == 4
            assert sum('air release resumes' in s for s in release) == 4
            item['roles'][role] = dict(log_sha256=sha(log), pass_count=pass_count,
                failures=failures, rounds=compact, release_checks=release)
            for metric in logged(lines, 'FAST HELD METRIC '):
                item['delay'][CASES[metric['round']]] = fit(metric)
        assert len(item['delay']) == 4 and sum(v['passed'] for v in item['delay'].values()) == (4 if passed else 3)
        memory = read(run / 'memory-timeline.json')
        assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
        assert all(not (run / name).exists() for name in ('host', 'join', 'frozen'))
        item['minimum_commit_gib'] = min(row['free_commit_bytes'] for row in memory['rows']) / 2 ** 30
        item['copies_cleaned'] = True
        if baseline_environment is None:
            baseline_environment = environment
        assert environment == baseline_environment and len(environment['installation']) == 22
        report['runs'][label] = item
    report['same_inputs_settings_except_product_and_port'] = True
    report['failed_diagnostics_sha256'] = sha(failed_out / 'failed-measurement-diagnostics.json')
    if args.write:
        with (HERE / 'held-metrics.json').open('x', encoding='utf-8') as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    for label, item in report['runs'].items():
        print(label, {case: value['lag_ms'] for case, value in item['delay'].items()})
        for role, values in item['roles'].items():
            print(role, [(r['case'], round(r['enter_fps'], 2), r['render_intervals']['maximum']) for r in values['rounds']])


if __name__ == '__main__':
    main()
