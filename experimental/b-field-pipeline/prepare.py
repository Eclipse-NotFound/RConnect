"""Assemble the reviewed B field6 source overlay. Does not compile, test or install."""
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
    parser.add_argument('--output', required=True, help='New source directory directly under build/ab')
    args = parser.parse_args()
    plan = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    baseline = child(ROOT, plan['baseline']['directory'])
    manifest_file = baseline / 'build-input.json'
    if digest(manifest_file) != plan['baseline']['manifest_sha256']:
        raise ValueError('Baseline build manifest changed')
    manifest = json.loads(manifest_file.read_text(encoding='utf-8-sig'))
    if manifest['source_id'] != plan['baseline']['source_id']:
        raise ValueError('Wrong baseline source')
    # Validate before creating the output; only source/stub files are copied.
    for name, expected in manifest['sources'].items():
        if name.split('/')[0] not in ('src', 'stubs') or digest(child(baseline, name)) != expected:
            raise ValueError('Baseline source changed: ' + name)
    for name, expected in plan['overlay'].items():
        if name not in manifest['sources'] or digest(child(HERE, name)) != expected:
            raise ValueError('Overlay source changed: ' + name)
    output = child(ROOT, args.output)
    if output.parent != (ROOT / 'build/ab').resolve() or not output.name.startswith('b190-pipeline'):
        raise ValueError('Use a new build/ab/b190-pipeline*-source directory')
    if not output.name.endswith('-source') or output.exists():
        raise ValueError('Output must be a new source directory')
    output.mkdir()
    for name in manifest['sources']:
        target = child(output, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(child(baseline, name), target)
    for name in plan['overlay']:
        shutil.copy2(child(HERE, name), child(output, name))
    (output / 'assembly.json').write_text(json.dumps(dict(
        status='source-only-uncompiled-untested',
        plan=str(HERE / 'source-manifest.json'),
        plan_sha256=digest(HERE / 'source-manifest.json'),
        installed_version_unchanged=True,
    ), indent=2) + '\n', encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
