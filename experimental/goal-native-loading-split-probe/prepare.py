"""Read-only source/ABI check. This file never builds or launches anything."""
from pathlib import Path
import argparse
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-entry-observer-driver-01'
BASE_SHA = 'ae5c4035054e4474baa94a1003b0d9a32261bc8df82be0edd09255bdc69abc55'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(value, message):
    if not value:
        raise RuntimeError(message)


def method(text, name):
    start = re.search(r'\bfunction\s+' + re.escape(name) + r'\s*\(', text)
    require(start is not None, 'Missing method ' + name)
    opening = text.index('{', start.end())
    depth = 1
    index = opening + 1
    while depth and index < len(text):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
        index += 1
    require(depth == 0, 'Unclosed method ' + name)
    return text[start.start():index]


def verify():
    manifest = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    require(sha(BASE / 'prepared.json') == BASE_SHA, 'Frozen base receipt changed')
    base = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8'))
    expected = {k: v for k, v in base['files'].items() if k.startswith('tests/') and k.endswith('.as')}
    require(len(expected) == 17 and manifest['original_sources'] == expected, 'Original source set changed')
    actual_paths = {p.relative_to(HERE).as_posix() for p in (HERE / 'tests').rglob('*.as')}
    require(actual_paths == set(expected), 'Unexpected or missing AS file')
    changed = []
    for name, digest in expected.items():
        require(sha(BASE / name) == digest, 'Historical source changed: ' + name)
        if sha(HERE / name) != digest:
            changed.append(name)
    require(changed == ['tests/RoomEntryProbe.as'], 'Only display observer may change')
    for name, digest in manifest['files'].items():
        require(sha(HERE / name) == digest, 'Prepared source changed: ' + name)
    for name, digest in manifest['dependencies'].items():
        require(sha(ROOT / name) == digest, 'Historical ABI/harness changed: ' + name)
    before = (BASE / 'tests/RoomEntryProbe.as').read_text(encoding='utf-8')
    after = (HERE / 'tests/RoomEntryProbe.as').read_text(encoding='utf-8')
    preserved = ['RoomEntryProbe', 'check', 'require', 'watch', 'observeConnection',
                 'observeLink', 'confirmationView', 'capture']
    for name in preserved:
        require(method(before, name) == method(after, name), 'Non-display method changed: ' + name)
    require(not re.search(r'\brconnectLoadingView\s*\(', after), 'Observer must not acquire a display lease')
    for original in [
        'require(!rooms.accepts(confirmedStamp),"new native room rejects previous room state");',
        'require(!rooms.canSyncWorld,"new native room cannot publish before handoff");',
        'require(w.loc===mod.game.loc && w.land.loc===w.loc && w.gg.loc===w.loc,"first released frame has one native room identity");',
        'var scalarParity:Object=RoomScalarParity.run(mod.game.world);',
        'check(scalarParity.objects>0 && scalarParity.fields>0 && scalarParity.differences.length==0,',
        'var pending:Boolean=!rooms.ready || !sameConfirmed;'
    ]:
        require(before.count(original) == 1 and after.count(original) == 1, 'Original assertion missing or duplicated')
    require(after.count('stationaryUntil=getTimer()+2000;') == 1, 'Stationary observation contract changed')
    require('getTimer()-at>2500' in (HERE / 'tests/RoomCooperationTestDoc.as').read_text(), 'Original stationary hold missing')
    return {'kind': 'native-loading-split-probe-source', 'source_checked': True,
            'entry': str(HERE / 'tests/A22RoomEntryTestDoc.as'), 'source_path': str(HERE / 'tests'),
            'original_sources': 17, 'byte_unchanged_sources': 16, 'changed': changed,
            'preserved_observer_methods': preserved, 'dependencies': manifest['dependencies'],
            'source_manifest_sha256': sha(HERE / 'source-manifest.json'),
            'compiled': False, 'runtime_tested': False, 'performance_qualified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='verify prepared source only (also the default)')
    parser.parse_args()
    print(json.dumps(verify(), ensure_ascii=False, indent=2))
