"""Read exact native12 flight records; preserve every original failure."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'build/m52/recovery-flight-native-10'
RUN = ROOT / 'build/cooperation/48e9ff1838'
sys.path.insert(0, str(ROOT / 'experimental/recovery-flight-empty-frame'))
import analyze as flight


def main():
    result = json.loads((OUT / 'result.json').read_text(encoding='utf-8'))
    summary = json.loads((OUT / 'flight-summary.json').read_text(encoding='utf-8'))
    logs = {role: flight.load(RUN / (role + '.log'), role) for role in ('host', 'join')}
    cases = []
    for case in summary['cases']:
        trace = logs[case['remote_role']]['remote'][case['round']]
        rows = trace['frames']
        unique = []
        for row in rows:
            if row['clips'] and (not unique or unique[-1]['frame'] != row['frame']):
                unique.append(row)
        gaps = []
        for left, right in zip(unique, unique[1:]):
            gap = right['at'] - left['at']
            if gap < 70:
                continue
            between = [r for r in rows if left['at'] < r['at'] < right['at']]
            wire = [r for r in trace['wire'] if left['at'] < r['at'] <= right['at']]
            gaps.append(dict(ms=gap, before=dict(at=left['at'], frame=left['frame'], wall=left['wall']),
                after=dict(at=right['at'], frame=right['frame'], wall=right['wall']),
                intervening_render_rows=len(between),
                intervening_game_frames=sorted({r['frame'] for r in between if r['frame'] != left['frame']}),
                wire=[dict(at=r['at'], type=r['type'], samples=len(r['samples']),
                           sampleTime=r['sampleTime'], end=r['end']) for r in wire]))
        cases.append(dict(round=case['round'], weapon=case['weapon'],
            failed=[key for key, passed in case['checks'].items() if not passed],
            source_gap=case['source']['max_visible_gap_ms'], remote_gap=case['remote']['max_visible_gap_ms'],
            allowed_gap=case['allowed_visible_render_gap_ms'], start_lag_ms=case['start_lag_ms'],
            large_gaps=gaps))
    report = dict(native_passed=result['passed'], original_failures_preserved=True,
        performance_qualified=False, cases=cases,
        inputs={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (OUT / 'result.json', OUT / 'flight-summary.json', RUN / 'host.log', RUN / 'join.log')})
    target = HERE / 'review.json'
    assert not target.exists()
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(cases=cases, original_passed=result['passed']), ensure_ascii=False))


if __name__ == '__main__':
    main()
