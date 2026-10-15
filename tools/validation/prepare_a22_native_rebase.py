"""Rebase only the reviewed A22 Land patch onto a pinned current installation.

Produces a new build/m52 candidate; never writes the installation or parent.
Production module, version, source, tests and build tools stay byte-identical.
FFDec imports only Land. The receipt states the exact verification scope:
Land/MainFE source checks and unchanged non-code tags, not every class's code.
"""
import argparse
import difflib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_a22_testpack import (ROOT, BUILD, COMPILE_STUB, BINARIES, digest,
                                 inventory, relative_file, require, verify_manifest)


GAME = ROOT.parents[1]
RECIPE = ROOT / 'build/m51/map-seed-game-58'
RECIPE_FILES = {
    'export/scripts/fe/loc/Land.as':
        '797ca940e54eb7fae7853490fea885c8784e4cb60fa39f1a952c2b735ce2abd9',
    'import/fe/loc/Land.as':
        'af590968605821ebda481e546dcb19cba38fce8f68926617ad236a5f376aa33f',
    'verified/scripts/fe/loc/Land.as':
        'b1727e83fbec9863a267b07b5428853cb734c442572d747d592922e8b1ebc060'}
LAND = 'scripts/fe/loc/Land.as'
MAIN = 'scripts/MainFE.as'


def sha(path):
    return digest(path.read_bytes())


def text(data):
    return data.decode('utf-8-sig').replace('\r\n', '\n').replace('\r', '\n')


