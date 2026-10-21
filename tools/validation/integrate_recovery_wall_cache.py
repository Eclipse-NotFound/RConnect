"""Review/apply the tested wall-word cache to the isolated recovery3 source.

Default: verify all inputs and print a dry-run summary; --show-diff prints the
two source changes. Only --apply writes the active experimental tree. No build,
native runtime, installed files or frozen evidence is changed by this script.
"""
import argparse
import copy
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT/'experimental/recovery-integrated'
FROZEN = ROOT/'build/m52/recovery-03'
BASE = ROOT/'build/m52/recovery-02/src'
CACHE = ROOT/'experimental/recovery-wall-decode'
COMPONENT = ROOT/'build/m52/recovery-wall-decode-component-01'
WALL = 'rconnect/game/WallImpactVisuals.as'
VERSION = '0.2.24-recovery4'
COMPONENT_HASH = 'c80133db135d957d912de0d3d93f150c3a27967169b5f518f0d1454320b747d4'
PINS = {
    'experimental/recovery-integrated/integration.json': '74d621994870c233870407f29f7311597207fa9dbb92b6786859791e293ff4a7',
    'build/m52/recovery-03/integration.json': '74d621994870c233870407f29f7311597207fa9dbb92b6786859791e293ff4a7',
    'build/m52/recovery-03/prepared.json': '89b3afd7d3e2390ea13550b626c5261ac4db90cbcbb6a161c0a27aab1ce420e1',
    'experimental/recovery-wall-decode/inputs.json': 'b29b876947e01b613b00315e8fa852c19df58c7f6161cef5f244d7b3f89254e8',
    'build/m52/recovery-wall-decode-component-01/intent.json': '6b9ae537895515c8f0648d01e65b938a401d7c334e7d68c3eaf0424d3167229d',
    'build/m52/recovery-wall-decode-component-01/receipt.json': '274cd884a9cbb171bf3d8687f0db40c723ff0a1c03ef9bb9ab9e3f4bf25e3f13',
    'build/m52/recovery-wall-decode-component-01/component-result.json': '9d1389d55806c2b87c6fc453d34c9ea2dc0e4d8257283c00f5ac28ef924aeae7',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def inventory(folder):
    return {p.relative_to(folder).as_posix(): p.read_bytes()
            for p in sorted(folder.rglob('*.as'))}


def one(text, old, new):
    require(text.count(old) == 1, 'Missing/ambiguous reviewed merge anchor: '+old[:90])
    return text.replace(old, new, 1)


def methods(text):
    clean = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27',
                   lambda m: ' '*len(m.group()), text)
    result = {}
    for match in re.finditer(r'(?m)^      (?:public|private) (?:static )?function (\w+)\(', clean):
        start = clean.index('{', match.end())
        end, depth = start+1, 1
        while depth:
            require(end < len(clean), 'Unclosed method: '+match[1])
            depth += (clean[end] == '{') - (clean[end] == '}')
            end += 1
        require(match[1] not in result, 'Duplicate method: '+match[1])
        result[match[1]] = text[match.start():end]
    return result


def merge_wall(ancestor, overlay, current):
    old, new = methods(ancestor), methods(overlay)
    require(set(new)-set(old) == {'decodeWords', 'rememberWords'}, 'Unexpected cache methods')
    require(set(old)-set(new) == set(), 'Cache removed an existing method')
    for name in set(old)-{'decode', 'reset'}:
        require(old[name] == new[name], 'Unexpected proposal method change: '+name)
    field_start = '      private static const MARGIN:int=96;'
    field_end = '      private var rooms:'
    old_fields = ancestor[ancestor.index(field_start):ancestor.index(field_end)]
    new_fields = overlay[overlay.index(field_start):overlay.index(field_end)]
    helper_start = '      /** The payload alone determines these words.'
    helper_end = '      private function protectedPixels('
    helpers = overlay[overlay.index(helper_start):overlay.index(helper_end)]

    def apply(text):
        text = one(text, old_fields, new_fields)
        for name in ('decode', 'reset'):
            text = one(text, old[name], new[name])
        return one(text, helper_end, helpers+helper_end)

    require(apply(ancestor) == overlay, 'Reviewed anchors do not account for the entire cache delta')
    result = apply(current)
    before, after = methods(current), methods(result)
    for name in set(before)-{'decode', 'reset'}:
        require(before[name] == after[name], 'Existing recovery3 method overwritten: '+name)
    require('snapshot(loc:Object,observeNow:Boolean=true)' in after['snapshot'], 'Lost recovery3 snapshot deduplication')
    require('if(observeNow)observe(loc);' in after['snapshot'], 'Lost recovery3 conditional observe')
    return result


