"""Restore the exact narrow loading repair source into a fresh build directory."""
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    plan = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    parent = ROOT / plan['parent']
    assert sha(parent / 'source-manifest.json') == plan['parent_manifest_sha256']
    assert sha(parent / 'prepare.py') == plan['parent_prepare_sha256']
    output = (ROOT / args.output).resolve()
    assert output.parent == (ROOT / 'build/ab').resolve() and not output.exists()
    for name, expected in plan['overlay'].items():
        p = (HERE / name).resolve()
        assert p.is_relative_to(HERE) and sha(p) == expected and name.endswith('.as')
    subprocess.run([sys.executable, str(parent / 'prepare.py'), '--output', args.output], cwd=ROOT, check=True)
    for name in plan['overlay']:
        target = (output / name).resolve()
        assert target.is_relative_to(output) and target.is_file()
        target.write_bytes((HERE / name).read_bytes())
    files = {p.relative_to(output).as_posix(): sha(p) for f in ('src', 'stubs') for p in (output / f).rglob('*.as')}
    identity = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    assert identity == plan['source_id'], 'Restored source differs from candidate'
    (output / 'loadfix-assembly.json').write_text(json.dumps(dict(source_id=identity, overlay_sha256=sha(HERE / 'source-manifest.json')), indent=2)+'\n', encoding='utf-8')
    print(identity)


if __name__ == '__main__':
    main()
