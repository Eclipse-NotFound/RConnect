"""Read native host/join WeaponPoseProbe traces; never launch or modify a game.

Run: python -B analyze_weapon_pose.py <build/cooperation/run-id>
No use of `completed` as a substitute for visible-pose evidence. Frame counts,
reflection checks and source/remote motion are independently derived from rows.
"""
from pathlib import Path
import argparse
import bisect
import hashlib
import json
import math
import re
import statistics

FIELDS = ('a', 'b', 'c', 'd', 'x', 'y')

def finite_matrix(values):
    return isinstance(values, list) and len(values) == 6 and all(
        isinstance(x, (int, float)) and math.isfinite(x) for x in values)

def determinant(matrix):
    return matrix[0] * matrix[3] - matrix[1] * matrix[2]

def signature(matrix):
    det = determinant(matrix)
    return -1 if det < -1e-6 else 1 if det > 1e-6 else 0

def distance(a, b):
    # Linear matrix terms convert into px at the tip of a 100 px weapon.
    linear = sum((a[i] - b[i]) ** 2 for i in range(4)) * 10000
    return math.sqrt(linear + (a[4] - b[4]) ** 2 + (a[5] - b[5]) ** 2)

def angles(matrix):
    return math.atan2(matrix[1], matrix[0])

def angle_delta(a, b):
    return (b - a + math.pi) % (2 * math.pi) - math.pi

def decode(matrix):
    sx = math.hypot(matrix[0], matrix[1])
    return (angles(matrix), sx, determinant(matrix) / sx if sx > 1e-9 else 0)

def pose_between(a, b, amount):
    """Independent interpolation of the recorded native display transforms.
    Reflection changes are discrete, matching actual authored state selection.
    This helper does not call or read the product's interpolation output.
    """
    if amount >= 1:
        return b
    ar, ax, ay = decode(a)
    br, bx, by = decode(b)
    angle = ar + angle_delta(ar, br) * amount
    # Product capture preserves scale/handedness from the selected source pose.
    c, s = math.cos(angle), math.sin(angle)
    return [c * ax, s * ax, -s * ay, c * ay,
            a[4] + (b[4] - a[4]) * amount, a[5] + (b[5] - a[5]) * amount]

def actor_rows(data, ident):
    result = []
    for row in data.get('rows', []):
        for actor in row.get('actors', []):
            if actor.get('id') != ident or not actor.get('onStage'):
                continue
            if not finite_matrix(actor.get('matrix')):
                continue
            result.append(dict(age=row['age'], at=row['at'], matrix=actor['matrix'],
                               visible=actor.get('visible'), frames=actor.get('frames', []),
                               native_attack=actor.get('attack')))
    return result

def clip_paths(frames):
    # Flash auto instance numbers differ across separate processes. Preserve
    # authored names; map anonymous siblings by encounter order in this frame.
    # Never call differently named authored clips the same track.
    branches = {}
    result = []
    for clip in frames:
        original = clip['path'].split('/')
        canonical = ''
        raw_parent = ''
        for part in original:
            if not part:
                continue
            if re.fullmatch(r'instance\d+', part):
                siblings = branches.setdefault(raw_parent, {})
                token = siblings.setdefault(part, '@'+str(len(siblings)))
            else:
                token = part
            raw_parent += '/'+part
            canonical += '/'+token
        result.append(dict(clip, path=canonical))
    return result

def summary(rows):
    moving = [r for r in rows if 1200 <= r['age'] < 13000]
    repeated = changes = 0
    longest_repeat_ms = repeat_start = 0
    signs = set()
    transitions = []
    clips = {}
    for i, row in enumerate(moving):
        signs.add(signature(row['matrix']))
        if i:
            previous = moving[i-1]
            if signature(previous['matrix']) != signature(row['matrix']):
                transitions.append(row['age'])
            if distance(previous['matrix'], row['matrix']) < .05:
                repeated += 1
                if not repeat_start:
                    repeat_start = previous['age']
                longest_repeat_ms = max(longest_repeat_ms, row['age'] - repeat_start)
            else:
                changes += 1
                repeat_start = 0
        for clip in clip_paths(row['frames']):
            key = clip['path'] + '|' + clip['cls']
            item = clips.setdefault(key, {'path': clip['path'], 'class': clip['cls'],
                                         'total': clip['total'], 'samples': 0, 'changes': 0, 'seen': set()})
            if item['samples'] and item.get('last') != clip['frame']:
                item['changes'] += 1
            item['samples'] += 1
            item['last'] = clip['frame']
            item['seen'].add(clip['frame'])
    for item in clips.values():
        item['distinct_frames'] = sorted(item.pop('seen'))
        item.pop('last', None)
    return {'rendered_samples': len(rows), 'active_samples': len(moving),
            'positive_determinant': sum(signature(r['matrix']) == 1 for r in moving),
            'negative_determinant': sum(signature(r['matrix']) == -1 for r in moving),
            'singular_matrices': sum(signature(r['matrix']) == 0 for r in moving),
            'handedness': sorted(signs), 'flip_ages_ms': transitions,
            'native_or_remote_changed_frames': changes,
            'same_pose_frames': repeated, 'longest_same_pose_ms': longest_repeat_ms,
            'clip_frames': list(clips.values())}

