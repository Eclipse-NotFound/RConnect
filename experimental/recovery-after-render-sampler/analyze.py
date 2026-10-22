"""Read post-RENDER CPU windows; wall time without CPU samples remains unexplained."""
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'AFTER RENDER CPU PROFILE '


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(data):
    assert data['schema'] == 1 and data['scope'] == 'stage-render-tail-to-next-stage-enter-entry'
    rows, counts = data['frames'], data['counts'] or {}
    assert len(rows) <= 4096
    assert all(str(k) in ('0', '1', '5', '6') and 0 <= v <= 6 for k, v in counts.items())
    assert sum(counts.values()) <= 24
    inclusive, leaf = Counter(), Counter()
    actual_counts, phases = Counter(), {}
    timing = []
    total_cpu = 0
    for row in rows:
        assert 'allocations' not in row and 'deleted' not in row
        assert len(row['stacks']) <= 1024
        assert sum(row['stacks'].values()) + row['stackOverflow'] == row['cpu']
        assert row['collectEnd'] >= row['collectStart']
        assert row['collectMs'] == row['collectEnd'] - row['collectStart']
        p = phases.setdefault(str(row['phase']), dict(frames=0, sampled=0, complete=0, incomplete=0, cpu=0))
        p['frames'] += 1
        if row['sampled']:
            actual_counts[str(row['phase'])] += 1
            p['sampled'] += 1
            assert row['at'] <= row['after'] <= row['renderAt'] <= row['startCallAt'] <= row['start']
            assert row['start'] <= row['stop'] <= row['pauseReturned'] <= row['collectStart']
        else:
            assert row['start'] == row['cpu'] == 0 and not row['stacks']
        if row['complete']:
            assert row['reason'] == 'next-enter'
            assert row['at'] <= row['after'] <= row['renderAt'] <= row['stop']
            p['complete'] += 1
        else:
            assert row['reason'] != 'next-enter'
            p['incomplete'] += 1
        p['cpu'] += row['cpu']
        total_cpu += row['cpu']
        for stack, count in row['stacks'].items():
            names = [part.split('@', 1)[0] for part in stack.split(' <- ') if part]
            for name in set(names):
                inclusive[name] += count
            if names:
                leaf[names[0]] += count
        t = {k:row[k] for k in ('phase', 'frame', 'at', 'after', 'renderAt', 'startCallAt', 'start',
             'stop', 'pauseReturned', 'collectStart', 'collectEnd', 'collectMs', 'sampled',
             'complete', 'reason', 'cpu', 'extraRenders', 'stackOverflow', 'depthTruncated')}
        t['render_to_stop_ms'] = row['stop'] - row['renderAt'] if row['renderAt'] > 0 else None
        t['start_return_to_stop_ms'] = row['stop'] - row['start'] if row['sampled'] else None
        t['frame_to_next_enter_ms'] = row['stop'] - row['at'] if row['complete'] else None
        timing.append(t)
    assert all(actual_counts[k] <= v for k, v in counts.items())
    if data['droppedRows'] == 0:
        assert dict(actual_counts) == {str(k):v for k,v in counts.items() if v}
    return dict(recorded_frames=len(rows), sampled_windows=sum(actual_counts.values()),
        counts=counts, dropped_rows=data['droppedRows'], cpu_samples=total_cpu,
        valid_cpu_sample=total_cpu > 0, phases=phases, timings=timing,
        inclusive_top=inclusive.most_common(45), leaf_top=leaf.most_common(35),
        zero_cpu_does_not_prove_waiting=True, performance_qualified=False,
        scope='Original stage RENDER -1000000 through next stage ENTER +1000000; collector is paused; native/global broadcast order not certified')


def analyze(out):
    result = json.loads((out/'result.json').read_text('utf-8-sig'))
    folder = ROOT/'build/cooperation'/result['run']
    report = dict(run=result['run'], diagnostic_only=True, performance_qualified=False,
        release_qualified=False, installed_unchanged=result['installation_unchanged'],
        exclusive=result['exclusive_air_confirmed'], result_sha256=sha(out/'result.json'), roles={})
    for role in ('host', 'join'):
        log = folder/(role+'.log')
        data = [json.loads(line[len(PREFIX):]) for line in log.read_text('utf-8-sig').splitlines() if line.startswith(PREFIX)]
        assert len(data) == 1 and data[0]['role'] == role
        report['roles'][role] = dict(summarize(data[0]), log_sha256=sha(log))
    return report
