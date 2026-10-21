"""Assemble only AS sources under this proposal. Does not run a compiler/AIR.

control/proposal share exactly the same test and adjacent fixtures. observed
reads a parent-integrated frozen source tree without applying any overlay.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
REAL = ['rconnect/game/UnitPresentation.as', 'rconnect/game/ProjectileVisuals.as',
        'rconnect/game/ImpactEventQueue.as', 'rconnect/game/ProjectileFrameStream.as',
        'rconnect/game/RemoteMotion.as', 'rconnect/game/ProjectileExplosionVisuals.as',
        'rconnect/net/BinaryMessageCodec.as']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--variant', choices=['control', 'proposal', 'observed'], required=True)
    ap.add_argument('--source', default='build/m52/recovery-04/src')
    ap.add_argument('--name', help='Fresh source package name under this proposal/components')
    args = ap.parse_args()
    source = (RC/args.source).resolve()
    assert source.is_relative_to(RC/'build') and source.is_dir()
    if args.variant != 'observed':
        assert source == RC/'build/m52/recovery-04/src', '04 overlay is not a whole-tree upgrade for 05'
    name = args.name or args.variant
    assert Path(name).name == name and name not in ('.', '..')
    out = HERE/'components'/name
    assert not out.exists(), 'Source packages are append-only; choose a fresh --name'
    shutil.copytree(HERE/'tests',out)
    sources = {}
    for name in REAL:
        candidate = HERE/'src'/name
        original = candidate if args.variant == 'proposal' and candidate.is_file() else source/name
        assert original.is_file(), original
        target = out/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(original,target)
        sources[name] = dict(path=str(original),sha256=sha(original))
    data = dict(variant=args.variant,source=str(source),entry='SpecialImpactChecks.as',
        production=sources,fixture={p.relative_to(HERE/'tests').as_posix():sha(p)
            for p in (HERE/'tests').rglob('*.as')},compiled=False,air_started=False,native_game=False)
    (out/'inputs.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'source':str(out),'entry':data['entry'],'compiled':False},ensure_ascii=False))


if __name__ == '__main__':
    main()
