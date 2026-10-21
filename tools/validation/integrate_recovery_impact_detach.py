"""Apply the reviewed, component-tested detach fix to isolated recovery4 only."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
FROZEN = ROOT / 'build/m52/recovery-04'
PATCH = ROOT / 'experimental/recovery-impact-detach'
VERSION = '0.2.24-recovery5'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def require(value, message):
    if not value:
        raise ValueError(message)


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*.as'))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    before = read(ACTIVE / 'integration.json')
    manifest = read(PATCH / 'manifest.json')
    expected = read(FROZEN / 'prepared.json')['source']
    require(before['version'] == '0.2.24-recovery4', 'Expected active recovery4')
    require(len(expected) == 85 and inventory(ACTIVE / 'src') == expected
            and inventory(FROZEN / 'src') == expected, 'Source differs from frozen recovery4')
    require({r['path']: r['sha256'] for r in before['source']} == expected,
            'Active manifest differs from actual source')
    require(inventory(PATCH / 'src') == manifest['overlay_sources'], 'Overlay changed')
    require(len(manifest['overlay_sources']) == 4, 'Expected exactly four reviewed files')
    for name, digest in manifest['base_sources'].items():
        require(expected[name] == digest, 'Overlay ancestor differs: ' + name)

    proof = []
    labels = None
    for variant, failures in [('control', 13), ('candidate', 0)]:
        folder = ROOT / ('build/m52/impact-detach-' + variant + '-01')
        receipt, result = read(folder / 'receipt.json'), read(folder / 'result.json')
        checks = result.get('assertions', [])
        require(len(checks) == 35 and all(type(r.get('passed')) is bool for r in checks),
                'Incomplete actual assertions: ' + variant)
        require(sum(not r['passed'] for r in checks) == failures == result['failed'],
                'Unexpected raw failures: ' + variant)
        current_labels = [r['label'] for r in checks]
        require(labels is None or labels == current_labels, 'Control/candidate tests differ')
        labels = current_labels
        require(receipt['ran'] and receipt['compiled'] and receipt['report_valid']
                and receipt['sources_unchanged'] and receipt['frozen_sources_unchanged']
                and receipt['installation_unchanged'] and not receipt['unrelated_failures'],
                'Invalid component receipt: ' + variant)
        require(receipt['functional_pass'] == (failures == 0)
                and receipt['exit'] == (1 if failures else 0)
                and sha(folder / 'Checks.swf') == receipt['checks_swf_sha256'],
                'Component execution/artifact differs: ' + variant)
        tested = inventory(folder / 'src')
        for name, digest in manifest['overlay_sources'].items():
            require(tested[name] == (digest if variant == 'candidate'
                                    else manifest['base_sources'][name]), 'Tested source differs: ' + name)
        proof.append(dict(variant=variant, path=folder.relative_to(ROOT).as_posix(),
                          receipt_sha256=sha(folder / 'receipt.json'),
                          result_sha256=sha(folder / 'result.json'),
                          swf_sha256=receipt['checks_swf_sha256'], checks=35, failures=failures))

    planned = {name: (PATCH / 'src' / name).read_bytes() for name in manifest['overlay_sources']}
    entry = (ACTIVE / 'src/RConnectMod.as').read_text(encoding='utf-8')
    require(entry.count('0.2.24-recovery4') == 1, 'Version anchor differs')
    planned['RConnectMod.as'] = entry.replace('0.2.24-recovery4', VERSION).encode('utf-8')
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='received-impact-clock-detach-on-shooter-leave',
        source='experimental/recovery-impact-detach/src',
        manifest_sha256=sha(PATCH / 'manifest.json'), component=proof,
        files=[dict(path=n, before_sha256=expected[n], merged_sha256=h)
               for n, h in manifest['overlay_sources'].items()]))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version=VERSION, compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False,
        followup_review='Only shooter-leave impact clock detach; control 13/35 failures, candidate 35/35 pass. Native departure and overall performance remain unqualified.',
        integration_recipe_sha256=sha(Path(__file__)))
    updated['static_checks'].update(compiler_checked=False, impact_detach_red_green_35=True)
    if args.apply:
        require(inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before,
                'Concurrent active-tree modification')
        original = {name: (ACTIVE / 'src' / name).read_bytes() for name in planned}
        try:
            for name, data in planned.items():
                require((ACTIVE / 'src' / name).read_bytes() == original[name], 'Concurrent source edit')
                (ACTIVE / 'src' / name).write_bytes(data)
            (ACTIVE / 'integration.json').write_text(json.dumps(updated, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        except Exception:
            for name, data in planned.items():
                if (ACTIVE / 'src' / name).read_bytes() == data:
                    (ACTIVE / 'src' / name).write_bytes(original[name])
            raise
    print(json.dumps(dict(applied=args.apply, version=VERSION, files=sorted(planned),
                          proof=proof, native_tested=False, installed=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