def validate_component(inputs):
    receipt, result, intent = (read(COMPONENT/name) for name in
                              ('receipt.json', 'component-result.json', 'intent.json'))
    for key in ('passed', 'compiled', 'air_started', 'installation_unchanged', 'source_unchanged'):
        require(receipt.get(key) is True, 'Component receipt not confirmed: '+key)
    require(receipt.get('compile_exit') == 0 and receipt.get('exit_code') == 0, 'Component process failed')
    require(receipt.get('observed_checks') == 120 and receipt.get('checks_failed') == 0
            and receipt.get('failures') == [], 'Component summary differs from 120/0')
    require(receipt.get('native_game_test') is False and receipt.get('performance_qualified') is False,
            'Keep component proof separate from game/performance qualification')
    require(receipt.get('component_sha256') == COMPONENT_HASH
            and digest((COMPONENT/'Checks.swf').read_bytes()) == COMPONENT_HASH, 'Component artifact differs')
    rows = result.get('assertions')
    require(result.get('passed') is True and result.get('failed') == 0
            and result.get('functional_only') is True and result.get('native_runtime') is False,
            'Raw component result failed or changed scope')
    require(isinstance(rows, list) and len(rows) == 120
            and all(r.get('passed') is True and isinstance(r.get('label'), str) for r in rows),
            'Raw assertions are not exactly 120 passing checks')
    require(len({r['label'] for r in rows}) == 120, 'Duplicate labels in raw assertions')
    require(intent.get('entry') == 'RecoveryWallDecodeChecks.as' and intent.get('expected') == 120,
            'Wrong component entry or expected count')
    require(Path(intent['source']).resolve() == (CACHE/'components').resolve(), 'Wrong component source root')
    require(inputs['components'] == intent['sources'], 'Tested source list differs from proposal')
    tested, proposal = inventory(COMPONENT/'src'), inventory(CACHE/'components')
    require(set(tested) == set(proposal) == set(intent['sources']), 'Unexpected component source files')
    for name, expected in intent['sources'].items():
        require(digest(tested[name]) == expected and digest(proposal[name]) == expected,
                'Changed component source: '+name)
    # Prove that tested renamed classes contain the exact production methods.
    for suffix, original in [('Before', (BASE/WALL).read_text(encoding='utf-8-sig')),
                             ('After', (CACHE/'src'/WALL).read_text(encoding='utf-8-sig'))]:
        fixture = proposal['rconnect/game/Wall'+suffix+'.as'].decode('utf-8-sig')
        fixture = fixture.replace('class Wall'+suffix, 'class WallImpactVisuals').replace(
            'function Wall'+suffix+'(', 'function WallImpactVisuals(')
        fixture = fixture.replace('      public function decode(', '      private function decode(')
        if suffix == 'After':
            fixture = one(fixture, '      public function cacheStats():Object {return {entries:wordOrder.length,words:wordCount,chars:wordChars};}\n', '')
        require(fixture == original, 'Test class no longer matches proposal: '+suffix)
    codec = one(proposal['rconnect/net/RoomCodec.as'].decode('utf-8-sig'), '\n         DecodeCounter.calls++;', '')
    require(codec == (BASE/'rconnect/net/RoomCodec.as').read_text(encoding='utf-8-sig'), 'Tested RoomCodec differs')
    return dict(receipt='build/m52/recovery-wall-decode-component-01/receipt.json',
                receipt_sha256=digest((COMPONENT/'receipt.json').read_bytes()),
                raw_result_sha256=digest((COMPONENT/'component-result.json').read_bytes()),
                intent_sha256=digest((COMPONENT/'intent.json').read_bytes()),
                component_sha256=COMPONENT_HASH, checks=120, failed=0,
                native_game_test=False, performance_qualified=False)


