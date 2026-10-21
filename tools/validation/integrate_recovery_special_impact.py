"""Apply the reviewed no-clip explosion method delta to isolated recovery6."""
import argparse
from collections import Counter
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
BASE = ROOT / 'build/m52/recovery-06'
PATCH = ROOT / 'experimental/recovery-special-impact'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))


def inventory(p):
    return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*.as'))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    before = read(ACTIVE / 'integration.json')
    expected = read(BASE / 'prepared.json')['source']
    assert before['version'] == '0.2.24-recovery6'
    assert len(expected) == 85 and inventory(BASE / 'src') == expected
    assert inventory(ACTIVE / 'src') == expected
    assert {r['path']: r['sha256'] for r in before['source']} == expected
    spec = importlib.util.spec_from_file_location('special_method_merge', PATCH / 'prepare_method_delta.py')
    merge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(merge)
    delta = read(PATCH / 'method-delta-on05.json')['files']
    proof, semantic_labels, fixture = [], None, None
    for variant, folder, count, failures in [
        ('control', 'recovery-special-control-01', 77, 23),
        ('proposal', 'recovery-special-component-02', 87, 0),
    ]:
        run = ROOT / 'build/m52' / folder
        receipt, raw = read(run / 'receipt.json'), read(run / 'component-result.json')
        rows = raw['assertions']
        assert len(rows) == count and all(type(r['passed']) is bool for r in rows)
        assert sum(not r['passed'] for r in rows) == failures == raw['failed']
        assert receipt['compiled'] and receipt['air_started']
        assert receipt['installation_unchanged'] and receipt['source_unchanged']
        assert receipt['passed'] == (failures == 0) and receipt['exit_code'] == (1 if failures else 0)
        assert sha(run / 'Checks.swf') == receipt['component_sha256']
        assert not any('uncaught ' in r['label'] for r in rows)
        # A missing old packet bypasses wire(); the candidate executes ten more
        # codec assertions. All semantic assertions and test bytes are identical.
        labels = Counter(r['label'] for r in rows if 'real binary codec' not in r['label'])
        assert semantic_labels is None or labels == semantic_labels
        semantic_labels = labels
        files = inventory(run / 'src')
        non_delta = {n: h for n, h in files.items() if n not in delta}
        assert fixture is None or non_delta == fixture
        fixture = non_delta
        for name, change in delta.items():
            wanted = change['proposal_sha256'] if variant == 'proposal' else sha(ROOT / 'build/m52/recovery-04/src' / name)
            assert files[name] == wanted
        proof.append(dict(path=str(run.relative_to(ROOT)), rows=count, failures=failures,
                          receipt_sha256=sha(run / 'receipt.json'), raw_sha256=sha(run / 'component-result.json')))
    planned = {}
    for name, change in delta.items():
        assert expected[name] == change['base_sha256']
        assert sha(PATCH / 'src' / name) == change['proposal_sha256']
        old = (ACTIVE / 'src' / name).read_text(encoding='utf-8')
        proposal = (PATCH / 'src' / name).read_text(encoding='utf-8')
        new = old
        for method in change['modified_methods']:
            new = merge.replace_method(new, proposal, method)
        for method in change['added_methods']:
            assert 'function ' + method + '(' not in old
            at = merge.method(new, 'tick')[0]
            new = new[:at] + merge.method(proposal, method)[2] + '\n' + new[at:]
        if name.endswith('ImpactEventQueue.as'):
            assert merge.method(old, 'forget')[2] == merge.method(new, 'forget')[2]
            assert merge.method(old, 'setPaused')[2] == merge.method(new, 'setPaused')[2]
            assert 'channel:channel' in merge.method(new, 'enqueue')[2]
        if name.endswith('ProjectileVisuals.as'):
            assert merge.method(old, 'forget')[2] == merge.method(new, 'forget')[2]
        planned[name] = new.encode('utf-8')
        assert hashlib.sha256(planned[name]).hexdigest() == change['merged_text_sha256']
    entry = (ACTIVE / 'src/RConnectMod.as').read_text(encoding='utf-8')
    assert entry.count('0.2.24-recovery6') == 1
    planned['RConnectMod.as'] = entry.replace('0.2.24-recovery6', '0.2.24-recovery7').encode('utf-8')
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='native-no-clip-explosion-events', source=str(PATCH.relative_to(ROOT)),
        delta_sha256=sha(PATCH / 'method-delta-on05.json'), proof=proof,
        files=[dict(path=n, before_sha256=expected[n], merged_sha256=hashlib.sha256(b).hexdigest())
               for n, b in planned.items() if n != 'RConnectMod.as']))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version='0.2.24-recovery7', compiled=False, runtime_tested=False,
                   deployed=False, gameplay_qualified=False, performance_qualified=False,
                   followup_review='87 proposal component checks pass; final merged detach/native visual checks pending. Gas pulses and acid ground remain separate gaps.',
                   integration_recipe_sha256=sha(Path(__file__)))
    updated['static_checks'].update(compiler_checked=False, no_clip_explosion_component=True)
    if args.apply:
        assert inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before
        originals = {n: (ACTIVE / 'src' / n).read_bytes() for n in planned}
        try:
            for name, data in planned.items():
                assert (ACTIVE / 'src' / name).read_bytes() == originals[name]
                (ACTIVE / 'src' / name).write_bytes(data)
            (ACTIVE / 'integration.json').write_bytes((json.dumps(updated, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
        except Exception:
            for name, data in planned.items():
                if (ACTIVE / 'src' / name).read_bytes() == data:
                    (ACTIVE / 'src' / name).write_bytes(originals[name])
            raise
    print(json.dumps(dict(applied=args.apply, files=sorted(planned), proof=proof, installed=False)))


if __name__ == '__main__':
    main()
