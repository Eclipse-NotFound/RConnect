"""Read-only source and provenance check. Never starts a compiler or AIR."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-room-production-05'
V1 = ROOT / 'experimental/goal-remote-motion-current'
V1_PRODUCT = ROOT / 'build/m52/goal-remote-motion-current-product-01'
REL = 'rconnect/game/RemoteMotion.as'
PRODUCT_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
V1_SHA = '89f1b9235b809c1595559ede873b763dc15f9ca7c393c82231c48981b1d78215'
CANDIDATE_SHA = '3c8bcb917d4b3fa2108b2d7a6c195728b3e61443d2ab6fd658351dc39a9c509e'
VERSION = '0.2.24-motionclock2'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def data(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def normalized(path):
    return path.read_text(encoding='utf-8-sig')


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def diff(before, after, before_name, after_name):
    return ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                      fromfile=before_name, tofile=after_name))


def recorded_source(slices):
    lines = ['package {', '   /** Exact first 3000ms of each recorded join window; no invented prefix. */',
             '   public class RecordedMotionInputs {']
    for name, item in slices.items():
        value = {key: item[key] for key in ('startedAt', 'arrivals', 'displays')}
        lines.append('      public static const ' + name.upper() + ':Object=' +
                     json.dumps(value, separators=(',', ':')) + ';')
    return '\n'.join(lines + ['   }', '}']) + '\n'


def verify():
    manifest = data(HERE / 'source-manifest.json')
    for name, digest in manifest['inputs'].items():
        assert sha(ROOT / name) == digest, 'Pinned input changed: ' + name
    actual = {name: digest for name, digest in inventory(HERE).items() if name != 'source-manifest.json'}
    assert actual == manifest['files'], 'Frozen package changed'
    base_meta, base_compile = [data(BASE / p) for p in ('prepared.json', 'compile.json')]
    assert manifest['base_source'] == base_meta['source'] == inventory(BASE / 'src')
    assert len(manifest['base_source']) == 81 and base_meta['inputs'] == inventory(BASE / 'tools')
    assert base_compile['compiled'] is True and base_compile['candidate_sha256'] == PRODUCT_SHA
    assert sha(BASE / 'RConnectMod.swf') == sha(ROOT / 'release/RConnectMod.swf') == PRODUCT_SHA
    assert data(V1_PRODUCT / 'compile.json')['compiled'] is True
    assert data(V1_PRODUCT / 'compile.json')['candidate_sha256'] == sha(V1_PRODUCT / 'RConnectMod.swf') == V1_SHA
    assert (V1_PRODUCT / 'src' / REL).read_bytes() == (V1 / 'src' / REL).read_bytes()
    assert sha(HERE / 'src' / REL) == CANDIDATE_SHA
    assert (HERE / 'src' / REL).read_bytes() == (HERE / 'components' / REL).read_bytes()
    # Outside one scalar and the four lifecycle/clock bodies, v1 is exact:
    # interval tangent freezing, geometry, drop policy and public API remain.
    before, after = normalized(V1 / 'src' / REL), normalized(HERE / 'src' / REL)
    before = before.replace('      private var playbackRate:Number=1;',
        '      private var playbackRate:Number=1;\n'
        '      // Offset improvements are owed source time, repaid only on later frames.\n'
        '      private var calibrationDebt:Number=0;', 1)
    for start, end in [('      public function push(', '      public function sample('),
                       ('      public function settle(', '      private function pushTimed('),
                       ('      private function pushTimed(', '      private function delay('),
                       ('      private function sampleTimed(', '      /** Blit bodies')]:
        a0, a1 = before.index(start), before.index(end)
        b0, b1 = after.index(start), after.index(end)
        before = before[:a0] + after[b0:b1] + before[a1:]
    assert before == after, 'Unexpected production function change'
    entry = (BASE / 'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomfix5') == 1
    assert (HERE / 'src/RConnectMod.as').read_bytes() == entry.replace(b'0.2.24-roomfix5', VERSION.encode())
    changed = {'RConnectMod.as', REL}
    assert set(inventory(HERE / 'src')) == changed
    expected_source = dict(manifest['base_source'])
    expected_changes = {}
    for name in sorted(changed):
        expected_source[name] = sha(HERE / 'src' / name)
        expected_changes[name] = dict(base_sha256=manifest['base_source'][name], candidate_sha256=expected_source[name])
    assert manifest['candidate_source'] == expected_source and manifest['changes'] == expected_changes
    assert sum(expected_source[n] == h for n, h in manifest['base_source'].items()) == 79
    assert manifest['base_sha256'] == PRODUCT_SHA and manifest['version'] == VERSION
    expected_diff = ''.join(diff(normalized(BASE / 'src' / name), normalized(HERE / 'src' / name),
        'production05/src/' + name, 'overlay/src/' + name) for name in sorted(changed))
    assert normalized(HERE / 'source.diff') == expected_diff
    entry_name = 'MotionContinuityChecks.as'
    old_entry = normalized(V1 / 'components' / entry_name)
    marker = '            MotionCadenceRegression.run(check);'
    assert old_entry.count(marker) == 1
    assert normalized(HERE / 'components' / entry_name) == old_entry.replace(marker, marker + '\n            ClockDebtRegression.run(check);')
    fixtures = inventory(V1 / 'components')
    unchanged = set(fixtures) - {entry_name, REL}
    assert set(manifest['fixture_unchanged']) == unchanged
    for name in unchanged:
        assert (HERE / 'components' / name).read_bytes() == (V1 / 'components' / name).read_bytes()
    assert set(inventory(HERE / 'components')) == set(fixtures) | {'ClockDebtRegression.as', 'RecordedMotionInputs.as'}
    slices = data(HERE / 'recorded-slices.json')
    original = data(ROOT / 'experimental/goal-motion-clock-review/replay-inputs.json')['observed_partial']
    for label in ('baseline', 'candidate'):
        item = original[label]['join']
        expected = dict(item)
        for field in ('arrivals', 'displays'):
            expected[field] = [row for row in item[field] if row[0] <= item['startedAt'] + 3000]
        assert slices[label] == expected
        raw = ROOT / ('build/m52/goal-three-issues-native-jump-' + label + '-01/join-measurements.json')
        assert sha(raw) == item['raw_sha256']
        measured = data(raw)[0]
        snapshots = [dict(at=p['at'], **s) for p in measured['incoming'] for s in p['snapshots']]
        assert item['arrivals'] == [[s[k] for k in ('at', 'sampleTime', 'x', 'y', 'dx', 'dy', 'stay')] for s in snapshots]
        assert item['displays'] == [[v['at'], v['frameAt'], v['peer']['vx'], v['peer']['vy'], v['peer']['dy'], v['peer']['stay'], v['peer']['pose']] for v in measured['render']]
    assert normalized(HERE / 'components/RecordedMotionInputs.as') == recorded_source(slices)
    # Thin entry points are literally the v1 bounded compiler binding.
    for name in ('prepare.py', 'build.py'):
        assert (HERE / name).read_bytes() == (V1 / name).read_bytes()
    for name in ('check.py', 'prepare.py', 'build.py'):
        ast.parse(normalized(HERE / name))
    assert manifest['expected_component_assertions'] == 68
    return dict(source_check_passed=True, base_sha256=PRODUCT_SHA, version=VERSION,
                candidate_source_sha256=CANDIDATE_SHA, unchanged_source_count=79,
                expected_component_assertions=68, old_assertions_unchanged=37,
                compiled_here=False, air_started_here=False, performance_qualified=False)


if __name__ == '__main__':
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
