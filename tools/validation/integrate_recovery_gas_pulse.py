"""Merge the four-class, component-verified gas observer into exact recovery11.

No deployment. The native gas test and final performance qualification remain open.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from integrate_recovery_clock import ROOT, ACTIVE, sha, read, inventory, replace_transaction

BASE = ROOT / 'build/m52/recovery-11'
PATCH = ROOT / 'experimental/recovery-gas-pulse'
PIN = 'cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5'
FILES = {'rconnect/game/' + name + '.as' for name in (
    'UnitPresentation', 'EnergyImpactVisuals', 'ProjectileExplosionVisuals', 'DeathVisuals')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--component', type=Path, required=True)
    parser.add_argument('--control', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    component, control = [(ROOT / p).resolve() for p in (args.component, args.control)]
    assert component.parent == control.parent == ROOT / 'build/m52'
    before, prepared, patch = [read(p) for p in (
        ACTIVE / 'integration.json', BASE / 'prepared.json', PATCH / 'inputs.json')]
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery11' and prepared['compiled']
    assert sha(BASE / 'RConnectMod.swf') == patch['base_sha256'] == PIN
    assert inventory(ACTIVE / 'src') == inventory(BASE / 'src') == expected
    assert {r['path']: r['sha256'] for r in before['source']} == expected
    assert inventory(PATCH / 'src').keys() == FILES
    for name, digest in patch['source'].items():
        assert expected['rconnect/game/' + name] == digest
    for name, digest in patch['files'].items():
        assert sha(PATCH / name) == digest, name
    assertions = []
    proofs = []
    for folder, kind in ((control, 'control'), (component, 'candidate')):
        receipt, raw, intent = [read(folder / p) for p in ('receipt.json', 'component-result.json', 'intent.json')]
        assert receipt['compiled'] and receipt['air_started']
        assert receipt['source_unchanged'] and receipt['installation_unchanged']
        assert intent['entry'] == 'GasPulseChecks.as' and intent['expected'] == 63
        assert Path(intent['source']).resolve() == (PATCH / 'components' / kind).resolve()
        assert inventory(folder / 'src') == intent['sources'] == inventory(PATCH / 'components' / kind)
        assert sha(folder / 'Checks.swf') == receipt['component_sha256']
        rows = raw['assertions']
        assert len(rows) == receipt['observed_checks'] == 63
        assert raw['failed'] == receipt['checks_failed'] == sum(r['passed'] is False for r in rows)
        if kind == 'candidate':
            assert receipt['passed'] and receipt['exit_code'] == 0 and raw['passed'] and raw['failed'] == 0
            assert all(row['passed'] is True for row in rows)
            assert raw['wireBytes'] and max(raw['wireBytes']) < 24 * 1024
        else:
            assert not receipt['passed'] and receipt['exit_code'] == 1 and raw['failed'] == 34
        assertions.append([r['label'] for r in rows])
        proofs.append(dict(path=str(folder.relative_to(ROOT)), checks=63, failed=raw['failed'],
            receipt_sha256=sha(folder / 'receipt.json'), raw_sha256=sha(folder / 'component-result.json')))
    assert assertions[0] == assertions[1], 'Control and candidate did not run the same assertions'
    planned = {name: (PATCH / 'src' / name).read_bytes() for name in FILES}
    entry = (ACTIVE / 'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery11') == 1
    planned['RConnectMod.as'] = entry.replace('0.2.24-recovery11', '0.2.24-recovery12').encode('utf-8')
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='actual-native-gas-particles', source=str(PATCH.relative_to(ROOT)),
        proposal_sha256=sha(PATCH / 'inputs.json'), component_proofs=proofs,
        files=[dict(path=n, before_sha256=expected[n], merged_sha256=sha(PATCH / 'src' / n)) for n in sorted(FILES)]))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version='0.2.24-recovery12', compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False, integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Gas components only; native gas, final loading, motion and performance still unqualified.')
    updated['static_checks'].update(compiler_checked=False, gas_pulse_component=True)
    if args.apply:
        assert inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before
        targets = {ACTIVE / 'src' / name: data for name, data in planned.items()}
        targets[ACTIVE / 'integration.json'] = (json.dumps(updated, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        replace_transaction(targets)
        assert inventory(ACTIVE / 'src') == {r['path']: r['sha256'] for r in updated['source']}
    print(json.dumps(dict(applied=args.apply, files=sorted(planned), proofs=proofs, installed=False)))


if __name__ == '__main__':
    main()