def fit_native_timeline(source, remote):
    """A measured alignment, not a claimed private RemoteMotion cursor.
    Both age clocks start at the probe start handshake; fit a single lag from
    actual matrices. Preserve fit error so an unsupported alignment is obvious.
    """
    if len(source) < 2 or not remote:
        return {'available': False}
    times = [r['age'] for r in source]
    usable = [r for r in remote if 1600 <= r['age'] < 12500]
    if not usable:
        return {'available': False}
    def expected(age):
        i = bisect.bisect_right(times, age) - 1
        if i < 0 or i + 1 >= len(source):
            return None
        a, b = source[i], source[i+1]
        gap = b['age'] - a['age']
        if gap <= 0:
            return a['matrix']
        return pose_between(a['matrix'], b['matrix'], (age - a['age']) / gap)
    candidates = []
    # Sample all frames at coarse 5 ms resolution. No external source fixtures.
    for lag in range(-100, 801, 5):
        errors = [distance(r['matrix'], e) for r in usable
                  if (e := expected(r['age'] - lag)) is not None]
        if errors:
            candidates.append((statistics.median(errors), lag))
    if not candidates:
        return {'available': False}
    _, lag = min(candidates)
    errors = []
    wrong_reflection = eligible = missed_motion = 0
    previous = None
    for row in usable:
        target = expected(row['age'] - lag)
        if target is None:
            continue
        errors.append(distance(row['matrix'], target))
        eligible += 1
        wrong_reflection += signature(row['matrix']) != signature(target)
        if previous:
            prev_row, prev_target = previous
            # Count additional held frames only where real native artwork moved.
            if distance(prev_target, target) > .5 and distance(prev_row['matrix'], row['matrix']) < .05:
                missed_motion += 1
        previous = row, target
    errors.sort()
    return {'available': True, 'estimated_common_lag_ms': lag,
            'at_search_boundary': lag in (-100, 800),
            'median_tip_equivalent_error_px': statistics.median(errors),
            'p95_tip_equivalent_error_px': errors[min(len(errors)-1, int(len(errors)*.95))],
            'compared_frames': eligible, 'reflection_mismatch_frames': wrong_reflection,
            'remote_held_while_aligned_native_moved': missed_motion,
            'note': 'Fit from real observed matrices; not the private source cursor or a performance score.'}

def analyze(host, join):
    output = {'kind': 'native-enemy-weapon-pose-analysis', 'checks': [], 'actors': [],
              'boundary': 'Structural visual assertions and actual frame counts; completed is reported separately, never used to pass these checks.'}
    def check(name, ok, evidence):
        output['checks'].append({'name': name, 'ok': bool(ok), 'evidence': evidence})
    check('Correct native probe traces', host.get('kind') == join.get('kind') == 'native-enemy-weapon-pose',
          [host.get('kind'), join.get('kind')])
    check('Both roles present', host.get('role') == 'host' and join.get('role') == 'join',
          [host.get('role'), join.get('role')])
    output['driver_status'] = {role: {'completed': data.get('completed'), 'error': data.get('error')}
                               for role, data in [('host', host), ('join', join)]}
    specs = host.get('specs', [])
    check('Real source weapon fixtures recorded', len(specs) >= 4, specs)
    for spec in specs:
        ident = spec['id']
        source_rows, remote_rows = actor_rows(host, ident), actor_rows(join, ident)
        source, remote = summary(source_rows), summary(remote_rows)
        fit = fit_native_timeline(source_rows, remote_rows)
        output['actors'].append({'id': ident, 'weapon': spec['weapon'], 'source': source,
                                 'remote': remote, 'timeline_fit': fit})
        check(ident + ': source and remote genuinely on stage', bool(source_rows) and bool(remote_rows),
              [len(source_rows), len(remote_rows)])
        check(ident + ': source has both true determinant signs', source['handedness'] == [-1, 1], source['handedness'])
        check(ident + ': remote has both true determinant signs', remote['handedness'] == [-1, 1], remote['handedness'])
        check(ident + ': no rendered singular weapon matrices', bool(source_rows) and bool(remote_rows) and source['singular_matrices'] == remote['singular_matrices'] == 0,
              [source['singular_matrices'], remote['singular_matrices']])
        check(ident + ': native and remote actual pose changes observed',
              source['native_or_remote_changed_frames'] > 0 and remote['native_or_remote_changed_frames'] > 0,
              [source['native_or_remote_changed_frames'], remote['native_or_remote_changed_frames']])
        fast = [p for p in join.get('wire', []) if p.get('id') == ident and p.get('stream') == 'enemyMotion']
        check(ident + ': every observed frequent packet has native transform', bool(fast) and all(p.get('display') is not None for p in fast), len(fast))
        if ident in ('weaponpose_club', 'weaponpose_laser'):
            check(ident + ': frequent packets carry real melee history', bool(fast) and all(p.get('meleeCount', 0) > 0 for p in fast),
                  {'packets': len(fast), 'with_history': sum(p.get('meleeCount', 0) > 0 for p in fast)})
            source_tracks = {p['path']+'|'+p['class']: p for p in source['clip_frames']}
            remote_tracks = {p['path']+'|'+p['class']: p for p in remote['clip_frames']}
            # Only demand animation where the native source really changed.
            for key, track in source_tracks.items():
                if track['changes'] > 0:
                    seen = remote_tracks.get(key)
                    check(ident + ': source-changing clip also changes remotely: '+track['path'],
                          seen is not None and seen['changes'] > 0,
                          {'source_changes': track['changes'], 'remote_changes': None if seen is None else seen['changes']})
    output['structural_visual_checks_passed'] = all(c['ok'] for c in output['checks'])
    output['overall_smoothness_qualified'] = False
    return output

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    paths = {r: args.run/'logs'/r/'stutter-result.json' for r in ('host', 'join')}
    data = {r: json.loads(p.read_text(encoding='utf-8-sig')) for r, p in paths.items()}
    result = analyze(data['host'], data['join'])
    result['inputs'] = {r: {'path': str(p.resolve()), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for r, p in paths.items()}
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
