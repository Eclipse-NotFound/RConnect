"""Text-only, bounded weapon-container experiment. No compiler or AIR entry.

--generate writes this directory's AS/JSON/diff only. --check verifies the
already materialized sources and their exact reverse transformations.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-22/src/rconnect/game'
HASHES = {
    'RemoteMotion.as': '5f0d0ba3b8de5ec1a08d392b4147f04a4d318c0bcdd0a2f7bbf236a5d28fc877',
    'WeaponDisplay.as': 'c76a6b157992398dbb8d8620de2482375594423226cd64b90e13e8fee96066f2',
    'TeleportVisuals.as': 'ec323ce52b1926e6cb1c98e722c78544cd396fa5b3661ba257111b4b703c272c',
}
ADAPTER = '''      // COMPONENT-ONLY ADAPTER; removed before exact source comparison.
      public static function componentBlend(first:Array,last:Array,t:Number):Array {
         return blendWeapons(first,last,t);
      }

'''
OLD = '''         var blended:Array=WeaponDisplay.interpolate(first,last,t),out:Array=[];
         for each(var a:Object in blended) {
            if(a.display!=null){out.push(a);continue;}
'''
NEW = '''         var blended:Array=WeaponDisplay.interpolate(first,last,t);
         for(var i:int=0;i<blended.length;i++) {
            var a:Object=blended[i];
            if(a.display!=null)continue;
'''
TAIL_OLD = '''            out.push(copy);
         }
         return out;
      }

      /** Shape-preserving cubic'''
TAIL_NEW = '''            blended[i]=copy;
         }
         return blended;
      }

      /** Shape-preserving cubic'''
ENTRY = 'WeaponContainerChecks.as'
EXPECTED = 70


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode('utf-8'))


def save_json(path, data):
    save(path, json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def rename(text, suffix):
    # Whole identifiers only: never replace names such as setCoopPaused.
    for name in ('RemoteMotion', 'TeleportVisuals'):
        text = re.sub(r'\b' + name + r'\b', name + suffix, text)
    return text


def restore(text, suffix):
    assert text.count(ADAPTER) == 1
    text = text.replace(ADAPTER, '')
    for name in ('RemoteMotion', 'TeleportVisuals'):
        text = re.sub(r'\b' + name + suffix + r'\b', name, text)
    return text


def originals():
    out = {}
    for name, digest in HASHES.items():
        raw = (BASE / name).read_bytes()
        assert sha(raw) == digest, ('accurate 22 source changed', name)
        out[name] = raw.decode('utf-8')
    return out


def candidate(original):
    assert original.count(OLD) == original.count(TAIL_OLD) == 1
    return original.replace(OLD, NEW).replace(TAIL_OLD, TAIL_NEW)


def derived_files(source):
    before = source['RemoteMotion.as']
    after = candidate(before)
    result = {'src/rconnect/game/RemoteMotion.as': after,
              'components/rconnect/game/WeaponDisplay.as': source['WeaponDisplay.as']}
    marker = '      private static function blendWeapons('
    for suffix, text in (('Before', before), ('After', after)):
        assert text.count(marker) == 1
        result[f'components/rconnect/game/RemoteMotion{suffix}.as'] = rename(
            text.replace(marker, ADAPTER + marker), suffix)
        result[f'components/rconnect/game/TeleportVisuals{suffix}.as'] = rename(
            source['TeleportVisuals.as'], suffix)
    return result


def verify(source):
    checks = []
    def check(ok, label):
        checks.append({'passed': bool(ok), 'label': label})
        assert ok, label
    derived = derived_files(source)
    for name, text in derived.items():
        check((HERE / name).read_bytes() == text.encode('utf-8'), name + ' exact derived bytes')
    before, after = source['RemoteMotion.as'], candidate(source['RemoteMotion.as'])
    check(after.replace(NEW, OLD).replace(TAIL_NEW, TAIL_OLD) == before,
          'candidate reverses to accurate 22 byte for byte; only container block changes')
    for suffix, expected in (('Before', before), ('After', after)):
        text = (HERE / f'components/rconnect/game/RemoteMotion{suffix}.as').read_bytes().decode('utf-8')
        check(restore(text, suffix) == expected, suffix + ' full class after adapter/name reversal')
    check(before.count('=blendWeapons(') == 1, 'one production call site')
    check('if(a.snap.weapons is Array && b.snap.weapons is Array)\n            state.weapons=blendWeapons(' in before,
          'production caller excludes null and non-Array operands')
    interpolate = source['WeaponDisplay.as'].split('public static function interpolate(', 1)[1].split('public function apply(', 1)[0]
    check('var result:Array=[];' in interpolate and 'return result;' in interpolate,
          'valid production operands always get a new result Array')
    check('result.push(a)' in interpolate and 'result.push(copy)' in interpolate and 'result[' not in interpolate,
          'interpolate produces dense ordered own indices, without exposing result to source')
    check('Infinity' not in (HERE / 'components' / ENTRY).read_text(encoding='utf-8'),
          'no infinite angle fixture can enter unchanged wrapping while loop')
    check('EXPECTED:int=' + str(EXPECTED) in (HERE / 'components' / ENTRY).read_text(encoding='utf-8'),
          'component expected count agrees with recipe')
    entry = (HERE / 'components' / ENTRY).read_text(encoding='utf-8')
    def body(name):
        start = entry.index('private function ' + name + '(')
        start = entry.index('{', start)
        depth = 1
        end = start + 1
        # Test method bodies contain no braces in string literals. The only
        # canonicalization braces are in the separate static canon method.
        while depth:
            depth += (entry[end] == '{') - (entry[end] == '}')
            end += 1
        return entry[start:end]
    counts = {name: len(re.findall(r'\bcheck\(', body(name))) for name in
              ('modern', 'compatibility', 'containers', 'edges', 'publicPaths', 'verifyBench')}
    check(counts == {'modern': 10, 'compatibility': 10, 'containers': 12,
                     'edges': 1, 'publicPaths': 8, 'verifyBench': 2},
          'assertion sites match fixed 10 + 10 + 12 + 12 + (4x4+4) + 6 plan')
    check('i<12' in body('edges') and '["actor","held","enemy","drop"]' in body('publicPaths')
          and '["modern","compatibility","mixed"]' in body('verifyBench'),
          'bounded loops produce exactly 70 planned runtime assertions')
    check('out:Array=[]' not in after.split('private static function blendWeapons(', 1)[1].split('/** Shape-preserving', 1)[0],
          'only redundant second container is removed, not compatibility copies')
    # No binary or extra production files are materialized.
    check([p.relative_to(HERE / 'src').as_posix() for p in (HERE / 'src').rglob('*') if p.is_file()]
          == ['rconnect/game/RemoteMotion.as'], 'one sparse production override')
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--generate', action='store_true')
    group.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source = originals()
    if args.generate:
        for name, text in derived_files(source).items():
            save(HERE / name, text)
        before, after = source['RemoteMotion.as'], candidate(source['RemoteMotion.as'])
        save(HERE / 'proposal.patch', ''.join(difflib.unified_diff(
            before.splitlines(True), after.splitlines(True),
            fromfile='recovery-22/src/rconnect/game/RemoteMotion.as',
            tofile='recovery-weapon-container/src/rconnect/game/RemoteMotion.as')))
    checks = verify(source)
    if args.generate:
        save_json(HERE / 'static-checks.json', {'passed': True, 'checks': checks,
                  'compiled': False, 'air_started': False, 'component_expected': EXPECTED})
        files = {p.relative_to(HERE).as_posix(): sha(p.read_bytes()) for p in sorted(HERE.rglob('*'))
                 if p.is_file() and p.name != 'inputs.json'}
        save_json(HERE / 'inputs.json', {'base': 'build/m52/recovery-22', 'base_source_sha256': HASHES,
                  'files': files, 'component_expected': EXPECTED,
                  'compiled': False, 'native_game_test': False, 'performance_qualified': False})
    else:
        manifest = json.loads((HERE / 'inputs.json').read_text(encoding='utf-8'))
        actual = {p.relative_to(HERE).as_posix(): sha(p.read_bytes()) for p in sorted(HERE.rglob('*'))
                  if p.is_file() and p.name != 'inputs.json'}
        assert actual == manifest['files'], 'manifest does not match exact text inputs'
    print(json.dumps({'static_passed': True, 'checks': len(checks), 'component_expected': EXPECTED,
                      'compiled': False, 'air_started': False}, ensure_ascii=False))


if __name__ == '__main__':
    main()
