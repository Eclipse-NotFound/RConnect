"""Read existing runner receipts; never set or query a live process policy."""
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NAMES = ('RConnect.Process.ps1', 'keep_test_responsive.ps1')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def expected_policy():
    meta = read(HERE/'inputs.json')
    expected = meta['process_policy_helpers']
    assert set(expected) == set(NAMES)
    for name in NAMES:
        assert sha(ROOT/'tools'/name) == expected[name], 'Formal helper changed: '+name
    return expected


def validate_values(evidence, expected, expected_runner):
    """Pure validation of the runner's actual files; no live process access."""
    run_id = evidence['run']
    assert re.fullmatch('[0-9a-f]{10}', run_id), 'Invalid isolated run identity'
    assert set(expected) == set(NAMES), 'Incomplete expected helper identities'
    pids = evidence['pids']
    assert isinstance(pids, list) and len(pids) == 2
    assert all(type(pid) is int and pid > 0 for pid in pids) and len(set(pids)) == 2
    assert evidence['retained_helper_sources'] == expected, 'Retained formal helper differs'
    assert evidence['retained_runner_source'] == expected_runner, 'Retained runner source differs'
    assert set(evidence['roles']) == {'host', 'join'}
    for index, role in enumerate(('host', 'join')):
        row = evidence['roles'][role]
        assert row['run_policy'] == row['input_policy'] == expected, \
            role+': runner-recorded actual helper hash differs'
        assert row['descriptor_sha256'] == row['run_descriptor_sha256'] == row['input_descriptor_sha256'], \
            role+': descriptor identity differs'
        assert row['appid'] == 'pfe-modsettings-rconnect-coop-'+role+'-'+run_id, role+': wrong AppID'
        receipt = row['receipt']
        assert type(receipt['pid']) is int and receipt['pid'] == pids[index], role+': wrong owned PID'
        for key in ('control', 'state'):
            assert type(receipt[key]) is int and 0 <= receipt[key] <= 0xffffffff, role+': invalid mask'
        assert receipt['control'] & 1 and not receipt['state'] & 1, role+': HighQoS readback absent'
    return True


def audit_policy(folder, run, run_input, expected, helper_sources, runner_source):
    """Keep a failed receipt explicit, so missing proof cannot pass the result."""
    evidence = {'run': folder.name, 'pids': run.get('pids'), 'roles': {}}
    try:
        assert expected_policy() == expected, 'Formal helper changed during run'
        meta = read(HERE/'inputs.json')
        expected_runner = meta['dependencies'][str(ROOT/'tools/run_coop_regression.py')]
        evidence['retained_helper_sources'] = {name: sha(helper_sources/name) for name in NAMES}
        evidence['retained_runner_source'] = sha(runner_source)
        for role in ('host', 'join'):
            descriptor = folder/'descriptors'/(role+'.xml')
            receipt = folder/(role+'.process-policy.json')
            evidence['roles'][role] = {
                'run_policy': run['inputs'][role].get('process_policy'),
                'input_policy': run_input['inputs'][role].get('process_policy'),
                'descriptor_sha256': sha(descriptor),
                'run_descriptor_sha256': run['descriptors'][role],
                'input_descriptor_sha256': run_input['descriptors'][role],
                'appid': ET.parse(descriptor).getroot().findtext('{http://ns.adobe.com/air/application/30.0}id'),
                'receipt': read(receipt), 'receipt_sha256': sha(receipt)}
        validate_values(evidence, expected, expected_runner)
        return {'confirmed': True, 'evidence': evidence, 'scope': 'startup-readback-only',
                'actual_game_copy_hash_source': 'runner measured role/tools after clone before launch; copies cleaned normally',
                'postrun_game_copies_reread': False,
                'proves_prior_throttling': False, 'proves_performance_cause': False}
    except (AssertionError, KeyError, OSError, ValueError, TypeError, ET.ParseError) as error:
        return {'confirmed': False, 'evidence': evidence, 'error': str(error),
                'scope': 'startup-readback-only', 'proves_prior_throttling': False,
                'proves_performance_cause': False}
