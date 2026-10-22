"""Explicit bounded analysis of the completed modules run; no polling or AIR launch."""
from pathlib import Path
import argparse, hashlib, json, re

ROOT = Path(__file__).resolve().parents[2]
DRIVER = ROOT / 'build/m52/recovery-paint-enter-modules-driver-01'
MANIFEST_SHA = '5ddf698d425d78c9623d5986a8245af7e0f1bfda8fa5e86fa70a6ef967b032cb'
DRIVER_SHA = 'fa58bdd0b0a0e233e1cd450e84ecd882b6bfca3a620ce842c3f48b5524dd385e'
PRIORITIES = [-79, -81, -99, -101, -199, -201, -6999, -7001]
NOTES = [
    'Only intervals within this Stage dispatcher, not exclusive module attribution; marker overhead remains.',
    'Priority -80 is shared by LightAndDarkness (LAD) and PermanentInjury (PI).',
    'Priority -100 is shared by WallBlend (WB) and FirearmAttachments (FA).',
    'The -199 to -201 interval brackets priority -200, including CS; it is not exclusive attribution.',
    'The exact TDFC runtime/source binding is incomplete; no exclusive TDFC attribution is supported.',
    'No direct main-thread/native/GPU attribution or performance qualification is provided.',
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def text(path):
    assert path.is_file(), 'Result/log not ready; this script does not wait: ' + str(path)
    assert path.stat().st_size <= 32 * 1024 * 1024, 'Analysis input exceeds 32 MiB limit'
    return path.read_text(encoding='utf-8-sig')

def read(path):
    return json.loads(text(path))

def analyze_row(row):
    band = row['stageEnterBands']; render = row['renderBoundary']; marks = band['marks']
    assert band['priorities'] == PRIORITIES and band['limit'] == 8
    assert len(marks) <= 8 and len(band['unavailable']) == 8 and len(render['marks']) <= 16
    indices = [m['index'] for m in marks]
    assert len(set(indices)) == len(indices) and all(type(i) is int and 0 <= i < 8 for i in indices)
    assert all(m['priority'] == PRIORITIES[m['index']] for m in marks)
    assert band['mask'] == sum(1 << i for i in indices)
    assert band['completeCoverage'] == (len(indices) == 8)
    missing = [dict(priority=p, reason=band['unavailable'][i]) for i, p in enumerate(PRIORITIES) if i not in indices]
    assert all(m['reason'] for m in missing) and all(band['unavailable'][i] == '' for i in indices)
    summary = dict(segment=row['segment'], triggered=row['triggered'], missing=missing,
        band_faults=band['faults'], duplicates=band['duplicates'], overflow=band['overflow'],
        band_incomplete=band['incomplete'], total_samples=row['totalSamples'], intervals=None)
    if not row['triggered']:
        assert not marks and not render['marks'] and row['stageEnterAfterDefault'] is None and row['stageEnterTail'] is None
        summary.update(applicable=False, reason=row['reason'])
        return summary
    summary['applicable'] = True
    valid = bool(row['complete'] and row['clockOrdered'] and row['cleanupComplete'] and row['samplingComplete']
        and not row['errors'] and not band['incomplete'] and not band['faults'] and not band['duplicates']
        and not band['overflow'] and not missing and not row['stageEnterAfterDefaultIncomplete']
        and not row['stageEnterTailIncomplete'] and not row['stageEnterAfterDefaultUnavailable']
        and not row['stageEnterTailUnavailable'] and render['attached'] and render['available']
        and not render['incomplete'] and not render['faults'] and not render['overflow'])
    summary['valid'] = valid
    if not valid:
        return summary
    assert indices == list(range(8))
    phases = [m['phase'] for m in render['marks']]
    assert phases == ['high', 'low'] * (len(phases) // 2) and phases
    assert render['observed'] == len(phases)
    assert all(render['marks'][i+1]['serial'] == render['marks'][i]['serial'] + 1 for i in range(len(phases)-1))
    points = [('start', row['clocks']['startReturned']), ('-1', row['stageEnterAfterDefault'])]
    points += [(str(m['priority']), m) for m in marks]
    points += [('lowest', row['stageEnterTail']), ('render_first', render['marks'][0]),
               ('render_last', render['marks'][-1]), ('next_enter', row['clocks']['stop'])]
    assert row['stopStage'] == row['startStage'] + 1
    assert all(m['enter'] == row['startStage'] for _, m in points[1:-1])
    intervals = []
    for (left, a), (right, b) in zip(points, points[1:]):
        assert b['t'] >= a['t'] and b['wall'] >= a['wall'], (row['segment'], left, right)
        intervals.append(dict(start=left, end=right, get_timer_ms=b['t']-a['t'], wall_ms=b['wall']-a['wall']))
    totals = {key: sum(r[key] for r in intervals) for key in ('get_timer_ms', 'wall_ms')}
    assert totals['get_timer_ms'] == points[-1][1]['t']-points[0][1]['t']
    assert totals['wall_ms'] == points[-1][1]['wall']-points[0][1]['wall']
    summary.update(intervals=intervals, totals=totals, start_stage=row['startStage'],
        stop_stage=row['stopStage'], marker_count=len(marks), render_count=len(phases))
    return summary

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--result', default='build/m52/recovery-paint-enter-modules-solo-01/result.json')
    parser.add_argument('--write', action='store_true', help='Save modules-alignment.json beside the existing result')
    args = parser.parse_args(); path = (ROOT / args.result).resolve()
    assert path.name == 'result.json' and path.parent.parent == ROOT / 'build/m52'
    result = read(path)
    assert sha(DRIVER / 'prepared.json') == MANIFEST_SHA and sha(DRIVER / 'scene/EffectsDriver.swf') == DRIVER_SHA
    meta = read(DRIVER / 'prepared.json')
    assert len(meta['files']) == 18
    for name, digest in meta['files'].items():
        assert sha(DRIVER / name) == digest, name
    assert re.fullmatch(r'[0-9a-f]{10}', result['run']) and list(result['roles']) == ['host']
    run = ROOT / 'build/cooperation' / result['run']; actual = read(run / 'input.json')
    assert actual['inputs']['host']['driver'] == DRIVER_SHA
    assert read(path.parent / 'intent.json')['driver_manifest'] == MANIFEST_SHA
    log = run / 'host.log'; rows = []
    for line in text(log).splitlines():
        if line.startswith('EARLY PAINT TAIL {'):
            assert len(rows) < 3, 'More than three diagnostic segments'
            rows.append(json.loads(line[len('EARLY PAINT TAIL '):]))
    assert [r['segment'] for r in rows] == [0, 1, 2]
    report = dict(run=result['run'], driver_sha256=DRIVER_SHA, manifest_sha256=MANIFEST_SHA,
        source_result_sha256=sha(path), source_host_log_sha256=sha(log), priorities=PRIORITIES,
        scene_passed=result['passed'], checks=result['roles']['host']['checks'], scene_errors=result['roles']['host']['errors'],
        installation_unchanged=result['installation_unchanged'], rows=[analyze_row(row) for row in rows],
        diagnostic_only=True, performance_qualified=False, interpretation=NOTES)
    if args.write:
        destination = path.parent / 'modules-alignment.json'
        serialized = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
        if destination.exists():
            assert text(destination) == serialized, 'Refusing to replace different existing analysis'
        else:
            destination.write_text(serialized, encoding='utf-8')
    print('run={} checks={} errors={} installation_unchanged={} performance_qualified=False'.format(
        report['run'], report['checks'], report['scene_errors'], report['installation_unchanged']))
    for row in report['rows']:
        if not row['applicable']:
            print('segment {}: not triggered ({})'.format(row['segment'], row['reason']))
        elif not row['valid']:
            print('segment {}: INCOMPLETE; no intervals inferred'.format(row['segment']))
        else:
            print('segment {}: total={}ms; intervals timer/wall: {}'.format(row['segment'], row['totals']['get_timer_ms'],
                ', '.join('{}>{}={}/{}'.format(i['start'], i['end'], i['get_timer_ms'], i['wall_ms']) for i in row['intervals'])))
    print('-80=LAD+PI; -100=WB+FA; -200 includes CS; exact TDFC source binding incomplete; no exclusive attribution.')

if __name__ == '__main__':
    main()
