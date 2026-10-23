"""Audit aura1, then reuse the prior atomic RC-only deployment and installed smoke.

No deployment occurs without --deploy. The prior deployment file is immutable;
only its candidate constants and evidence audit are bound to this release.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys

if sys.flags.optimize:
    raise RuntimeError('Validation requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
PRODUCT = M52 / 'recovery-aura-offline-01'
DRIVERS = M52 / 'recovery-aura-offline-drivers-01'
GRIP = M52 / 'recovery-aura-offline-grip-02'
THROW = M52 / 'recovery-aura-throw-fixture-native-01'
THROW_DRIVERS = M52 / 'recovery-aura-throw-fixture-drivers-01'
COMPONENT = M52 / 'recovery-aura-offline-component-02'
BASE = 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
NEW = 'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
VERSION = '0.2.24-aura1'
RC = 'mods/Rconnect/release/RConnectMod.swf'
RV = 'mods/RealisticVision/release/RealisticVisionMod.swf'
RV_BUILD = '83d8e590c062e181b70bd5cabef2200084d5e81aaca081d1d1ebc347205c7e65'
RV_RUNTIME = '6dbbae60eb09ff8f42d34e31edc92fb9f83009ba918e9145980c6d289723d8ba'
ORIGIN = ROOT / 'experimental/recovery-offline-production/deploy.py'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def engine():
    assert sha(ORIGIN) == '11ed24df492ec79ca006f12522361be60ed88be97749239194d26797798b9f04'
    module = load('aura_prior_atomic_deployment', ORIGIN)
    module.BASE, module.NEW = BASE, NEW
    module.CANDIDATE, module.VERSION = PRODUCT, VERSION
    module.audit = lambda first: audit(module, first)
    return module


def frozen_product(builder):
    """Verify the historic build without pretending its environment is current.

    This retains every source/artifact/compiler check from builder.verify.
    Installation is checked separately against the one explicit RV update and
    must match both new native runs and the actual release smoke.
    """
    meta = read(PRODUCT / 'prepared.json')
    base = Path(meta['base'])
    builder.base_check(base)
    assert sha(base / 'prepared.json') == meta['base_manifest_sha256']
    assert sha(base / 'compile.json') == meta['base_compile_sha256']
    assert builder.BASES[base.name] == meta['base_sha256']
    assert builder.inventory(Path(meta['overlay'])) == meta['overlay_inputs']
    assert builder.inventory(PRODUCT / 'src') == meta['source']
    assert builder.inventory(PRODUCT / 'tools') == meta['inputs']
    assert sha(PRODUCT / 'source.diff') == meta['patch_sha256']
    assert builder.deps() == meta['dependencies']
    compiled = read(PRODUCT / 'compile.json')
    assert compiled['compiled'] and compiled['compile_exit'] == 0
    assert compiled['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf') == NEW
    assert compiled['prepared_sha256'] == sha(PRODUCT / 'prepared.json')
    assert compiled['installation_before'] == compiled['installation_after'] == meta['installation_before']
    assert compiled['sources_unchanged'] and compiled['installation_unchanged']
    for name, digest in compiled['artifacts'].items():
        assert sha(PRODUCT / name) == digest
    return meta


def audit(m, first=GRIP):
    assert first.resolve() == GRIP.resolve()
    for folder in (ROOT / 'tools', ROOT / 'tools/validation', ROOT / 'tools/host_authority',
                   ROOT.parent / 'ModLoader/tools', ROOT / 'experimental/recovery-tests'):
        sys.path.insert(0, str(folder))
    from run_security_terminals import installation
    builder = load('aura_overlay_builder', ROOT / 'experimental/recovery-isolated-overlay/build.py')
    meta = frozen_product(builder)
    assert meta['version'] == VERSION and meta['diagnostic_only'] is False
    assert meta['base_sha256'] == BASE and sha(PRODUCT / 'RConnectMod.swf') == NEW
    build_baseline = meta['installation_before']
    assert build_baseline[RV] == RV_BUILD
    baseline = dict(build_baseline)
    baseline[RV] = RV_RUNTIME
    assert len(baseline) == 22 and baseline[RC] == BASE and installation() == baseline
    files = {}
    for name, digest in meta['dependencies'].items():
        m.record(files, name, digest)
    for name, digest in read(PRODUCT / 'compile.json')['artifacts'].items():
        m.record(files, PRODUCT / name, digest)
    for path in (Path(__file__), ORIGIN, PRODUCT / 'RConnectMod.swf', PRODUCT / 'prepared.json',
                 PRODUCT / 'compile.json', PRODUCT / 'source.diff', HERE / 'source-manifest.json',
                 ROOT / 'experimental/recovery-isolated-overlay/build.py'):
        m.record(files, path)
    for section, folder in (('source', 'src'), ('inputs', 'tools')):
        for name, digest in meta[section].items():
            m.record(files, PRODUCT / folder / name, digest)
    old = ROOT / 'build/m52/recovery-offline-production-01/src'
    changed = {name for name in meta['source'] if (old / name).read_bytes() != (PRODUCT / 'src' / name).read_bytes()}
    assert changed == {'RConnectMod.as', 'rconnect/core/PeerGrip.as', 'rconnect/game/TelekinesisVisuals.as',
                       'rconnect/game/PlayerBodyEffects.as', 'rconnect/game/GameBridge.as'}
    prep = load('aura_original_driver_prepare', ROOT / 'experimental/recovery-tests/prepare.py')
    checks = load('aura_original_native_checks', ROOT / 'experimental/recovery-tests/run.py')
    for driver_root, entries, components, commands in (
            (DRIVERS, {'PeerGripTestDoc', 'PeerThrowDamageTestDoc'}, {'aura'}, 5),
            (THROW_DRIVERS, {'PeerThrowDamageTestDoc'}, set(), 3)):
        driver = prep.verify(driver_root, PRODUCT / 'src', runtime=True)
        assert driver['compiled'] and driver['candidate_sha256'] == NEW
        assert set(driver['entries']) == entries and set(driver['components']) == components
        for name, digest in driver['files'].items():
            m.record(files, driver_root / name, digest)
        m.record(files, driver_root / 'prepared.json')
        m.record(files, driver_root / 'bounded-compiler.json')
        compiler = read(driver_root / 'bounded-compiler.json')
        assert compiler['error'] is None and len(compiler['commands']) == commands
        assert all(r['exit_code'] == 0 and r['reaped'] for r in compiler['commands'])
        if driver_root == THROW_DRIVERS:
            fixture = driver['fixture_overlay']
            fixture_root = ROOT / 'experimental/recovery-aura-throw-fixture'
            fixture_sha = '8fda8d98a52f03d1300ef5c6d51a4501ac5783b18523d2e62bb5ee0ae527c6b9'
            assert fixture['original_sha256'] == '950fce4ada12525760b5c55c861b9b4188d2b4b5a5c5adf21c2cdcbdb4a52e9e'
            assert fixture['source_sha256'] == fixture_sha
            assert fixture['observation_only'] is False and fixture['native_skill_health_fixture'] is True
            assert fixture['original_rounds'] == 20
            assert Path(fixture['source']).resolve() == fixture_root / 'PeerThrowDamageTestDoc.as'
            m.record(files, fixture_root / 'PeerThrowDamageTestDoc.as', fixture_sha)
            m.record(files, driver_root / 'tests/PeerThrowDamageTestDoc.as', fixture_sha)
            m.record(files, fixture_root / 'prepare.py', fixture['preparation_sha256'])
    runs = []
    for folder, driver_root, entry, suite, rounds in ((GRIP, DRIVERS, 'PeerGripTestDoc', 'peer-grip', 16),
                                         (THROW, THROW_DRIVERS, 'PeerThrowDamageTestDoc', 'peer-throw-damage', 20)):
        result, intent = read(folder / 'result.json'), read(folder / 'intent.json')
        assert result['passed'] and result['exit_code'] == 0 and result['native_game_pass']
        assert result['frozen_inputs_unchanged'] and not result['installation_changes'] and result['installation_after'] == baseline
        assert intent['candidate_sha256'] == NEW and intent['installation_before'] == baseline
        assert intent['entry'] == entry and intent['control'] is False
        assert Path(intent['drivers']).resolve() == driver_root
        assert intent['prepared_sha256'] == sha(driver_root / 'prepared.json')
        for name, digest in intent['tools'].items():
            m.record(files, name, digest)
        run = Path(result['run'])
        raw, logs = m.recorded_run(run, baseline, files, drivers=driver_root / 'drivers' / entry)
        assert Path(raw['candidate']).resolve() == PRODUCT / 'RConnectMod.swf'
        assert result['run_receipt_sha256'] == sha(run / 'run.json')
        registry = read(run / 'registry-result.json')
        assert registry['passed'] is True and registry['cancelled'] is False
        m.record(files, run / 'registry-result.json')
        for role, text in logs.items():
            observed = result[role]
            assert observed['failed_checks'] == 0 and not observed['errors'] and observed['done']
            assert observed['version_loaded'] and observed['connected'] and observed['observed_rounds'] == list(range(rounds))
            passes = re.findall(r'^COOP PASS ' + suite + r' .+$', text, re.M)
            assert len(passes) == observed['passed_checks']
            assert sorted({int(n) for line in passes for n in re.findall(r'\b(?:round|case)=(\d+)\b', line)}) == list(range(rounds))
            assert not checks.errors_in([run / (role + '.log'), run / (role + '.stdout.log')] + sorted((run / 'module-logs' / role).rglob('*.log')))
            assert 'COOP EFFECTS DONE ' + suite in text and 'v' + VERSION + ' initialized' in text
            for name, digest in observed['log_hashes'].items():
                m.record(files, run / name, digest)
        for name in ('result.json', 'intent.json', 'run.log'):
            m.record(files, folder / name)
        runs.append(dict(run=run.name, entry=entry, counts={r:result[r]['passed_checks'] for r in ('host','join')}))
    component = read(COMPONENT / 'result.json')
    ci = read(COMPONENT / 'intent.json')
    raw = read(COMPONENT / 'component-result.json')
    assert Path(ci['drivers']).resolve() == DRIVERS and ci['prepared_sha256'] == sha(DRIVERS / 'prepared.json')
    assert ci['component'] == 'aura' and ci['entry'] == 'PlayerAuraChecks' and ci['expected_checks'] == 59
    # These 59 isolated class checks load no game or RV. Preserve their original
    # RV83D8 inventory rather than relabelling them as a new native combination.
    assert ci['installation_before'] == build_baseline and component['installation_after'] == build_baseline
    assert ci['component_sha256'] == sha(DRIVERS / 'components/aura/Checks.swf') == sha(COMPONENT / 'runtime/Checks.swf')
    assert component['raw_result_sha256'] == sha(COMPONENT / 'component-result.json')
    assert ci['private_desktop'] and ci['minimum_start_bytes'] == 1024**3 and ci['minimum_runtime_bytes'] == 512*1024**2
    timeline = read(COMPONENT / 'memory-timeline.json')
    assert timeline['minimum_commit_bytes'] == 512*1024**2 and timeline['reason'] is None and timeline['exit_code'] == 0
    assert read(COMPONENT / 'memory-before.json')['free_commit_bytes'] >= 1024**3
    for path, digest in ci['tools'].items():
        m.record(files, path, digest)
    assert component['passed'] and component['checks_passed'] == 59 and component['checks_failed'] == 0
    assert component['expected_count_matches'] and component['exit_code'] == 0 and not component['errors']
    assert not component['installation_changes'] and component['frozen_inputs_unchanged']
    assert raw['gameLoaded'] is False
    assert raw['pass'] == 59 and raw['fail'] == 0 and len(raw['checks']) == 59 and all(r['pass'] for r in raw['checks'])
    for name in ('result.json','intent.json','component-result.json','stdout.log','memory-before.json','memory-timeline.json','runtime/Checks.swf'):
        m.record(files, COMPONENT / name)
    visual = read(HERE / 'visual-review-current.json')
    assert visual['run'] == runs[0]['run'] and visual['candidate_sha256'] == NEW and visual['reviewed'] is True
    assert len(visual['images']) == 8
    image_root = ROOT / 'build/cooperation' / runs[0]['run']
    expected_images = {image_root / (role + '-presentation-peer-aura-' + str(round_no) + '-raster-with.png')
                       for role in ('host','join') for round_no in (1,9)}
    expected_images.update(image_root / (role + '-presentation-peer-aura-' + str(round_no) + '-' + state + '.png')
                           for role, round_no in (('join',1),('host',9)) for state in ('raster-without','released'))
    assert {Path(row['path']).resolve() for row in visual['images']} == expected_images
    for row in visual['images']:
        assert row['observed']
        m.record(files, Path(row['path']), row['sha256'])
    m.record(files, HERE / 'visual-review-current.json')
    assert installation() == baseline
    return dict(candidate_sha256=NEW, baseline=baseline, version=VERSION,
                build_baseline=build_baseline, runtime_update={RV:dict(before=RV_BUILD, after=RV_RUNTIME)},
                first_connect=str(GRIP), legacy_key_note='first_connect points to the new PeerGrip audit, not the old offline first-connect run',
                runs=runs, component_checks=59, reviewed_files=files,
                qualified_scope='Peer player telekinesis body aura and cleanup; retains installed offline1 behavior',
                performance_qualified=False, four_reported_fixes_qualified=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument('--audit', action='store_true')
    mode.add_argument('--deploy', action='store_true')
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and re.fullmatch(r'recovery-aura-offline-deploy-(?:audit-)?\d+', out.name)
    assert not out.exists() and 0 <= args.registry_wait <= 3600
    m = engine()
    out.mkdir()
    try:
        proof = audit(m)
        m.save(out / 'audit.json', proof)
        result = m.deploy(out, proof, args.registry_wait) if args.deploy else {'status':'audit-passed-not-installed'}
        m.save(out / 'result.json', dict(passed=True, mode='deploy' if args.deploy else 'audit', **result))
        print(json.dumps({'output':str(out),'status':result['status']}, ensure_ascii=False))
    except BaseException as error:
        m.save(out / 'result.json', dict(passed=False,error=repr(error),release_sha256=sha(m.RELEASE)))
        raise


if __name__ == '__main__':
    main()
