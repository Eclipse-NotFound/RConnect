"""Merge the component-verified two-file acid footprint patch into recovery8."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
BASE = ROOT / 'build/m52/recovery-08'
PATCH = ROOT / 'experimental/recovery-acid-ground'
BASE_SHA = '74d2ab0f6c1d174153af56e9c3a8e3750fa429de066f0dfe90226d48db906f02'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*.as'))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--component', type=Path, required=True)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    component = (ROOT / args.component).resolve()
    assert component.parent == ROOT / 'build/m52'
    before, prepared, patch = read(ACTIVE / 'integration.json'), read(BASE / 'prepared.json'), read(PATCH / 'inputs.json')
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery8' and sha(BASE / 'RConnectMod.swf') == BASE_SHA
    assert len(expected) == 85 and inventory(BASE / 'src') == inventory(ACTIVE / 'src') == expected
    assert {r['path']: r['sha256'] for r in before['source']} == expected
    assert patch['ancestor'] == 'build/m52/recovery-07' and patch['expected_assertions'] == 49
    for name, digest in patch['files'].items():
        assert sha(PATCH / name) == digest, name
    assert sha(PATCH / 'prepare.py') == patch['prepare_sha256']
    assert sha(PATCH / 'proposal.patch') == patch['patch_sha256']
    planned = {}
    for name, digest in patch['baseline'].items():
        relative = 'rconnect/game/' + name
        assert expected[relative] == digest, 'Cannot overwrite a later independent fix'
        planned[relative] = (PATCH / 'src' / relative).read_bytes()
    assert set(planned) == {'rconnect/game/BurnVisuals.as', 'rconnect/game/ProjectileExplosionVisuals.as'}
    receipt, raw = read(component / 'receipt.json'), read(component / 'component-result.json')
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code'] == 0
    assert receipt['source_unchanged'] and receipt['installation_unchanged']
    assert receipt['observed_checks'] == 49 and receipt['checks_failed'] == 0
    assert len(raw['assertions']) == 49 and all(r['passed'] is True for r in raw['assertions'])
    assert raw['passed'] and raw['failed'] == 0
    assert sha(component / 'Checks.swf') == receipt['component_sha256']
    assert inventory(component / 'src') == inventory(PATCH / 'components')
    entry = (ACTIVE / 'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery8') == 1
    planned['RConnectMod.as'] = entry.replace('0.2.24-recovery8', '0.2.24-recovery9').encode('utf-8')
    proof = dict(path=str(component.relative_to(ROOT)), checks=49,
        receipt_sha256=sha(component / 'receipt.json'), raw_sha256=sha(component / 'component-result.json'),
        native_game_tested=False, performance_qualified=False)
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='native-acid-ground-footprints', source=str(PATCH.relative_to(ROOT)),
        proposal_sha256=sha(PATCH / 'inputs.json'), proof=proof,
        files=[dict(path=n, before_sha256=expected[n], merged_sha256=hashlib.sha256(b).hexdigest())
               for n, b in planned.items() if n != 'RConnectMod.as']))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version='0.2.24-recovery9', compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False, integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Acid ground component passes; native acid, gas pulses, motion and loading remain unqualified.')
    updated['static_checks'].update(compiler_checked=False, acid_ground_component=True)
    if args.apply:
        assert inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before
        originals = {n: (ACTIVE / 'src' / n).read_bytes() for n in planned}
        original_manifest = (ACTIVE / 'integration.json').read_bytes()
        try:
            for name, data in planned.items():
                assert (ACTIVE / 'src' / name).read_bytes() == originals[name]
                (ACTIVE / 'src' / name).write_bytes(data)
            (ACTIVE / 'integration.json').write_text(json.dumps(updated, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        except Exception:
            for name, data in planned.items():
                if (ACTIVE / 'src' / name).read_bytes() == data:
                    (ACTIVE / 'src' / name).write_bytes(originals[name])
            (ACTIVE / 'integration.json').write_bytes(original_manifest)
            raise
    print(json.dumps(dict(applied=args.apply, files=sorted(planned), proof=proof, installed=False)))


if __name__ == '__main__':
    main()
