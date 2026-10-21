"""Add one native entry to the existing frozen-driver framework without editing it.

prepare freezes new inputs, optionally compiles; run delegates to the unchanged
runner and all its installation, ownership, log and coverage checks.
"""
import argparse
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'experimental/recovery-tests'))
import prepare

ENTRY = 'MSWNoVisualExplosionTestDoc'
prepare.ENTRIES[ENTRY] = (2, 300, 'MSW真实无图像爆炸对象、独立事件与双侧原生粒子像素')
# This entry has its own separately executed 87-check capture component. Do not
# compile the generic old impact fixture, which lacks the new explosion class.
prepare.COMPONENTS = {}


def main():
    assert len(sys.argv) > 1 and sys.argv[1] in ('prepare', 'run')
    mode = sys.argv.pop(1)
    if mode == 'run':
        import run
        run.SUITES[ENTRY] = 'msw-no-visual'
        driver_arg = sys.argv[sys.argv.index('--drivers') + 1]
        manifest = prepare.read((ROOT / driver_arg).resolve() / 'prepared.json')
        expected = manifest['extension']['script_sha256']
        assert prepare.sha(Path(__file__)) == expected, 'Entry adapter changed after freeze'
        sys.argv.insert(1, 'native')
        code = run.main()
        assert prepare.sha(Path(__file__)) == expected, 'Entry adapter changed during run'
        return code
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    source, out = (ROOT / args.source).resolve(), (ROOT / args.output).resolve()
    assert source.is_relative_to(ROOT / 'build') and source.name == 'src'
    assert out.parent == ROOT / 'build/m52' and not out.exists()
    manifest = prepare.freeze(source, out, entry_names=[ENTRY])
    original = HERE / 'native' / (ENTRY + '.as')
    binding = prepare.read(HERE / 'native-plan.json')
    assert prepare.sha(original) == binding['source_sha256']
    target = out / 'tests' / original.name
    assert not target.exists()
    shutil.copyfile(original, target)
    manifest['inputs'][target.relative_to(out).as_posix()] = prepare.sha(target)
    for p in (original, Path(__file__).resolve(), HERE / 'native-plan.json'):
        manifest['originals'][str(p)] = prepare.sha(p)
    for p in (Path(__file__).resolve(), HERE / 'native-plan.json'):
        dest = out / 'inputs' / p.name
        shutil.copyfile(p, dest)
        manifest['inputs'][dest.relative_to(out).as_posix()] = prepare.sha(dest)
    manifest['extension'] = dict(entry=ENTRY, source_sha256=prepare.sha(original),
                                script_sha256=prepare.sha(Path(__file__)))
    prepare.save(out / 'prepared.json', manifest)
    prepare.verify(out, source)
    if args.build:
        prepare.build(source, out, args.registry_wait)
    print(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
