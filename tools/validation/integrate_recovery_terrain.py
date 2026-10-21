"""Integrate the proven local terrain loop into exact recovery10; no deployment."""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from integrate_recovery_clock import ROOT, ACTIVE, sha, read, inventory, replace_transaction

BASE = ROOT/'build/m52/recovery-10'
PATCH = ROOT/'experimental/recovery-terrain-loop'
BASE_SHA = '184eea3d6405ee57cb0bc3f6cfa78668f5ca9334888b0ca2af04095bc17c4608'
FILE = 'rconnect/game/NativeTileState.as'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--component', type=Path, required=True)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    component = (ROOT/args.component).resolve()
    assert component.parent == ROOT/'build/m52'
    before, prepared, patch = read(ACTIVE/'integration.json'), read(BASE/'prepared.json'), read(PATCH/'inputs.json')
    expected = prepared['source']
    assert before['version'] == '0.2.24-recovery10' and sha(BASE/'RConnectMod.swf') == BASE_SHA
    assert len(expected) == 85 and inventory(BASE/'src') == inventory(ACTIVE/'src') == expected
    assert {row['path']:row['sha256'] for row in before['source']} == expected
    for name, digest in patch['input_sources'].items():
        assert sha(Path(name)) == digest, name
    for name, digest in patch['outputs'].items():
        assert sha(PATCH/name) == digest, name
    assert inventory(PATCH/'src').keys() == {FILE}
    assert sha(ROOT/'build/m52/recovery-09/src'/FILE) == expected[FILE]
    old = (BASE/'src'/FILE).read_text(encoding='utf-8')
    assert (PATCH/'components/rconnect/game/ControlNativeTileState.as').read_text(encoding='utf-8') == re.sub(r'\bNativeTileState\b','ControlNativeTileState',old)
    assert (PATCH/'components'/FILE).read_bytes() == (PATCH/'src'/FILE).read_bytes()
    receipt, raw, intent = [read(component/n) for n in ('receipt.json','component-result.json','intent.json')]
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code'] == 0
    assert receipt['source_unchanged'] and receipt['installation_unchanged']
    assert receipt['observed_checks'] == 67 and receipt['checks_failed'] == 0
    assert raw['passed'] and raw['complete'] and raw['failed'] == 0 and len(raw['assertions']) == 67
    assert all(row['passed'] is True for row in raw['assertions'])
    assert intent['entry'] == 'TerrainLoopChecks.as' and intent['expected'] == 67
    assert Path(intent['source']).resolve() == (PATCH/'components').resolve()
    assert intent['sources'] == inventory(component/'src') == inventory(PATCH/'components')
    assert sha(component/'Checks.swf') == receipt['component_sha256']
    assert len(raw['measurements']) == 3
    for row in raw['measurements']:
        assert all(row[n] == 30000 for n in ('tiles','cellsChecked','tableRowsChecked','referenceCellsChecked','callbacksOld','callbacksNew'))
        assert row['scalarValuesCompared'] == row['scalarFields']*30000 and row['scalarFields'] == 45
    entry = (ACTIVE/'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery10') == 1
    planned = {FILE:(PATCH/'src'/FILE).read_bytes(),
        'RConnectMod.as':entry.replace('0.2.24-recovery10','0.2.24-recovery11').encode('utf-8')}
    proof = dict(path=str(component.relative_to(ROOT)), checks=67,
        receipt_sha256=sha(component/'receipt.json'), raw_sha256=sha(component/'component-result.json'),
        native_game_tested=False, performance_qualified=False)
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='local-terrain-loop-metadata', source=str(PATCH.relative_to(ROOT)),
        proposal_sha256=sha(PATCH/'inputs.json'), proof=proof,
        files=[dict(path=FILE,before_sha256=expected[FILE],merged_sha256=sha(PATCH/'src'/FILE))]))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(row['path'] for row in updated['source'] if row['changed'])
    updated.update(version='0.2.24-recovery11',compiled=False,runtime_tested=False,deployed=False,
        gameplay_qualified=False,performance_qualified=False,integration_recipe_sha256=sha(Path(__file__)),
        followup_review='Full terrain class equivalence only; native loading and final motion remain unqualified.')
    updated['static_checks'].update(compiler_checked=False,terrain_loop_component=True)
    if args.apply:
        assert inventory(ACTIVE/'src') == expected and read(ACTIVE/'integration.json') == before
        targets = {ACTIVE/'src'/n:data for n,data in planned.items()}
        targets[ACTIVE/'integration.json'] = (json.dumps(updated,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
        replace_transaction(targets)
        assert inventory(ACTIVE/'src') == {row['path']:row['sha256'] for row in updated['source']}
        assert read(ACTIVE/'integration.json') == updated
    print(json.dumps(dict(applied=args.apply,files=sorted(planned),proof=proof,installed=False)))


if __name__ == '__main__':
    main()
