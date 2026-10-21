"""Integrate the measured, bounded wall-cache capacity change into recovery7."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
BASE = ROOT / 'build/m52/recovery-07'
PATCH = ROOT / 'experimental/recovery-wall-working-set'
NAME = 'rconnect/game/WallImpactVisuals.as'
BASE_SHA = 'c9f6492117124dea23a6991396cf9957d7b73a9730b747b4c8b1cad9533ca3bc'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def inventory(p):
    return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*.as'))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--component', type=Path, required=True)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    component = (ROOT / args.component).resolve()
    assert component.parent == ROOT / 'build/m52'
    before, prepared, patch = read(ACTIVE / 'integration.json'), read(BASE / 'prepared.json'), read(PATCH / 'inputs.json')
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery7' and sha(BASE / 'RConnectMod.swf') == BASE_SHA
    assert len(expected) == 85 and inventory(BASE / 'src') == inventory(ACTIVE / 'src') == expected
    assert {r['path']: r['sha256'] for r in before['source']} == expected
    assert patch['baselineSHA256'] == BASE_SHA and patch['sourceInputs'][str(BASE / 'src' / NAME)] == expected[NAME]
    for name, digest in patch['outputs'].items():
        assert sha(PATCH / name) == digest, name
    old = (BASE / 'src' / NAME).read_text(encoding='utf-8-sig')
    new = (PATCH / 'src' / NAME).read_text(encoding='utf-8-sig')
    restored = new
    for key, a, b in [('ENTRIES', 64, 128), ('WORDS', 32768, 131072), ('CHARS', 131072, 524288)]:
        token = f'WORD_CACHE_{key}:int={b};'
        assert restored.count(token) == 1
        restored = restored.replace(token, f'WORD_CACHE_{key}:int={a};')
    assert restored == old, 'Delta exceeds three capacity constants'
    receipt, raw = read(component / 'receipt.json'), read(component / 'component-result.json')
    rows = raw['assertions']
    assert len(rows) == 73 and all(r['passed'] is True for r in rows) and raw['failed'] == 0 and raw['passed'] is True
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code'] == 0
    assert receipt['inputs_unchanged'] is True and receipt['installation_changes'] == {}
    assert len(receipt['installation_after']) == 22
    assert sha(component / 'Checks.swf') == receipt['component_sha256']
    assert inventory(component / 'frozen/components') == inventory(PATCH / 'components')
    assert sha(component / 'frozen/data/flight-payloads.json') == patch['outputs']['data/flight-payloads.json']
    assert raw['measurements']['trace']['oldUnpack'] == 1276 and raw['measurements']['trace']['newUnpack'] == 82
    entry = (ACTIVE / 'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery7') == 1
    planned = {NAME: (PATCH / 'src' / NAME).read_bytes(),
               'RConnectMod.as': entry.replace('0.2.24-recovery7', '0.2.24-recovery8').encode('utf-8')}
    proof = dict(path=str(component.relative_to(ROOT)), checks=73, old_unpack=1276, new_unpack=82,
                 receipt_sha256=sha(component / 'receipt.json'), raw_sha256=sha(component / 'component-result.json'),
                 game_loaded=False, performance_qualified=False)
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='bounded-wall-cache-working-set', source=str(PATCH.relative_to(ROOT)),
        proposal_sha256=sha(PATCH / 'inputs.json'), proof=proof,
        files=[dict(path=NAME, before_sha256=expected[NAME], merged_sha256=hashlib.sha256(planned[NAME]).hexdigest())]))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version='0.2.24-recovery8', compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False, integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Actual cache replay passes; native flight, special explosions, loading and final combined qualification remain pending.')
    updated['static_checks'].update(compiler_checked=False, bounded_working_set_component=True)
    if args.apply:
        assert inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before
        originals = {n: (ACTIVE / 'src' / n).read_bytes() for n in planned}
        manifest_bytes = (ACTIVE / 'integration.json').read_bytes()
        try:
            for name, data in planned.items():
                assert (ACTIVE / 'src' / name).read_bytes() == originals[name]
                (ACTIVE / 'src' / name).write_bytes(data)
            (ACTIVE / 'integration.json').write_text(json.dumps(updated, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        except Exception:
            for name, data in planned.items():
                if (ACTIVE / 'src' / name).read_bytes() == data:
                    (ACTIVE / 'src' / name).write_bytes(originals[name])
            (ACTIVE / 'integration.json').write_bytes(manifest_bytes)
            raise
    print(json.dumps(dict(applied=args.apply, files=sorted(planned), proof=proof, installed=False)))


if __name__ == '__main__':
    main()