def plan():
    for name, expected in PINS.items():
        require(digest((ROOT/name).read_bytes()) == expected, 'Pinned input changed: '+name)
    original_meta = (ACTIVE/'integration.json').read_bytes()
    meta, frozen = read(ACTIVE/'integration.json'), read(FROZEN/'prepared.json')
    require(meta['version'] == frozen['version'] == '0.2.24-recovery3', 'Single-use recovery3 integration')
    require(frozen['integration_sha256'] == digest(original_meta), 'Frozen integration receipt differs')
    current, frozen_source = inventory(ACTIVE/'src'), inventory(FROZEN/'src')
    expected = frozen['source']
    require(len(current) == len(frozen_source) == len(expected) == len(meta['source']) == 85,
            'Expected exactly 85 recovery3 source files')
    require(set(current) == set(frozen_source) == set(expected), 'Missing or extra recovery3 source file')
    require({r['path']:r['sha256'] for r in meta['source']} == expected, 'Active/frozen manifest disagreement')
    for name, value in expected.items():
        require(digest(current[name]) == digest(frozen_source[name]) == value, 'Recovery3 source changed: '+name)
    inputs = read(CACHE/'inputs.json')
    require(inputs['base'] == 'build/m52/recovery-02/src'
            and inputs['expected_component_assertions'] == 120, 'Wrong cache proposal base')
    for name, value in inputs['base_inputs'].items():
        require(digest((BASE/name).read_bytes()) == value, 'Cache ancestor changed: '+name)
    require(set(inputs['overlay']) == {WALL}, 'Expected a single production cache overlay')
    overlay_bytes = (CACHE/'src'/WALL).read_bytes()
    require(digest(overlay_bytes) == inputs['overlay'][WALL], 'Cache overlay changed')
    proof = validate_component(inputs)
    ancestor_bytes = (BASE/WALL).read_bytes()
    require(b'\r' not in current[WALL] and b'\r' not in overlay_bytes and b'\r' not in ancestor_bytes,
            'Review line-ending changes before method merging')
    planned = dict(current)
    planned[WALL] = merge_wall(ancestor_bytes.decode('utf-8'), overlay_bytes.decode('utf-8'),
                              current[WALL].decode('utf-8')).encode('utf-8')
    planned['RConnectMod.as'] = one(current['RConnectMod.as'].decode('utf-8'),
        '0.2.24-recovery3', VERSION).encode('utf-8')
    changed = sorted(name for name in planned if planned[name] != current[name])
    require(changed == ['RConnectMod.as', WALL], 'Unexpected changed production files')
    bridge = planned['rconnect/game/GameBridge.as'].decode('utf-8')
    require('var paint:Object=_wall.report(loc,false);' in bridge
            and '_wall.snapshot(loc,observeNow)' in bridge, 'Recovery3 report/snapshot deduplication missing')
    require('usMsg.wallPaint=mod.game.readWallPaint(false);' in planned['rconnect/core/Session.as'].decode('utf-8'),
            'Recovery3 caller-side observe deduplication missing')
    updated = copy.deepcopy(meta)
    updated['layers'].append(dict(name='validated-exact-wall-word-cache',
        source='experimental/recovery-wall-decode/src', ancestor='build/m52/recovery-02/src',
        files=[dict(path=WALL, ancestor_sha256=digest(ancestor_bytes), source_sha256=digest(overlay_bytes),
                    before_sha256=digest(current[WALL]), merged_sha256=digest(planned[WALL]),
                    merge='exact decode/reset methods, bounded cache members and helpers; recovery3 observe deduplication retained')],
        component=proof))
    for row in updated['source']:
        row['sha256'] = digest(planned[row['path']])
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version=VERSION, compiled=False, runtime_tested=False, deployed=False,
                   gameplay_qualified=False, performance_qualified=False, static_errors=[],
                   followup_review='Wall decoder 120/0 component proof; exact method merge keeps recovery3 native travel and observe deduplication. Native cache hit-rate and net performance remain untested.',
                   integration_recipe_sha256=digest(Path(__file__).read_bytes()))
    updated['static_checks'].update(input_hashes=True, exact_overlap_anchors=True, no_conflict_markers=True,
        version=True, compiler_checked=False, frozen_recovery3_85_files=True,
        wall_component_120_raw_assertions=True, recovery3_observe_deduplication_preserved=True)
    for name in changed:
        require(b'<<<<<<<' not in planned[name] and b'>>>>>>>' not in planned[name], 'Conflict markers: '+name)
    metadata = (json.dumps(updated, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    return current, planned, original_meta, metadata, changed, proof


def atomic_write(target, data):
    require(target.resolve().is_relative_to(ACTIVE.resolve()), 'Output must remain in the active experimental tree')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix='.wall-cache-', suffix='.tmp', dir=target.parent, delete=False) as file:
            temporary = Path(file.name)
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, target)
        temporary = None
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Apply verified changes to the isolated active source only')
    parser.add_argument('--show-diff', action='store_true', help='Print the two production source differences')
    args = parser.parse_args()
    current, planned, before_meta, after_meta, changed, proof = plan()
    if args.show_diff:
        for name in changed:
            print(''.join(difflib.unified_diff(current[name].decode('utf-8').splitlines(True),
                planned[name].decode('utf-8').splitlines(True), fromfile='recovery3/'+name,
                tofile='recovery4/'+name)), end='')
    if args.apply:
        # Recheck all 85 inputs immediately before publishing; never replace a
        # concurrent edit with this already-computed plan.
        require(inventory(ACTIVE/'src') == current and (ACTIVE/'integration.json').read_bytes() == before_meta,
                'Active tree changed during validation; no writes performed')
        writes = [(ACTIVE/'src'/name, current[name], planned[name]) for name in changed]
        writes.append((ACTIVE/'integration.json', before_meta, after_meta))
        published = []
        try:
            for path, before, after in writes:
                require(path.read_bytes() == before, 'Output changed before write: '+str(path))
                atomic_write(path, after)
                published.append((path, before, after))
        except Exception:
            for path, before, after in reversed(published):
                require(path.read_bytes() == after, 'Concurrent edit prevents rollback: '+str(path))
                atomic_write(path, before)
            raise
    print(json.dumps(dict(version=VERSION, applied=args.apply, source_files=85, changed_files=changed,
        wall_sha256=digest(planned[WALL]), integration_sha256=digest(after_meta),
        component_checks=proof['checks'], compiled=False, installed=False, performance_qualified=False)))


if __name__ == '__main__':
    main()
