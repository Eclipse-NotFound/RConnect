"""Assemble B field7 candidate sources only; never compile, run or install."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def child(root, name):
    result = (root / name).resolve()
    if not result.is_relative_to(root.resolve()):
        raise ValueError('Source path escapes its directory: ' + name)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='New directory directly under build/ab')
    args = parser.parse_args()
    plan = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    baseline = child(ROOT, plan['baseline']['directory'])
    manifest_file = baseline / 'build-input.json'
    if digest(manifest_file) != plan['baseline']['manifest_sha256']:
        raise ValueError('Baseline build manifest changed')
    manifest = json.loads(manifest_file.read_text(encoding='utf-8-sig'))
    if manifest['source_id'] != plan['baseline']['source_id']:
        raise ValueError('Wrong baseline source')
    for name, expected in manifest['sources'].items():
        if name.split('/')[0] not in ('src', 'stubs') or digest(child(baseline, name)) != expected:
            raise ValueError('Baseline source changed: ' + name)
    additions = set(plan['new_sources'])
    if additions != set(plan['overlay']) - set(manifest['sources']):
        raise ValueError('Unexpected source additions')
    for name, expected in plan['overlay'].items():
        if not name.startswith('src/') or not name.endswith('.as') or digest(child(HERE, name)) != expected:
            raise ValueError('Overlay source changed: ' + name)
    stamp = (HERE / 'src/authority/BuildInfo.as').read_text(encoding='utf-8')
    if stamp.count('__SOURCE_HASH__') != 1:
        raise ValueError('Build requires an unstamped source template')
    output = child(ROOT, args.output)
    if output.parent != (ROOT / 'build/ab').resolve() or not output.name.startswith('b190-local-display'):
        raise ValueError('Use a new build/ab/b190-local-display*-source directory')
    if not output.name.endswith('-source') or output.exists():
        raise ValueError('Output must be a new source directory')
    output.mkdir()
    for name in manifest['sources']:
        target = child(output, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(child(baseline, name), target)
    for name in plan['overlay']:
        target = child(output, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(child(HERE, name), target)
    (output / 'assembly.json').write_text(json.dumps(dict(
        status='source-only-uncompiled-untested',
        version=plan['version'],
        plan=str(HERE / 'source-manifest.json'),
        plan_sha256=digest(HERE / 'source-manifest.json'),
        installed_files_written=False,
    ), indent=2) + '\n', encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
