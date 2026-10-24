"""Read-only identity/fixture verification; never starts compiler or AIR."""
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
OLD = ROOT / 'build/m52/motion2-clock-candidate-01'
REL = 'rconnect/game/RemoteMotion.as'
BASE_SHA = '19f035bfccb5a035fdb9df84c364db3a2eb845e2c002d825f8ed0665517174aa'
CANDIDATE_SHA = 'd2688b30bff412d9142835b059e73a256c0c45935235f0cefbd4d167297598cd'
PRODUCT_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
VERSION = '0.2.24-motionclock1'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def data(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def normalized(path):
    return path.read_text(encoding='utf-8-sig')


def diff(before, after, before_name, after_name):
    return ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                      fromfile=before_name, tofile=after_name))


def output_adapter(text):
    replacements = [
        ('{checks:checks,fail:failures,pass:checks.length-failures,gameLoaded:false}',
         '{assertions:checks,failed:failures,passed:failures==0,gameLoaded:false}'),
        ('checks.push({pass:ok,label:label});', 'checks.push({passed:ok,label:label});'),
    ]
    for before, after in replacements:
        assert text.count(before) == 1
        text = text.replace(before, after)
    return text


def verify():
    manifest = data(HERE / 'source-manifest.json')
    for name, digest in manifest['inputs'].items():
        assert sha(ROOT / name) == digest, 'Input changed: ' + name
    actual = {p.relative_to(HERE).as_posix(): sha(p) for p in HERE.rglob('*')
              if p.is_file() and p.name != 'source-manifest.json'}
    assert actual == manifest['files'], 'Candidate package changed'
    for name, digest in manifest['base_source'].items():
        assert sha(BASE / 'src' / name) == digest, 'Base source changed: ' + name
    base_meta = data(BASE / 'prepared.json')
    assert base_meta['source'] == manifest['base_source'] and len(manifest['base_source']) == 81
    assert {p.relative_to(BASE / 'tools').as_posix(): sha(p) for p in (BASE / 'tools').rglob('*')
            if p.is_file()} == base_meta['inputs']
    compile_record = data(BASE / 'compile.json')
    assert compile_record['compiled'] is True and compile_record['candidate_sha256'] == PRODUCT_SHA
    assert sha(BASE / 'RConnectMod.swf') == PRODUCT_SHA
    assert sha(ROOT / 'release/RConnectMod.swf') == PRODUCT_SHA, 'Installed RConnect is no longer 78C'
    assert sha(BASE / 'src' / REL) == BASE_SHA
    assert sha(ROOT / 'build/m52/motion2-clock-baseline-01/src' / REL) == BASE_SHA
    assert sha(HERE / 'src' / REL) == CANDIDATE_SHA == sha(OLD / 'src' / REL)
    assert (HERE / 'components' / REL).read_bytes() == (HERE / 'src' / REL).read_bytes()
    before, after = normalized(BASE / 'src' / REL), normalized(HERE / 'src' / REL)
    # Exactly the two previously tested function bodies may differ. Fixed SHA
    # above pins the particular correction; this is not a general allowlist.
    for start, end in [('      private function pushTimed(', '      private function delay('),
                       ('      private function curve(', '      private static function tangent(')]:
        a0, a1 = before.index(start), before.index(end)
        b0, b1 = after.index(start), after.index(end)
        before = before[:a0] + after[b0:b1] + before[a1:]
    assert before == after, 'Unexpected production changes'
    entry_bytes = (BASE / 'src/RConnectMod.as').read_bytes()
    assert entry_bytes.count(b'0.2.24-roomfix5') == 1
    assert (HERE / 'src/RConnectMod.as').read_bytes() == entry_bytes.replace(b'0.2.24-roomfix5', VERSION.encode())
    changed = {'RConnectMod.as', REL}
    assert {p.relative_to(HERE / 'src').as_posix() for p in (HERE / 'src').rglob('*.as')} == changed
    expected_diff = ''.join(diff(normalized(BASE / 'src' / name), normalized(HERE / 'src' / name),
        'production05/src/' + name, 'overlay/src/' + name) for name in sorted(changed))
    assert normalized(HERE / 'source.diff') == expected_diff
    expected_source = dict(manifest['base_source'])
    expected_changes = {}
    for name in sorted(changed):
        expected_source[name] = sha(HERE / 'src' / name)
        expected_changes[name] = {'base_sha256': manifest['base_source'][name],
                                  'candidate_sha256': expected_source[name]}
    assert manifest['changes'] == expected_changes and manifest['candidate_source'] == expected_source
    assert manifest['base_sha256'] == PRODUCT_SHA and manifest['version'] == VERSION
    assert sum(expected_source[n] == h for n, h in manifest['base_source'].items()) == 79
    entry = 'MotionContinuityChecks.as'
    assert normalized(HERE / 'components' / entry) == output_adapter(normalized(OLD / 'src' / entry))
    for name in manifest['fixture_unchanged']:
        assert (HERE / 'components' / name).read_bytes() == (OLD / 'src' / name).read_bytes()
    assert normalized(HERE / 'component-output.diff') == diff(normalized(OLD / 'src' / entry),
        normalized(HERE / 'components' / entry), 'old/' + entry, 'components/' + entry)
    for old_name, passed, failed in [('motion2-clock-baseline-01', 31, 6), ('motion2-clock-candidate-01', 37, 0)]:
        folder = ROOT / 'build/m52' / old_name
        receipt, result = data(folder / 'receipt.json'), data(folder / 'result.json')
        assert receipt['passed'] == passed and receipt['failed'] == failed
        assert len(result['checks']) == 37 and sum(row['pass'] is True for row in result['checks']) == passed
        assert receipt['source_unchanged'] is True and receipt['installation_unchanged'] is True
        assert receipt['native_game_pass'] is False
    for script in ('check.py', 'prepare.py', 'build.py'):
        ast.parse((HERE / script).read_text(encoding='utf-8'))
    return {'source_check_passed': True, 'base_sha256': PRODUCT_SHA,
            'version': VERSION, 'production_changed_classes': sorted(changed),
            'unchanged_source_count': 79, 'candidate_source_sha256': CANDIDATE_SHA,
            'expected_component_assertions': 37, 'component_executed_here': False,
            'native_game_tested_here': False, 'performance_qualified': False}


if __name__ == '__main__':
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