def write_new(root, name, data):
    target = relative_file(root, name)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as stream:
        stream.write(data)
    require(target.read_bytes() == data, 'Copy verification failed: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--base', required=True, type=Path)
    parser.add_argument('--expected-game-sha', required=True)
    args = parser.parse_args()
    expected_game = args.expected_game_sha.lower()
    require(re.fullmatch('[0-9a-f]{64}', expected_game) is not None,
            '--expected-game-sha must be a SHA256 digest')
    base, out = [(ROOT / path).resolve() for path in (args.base, args.output)]
    require(base.parent == BUILD and base.is_dir(), '--base must be a frozen build/m52 child')
    require(out.parent == BUILD and not out.exists(), 'Output must be a new build/m52 child')
    parent_file = base / 'prepared.json'
    parent_bytes = parent_file.read_bytes()
    parent = json.loads(parent_bytes.decode('utf-8-sig'))
    require(parent.get('kind') in ('isolated-a22-followup', 'isolated-a22-testpack'),
            'Base must be a frozen A22 follow-up or testpack')
    version = parent.get('version')
    require(isinstance(version, str) and version.startswith('0.2.22-'), 'Base is not A22')

    def verify_parent():
        require(parent_file.read_bytes() == parent_bytes, 'Parent receipt changed')
        verify_manifest(base, parent['source'], inventory(base, ('src',)), 'parent source')
        expected = inventory(base, ('tools', 'tests'))
        if parent['kind'] == 'isolated-a22-testpack':
            expected.add(COMPILE_STUB)
            require(parent.get('compile_dependencies') ==
                    {COMPILE_STUB: parent['inputs'].get(COMPILE_STUB)},
                    'Parent compile-dependency receipt differs from inputs')
        verify_manifest(base, parent['inputs'], expected, 'parent inputs')
        for name, field in BINARIES.items():
            require(sha(relative_file(base, name)) == parent[field],
                    'Parent binary changed: ' + name)

    verify_parent()
    declaration = re.search(r'\bconst\s+VERSION\s*:\s*String\s*=\s*"([^"]+)"',
                            text((base / 'src/RConnectMod.as').read_bytes()))
    require(declaration is not None and declaration.group(1) == version,
            'Parent source version differs from receipt')
    recipe = {name: relative_file(RECIPE, name).read_bytes() for name in RECIPE_FILES}
    for name, expected in RECIPE_FILES.items():
        require(digest(recipe[name]) == expected, 'Reviewed map recipe changed: ' + name)
    original = GAME / 'pfe.swf'
    game_bytes = original.read_bytes()
    require(digest(game_bytes) == expected_game, 'Current installed game differs from explicit SHA')

    inherited = {**parent['source'], **parent['inputs']}
    # Full-build parents did not record their compile-only SWC in inputs.
    # Preserve it too so existing external-driver compilation remains usable.
    compile_hash = sha(relative_file(base, COMPILE_STUB))
    if COMPILE_STUB in inherited:
        require(inherited[COMPILE_STUB] == compile_hash, 'Parent declaration SWC changed')
    inherited[COMPILE_STUB] = compile_hash
    for name in ('RConnectMod.swf', 'control.swf'):
        inherited[name] = parent[BINARIES[name]]
    files = {}
    for name, expected in inherited.items():
        data = relative_file(base, name).read_bytes()
        require(digest(data) == expected, 'Parent changed while buffering: ' + name)
        files[name] = data
    require(shutil.disk_usage(BUILD).free > sum(map(len, files.values())) +
            len(game_bytes) * 3 + 64 * 1024 * 1024, 'Insufficient room for isolated native build')

    # Same toolchain and SWF tag verifier as the reviewed map-refresh pipeline.
    # Imports are inside main so static inspection never invokes native tooling.
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    from common import JAVA, FFDEC
    from patch_native import swf_tags
    dependencies = [Path(__file__).resolve(), ROOT / 'tools/validation/prepare_a22_testpack.py',
                    ROOT / 'tools/host_authority/common.py', ROOT / 'tools/host_authority/patch_native.py',
                    JAVA, FFDEC]
    tool_hashes = {str(path): sha(path) for path in dependencies}
    commands = []

    def unchanged():
        verify_parent()
        require(sha(original) == expected_game, 'Installation changed during native build')
        require(sha(relative_file(base, COMPILE_STUB)) == compile_hash, 'Parent declaration SWC changed')
        for name, expected in RECIPE_FILES.items():
            require(sha(relative_file(RECIPE, name)) == expected, 'Reviewed recipe changed: ' + name)
        for name, expected in tool_hashes.items():
            require(sha(Path(name)) == expected, 'Build tool changed: ' + name)

    def run(arguments, log_name):
        unchanged()
        command = [str(JAVA), '-jar', str(FFDEC)] + [str(value) for value in arguments]
        commands.append(command)
        with relative_file(out, log_name).open('x', encoding='utf-8') as stream:
            subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, check=True)
        unchanged()

    unchanged()
    out.mkdir()  # No reuse, overwrite, cleanup or installation deployment.
    for name, data in sorted(files.items()):
        write_new(out, name, data)
    write_new(out, 'original/pfe.swf', game_bytes)
    native = out / 'native'
    native.mkdir()
    for name, data in recipe.items():
        write_new(out, 'native/recipe/' + name, data)
    run(['-selectclass', 'fe.loc.Land,MainFE', '-export', 'script', native / 'before',
         out / 'original/pfe.swf'], 'native/export.log')
    before_land = (native / 'before' / LAND).read_bytes()
    require(text(before_land) == text(recipe['export/' + LAND]),
            'Installed Land differs from reviewed map58 input; manual review required')
    imported = recipe['import/fe/loc/Land.as']
    write_new(out, 'native/import/fe/loc/Land.as', imported)
    patch = ''.join(difflib.unified_diff(text(before_land).splitlines(True),
                text(imported).splitlines(True), fromfile='current/Land.as', tofile='rebased/Land.as'))
    write_new(out, 'native/land.patch', patch.encode('utf-8'))
    run(['-importScript', out / 'original/pfe.swf', native / 'pfe.swf', native / 'import'],
        'native/import.log')
    run(['-selectclass', 'fe.loc.Land,MainFE', '-export', 'script', native / 'after',
         native / 'pfe.swf'], 'native/verify.log')
    require(text((native / 'after' / LAND).read_bytes()) == text(recipe['verified/' + LAND]),
            'Rebased Land read-back differs from reviewed result')
    require((native / 'before' / MAIN).read_bytes() == (native / 'after' / MAIN).read_bytes(),
            'Native loader MainFE changed')
    before_tags = swf_tags(out / 'original/pfe.swf')
    after_tags = swf_tags(native / 'pfe.swf')
    require(len(before_tags) == len(after_tags), 'Native SWF tag count changed')
    changed = [index for index, pair in enumerate(zip(before_tags, after_tags)) if pair[0] != pair[1]]
    require(len(changed) == 1 and before_tags[changed[0]][0] == after_tags[changed[0]][0] == 82,
            'Expected exactly one changed DoABC tag; changed tags: ' + repr(changed))

    inputs = dict(parent['inputs'])
    inputs[COMPILE_STUB] = compile_hash
    inputs['original/pfe.swf'] = expected_game
    native_names = inventory(out, ('native/before', 'native/after', 'native/import', 'native/recipe'))
    for name in sorted(native_names | {'native/land.patch'}):
        inputs[name] = sha(relative_file(out, name))
    verify_manifest(out, parent['source'], inventory(out, ('src',)), 'copied source')
    verify_manifest(out, inputs, set(inputs), 'copied inputs and native evidence')
    for name in ('RConnectMod.swf', 'control.swf'):
        require(sha(out / name) == parent[BINARIES[name]], 'Production binary changed: ' + name)
    require(inventory(out, ('tools', 'tests')) == inventory(base, ('tools', 'tests')),
            'Copied tests or build tools differ in inventory')
    unchanged()
    receipt = dict(parent)
    receipt.update(kind='isolated-a22-native-rebase', installed=False,
        parent_candidate=base.relative_to(ROOT).as_posix(), parent_prepared_sha256=digest(parent_bytes),
        parent_original_game_sha256=parent['original_game_sha256'],
        parent_candidate_game_sha256=parent['candidate_game_sha256'],
        same_production_sha256=parent['candidate_sha256'], production_recompiled=False,
        original_game_sha256=expected_game, candidate_game_sha256=sha(native / 'pfe.swf'),
        source=dict(parent['source']), inputs=inputs, script_sha256=tool_hashes[str(Path(__file__).resolve())],
        compile_dependencies={COMPILE_STUB: compile_hash},
        compile_dependencies_origin=('parent-inputs-manifest' if COMPILE_STUB in parent['inputs']
                                     else 'captured-parent-build-output'),
        loader_unchanged=True, non_code_tags_unchanged=True, changed_tags=changed,
        native_rebase={'recipe': RECIPE.relative_to(ROOT).as_posix(), 'recipe_sources': RECIPE_FILES,
            'tools': tool_hashes, 'commands': commands, 'land_readback_matches_reviewed': True,
            'mainfe_source_unchanged': True, 'tag_count': len(after_tags),
            'all_other_classes_individually_verified': False, 'installation_modified': False})
    write_new(out, 'prepared.json', json.dumps(receipt, ensure_ascii=False, indent=2).encode('utf-8'))
    print(json.dumps({key: receipt[key] for key in ('kind', 'version', 'candidate_sha256',
          'original_game_sha256', 'candidate_game_sha256', 'parent_prepared_sha256')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
