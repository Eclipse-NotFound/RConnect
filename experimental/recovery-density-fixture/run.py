"""Thin adapter: original motion runner, then mandatory actual-scene audit."""
import argparse
from pathlib import Path
import subprocess
import sys
from prepare import ROOT, M52, verify, sha, save
from audit import audit


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('candidate', 'drivers', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--reference', type=Path)
    p.add_argument('--registry-wait', type=int, default=900)
    a = p.parse_args()
    candidate, drivers, out = [(ROOT / getattr(a, key)).resolve() for key in ('candidate', 'drivers', 'output')]
    ref = (ROOT / a.reference).resolve() if a.reference else None
    assert candidate.parent == drivers.parent == out.parent == M52.resolve() and not out.exists()
    assert ref is None or ref.parent == M52.resolve()
    meta = verify(drivers)
    assert meta['compiled'] and meta['compile_exit'] == 0
    wrapper = ROOT / 'tools/validation/run_motion_comparison.py'
    recipe = {str(path): sha(path) for path in [Path(__file__), Path(__file__).with_name('prepare.py'),
        Path(__file__).with_name('audit.py'), wrapper]}
    command = [sys.executable, '-B', '-X', 'utf8', str(wrapper), '--candidate', str(candidate),
        '--drivers', str(drivers), '--output', str(out), '--case', 'density', '--registry-wait', str(a.registry_wait)]
    if ref:
        command += ['--reference', str(ref)]
    # The existing wrapper retains full mods, unique AppIDs, private desktop,
    # defer-visible, wait-host-world, exclusive AIR and original memory gates.
    process = subprocess.run(command, cwd=ROOT)
    if not out.exists():
        raise SystemExit(process.returncode or 1)
    report = audit(out, ref) if (out / 'result.json').exists() else dict(passed=False, error='Original wrapper did not finish')
    report.update(recipe_sha256=recipe, delegated_exit=process.returncode, original_result_unchanged=True)
    try:
        verify(drivers)
        assert all(sha(Path(name)) == digest for name, digest in recipe.items())
        report['recipe_and_driver_unchanged'] = True
    except (AssertionError, OSError, ValueError) as error:
        report.update(passed=False, attribution_allowed=False, recipe_and_driver_unchanged=False, error=str(error))
    target = out / 'fixture-audit.json'
    assert not target.exists()
    save(target, report)
    print('FIXTURE_AUDIT ' + str(target), flush=True)
    raise SystemExit(0 if process.returncode == 0 and report['passed'] else 1)


if __name__ == '__main__':
    main()
