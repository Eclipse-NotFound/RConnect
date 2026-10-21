"""Apply only the verified optional-codec-diagnostics change to recovery5."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from integrate_recovery_impact_detach import ROOT, ACTIVE, sha, read, require, inventory

PATCH = ROOT / 'experimental/recovery-codec-diagnostics'
CHECKS = ROOT / 'build/m52/recovery-codec-diagnostics-component-01'
FROZEN = ROOT / 'build/m52/recovery-05'
NAME = 'rconnect/net/RoomCodec.as'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    before, frozen = read(ACTIVE / 'integration.json'), read(FROZEN / 'prepared.json')
    expected, manifest = frozen['source'], read(PATCH / 'manifest.json')
    require(before['version'] == '0.2.24-recovery5' and len(expected) == 85, 'Wrong base')
    require(inventory(ACTIVE / 'src') == expected == inventory(FROZEN / 'src'), 'Base source changed')
    require(expected[NAME] == manifest['source_sha256'], 'Codec ancestor differs')
    for name, digest in manifest['files'].items():
        require(sha(ROOT / name) == digest, 'Proposal changed: ' + name)
    receipt, raw = read(CHECKS / 'receipt.json'), read(CHECKS / 'component-result.json')
    require(receipt['passed'] and receipt['source_unchanged'] and receipt['installation_unchanged']
            and receipt['observed_checks'] == 199 and receipt['checks_failed'] == 0
            and receipt['exit_code'] == 0 and receipt['compile_exit'] == 0, 'Component did not pass')
    require(sha(CHECKS / 'Checks.swf') == receipt['component_sha256'], 'Component changed')
    require(len(raw['assertions']) == 199 and all(r['passed'] is True for r in raw['assertions']),
            'Expected actual 199 passing checks')
    require(inventory(PATCH / 'components') == inventory(CHECKS / 'src'), 'Tested source changed')
    proposed = (PATCH / 'src' / NAME).read_bytes()
    require((CHECKS / 'src/rconnect/net/CodecAfter.as').read_bytes().replace(b'class CodecAfter', b'class RoomCodec') == proposed,
            'Test class does not match production proposal')
    require((CHECKS / 'src/rconnect/net/CodecBefore.as').read_bytes().replace(b'class CodecBefore', b'class RoomCodec')
            == (ACTIVE / 'src' / NAME).read_bytes(), 'Control class differs')
    version = '0.2.24-recovery6'
    entry = (ACTIVE / 'src/RConnectMod.as').read_bytes()
    require(entry.count(b'0.2.24-recovery5') == 1, 'Version anchor differs')
    planned = {NAME: proposed, 'RConnectMod.as': entry.replace(b'0.2.24-recovery5', version.encode())}
    updated = copy.deepcopy(before)
    updated['layers'].append(dict(name='opt-in-codec-diagnostics', source='experimental/recovery-codec-diagnostics/src',
        files=[dict(path=NAME, before_sha256=expected[NAME], merged_sha256=hashlib.sha256(proposed).hexdigest())],
        component=dict(receipt='build/m52/recovery-codec-diagnostics-component-01/receipt.json',
                       receipt_sha256=sha(CHECKS / 'receipt.json'), raw_result_sha256=sha(CHECKS / 'component-result.json'),
                       checks=199, failed=0, native_game_test=False, performance_qualified=False)))
    for row in updated['source']:
        if row['path'] in planned:
            row['sha256'] = hashlib.sha256(planned[row['path']]).hexdigest()
        row['changed'] = row['sha256'] != row['baseline_sha256']
    updated['changed_files'] = sorted(r['path'] for r in updated['source'] if r['changed'])
    updated.update(version=version, compiled=False, runtime_tested=False, deployed=False,
        gameplay_qualified=False, performance_qualified=False,
        followup_review='Codec diagnostics default off; actual old/new encoding, decoding and limits 199/0. Native frame-time effect untested.',
        integration_recipe_sha256=sha(Path(__file__)))
    updated['static_checks'].update(compiler_checked=False, codec_diagnostics_component_199=True)
    if args.apply:
        require(inventory(ACTIVE / 'src') == expected and read(ACTIVE / 'integration.json') == before, 'Concurrent changes')
        for name, data in planned.items():
            (ACTIVE / 'src' / name).write_bytes(data)
        (ACTIVE / 'integration.json').write_bytes((json.dumps(updated, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))
    print(json.dumps(dict(applied=args.apply, version=version, changes=sorted(planned), checks=199,
                          native_tested=False, installed=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
