"""Restore a recorded B source overlay, without compiling or updating a runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def sources(root):
    return {p.relative_to(root).as_posix(): sha(p)
            for folder in ('src', 'stubs') for p in (root / folder).rglob('*.as')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    snapshot = (HERE / args.snapshot).resolve()
    if snapshot.parent != HERE or not snapshot.name.startswith('source-'):
        raise ValueError('Use a recorded direct-child source snapshot')
    plan = json.loads((snapshot / 'source-manifest.json').read_text(encoding='utf-8'))
    parent = (ROOT / plan['parent']).resolve()
    expected_parent = ROOT / 'experimental/b-field-loadfix'
    if parent != expected_parent or sha(parent / 'source-manifest.json') != plan['parent_manifest_sha256']:
        raise ValueError('Parent source record changed')
    if sha(parent / 'restore-source.py') != plan['parent_restore_sha256']:
        raise ValueError('Parent source assembler changed')
    if sources(snapshot) != plan['overlay']:
        raise ValueError('Snapshot inventory or bytes changed')
    output = (ROOT / args.output).resolve()
    if output.parent != ROOT / 'build/ab' or not output.name.startswith('b190-visual-motion') or not output.name.endswith('-source') or output.exists():
        raise ValueError('Use a fresh build/ab/b190-visual-motion*-source directory')
    subprocess.run([sys.executable, str(parent / 'restore-source.py'), '--output', args.output], cwd=ROOT, check=True)
    for name in plan['overlay']:
        target = (output / name).resolve()
        if not target.is_relative_to(output):
            raise ValueError('Source path escaped its root')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((snapshot / name).read_bytes())
    final = sources(output)
    identity = hashlib.sha256(json.dumps(final, sort_keys=True).encode()).hexdigest()
    if final != plan['sources'] or identity != plan['source_id']:
        raise ValueError('Restored source does not match the recorded candidate')
    print(json.dumps({'source_id': identity, 'sources': len(final), 'compiled': False}))


if __name__ == '__main__':
    main()
