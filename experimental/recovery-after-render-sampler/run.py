"""Driver03's original verification/audit with explicit frozen player RV templates."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT/'experimental/recovery-density-corridor-readyfix'))
from sampler import M52, PROFILE, frozen_sources, verify_sampler, sha, save, write_diagnostic
from audit import audit


def frozen_inputs():
    frozen_sources()
    meta = json.loads((PROFILE/'inputs.json').read_text(encoding='utf-8'))
    handoff = json.loads((PROFILE/'handoff.json').read_text(encoding='utf-8'))
    for name, digest in handoff['files'].items():
        assert sha(PROFILE/name) == digest, 'Profile recipe changed: '+name
    for name, digest in meta['dependencies'].items():
        assert sha(Path(name)) == digest, 'Original dependency changed: '+name
    for row in meta['templates'].values():
        assert sha(PROFILE/row['frozen']) == row['sha256'], 'Frozen RV template changed'
    return meta


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('candidate', 'output'):
        p.add_argument('--'+name, type=Path, required=True)
    p.add_argument('--drivers', type=Path, default=Path('build/m52/recovery-after-render-sampler-drivers-01'))
    p.add_argument('--reference', type=Path)
    p.add_argument('--registry-wait', type=int, default=900)
    a = p.parse_args()
    profile = frozen_inputs()
    candidate, drivers, out = [(ROOT/getattr(a, key)).resolve() for key in ('candidate', 'drivers', 'output')]
    ref = (ROOT/a.reference).resolve() if a.reference else None
    assert candidate.parent == drivers.parent == out.parent == M52.resolve() and not out.exists()
    assert ref is None or ref.parent == M52.resolve()
    meta = verify_sampler(drivers)
    assert meta['compiled'] and meta['compile_exit'] == 0
    user_before = {role: sha(Path(row['source'])) for role, row in profile['templates'].items()}
    assert user_before == {role: row['sha256'] for role, row in profile['templates'].items()}, \
        'Live user settings changed since capture; freeze a new profile before testing'
    wrapper = PROFILE/'run_motion_comparison.py'
    recipe = {str(path): sha(path) for path in [HERE/'handoff.json', HERE/'inputs.json',
        Path(__file__), wrapper]}
    command = [sys.executable, '-B', '-X', 'utf8', str(wrapper), '--candidate', str(candidate),
        '--drivers', str(drivers), '--output', str(out), '--case', 'density', '--registry-wait', str(a.registry_wait)]
    for role, row in profile['templates'].items():
        command += ['--'+role+'-vision-config-template', str(PROFILE/row['frozen'])]
    if ref:
        command += ['--reference', str(ref)]
    # Same registered lower runner; no direct AIR launch or global process hook.
    process = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace')
    if not out.exists() and process.stderr:
        print(process.stderr[-4000:], file=sys.stderr)
    if not out.exists():
        raise SystemExit(process.returncode or 1)
    (out/'profile-wrapper.stdout.log').write_text(process.stdout, encoding='utf-8')
    (out/'profile-wrapper.stderr.log').write_text(process.stderr, encoding='utf-8')
    report = audit(out, ref) if (out/'result.json').exists() else dict(passed=False, error='Profile wrapper did not finish')
    report.update(recipe_sha256=recipe, delegated_exit=process.returncode, original_result_unchanged=True,
        settings_profile='frozen-current-player-rv-settings', user_settings_before=user_before,
        diagnostic_only=True, performance_qualified=False, release_qualified=False)
    try:
        verify_sampler(drivers)
        frozen_inputs()
        assert all(sha(Path(name)) == digest for name, digest in recipe.items())
        user_after = {role: sha(Path(row['source'])) for role, row in profile['templates'].items()}
        report['user_settings_after'] = user_after
        report['user_settings_unchanged'] = user_after == user_before
        assert report['user_settings_unchanged'], 'Live user settings changed during diagnostic'
        report['recipe_and_driver_unchanged'] = True
    except (AssertionError, OSError, ValueError) as error:
        report.update(passed=False, attribution_allowed=False, recipe_and_driver_unchanged=False, error=str(error))
    target = out/'fixture-audit.json'
    assert not target.exists()
    save(target, report)
    if (out/'result.json').exists():
        write_diagnostic(out)
    print('FIXTURE_AUDIT '+str(target), flush=True)
    raise SystemExit(0 if process.returncode == 0 and report['passed'] else 1)


if __name__ == '__main__':
    main()
