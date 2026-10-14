"""Extract only the reviewed map fix onto exact A22; no installation writes."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK, FFDEC
from patch_native import swf_tags

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value if isinstance(value, bytes) else value.encode('utf-8'))

def run(command, log):
    with log.open('w', encoding='utf-8') as stream:
        subprocess.run([str(x) for x in command], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)

def main():
    out = (ROOT/sys.argv[1]).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    out.mkdir(parents=True)
    base = git('rev-parse', '1a4b683').decode().strip()
    source_names = git('ls-tree', '-r', '--name-only', base, 'src').decode().splitlines()
    previous = json.loads((ROOT/'build/m50/final-presentation-30/source-input.json').read_text(encoding='utf-8-sig'))
    for name in source_names:
        frozen = ROOT/'build/m50/final-presentation-30'/name
        assert sha(frozen) == previous['source'][name]
        assert git('show', base+':'+name).decode('utf-8-sig').replace('\r\n','\n') == frozen.read_text(encoding='utf-8-sig')
        put(out/name, frozen.read_bytes())
    originals = {name: sha(out/name) for name in source_names}
    assert originals == previous['source'], 'A22 source must match deployed frozen input'
    for name in ('src/rconnect/core/RoomSync.as', 'src/rconnect/game/GameBridge.as'):
        patch = git('diff', 'bbb526b^', 'bbb526b', '--', name).decode('utf-8')
        source = (out/name).read_text(encoding='utf-8-sig')
        for hunk in re.split(r'^@@[^\n]*\n', patch, flags=re.M)[1:]:
            rows = hunk.splitlines(True)
            before = ''.join(row[1:] for row in rows if row.startswith((' ', '-')))
            after = ''.join(row[1:] for row in rows if row.startswith((' ', '+')))
            assert source.count(before) == 1, 'Map-only patch no longer applies: '+name
            source = source.replace(before, after, 1)
        put(out/name, source)
    put(out/'src/rconnect/core/MapGeneration.as', git('show', 'bbb526b:src/rconnect/core/MapGeneration.as'))
    entry = out/'src/RConnectMod.as'
    source = entry.read_text(encoding='utf-8-sig')
    assert source.count('"0.2.22-dev"') == 1
    put(entry, source.replace('"0.2.22-dev"', '"0.2.22-map1"'))
    changes = {}
    for name in source_names + ['src/rconnect/core/MapGeneration.as']:
        before = git('show', base+':'+name).decode('utf-8-sig') if name in originals else ''
        after = (out/name).read_text(encoding='utf-8-sig')
        if before != after:
            changes[name] = dict(before=originals.get(name), after=sha(out/name))
            put(out/'diff'/Path(name).with_suffix('.patch'), ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='A22/'+name, tofile='map-only/'+name)))
    assert set(changes) == {'src/RConnectMod.as', 'src/rconnect/core/MapGeneration.as', 'src/rconnect/core/RoomSync.as', 'src/rconnect/game/GameBridge.as'}
    for path in (ROOT/'tools/stubs').rglob('*'):
        if path.is_file(): put(out/path.relative_to(ROOT), path.read_bytes())
    for name in ('tools/build_mod.py', 'tools/build_effects_driver.py'):
        put(out/name, (ROOT/name).read_bytes())
    for path in (ROOT/'tests').rglob('*.as'):
        put(out/path.relative_to(ROOT), path.read_bytes())
    assert sha(ROOT/'release/RConnectMod.swf') == '32602e77a21b206d1f7ff0e927b953878c28254e7201529455818923a3539732'
    put(out/'control.swf', (ROOT/'release/RConnectMod.swf').read_bytes())
    run([sys.executable, '-B', '-X', 'utf8', out/'tools/build_mod.py', '--java', JAVA,
         '--amxmlc', SDK/'bin/amxmlc.bat', '--output', out/'RConnectMod.swf'], out/'build.log')

    original = GAME/'pfe.swf'
    put(out/'original/pfe.swf', original.read_bytes())
    native = out/'native'
    native.mkdir()
    ffdec = [JAVA, '-jar', FFDEC]
    run(ffdec+['-selectclass', 'fe.loc.Land,MainFE', '-export', 'script', native/'before', out/'original/pfe.swf'], native/'export.log')
    land = native/'before/scripts/fe/loc/Land.as'
    source = land.read_text(encoding='utf-8-sig')
    # Preserve every later installation change; reuse only a reviewed class
    # edit after confirming the original class itself is byte-for-byte equal.
    old = ROOT/'build/m51/map-seed-game-58/export/scripts/fe/loc/Land.as'
    assert source == old.read_text(encoding='utf-8-sig'), 'Installed Land changed: review new native edits first'
    new = (ROOT/'build/m51/map-seed-game-58/import/fe/loc/Land.as').read_text(encoding='utf-8-sig')
    put(native/'import/fe/loc/Land.as', new)
    put(native/'land.patch', ''.join(difflib.unified_diff(source.splitlines(True), new.splitlines(True), fromfile='installed/Land.as', tofile='map-only/Land.as')))
    run(ffdec+['-importScript', out/'original/pfe.swf', native/'pfe.swf', native/'import'], native/'import.log')
    run(ffdec+['-selectclass', 'fe.loc.Land,MainFE', '-export', 'script', native/'after', native/'pfe.swf'], native/'verify.log')
    after = (native/'after/scripts/fe/loc/Land.as').read_text(encoding='utf-8-sig')
    assert after == (ROOT/'build/m51/map-seed-game-58/verified/scripts/fe/loc/Land.as').read_text(encoding='utf-8-sig')
    assert (native/'before/scripts/MainFE.as').read_bytes() == (native/'after/scripts/MainFE.as').read_bytes()
    before_tags, after_tags = swf_tags(out/'original/pfe.swf'), swf_tags(native/'pfe.swf')
    changed_tags = [i for i,(a,b) in enumerate(zip(before_tags,after_tags)) if a != b]
    assert len(before_tags) == len(after_tags) and len(changed_tags) == 1
    assert before_tags[changed_tags[0]][0] == after_tags[changed_tags[0]][0] == 82
    assert sha(original) == sha(out/'original/pfe.swf'), 'Installation changed during build'
    for label, binary in [('control', out/'control.swf'), ('candidate', out/'RConnectMod.swf')]:
        run([sys.executable, '-B', '-X', 'utf8', out/'tools/build_effects_driver.py', '--candidate', binary,
             '--source-root', out/'src', '--java', JAVA, '--sdk', SDK, '--entry', 'NativeMapGenerationTestDoc',
             '--output', out/'build'/('driver-'+label)], out/(label+'-driver.log'))
    receipt = dict(kind='isolated-a22-map-only', installed=False, base_commit=base, changes=changes,
        original_game_sha256=sha(original), candidate_game_sha256=sha(native/'pfe.swf'),
        control_sha256=sha(out/'control.swf'), candidate_sha256=sha(out/'RConnectMod.swf'),
        loader_unchanged=True, non_code_tags_unchanged=True, changed_tags=changed_tags,
        source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')},
        inputs={p.relative_to(out).as_posix():sha(p) for directory in ('tools','tests') for p in (out/directory).rglob('*') if p.is_file()},
        script_sha256=sha(__file__))
    put(out/'prepared.json', json.dumps(receipt, ensure_ascii=False, indent=2))
    print(json.dumps({key:receipt[key] for key in ('kind','candidate_sha256','original_game_sha256','candidate_game_sha256','changes')}, ensure_ascii=False))

if __name__ == '__main__':
    main()
