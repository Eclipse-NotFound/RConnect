"""Read existing native records only; no test process or output files."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNS = ('goal-native-reduced-jump-01', 'goal-three-issues-native-jump-baseline-01',
        'goal-motion-clock-v2-native-jump-01')

for name in RUNS:
    folder = ROOT / 'build/m52' / name
    result = json.loads((folder / 'result.json').read_text(encoding='utf-8-sig'))
    report = {'folder': name, 'run': result['run'], 'candidate': result['candidate_sha256'], 'roles': {}}
    for role in ('host', 'join'):
        path = folder / (role + '-measurements.json')
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != result['roles'][role]['measurements_sha256']:
            raise RuntimeError('Changed recorded measurements: ' + str(path))
        windows = json.loads(path.read_text(encoding='utf-8-sig'))
        if len(windows) != 1 or windows[0]['kind'] != 'native-jump':
            raise RuntimeError('Unexpected recorded fixture')
        window = windows[0]
        rows = window['render']
        stats, examples = {}, []
        for who in ('local', 'peer'):
            valid = repeated = clamped = 0
            for before, after in zip(rows, rows[1:]):
                a, b = before[who], after[who]
                if not a or not b or a['pose'] != 'jump' or b['pose'] != 'jump':
                    continue
                if a['stay'] is not False or b['stay'] is not False:
                    continue
                if abs(a['dy']) < 3 or abs(b['dy']) < 3 or a['dy'] * b['dy'] < 0:
                    continue
                if abs(b['vy'] - a['vy']) < .01:
                    continue
                valid += 1
                if a['body'] == b['body']:
                    repeated += 1
                    if b['body'] in (1, 32):
                        clamped += 1
                    if who == 'peer' and len(examples) < 4:
                        examples.append({'age': after['at'] - window['startedAt'],
                            'dt': after['at'] - before['at'], 'body': b['body'],
                            'displayYDelta': round(b['vy'] - a['vy'], 3), 'snapshotDy': b['dy']})
            stats[who] = {'bodyRepeatedWhilePositionChanged': repeated, 'eligiblePairs': valid,
                         'repeatedAtClamp': clamped, 'repeatedInterior': repeated-clamped}
        report['roles'][role] = {'sha256': digest, 'frames': len(rows), 'stats': stats, 'examples': examples}
    report['limits'] = ['Different players and delayed phases, not exact paired body-clock replay.',
        'Records lack bodyPlaying, jump eligibility and internal cursor; no interpolation efficacy claim.',
        'Repeated frames include legal rounding and 1/32 clamping; counts are not defect counts.',
        'Reduced and full module sets are separate evidence, not a performance comparison.']
    print(json.dumps(report, ensure_ascii=False, separators=(',', ':')))
