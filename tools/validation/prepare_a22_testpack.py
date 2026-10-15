"""Freeze current external tests around an unchanged, verified A22 candidate.

No compiler, AIR process, installation or parent candidate is modified. Paths
are relative to this mod unless absolute; output must be a new build/m52 child.
The receipt is written last so an interrupted copy is never a runnable pack.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


ROOT = Path(__file__).resolve().parents[2]
BUILD = (ROOT / 'build/m52').resolve()
BUILD_TOOLS = ('tools/build_mod.py', 'tools/build_effects_driver.py')
COMPILE_STUB = 'build/GameCombatStubs.swc'
BINARIES = {'RConnectMod.swf': 'candidate_sha256',
            'native/pfe.swf': 'candidate_game_sha256',
            'control.swf': 'control_sha256'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def relative_file(root, name):
    require(isinstance(name, str) and name and '\\' not in name and ':' not in name,
            'Invalid manifest path: ' + repr(name))
    relative = PurePosixPath(name)
    require(not relative.is_absolute() and '..' not in relative.parts
            and relative.as_posix() == name, 'Noncanonical manifest path: ' + name)
    path = root / name
    require(path.resolve().is_relative_to(root) and not path.is_symlink(),
            'Manifest path escapes its frozen directory: ' + name)
    return path


def inventory(root, directories):
    names = set()
    for directory in directories:
        folder = root / directory
        require(folder.is_dir(), 'Missing directory: ' + str(folder))
        for path in folder.rglob('*'):
            if path.is_file():
                name = path.relative_to(root).as_posix()
                relative_file(root, name)
                names.add(name)
    return names


def verify_manifest(root, manifest, expected, label):
    require(isinstance(manifest, dict) and manifest, 'Missing ' + label + ' manifest')
    require(set(manifest) == expected, label + ' inventory differs from prepared.json')
    require(len({name.casefold() for name in manifest}) == len(manifest),
            'Case-colliding paths in ' + label)
    for name, expected_hash in manifest.items():
        require(isinstance(expected_hash, str) and re.fullmatch('[0-9a-f]{64}', expected_hash),
                'Invalid hash for ' + name)
        require(digest(relative_file(root, name).read_bytes()) == expected_hash,
                'Frozen input changed: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--base', required=True, type=Path)
    args = parser.parse_args()
    base, out = [(ROOT / path).resolve() for path in (args.base, args.output)]
    require(base.parent == BUILD and base.is_dir(), '--base must be a frozen build/m52 child')
    require(out.parent == BUILD and not out.exists(), 'Output must be a new build/m52 child')
    parent_file = base / 'prepared.json'
    parent_bytes = parent_file.read_bytes()
    parent = json.loads(parent_bytes.decode('utf-8-sig'))
    require(parent.get('kind') in ('isolated-a22-followup', 'isolated-a22-testpack'),
            'Base is not a frozen A22 follow-up or testpack')
    version = parent.get('version')
    require(isinstance(version, str) and version.startswith('0.2.22-'),
            'Base is not an A22 version')

    def verify_parent():
        require(parent_file.read_bytes() == parent_bytes, 'Parent receipt changed during freezing')
        verify_manifest(base, parent['source'], inventory(base, ('src',)), 'source')
        expected_inputs = inventory(base, ('tools', 'tests'))
        if parent['kind'] == 'isolated-a22-testpack':
            expected_inputs.add(COMPILE_STUB)
            require(parent.get('compile_dependencies') ==
                    {COMPILE_STUB: parent['inputs'].get(COMPILE_STUB)},
                    'Parent testpack compile-dependency receipt differs from inputs')
        verify_manifest(base, parent['inputs'], expected_inputs, 'inputs')
        for name, field in BINARIES.items():
            require(digest(relative_file(base, name).read_bytes()) == parent[field],
                    'Frozen binary changed: ' + name)

    verify_parent()
    declaration = re.search(r'\bconst\s+VERSION\s*:\s*String\s*=\s*"([^"]+)"',
                            (base / 'src/RConnectMod.as').read_text(encoding='utf-8-sig'))
    require(declaration is not None and declaration.group(1) == version,
            'Parent source version differs from prepared.json')

    # Keep the parent's production declarations and stubs, never root/src or
    # current root stubs. Only external fixtures and their build scripts change.
    inherited = dict(parent['source'])
    inherited.update({name: value for name, value in parent['inputs'].items()
                      if name.startswith('tools/stubs/')})
    require(any(name.startswith('tools/stubs/') for name in inherited), 'Parent stubs are missing')
    # The driver compiler also needs the parent's compiled declaration library.
    # Older follow-up receipts did not hash it: capture that fact explicitly,
    # then freeze/hash it here rather than rebuilding production or root stubs.
    compile_stub_data = relative_file(base, COMPILE_STUB).read_bytes()
    compile_stub_hash = digest(compile_stub_data)
    if COMPILE_STUB in parent['inputs']:
        require(compile_stub_hash == parent['inputs'][COMPILE_STUB],
                'Parent compiled declarations changed')
    inherited[COMPILE_STUB] = compile_stub_hash
    files = {}
    for name, expected_hash in inherited.items():
        data = relative_file(base, name).read_bytes()
        require(digest(data) == expected_hash, 'Parent changed while copying: ' + name)
        files[name] = data
    for name, field in BINARIES.items():
        data = relative_file(base, name).read_bytes()
        require(digest(data) == parent[field], 'Parent binary changed while copying: ' + name)
        files[name] = data

    current_names = inventory(ROOT, ('tests',)) | set(BUILD_TOOLS)
    current = {name: relative_file(ROOT, name).read_bytes() for name in sorted(current_names)}
    files.update(current)
    current_hashes = {name: digest(data) for name, data in current.items()}
    script_hash = digest(Path(__file__).read_bytes())

    out.mkdir()  # Fails rather than reusing a path created by another process.
    for name, data in sorted(files.items()):
        target = relative_file(out, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
        require(digest(target.read_bytes()) == digest(data), 'Copy verification failed: ' + name)

    # Recheck both sides before publishing a usable receipt. A concurrent edit
    # leaves an incomplete output directory for inspection, never a false pass.
    verify_parent()
    require(digest(relative_file(base, COMPILE_STUB).read_bytes()) == compile_stub_hash,
            'Parent compiled declarations changed during freezing')
    verify_manifest(ROOT, current_hashes, inventory(ROOT, ('tests',)) | set(BUILD_TOOLS),
                    'current external tests')
    require(digest(Path(__file__).read_bytes()) == script_hash, 'Preparation script changed during freezing')
    source = {name: digest(files[name]) for name in sorted(parent['source'])}
    inputs = {name: digest(data) for name, data in sorted(files.items())
              if name.startswith(('tools/', 'tests/')) or name == COMPILE_STUB}
    require(source == parent['source'], 'Production source changed')
    receipt = dict(parent)
    receipt.update(kind='isolated-a22-testpack', installed=False,
                   parent_candidate=base.relative_to(ROOT).as_posix(),
                   parent_prepared_sha256=digest(parent_bytes),
                   same_production_sha256=parent['candidate_sha256'],
                   production_recompiled=False, script_sha256=script_hash,
                   compile_dependencies={COMPILE_STUB: compile_stub_hash},
                   compile_dependencies_origin=('parent-inputs-manifest'
                       if COMPILE_STUB in parent['inputs'] else 'captured-parent-build-output'),
                   source=source, inputs=inputs)
    with (out / 'prepared.json').open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(receipt, ensure_ascii=False, indent=2))
    print(json.dumps({key: receipt[key] for key in
                      ('kind', 'version', 'candidate_sha256', 'same_production_sha256',
                       'parent_prepared_sha256', 'production_recompiled')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
