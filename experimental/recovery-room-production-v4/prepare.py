"""Prepare roomfix3 plus the clean codec and version only; no build or AIR."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-aura-offline-01'
PREVIOUS = ROOT / 'experimental/recovery-room-production-v3'
ACTUAL = ROOT / 'build/m52/recovery-room-production-03'
CLEAN = ROOT / 'experimental/recovery-room-production-clean'
VERSION = '0.2.24-roomfix4'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def inventory(p):
    return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*')) if f.is_file()}


def save(p, value):
    with p.open('x', encoding='utf-8') as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main():
    assert not (HERE / 'src').exists()
    assert sha(PREVIOUS / 'source-manifest.json') == 'd765cf5158992f8b425c030b6323e9d052c95b6d578fc6935acfe6d78ef6d625'
    assert sha(PREVIOUS / 'build.py') == '1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9'
    old = json.loads((PREVIOUS / 'source-manifest.json').read_text(encoding='utf-8'))
    assert old['version'] == '0.2.24-roomfix3'
    assert inventory(PREVIOUS / 'src') == {k: v['candidate_sha256'] for k, v in old['changes'].items()}
    assert sha(BASE / 'RConnectMod.swf') == old['base_sha256']
    actual = json.loads((ACTUAL / 'prepared.json').read_text(encoding='utf-8-sig'))
    assert inventory(ACTUAL / 'src') == actual['source']
    assert sha(ACTUAL / 'RConnectMod.swf') == '43277b92dc5e556702d64754c6976dd10a032008719851b71bbeb566d3104011'
    for name, value in old['changes'].items():
        assert sha(ACTUAL / 'src' / name) == value['candidate_sha256'], name
    codec = CLEAN / 'src/rconnect/net/RoomCodec.as'
    assert sha(codec) == 'bd98187fb1201c118f4980a3a93e3a06b0ebed28ba1cfc1be8661dcb33762570'
    clean = json.loads((CLEAN / 'source-manifest.json').read_text(encoding='utf-8'))
    assert clean['source_sha256'] == actual['source']['rconnect/net/RoomCodec.as']
    assert all(sha(CLEAN / n) == h for n, h in clean['files'].items())
    shutil.copytree(PREVIOUS / 'src', HERE / 'src')
    shutil.copyfile(codec, HERE / 'src/rconnect/net/RoomCodec.as')
    entry = HERE / 'src/RConnectMod.as'
    body = entry.read_text(encoding='utf-8')
    assert body.count(old['version']) == 1
    entry.write_text(body.replace(old['version'], VERSION), encoding='utf-8', newline='\n')
    changes, incremental, full_diff, incremental_diff = {}, {}, [], []
    for name in inventory(HERE / 'src'):
        new, prior, previous = HERE / 'src' / name, BASE / 'src' / name, ACTUAL / 'src' / name
        before = prior.read_text(encoding='utf-8-sig') if prior.exists() else ''
        after = new.read_text(encoding='utf-8-sig')
        changes[name] = dict(base_sha256=sha(prior) if prior.exists() else None, candidate_sha256=sha(new))
        full_diff.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                         fromfile='aura1/' + name, tofile=VERSION + '/' + name))
        if sha(new) != sha(previous):
            incremental[name] = dict(previous_sha256=sha(previous), candidate_sha256=sha(new))
            incremental_diff.extend(difflib.unified_diff(previous.read_text(encoding='utf-8-sig').splitlines(True),
                after.splitlines(True), fromfile='roomfix3/' + name, tofile='roomfix4/' + name))
    assert set(incremental) == {'RConnectMod.as', 'rconnect/net/RoomCodec.as'}
    (HERE / 'source.diff').write_text(''.join(full_diff), encoding='utf-8', newline='\n')
    (HERE / 'incremental.diff').write_text(''.join(incremental_diff), encoding='utf-8', newline='\n')
    shutil.copyfile(PREVIOUS / 'build.py', HERE / 'build.py')
    receipt = dict(version=VERSION, base=str(BASE), base_sha256=sha(BASE / 'RConnectMod.swf'),
        previous_overlay_sha256=sha(PREVIOUS / 'source-manifest.json'),
        previous_compiled_sha256=sha(ACTUAL / 'RConnectMod.swf'),
        previous_prepared_sha256=sha(ACTUAL / 'prepared.json'),
        review_sources={str(codec): sha(codec), str(CLEAN / 'source-manifest.json'): sha(CLEAN / 'source-manifest.json')},
        changes=changes, incremental_changes=incremental, recipe_sha256=sha(Path(__file__)),
        build_recipe_sha256=sha(HERE / 'build.py'), compiled=False, tested=False, installed=False)
    save(HERE / 'source-manifest.json', receipt)
    assert sha(HERE / 'build.py') == sha(PREVIOUS / 'build.py')
    assert inventory(ACTUAL / 'src') == actual['source']
    print(json.dumps(dict(version=VERSION, base_overlay_classes=len(changes),
                         incremental_changes=list(incremental), compiled=False, installed=False)))


if __name__ == '__main__':
    main()
