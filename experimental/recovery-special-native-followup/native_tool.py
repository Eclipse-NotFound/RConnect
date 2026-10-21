"""Thin adapter over recovery-tests: prepare/run regular drivers, or diag-prepare.

All output folders are fresh build/m52 children. No JVM/AIR without explicit
--build/run. Diagnostic reports retain raw framework evidence but never qualify
the normal production candidate.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'experimental/recovery-tests'))
import prepare
from diagnostic_candidate import verify_base

ENTRY = 'MSWNoVisualExplosionTestDoc'
prepare.ENTRIES[ENTRY] = (2, 300, 'MSW真实就绪首发、独立无图像爆炸及原生粒子像素')
prepare.COMPONENTS = {}


def run_entry():
    import run
    run.SUITES[ENTRY] = 'msw-no-visual'
    drivers = (ROOT / sys.argv[sys.argv.index('--drivers') + 1]).resolve()
    manifest = prepare.read(drivers / 'prepared.json')
    assert manifest['extension']['script_sha256'] == prepare.sha(__file__), 'Adapter changed after freeze'
    assert manifest['extension']['helper_sha256'] == prepare.sha(HERE / 'diagnostic_candidate.py'), 'Helper changed after freeze'
    diagnostic = manifest['extension']['diagnostic_only']
    assert not diagnostic or '--control' not in sys.argv, 'Use regular drivers for the uninstrumented control'
    # The framework remains the sole validator: 22 installed/runtime inputs,
    # exact candidate/driver binding, original FAILs, expected rounds and DONE.
    original_save = run.save
    diagnostic_result = {}
    def save_result(path, value):
        if diagnostic and Path(path).name == 'result.json':
            original_save(Path(path).with_name('framework-result.json'), dict(value))
            diagnostic_result['checks_passed'] = value.get('passed') is True
            # Change the in-memory summary too: the framework must not print
            # a production-looking passed:true for the instrumented variant.
            value.update(diagnostic_checks_passed=diagnostic_result['checks_passed'],
                         diagnostic_only=True, passed=False, native_game_pass=False,
                         production_qualified=False, performance_qualified=False)
        original_save(path, value)
    run.save = save_result
    sys.argv.insert(1, 'native')
    try:
        code = run.main()
        if diagnostic:
            print(json.dumps(dict(diagnostic_only=True, passed=False,
                diagnostic_checks_passed=diagnostic_result.get('checks_passed', False),
                production_qualified=False, performance_qualified=False)), flush=True)
            # Exit 0 only acknowledges successful diagnostic checks. The
            # result, raw evidence and console keep qualification distinct.
            return 0 if diagnostic_result.get('checks_passed') is True else (code or 1)
        return code
    finally:
        run.save = original_save
        assert manifest['extension']['script_sha256'] == prepare.sha(__file__), 'Adapter changed during run'
        assert manifest['extension']['helper_sha256'] == prepare.sha(HERE / 'diagnostic_candidate.py'), 'Helper changed during run'


def main():
    assert len(sys.argv) > 1 and sys.argv[1] in ('prepare', 'diag-prepare', 'run')
    mode = sys.argv.pop(1)
    if mode == 'run':
        return run_entry()
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    assert args.registry_wait >= 0
    if mode == 'diag-prepare':
        import diagnostic_candidate
        return diagnostic_candidate.main(args)
    source, out = (ROOT / args.source).resolve(), (ROOT / args.output).resolve()
    base = verify_base(source)
    assert out.parent == ROOT / 'build/m52' and not out.exists()
    binding = prepare.read(HERE / 'manifest.json')
    original = HERE / 'tests' / (ENTRY + '.as')
    assert prepare.sha(original) == binding['source_hashes']['tests/' + original.name]
    from run import installation, EXPECTED_INSTALLATION_FILES
    before = installation()
    assert len(before) == EXPECTED_INSTALLATION_FILES == 22
    try:
        manifest = prepare.freeze(source, out, entry_names=[ENTRY])
        target = out / 'tests' / original.name
        assert not target.exists(), 'Framework now has this entry; review the adapter'
        shutil.copyfile(original, target)
        manifest['inputs'][target.relative_to(out).as_posix()] = prepare.sha(target)
        for p in (original, Path(__file__), HERE / 'diagnostic_candidate.py', HERE / 'manifest.json'):
            manifest['originals'][str(p.resolve())] = prepare.sha(p)
        for p in (Path(__file__), HERE / 'diagnostic_candidate.py', HERE / 'manifest.json'):
            dest = out / 'inputs' / p.name
            shutil.copyfile(p, dest)
            manifest['inputs'][dest.relative_to(out).as_posix()] = prepare.sha(dest)
        manifest['extension'] = dict(entry=ENTRY, source_sha256=prepare.sha(original),
            script_sha256=prepare.sha(__file__), helper_sha256=prepare.sha(HERE / 'diagnostic_candidate.py'),
            diagnostic_only=base.get('diagnostic_only') is True)
        prepare.save(out / 'prepared.json', manifest)
        prepare.verify(out, source)
        if args.build:
            prepare.build(source, out, args.registry_wait)
    finally:
        after = installation()
        if out.exists():
            prepare.save(out / 'adapter-audit.json', dict(installation_before=before,
                installation_after=after, installation_count=22, unchanged=after == before))
        assert after == before, 'Installation changed while preparing drivers'
    print(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
