"""Thin adapter for the existing registered external-density builder; no AIR."""
import hashlib
import importlib.util
from pathlib import Path
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
FIXED = ROOT / 'experimental/recovery-density-fixture'
FROZEN = M52 / 'recovery-density-fixed-drivers-03'
CORRIDOR = M52 / 'recovery-density-corridor-drivers-01'
CORRIDOR_MANIFEST = '4aea5b4182948f6687e89160b52711d569d9a9e46a8b21ef75ba61b2f81832cf'
PROFILE = False
PINNED = {
    'prepare.py': '99249ad83c9adc2d4073d614e0dc4952c22ec647b228c363c5bcbd4220dd7cad',
    'run.py': '7d6bee96c9aa4d817754894f1e623ba4a081bd0a193960ddf65217162993b598',
    'audit.py': '293d8e60c53e47dc946c03726bb4ea5cf57ec3e785a1413a00ee840e83545abe',
}


def load_helper(name):
    path = FIXED / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == PINNED[name], 'Shared helper changed: ' + name
    spec = importlib.util.spec_from_file_location('corridor_base_' + path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


base = load_helper('prepare.py')
base.HERE = HERE
sha, read, save, verify = base.sha, base.read, base.save, base.verify
original_check, original_freeze = base.check_source, base.freeze


def check_source():
    required = original_check()  # Original frame, RENDER detector, all gates.
    manifest = read(FROZEN / 'prepared.json')
    before_path = FROZEN / 'tests/SustainedDensityTestDoc.as'
    assert sha(before_path) == manifest['files']['tests/SustainedDensityTestDoc.as']
    before = before_path.read_text(encoding='utf-8-sig')
    for old, new in read(HERE / 'edits.json'):
        assert before.count(old) == 1
        before = before.replace(old, new)
    assert before == (HERE / 'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8-sig'), 'Unexpected driver change'
    for name in ('DensityFixture.as', 'DensityTrajectoryTotals.as', 'ProjectileLoadTestDoc.as', 'DensityTotalsTestDoc.as'):
        assert sha(HERE / 'tests' / name) == manifest['files']['tests/' + name]
    profile = base.BASE / 'tests/ProjectileProfileTestDoc.as'
    assert sha(HERE / 'tests/ProjectileProfileTestDoc.as') == sha(profile)
    assert sha(profile) == read(base.BASE / 'prepared.json')['files']['tests/ProjectileProfileTestDoc.as']
    helper = (HERE / 'tests/CorridorFixture.as').read_text(encoding='utf-8')
    for literal in ('tile.mainFrame("A")', 'new tileClass(x,y)', 'mod.game.world.redrawLoc()', 'gun.animate();gun.getBulXY();'):
        assert literal in helper
    assert 'gun.attack(' not in helper and '.step(' not in helper
    assert helper.count('mod.game.world.redrawLoc()') == 1
    assert sha(CORRIDOR / 'prepared.json') == CORRIDOR_MANIFEST
    corridor = read(CORRIDOR / 'prepared.json')
    before_helper = CORRIDOR / 'tests/CorridorFixture.as'
    assert sha(before_helper) == corridor['files']['tests/CorridorFixture.as']
    expected = before_helper.read_text(encoding='utf-8-sig')
    for old, new in read(HERE / 'visual-edits.json'):
        assert expected.count(old) == 1
        expected = expected.replace(old, new)
    assert helper == expected, 'Unexpected visual restoration edit'
    # All timed stimulus and thresholds remain byte-exact to compiled corridor01.
    for path in (HERE / 'tests').rglob('*.as'):
        rel = 'tests/' + path.relative_to(HERE / 'tests').as_posix()
        if rel != 'tests/CorridorFixture.as':
            assert sha(path) == corridor['files'][rel], rel
    return required


def freeze(out, diagnostic):
    meta = original_freeze(out, diagnostic)
    # The delegated builder freezes every AS/Python input; add the edit recipe
    # and imported helpers, including originals so post-build drift is rejected.
    import shutil
    for name in ('edits.json', 'geometry-proof.json', 'visual-edits.json'):
        source = HERE / name
        shutil.copyfile(source, out / 'recipe' / name)
        meta['originals'][str(source)] = sha(source)
        meta['inputs']['recipe/' + name] = sha(out / 'recipe' / name)
    for name in PINNED:
        path = FIXED / name
        assert sha(path) == PINNED[name]
        meta['originals'][str(path)] = PINNED[name]
    for path in [FROZEN / 'prepared.json', *sorted((FROZEN / 'tests').glob('*.as'))]:
        meta['originals'][str(path)] = sha(path)
    profile = base.BASE / 'tests/ProjectileProfileTestDoc.as'
    meta['originals'][str(profile)] = sha(profile)
    for path in [CORRIDOR / 'prepared.json', *sorted((CORRIDOR / 'tests').rglob('*.as'))]:
        meta['originals'][str(path)] = sha(path)
    meta.update(fixture='native-open-corridor-v1', source_fixed_driver=str(FROZEN),
        source_fixed_manifest=sha(FROZEN / 'prepared.json'), native_flight_unmodified=True,
        geometry_proof_runtime_verified=False,
        profile=PROFILE,
        source_corridor_driver=str(CORRIDOR), source_corridor_manifest=CORRIDOR_MANIFEST,
        native_visual_restore=True,
        purpose='Native visual reattachment before readiness; unchanged 80 bodies/12 guns/seven windows/gates')
    if PROFILE:
        assert diagnostic
        meta['entry'] = 'ProjectileProfileTestDoc'
    save(out / 'prepared.json', meta)
    verify(out)
    return meta


base.check_source, base.freeze = check_source, freeze

if __name__ == '__main__':
    if '--profile' in sys.argv:
        assert '--diagnostic' not in sys.argv, 'Choose CPU profile or aggregate totals, not both'
        PROFILE = True
        sys.argv.remove('--profile')
        sys.argv.append('--diagnostic')
    if '--output' in sys.argv:
        target = (ROOT / sys.argv[sys.argv.index('--output') + 1]).resolve()
        if target.exists():
            assert read(target / 'prepared.json').get('profile', False) == PROFILE, 'Existing profile mode differs'
    base.main()
