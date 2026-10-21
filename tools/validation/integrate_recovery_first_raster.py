"""Merge the reviewed native/seed raster lifecycle into exact recovery12.

Only isolated source changes. The host and final native validation are separate.
"""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
from integrate_recovery_clock import ROOT, ACTIVE, sha, read, inventory, replace_transaction

BASE = ROOT / 'build/m52/recovery-12'
FIRST = ROOT / 'experimental/recovery-first-raster'
SEED = ROOT / 'experimental/recovery-seed-first-raster'
PIN = 'f16a8d005fc188b93044b2e7fdb99421edd6cb2a7182511b7a1219c78cf072b3'
FIRST_PIN = '7975167afc40992946624a8d73369df05f7c42ff742b52c4573bba0928b8f239'


def component(folder, entry, count):
    folder = ROOT / 'build/m52' / folder
    receipt, intent, result = [read(folder / name) for name in ('receipt.json', 'intent.json', 'component-result.json')]
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code'] == 0
    assert receipt['installation_unchanged'] and receipt['source_unchanged']
    assert intent['entry'] == entry and receipt['observed_checks'] == count and receipt['checks_failed'] == 0
    assert len(result['assertions']) == count and all(r['passed'] is True for r in result['assertions'])
    assert inventory(folder / 'src') == intent['sources'] == inventory(Path(intent['source']))
    assert sha(folder / 'Checks.swf') == receipt['component_sha256']
    return dict(path=str(folder.relative_to(ROOT)), checks=count, receipt_sha256=sha(folder / 'receipt.json'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    before, prepared = read(ACTIVE / 'integration.json'), read(BASE / 'prepared.json')
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery12' and prepared['compiled']
    assert sha(BASE / 'RConnectMod.swf') == PIN
    assert inventory(ACTIVE / 'src') == inventory(BASE / 'src') == expected
    assert {r['path']: r['sha256'] for r in before['source']} == expected
    first, seed = read(FIRST / 'integration.json'), read(SEED / 'integration.json')
    for name, digest in first['inputs'].items():
        path = ROOT / name
        assert sha(path) == digest
        if '/src/' in path.as_posix():
            relative = path.relative_to(ROOT / 'build/m52/recovery-11/src').as_posix()
            assert expected[relative] == digest, 'Recovery12 changed a raster ancestor'
    for name, digest in first['overlays'].items():
        assert sha(FIRST / name) == digest
    assert sha(ROOT / 'build/m52/recovery-first-raster-02/RConnectMod.swf') == seed['base_sha256'] == FIRST_PIN
    assert sha(FIRST / 'src/rconnect/core/RoomSync.as') == seed['base_source_sha256']
    assert inventory(SEED / 'src') == seed['sources']
    assert set(seed['sources']) == {'rconnect/core/RoomSync.as', 'rconnect/core/SeedRasterEntry.as'}
    # Validate the actual compiled host again, preserving its original failed
    # formatting-only readback receipt and the separate corrected acceptance.
    sys.path.insert(0, str(ROOT / 'experimental/recovery-first-raster-native'))
    import reverify_host
    host = reverify_host.verify()
    assert host['validated'] and host['candidate_sha256'] == seed['host_sha256']
    proofs = [
        component('recovery-first-raster-gate-01', 'FirstRasterGateChecks.as', 19),
        component('recovery-first-raster-room-02', 'NativeTravelRoomChecks.as', 79),
        component('recovery-first-raster-native-methods-02', 'FirstRasterNativeChecks.as', 20),
        component('recovery-seed-first-raster-room-01', 'NativeTravelRoomChecks.as', 109),
    ]
    planned = {name: (FIRST / 'src' / name).read_bytes() for name in inventory(FIRST / 'src')}
    planned.update({name: (SEED / 'src' / name).read_bytes() for name in seed['sources']})
    assert len(planned) == 6
    entry = (ACTIVE / 'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-recovery12') == 1
    planned['RConnectMod.as'] = entry.replace(b'0.2.24-recovery12', b'0.2.24-recovery13')
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='native-and-seed-confirmed-first-raster',
        proposals=[dict(path=str(p.relative_to(ROOT)), sha256=sha(p / 'integration.json')) for p in (FIRST, SEED)],
        required_host_sha256=host['candidate_sha256'], component_proofs=proofs,
        files=[dict(path=n, before_sha256=expected.get(n), merged_sha256=hashlib.sha256(data).hexdigest())
               for n, data in sorted(planned.items())]))
    rows = {r['path']: r for r in updated['source']}
    for name, data in planned.items():
        if name not in rows:
            rows[name] = dict(path=name, baseline_sha256=None)
        rows[name]['sha256'] = hashlib.sha256(data).hexdigest()
    for row in rows.values():
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['source'] = [rows[name] for name in sorted(rows)]
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version='0.2.24-recovery13', compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False, integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Native/seed first raster components only. Final loading, pixels, gameplay and performance unqualified.')
    updated['static_checks'].update(compiler_checked=False, seed_first_raster_component=True)
    if args.apply:
        assert inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before
        targets = {ACTIVE / 'src' / name: data for name, data in planned.items()}
        targets[ACTIVE / 'integration.json'] = (json.dumps(updated, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        created = []
        try:
            # Only the two explicitly named new classes may be created; all
            # preexisting files retain the existing rollback-safe replacement.
            for target, data in targets.items():
                if target.exists():
                    continue
                assert target.parent == ACTIVE / 'src/rconnect/core'
                assert target.name in ('FirstRasterGate.as', 'SeedRasterEntry.as')
                with target.open('xb') as stream:
                    stream.write(data)
                created.append(target)
            replace_transaction({p: data for p, data in targets.items() if p not in created})
        except BaseException:
            for target in created:
                assert target.resolve().is_relative_to(ACTIVE.resolve()) and target.read_bytes() == targets[target]
                target.unlink()
            raise
        assert inventory(ACTIVE / 'src') == {r['path']: r['sha256'] for r in updated['source']}
    print(json.dumps(dict(applied=args.apply, sources=len(updated['source']), files=sorted(planned),
        required_host=host['candidate_sha256'], proofs=proofs, installed=False)))


if __name__ == '__main__':
    main()
