"""Apply the reviewed single-file clock recovery only after actual AS checks."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
BASE = ROOT / 'build/m52/recovery-09'
PATCH = ROOT / 'experimental/recovery-clock-catchup'
BASE_SHA = '1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf'
FILE = 'rconnect/game/RemoteMotion.as'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*.as'))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--component', type=Path, required=True)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    component = (ROOT / args.component).resolve()
    assert component.parent == ROOT / 'build/m52'
    before, prepared, patch = read(ACTIVE/'integration.json'), read(BASE/'prepared.json'), read(PATCH/'inputs.json')
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery9' and sha(BASE/'RConnectMod.swf') == BASE_SHA
    assert len(expected) == 85 and inventory(BASE/'src') == inventory(ACTIVE/'src') == expected
    assert {row['path']: row['sha256'] for row in before['source']} == expected
    assert patch['baseline'] == 'recovery-09'
    for name, digest in patch['ancestors'].items():
        assert sha(Path(name)) == digest, name
    for name, digest in patch['files'].items():
        assert sha(PATCH/name) == digest, name
    assert inventory(PATCH/'src').keys() == {FILE}
    old = (BASE/'src'/FILE).read_text(encoding='utf-8')
    new = (PATCH/'src'/FILE).read_text(encoding='utf-8')
    assert (PATCH/'components/rconnect/game/RemoteMotionBefore.as').read_text(encoding='utf-8') == re.sub(r'\bRemoteMotion\b', 'RemoteMotionBefore', old)
    assert (PATCH/'components/rconnect/game/RemoteMotionAfter.as').read_text(encoding='utf-8') == re.sub(r'\bRemoteMotion\b', 'RemoteMotionAfter', new)
    receipt, raw = read(component/'receipt.json'), read(component/'component-result.json')
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code'] == 0
    assert receipt['source_unchanged'] and receipt['installation_unchanged']
    assert receipt['observed_checks'] == 40 and receipt['checks_failed'] == 0
    assert raw['passed'] and raw['failed'] == 0 and len(raw['assertions']) == 40
    assert all(row['passed'] is True for row in raw['assertions'])
    assert inventory(component/'src') == inventory(PATCH/'components')
    assert sha(component/'Checks.swf') == receipt['component_sha256']
    assert raw['metrics']['recorded']['rows'] == 180
    assert len(raw['trace']) == 180
    entry = (ACTIVE/'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery9') == 1
    planned = {FILE: (PATCH/'src'/FILE).read_bytes(),
               'RConnectMod.as': entry.replace('0.2.24-recovery9', '0.2.24-recovery10').encode('utf-8')}
    proof = dict(path=str(component.relative_to(ROOT)), checks=40,
        receipt_sha256=sha(component/'receipt.json'), raw_sha256=sha(component/'component-result.json'),
        native_game_tested=False, performance_qualified=False)
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='continuous-accumulated-clock-recovery', source=str(PATCH.relative_to(ROOT)),
        proposal_sha256=sha(PATCH/'inputs.json'), proof=proof,
        files=[dict(path=FILE, before_sha256=expected[FILE], merged_sha256=sha(PATCH/'src'/FILE))]))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(row['path'] for row in updated['source'] if row['changed'])
    updated.update(version='0.2.24-recovery10', compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False, integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Actual clock component only; native motion and final combined gameplay/performance remain unqualified.')
    updated['static_checks'].update(compiler_checked=False, accumulated_clock_component=True)
    if args.apply:
        assert inventory(ACTIVE/'src') == expected and read(ACTIVE/'integration.json') == before
        originals = {name: (ACTIVE/'src'/name).read_bytes() for name in planned}
        manifest_bytes = (ACTIVE/'integration.json').read_bytes()
        try:
            for name, data in planned.items():
                assert (ACTIVE/'src'/name).read_bytes() == originals[name]
                (ACTIVE/'src'/name).write_bytes(data)
            (ACTIVE/'integration.json').write_text(json.dumps(updated, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        except BaseException:
            for name, data in planned.items():
                if (ACTIVE/'src'/name).read_bytes() == data:
                    (ACTIVE/'src'/name).write_bytes(originals[name])
            (ACTIVE/'integration.json').write_bytes(manifest_bytes)
            raise
    print(json.dumps(dict(applied=args.apply, files=sorted(planned), proof=proof, installed=False)))


if __name__ == '__main__':
    main()
