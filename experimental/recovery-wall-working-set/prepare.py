"""Materialize a three-constant overlay and source-derived AIR checks. No JVM/AIR.

Only files below this directory are written. Never edits the frozen recovery-07.
"""
from pathlib import Path
import argparse
import base64
import difflib
import hashlib
import json
import zlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-07'
LOG = ROOT / 'build/cooperation/5314f8125d/join.log'
BASE_SHA = 'c9f6492117124dea23a6991396cf9957d7b73a9730b747b4c8b1cad9533ca3bc'
LOG_SHA = '7b6cb1d4d0a71bfe0a4bc7a5baad6e55bc8114c7278fe253c74da88bd1c268a5'
WALL = 'rconnect/game/WallImpactVisuals.as'
CODEC = 'rconnect/net/RoomCodec.as'
COUNTER = '         WorkingSetCounter.unpack++; // WORKING_SET_COUNT_ONLY\n'
BRIDGE = '''      // WORKING_SET_TEST_ACCESS_BEGIN: wrappers only; production methods unchanged.
      public function testWords(data:String):Array {return decodeWords(data);}
      public function testCells(loc:Object,list:Array,limit:Boolean=true):Array {return decode(loc,list,limit);}
      public function testStats():Object {return {entries:wordOrder.length,words:wordCount,chars:wordChars};}
      public function testDispose():void {reset();scratchA.dispose();scratchB.dispose();}
      // WORKING_SET_TEST_ACCESS_END
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(name, value):
    path = (HERE / name).resolve()
    assert path.is_relative_to(HERE)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8', newline='\n')


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def records():
    assert sha(LOG) == LOG_SHA
    payloads, rows, header, done = [], [], None, None
    for line in LOG.read_text(encoding='utf-8-sig').splitlines():
        if 'FLIGHT DIAG ' not in line:
            continue
        tag, raw = line.split('FLIGHT DIAG ', 1)[1].split(' ', 1)
        obj = json.loads(raw)
        if tag == 'HEADER':
            assert header is None
            header = obj
        elif tag == 'ROWS':
            assert obj['from'] == len(rows)
            rows.extend(obj['rows'])
        elif tag == 'PAYLOAD':
            assert obj['id'] == len(payloads)
            payloads.append(obj)
        elif tag == 'DONE':
            done = obj
    assert header['complete'] and done['complete'] and len(rows) == 33741
    assert len(payloads) == 82 and header['wallMiss'] == 1276
    bins = [r for r in rows if r[0] == 6]
    assert bins[-1][11] == 0, 'Unexpected cache reset'
    events = [r for r in rows if r[0] == 7 and r[7] == 8]
    assert len(events) == 1276 and {r[6] for r in events} == {12}
    assert events[0][11:14] == [0, 0, 0], 'First recorded miss must start from an empty cache'
    assert {int(r[8]) for r in events} == set(range(82))
    for p in payloads:
        assert p['chars'] == len(p['data'])
        values = json.loads(zlib.decompress(base64.b64decode(p['data'])))
        assert len(values) % 2 == 0 and len(values) <= 3200
        assert all(type(v) is int for v in values)
        assert all(0 <= n < 1600 for n in values[::2])
        assert all(a < b for a, b in zip(values[::2], values[2::2]))
        assert all(0 <= n <= 4294967295 for n in values[1::2])
        p['words'] = len(values)
    return {'schema': 1, 'sourceLog': str(LOG), 'sourceLogSHA256': LOG_SHA,
            'role': 'join', 'owner': 12, 'payloads': payloads,
            'missOrder': [{'payload': int(r[8]), 'case': int(r[4]), 'at': int(r[1])} for r in events],
            'omittedReadOnlyHits': 1147, 'omittedProtectedDecodes': 122,
            'originalMisses': 1276, 'expectedCandidateMisses': 82,
            'scope': 'Exact observed miss order. Hit order was not logged; hits do not reorder FIFO. Protected direct unpack is outside this cache.'}


def derived(text, suffix):
    text = replace_once(text, 'class WallImpactVisuals', 'class Wall' + suffix)
    text = replace_once(text, 'function WallImpactVisuals(', 'function Wall' + suffix + '(')
    return replace_once(text, '      public function reset():void', BRIDGE + '      public function reset():void')


def materialize():
    assert sha(BASE / 'RConnectMod.swf') == BASE_SHA
    manifest = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
    for name in [WALL, CODEC]:
        assert sha(BASE / 'src' / name) == manifest['source'][name]
    old = (BASE / 'src' / WALL).read_text(encoding='utf-8-sig')
    new = old
    for name, a, b in [('ENTRIES', 64, 128), ('WORDS', 32768, 131072), ('CHARS', 131072, 524288)]:
        new = replace_once(new, f'WORD_CACHE_{name}:int={a};', f'WORD_CACHE_{name}:int={b};')
    write('src/' + WALL, new)
    write('components/rconnect/game/WallBefore.as', derived(old, 'Before'))
    write('components/rconnect/game/WallAfter.as', derived(new, 'After'))
    codec = (BASE / 'src' / CODEC).read_text(encoding='utf-8-sig')
    codec = replace_once(codec, '      public static function unpack(s:String):Object\n      {\n',
                         '      public static function unpack(s:String):Object\n      {\n' + COUNTER)
    write('components/' + CODEC, codec)
    write('components/rconnect/net/WorkingSetCounter.as',
          'package rconnect.net {public class WorkingSetCounter {public static var unpack:int=0;}}\n')
    write('components/rconnect/core/Log.as',
          'package rconnect.core {public class Log {public static var calls:int=0;public static function d(s:String):void{calls++;}}}\n')
    write('components/rconnect/game/GameBridge.as',
          'package rconnect.game {public class GameBridge {public static function probe(o:Object,k:String):*{try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}}}\n')
    fixture = ROOT / 'experimental/recovery-cost/components/fe/weapon/Bullet.as'
    write('components/fe/weapon/Bullet.as', fixture.read_text(encoding='utf-8-sig'))
    data = records()
    write('data/flight-payloads.json', json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    patch = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                    fromfile='recovery-07/src/' + WALL, tofile='overlay/src/' + WALL))
    write('proposal.patch', patch)
    inputs = {'baseline': str(BASE), 'baselineSHA256': BASE_SHA, 'JVMStarted': False, 'AIRStarted': False,
              'sourceInputs': {str(BASE / 'src' / n): sha(BASE / 'src' / n) for n in [WALL, CODEC]},
              'logSHA256': LOG_SHA, 'fixtureInput': {str(fixture): sha(fixture)},
              'payloads': 82, 'traceMisses': 1276,
              'outputs': {p.relative_to(HERE).as_posix(): sha(p) for folder in ['src', 'components', 'data']
                          for p in sorted((HERE / folder).rglob('*')) if p.is_file()},
              'recipeSHA256': sha(__file__), 'patchSHA256': sha(HERE / 'proposal.patch')}
    write('inputs.json', json.dumps(inputs, indent=2, ensure_ascii=False) + '\n')
    verify()


def verify():
    m = json.loads((HERE / 'inputs.json').read_text(encoding='utf-8-sig'))
    assert sha(BASE / 'RConnectMod.swf') == BASE_SHA and sha(LOG) == LOG_SHA
    for file, digest in {**m['sourceInputs'], **m['fixtureInput']}.items():
        assert sha(file) == digest
    for name, digest in m['outputs'].items():
        assert sha(HERE / name) == digest, name
    actual = {p.relative_to(HERE).as_posix() for folder in ['src', 'components', 'data']
              for p in (HERE / folder).rglob('*') if p.is_file()}
    assert actual == set(m['outputs']), 'Unlisted overlay/component input'
    old = (BASE / 'src' / WALL).read_text(encoding='utf-8-sig')
    new = (HERE / 'src' / WALL).read_text(encoding='utf-8')
    for suffix, production in [('Before', old), ('After', new)]:
        copy = (HERE / ('components/rconnect/game/Wall' + suffix + '.as')).read_text(encoding='utf-8')
        plain = copy.replace(BRIDGE, '').replace('class Wall' + suffix, 'class WallImpactVisuals').replace(
            'function Wall' + suffix + '(', 'function WallImpactVisuals(')
        assert plain == production, 'Test differs beyond rename/access wrappers'
    plain = (HERE / 'components' / CODEC).read_text(encoding='utf-8').replace(COUNTER, '')
    assert plain == (BASE / 'src' / CODEC).read_text(encoding='utf-8-sig')
    restored = new
    for name, a, b in [('ENTRIES', 64, 128), ('WORDS', 32768, 131072), ('CHARS', 131072, 524288)]:
        restored = restored.replace(f'WORD_CACHE_{name}:int={b};', f'WORD_CACHE_{name}:int={a};')
    assert restored == old, 'Production change exceeds three constants'
    assert sha(__file__) == m['recipeSHA256'] and sha(HERE / 'proposal.patch') == m['patchSHA256']
    print(json.dumps({'verified': True, 'production_changes': 'three cache constants',
                      'payloads': 82, 'recorded_miss_order': 1276, 'JVMStarted': False, 'AIRStarted': False}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    verify() if args.verify else materialize()
