"""Assemble the cumulative B field8 source overlay; never compile, run or install."""
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


def source_name(name):
    return name.split('/')[0] in ('src', 'stubs') and name.endswith('.as')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='New build/ab/b190-visual-motion*-source directory')
    args = parser.parse_args()
    plan = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    if digest(Path(__file__)) != plan['prepare_script_sha256']:
        raise ValueError('Preparation script changed')
    baseline = child(ROOT, plan['baseline']['directory'])
    manifest_file = baseline / 'build-input.json'
    if digest(manifest_file) != plan['baseline']['manifest_sha256']:
        raise ValueError('Baseline build manifest changed')
    manifest = json.loads(manifest_file.read_text(encoding='utf-8-sig'))
    if manifest['source_id'] != plan['baseline']['source_id']:
        raise ValueError('Wrong baseline source')
    for name, expected in manifest['sources'].items():
        if not source_name(name) or digest(child(baseline, name)) != expected:
            raise ValueError('Baseline source changed: ' + name)
    additions = set(plan['new_sources'])
    if additions != set(plan['overlay']) - set(manifest['sources']):
        raise ValueError('Unexpected source additions')
    actual_overlay = {p.relative_to(HERE).as_posix()
                      for folder in ('src', 'stubs') for p in (HERE / folder).rglob('*.as')}
    if actual_overlay != set(plan['overlay']):
        raise ValueError('Overlay source inventory changed')
    for name, expected in plan['overlay'].items():
        if not source_name(name) or digest(child(HERE, name)) != expected:
            raise ValueError('Overlay source changed: ' + name)
    stamp = (HERE / 'src/authority/BuildInfo.as').read_text(encoding='utf-8')
    if stamp.count('__SOURCE_HASH__') != 1:
        raise ValueError('Build requires an unstamped source template')
    sources = dict(manifest['sources'])
    sources.update(plan['overlay'])
    source_id = hashlib.sha256(json.dumps(sources, sort_keys=True).encode('utf-8')).hexdigest()
    if source_id != plan['assembled_source_id']:
        raise ValueError('Assembled source fingerprint differs from the frozen candidate')
    output = child(ROOT, args.output)
    if output.parent != (ROOT / 'build/ab').resolve() or not output.name.startswith('b190-visual-motion'):
        raise ValueError('Use a new build/ab/b190-visual-motion*-source directory')
    if not output.name.endswith('-source') or output.exists():
        raise ValueError('Output must be a new source directory')
    output.mkdir()
    for name in sources:
        target = child(output, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(child(HERE if name in plan['overlay'] else baseline, name), target)
    (output / 'assembly.json').write_text(json.dumps(dict(
        status='source-only-not-compiled-by-preparation',
        qualification='pending-final-qualification',
        version=plan['version'], source_id=source_id,
        plan=str(HERE / 'source-manifest.json'),
        plan_sha256=digest(HERE / 'source-manifest.json'),
        compiled_reference=plan['compiled_reference'],
        installed_files_written=False,
    ), indent=2) + '\n', encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
