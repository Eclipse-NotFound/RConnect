"""Assemble the existing 35-check detach fixture against a frozen candidate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', required=True)
    ap.add_argument('--name', required=True)
    args = ap.parse_args()
    source = (ROOT / args.source).resolve()
    assert source.is_relative_to(ROOT / 'build/m52') and source.name == 'src'
    assert Path(args.name).name == args.name and args.name not in ('.', '..')
    out = HERE / 'components' / args.name
    assert not out.exists()
    tests = ROOT / 'experimental/recovery-impact-detach/tests'
    shutil.copytree(tests, out)
    production = {}
    for name in ('ImpactEventQueue', 'ProjectileFrameStream', 'ProjectileVisuals',
                 'EnergyImpactVisuals', 'BallisticImpactVisuals', 'RemoteMotion'):
        relative = 'rconnect/game/' + name + '.as'
        shutil.copyfile(source / relative, out / relative)
        production[relative] = sha(source / relative)
    data = dict(source=str(source), production=production,
                fixture={p.relative_to(tests).as_posix(): sha(p) for p in tests.rglob('*.as')},
                expected=35, compiled=False, native_game=False)
    (out / 'inputs.json').write_bytes((json.dumps(data, indent=2) + '\n').encode('utf-8'))
    print(out)


if __name__ == '__main__':
    main()
