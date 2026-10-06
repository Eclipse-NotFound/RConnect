"""Retain completed checks only when their compiled/runtime inputs are unchanged.

Changed fixture drivers must run anew. Their independent setup does not justify
repeating already-green drivers with identical compiled and runtime inputs.
"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from validation_baseline import ROOT, sha, read, verify_protected

JAVA = 'C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
FFDEC = 'D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
ALLOWED = {'TelekinesisTestDoc', 'TelekinesisMotionTestDoc', 'EnemyGrabTestDoc', 'LightningSmartTestDoc', 'BeamTerrainTestDoc', 'SatsTestDoc', 'CoopPauseTestDoc', 'RoomCooperationTestDoc'}
FIXTURES = {'tests/BeamTerrainTestDoc.as', 'tests/SatsTestDoc.as', 'tests/ProjectileNetworkTestDoc.as'}
ap = argparse.ArgumentParser()
ap.add_argument('--from-snapshot', type=Path, required=True)
ap.add_argument('--snapshot', type=Path, required=True)
ap.add_argument('entries', nargs='+', choices=sorted(ALLOWED))
a = ap.parse_args()
old, out = a.from_snapshot.resolve(), a.snapshot.resolve()
for folder in (old, out):
    assert folder.parent == ROOT / 'build/m46' and folder.name.startswith('final'), folder
assert old != out
before, current = read(old / 'source-input.json'), read(out / 'source-input.json')
ov, nv = read(old / 'verified-test-input.json'), read(out / 'verified-test-input.json')
assert before['source'] == current['source']
assert before['candidate_sha256'] == current['candidate_sha256'] == sha(old / 'RConnectMod.swf') == sha(out / 'RConnectMod.swf')
assert before['stub_sha256'] == current['stub_sha256'] == sha(out / 'GameCombatStubs.swc')
verify_protected(current)
for name, digest in current['source'].items():
    assert sha(ROOT / name) == sha(old / name) == sha(out / name) == digest, name
changed_tests = []
for name, digest in ov.items():
    assert sha(old / 'verified-files' / name) == digest, name
    if name.startswith(('tests/', 'tools/stubs/')) or name in (
        'tools/build_mod.py', 'tools/build_effects_driver.py', 'tools/run_coop_regression.py',
        'tools/RConnect.Process.ps1', 'tools/keep_test_responsive.ps1', 'tools/verify_mask_png.py'):
        assert name in nv and sha(ROOT / name) == sha(out / 'verified-files' / name) == nv[name], name
        if nv[name] != digest:
            changed_tests.append(name)
assert set(changed_tests) <= FIXTURES, changed_tests
changed_validation = [name for name, digest in ov.items() if name.startswith('tools/validation/') and nv.get(name) != digest]
if not changed_tests:
    assert changed_validation and set(changed_validation) <= {
        'tools/validation/audit_final.py', 'tools/validation/carry_same_byte_checks.py'}, changed_validation
changed_classes = {Path(name).stem for name in changed_tests}
for role in ('host', 'join'):
    assert before['profiles'][role]['sha256'] == current['profiles'][role]['sha256']
receipt = out / 'carried-checks.json'
assert not receipt.exists()
records = []
for entry in a.entries:
    assert entry not in changed_classes, 'Changed fixture must run anew: ' + entry
    result = read(old / (entry + '-result.json'))
    assert result == {'entry': entry, 'run': result['run'], 'exit': 0}, result
    folder = ROOT / 'build/cooperation' / result['run']
    run, inp = read(folder / 'run.json'), read(folder / 'input.json')
    assert sha(folder / 'input.json') == run['input_manifest_sha256']
    assert run['inputs'] == inp['inputs'] and run['configuration_files'] == inp['configuration_files']
    assert run['sha256'] == current['candidate_sha256'] == sha(folder / 'candidate.swf')
    driver = old / (entry + '-driver')
    assert read(driver / 'driver-input.json') == {'candidate_sha256': current['candidate_sha256'], 'entry': entry}
    for role in ('host', 'join'):
        log = (folder / (role + '.log')).read_text(encoding='utf-8-sig')
        assert 'COOP EFFECTS DONE' in log and 'COOP FAIL' not in log and 'Error #1009' not in log
        assert run['inputs'][role]['driver'] == sha(driver / 'EffectsDriver.swf')
        assert run['inputs'][role]['harness'] == sha(driver / 'EffectsHarness.swf')
    listed = subprocess.run([JAVA, '-jar', FFDEC, '-dumpAS3', str(driver / 'EffectsDriver.swf')],
                            check=True, capture_output=True, text=True, encoding='utf-8', errors='replace')
    lines = [line for line in listed.stdout.splitlines() if line.strip()]
    classes = {line.split()[0] for line in lines}
    assert entry in classes and not classes.intersection(changed_classes), classes
    target = out / (entry + '-driver')
    assert not target.exists() and not (out / (entry + '-result.json')).exists()
    shutil.copytree(driver, target)
    (out / (entry + '-driver-classes.txt')).write_text(listed.stdout, encoding='utf-8')
    for suffix in ('result.json', 'build.log', 'runner.log'):
        shutil.copy2(old / (entry + '-' + suffix), out / (entry + '-' + suffix))
    records.append({'entry': entry, 'run': result['run'], 'origin': old.relative_to(ROOT).as_posix(),
                    'result_sha256': sha(out / (entry + '-result.json')),
                    'driver_sha256': sha(target / 'EffectsDriver.swf'),
                    'harness_sha256': sha(target / 'EffectsHarness.swf'),
                    'driver_classes_sha256': sha(out / (entry + '-driver-classes.txt')),
                    'unchanged_test_sha256': nv['tests/' + entry + '.as'],
                    'inputs_sha256': sha(folder / 'input.json'), 'pids': run['pids'],
                    'origin_carry_receipt_sha256': sha(old / 'carried-checks.json') if (old / 'carried-checks.json').exists() else None})
verify_protected(current)
record = {'kind': 'retained exact-byte checks, not new runs', 'entries': records,
          'old_source_manifest_sha256': sha(old / 'source-input.json'),
          'new_source_manifest_sha256': sha(out / 'source-input.json'),
          'old_verification_manifest_sha256': sha(old / 'verified-test-input.json'),
          'new_verification_manifest_sha256': sha(out / 'verified-test-input.json'),
          'changed_driver_source': changed_tests, 'changed_validation_source': changed_validation,
          'controller_sha256': sha(Path(__file__))}
receipt.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'carried': [r['entry'] for r in records], 'candidate_sha256': current['candidate_sha256']}, ensure_ascii=False))
