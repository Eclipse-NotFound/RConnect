"""Pin physical inputs for map diagnostics while other mods keep developing.

This does not amend the release baseline or its verify_protected gate. The
diagnostic input transition needs fresh controls and cannot qualify a release.
"""
import argparse
import copy
import json
import shutil
from datetime import datetime, timezone
from validation_baseline import ROOT, GAME, M51_BASELINE, read, sha
from native_runtime_assets import native_runtime_files, asset_hashes


def changes_from(baseline):
    result = {}
    for name, digest in baseline['protected'].items():
        actual = sha(GAME/name)
        if actual != digest:
            result[name] = dict(before=digest, after=actual)
    return result


def verify_bundle(folder):
    folder = folder.resolve()
    assert folder.parent == ROOT/'build/m51' and folder.name.startswith('map-runtime-')
    manifest = read(folder/'runtime-input.json')
    assert manifest['diagnostic_only']
    assert sha(ROOT/manifest['previous_baseline']/'inputs.json') == manifest['previous_baseline_sha256']
    for name, digest in manifest['files'].items():
        assert sha(folder/'game'/name) == digest, name
    assert asset_hashes(folder/'game') == manifest['runtime']['runtime_assets']
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('output')
    args = ap.parse_args()
    folder = (ROOT/args.output).resolve()
    assert folder.parent == ROOT/'build/m51' and folder.name.startswith('map-runtime-')
    assert not folder.exists(), 'Never replace a previous diagnostic input'
    old = read(ROOT/M51_BASELINE/'inputs.json')
    changes = changes_from(old)
    expected = {
        'mods/WallBlend/release/WallBlendMod.swf': '1bb9b65af80a946f6758824a72eed941173d0ae40b8c09c084ecf12b92458820',
        'mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf': '92454203d369fc48853602a4dca702b85ce829c1bc01104fb1f6c7352d33a956',
    }
    assert {n: v['after'] for n, v in changes.items()} == expected, changes
    runtime = copy.deepcopy(old)
    for name, pair in changes.items():
        runtime['protected'][name] = pair['after']
        for key in runtime['runtime_modules']:
            if key.replace('\\', '/').lower() == name.lower():
                runtime['runtime_modules'][key] = pair['after']
    files = set(native_runtime_files(GAME))
    files.update(GAME/name for name in runtime['runtime_modules'])
    files.update(GAME/name for name in runtime['runtime_config'])
    files.update((GAME/'mods/loader-manifest.txt', GAME/'mods/RConnect/release/RConnectMod.swf', GAME/'adl64.exe'))
    files.update(p for p in (GAME/'runtimes/air/win64').rglob('*') if p.is_file())
    hashes = {p.relative_to(GAME).as_posix(): sha(p) for p in sorted(files)}
    assert shutil.disk_usage(ROOT).free > sum(p.stat().st_size for p in files)*4
    folder.mkdir()
    for name, digest in hashes.items():
        target = folder/'game'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(GAME/name, target)
        assert sha(target) == digest and sha(GAME/name) == digest, 'Input changed during copy: '+name
    assert changes_from(old) == changes, 'Installation changed during freeze'
    for name, digest in hashes.items():
        assert sha(GAME/name) == digest, 'Input changed before freeze completed: '+name
    assert asset_hashes(folder/'game') == runtime['runtime_assets']
    manifest = dict(diagnostic_only=True, created_at=datetime.now(timezone.utc).isoformat(),
        purpose='Fresh old/new native map controls; no inherited release qualification',
        previous_baseline=M51_BASELINE, previous_baseline_sha256=sha(ROOT/M51_BASELINE/'inputs.json'),
        observed_external_transition=changes, files=hashes, runtime=runtime,
        script='tools/validation/freeze_map_runtime.py', script_sha256=sha(ROOT/'tools/validation/freeze_map_runtime.py'))
    (folder/'runtime-input.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    verify_bundle(folder)
    print(json.dumps(dict(path=str(folder), files=len(hashes), changes=changes), ensure_ascii=False))


if __name__ == '__main__':
    main()
