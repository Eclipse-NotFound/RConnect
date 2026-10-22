"""Pure/static preparation checks; stdout only, never launch AIR or mutate evidence."""
import ast
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from unittest.mock import patch
import xml.etree.ElementTree as ET
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'experimental/recovery-density-profile-settings'
sys.path.insert(0, str(HERE))
from policy_evidence import validate_values, expected_policy, audit_policy
import policy_evidence as policy


def main():
    labels = []
    def check(ok, label):
        assert ok, label
        labels.append(label)
    def load(path):
        return json.loads(path.read_text(encoding='utf-8-sig'))
    for name, edits in (('run.py', 'entry-edits.json'), ('run_motion_comparison.py', 'wrapper-edits.json')):
        original = (BASE/name).read_text(encoding='utf-8')
        expected = original
        for index, edit in enumerate(load(HERE/edits)):
            check(expected.count(edit['before']) == 1, name+' unique edit '+str(index+1))
            expected = expected.replace(edit['before'], edit['after'])
        check(expected == (HERE/name).read_text(encoding='utf-8'), name+' exact declared diff only')
    for name in ('run.py', 'run_motion_comparison.py', 'policy_evidence.py', 'check.py'):
        ast.parse((HERE/name).read_text(encoding='utf-8'))
        check(True, 'Python syntax '+name)
    old = ast.parse((BASE/'run_motion_comparison.py').read_text(encoding='utf-8'))
    new = ast.parse((HERE/'run_motion_comparison.py').read_text(encoding='utf-8'))
    def fn(tree, name):
        return next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == name)
    for name in ('summary', 'signature', 'exclusive_air_evidence', 'vision_signature_matches'):
        check(ast.dump(fn(old, name)) == ast.dump(fn(new, name)), 'original helper unchanged '+name)
    def assignment(tree, name):
        return next(node for node in tree.body if isinstance(node, ast.Assign)
                    and any(isinstance(t, ast.Name) and t.id == name for t in node.targets))
    check(ast.dump(assignment(old, 'CASES')) == ast.dump(assignment(new, 'CASES')), 'all durations/scenarios unchanged')
    old_main, new_main = fn(old, 'main'), fn(new, 'main')
    new_command = deepcopy(assignment(new_main, 'command'))
    check(sum(isinstance(node, ast.Constant) and node.value == '--responsive'
              for node in new_command.value.elts) == 1, 'one existing responsive flag')
    new_command.value.elts = [node for node in new_command.value.elts
                             if not (isinstance(node, ast.Constant) and node.value == '--responsive')]
    check(ast.dump(new_command) == ast.dump(assignment(old_main, 'command')), 'all other runner arguments unchanged')
    def reference_guard(tree):
        return next(node for node in tree.body if isinstance(node, ast.If)
                    and isinstance(node.test, ast.Name) and node.test.id == 'reference')
    old_guard, new_guard = reference_guard(old_main), reference_guard(new_main)
    old_nodes, new_nodes = [ast.dump(n) for n in old_guard.body], [ast.dump(n) for n in new_guard.body]
    indices = [new_nodes.index(node) for node in old_nodes]
    check(indices == sorted(indices), 'all original strict reference guards preserved in order')
    reference_checks = [n for n in new_guard.body if isinstance(n, ast.Assert)
                        and isinstance(n.msg, ast.Constant)
                        and n.msg.value == 'Reference actual startup readback not verified']
    check(len(reference_checks) == 1, 'same-wrapper reference also requires actual policy proof')
    expected = expected_policy()
    expected_runner = load(HERE/'inputs.json')['dependencies'][str(ROOT/'tools/run_coop_regression.py')]
    run_id = '0123456789'
    evidence = {'run': run_id, 'pids': [111, 222], 'retained_helper_sources': dict(expected),
                'retained_runner_source': expected_runner, 'roles': {}}
    for index, role in enumerate(('host', 'join')):
        evidence['roles'][role] = {'run_policy': dict(expected), 'input_policy': dict(expected),
            'descriptor_sha256': 'descriptor-'+role,
            'run_descriptor_sha256': 'descriptor-'+role, 'input_descriptor_sha256': 'descriptor-'+role,
            'appid': 'pfe-modsettings-rconnect-coop-'+role+'-'+run_id,
            'receipt': {'pid': evidence['pids'][index], 'control': 1, 'state': 0}}
    check(validate_values(evidence, expected, expected_runner), 'both actual startup readbacks accepted')
    retained = deepcopy(evidence)
    retained['roles']['join']['receipt'].update(control=5, state=4)
    check(validate_values(retained, expected, expected_runner), 'unrelated policy bits preserved rather than assumed zero')
    def rejects(value, label):
        try:
            validate_values(value, expected, expected_runner)
        except (AssertionError, KeyError, TypeError):
            check(True, label)
        else:
            raise AssertionError(label)
    mutations = [
        ('default 0/0 cannot claim explicit policy', lambda v: v['roles']['host']['receipt'].update(control=0, state=0)),
        ('enabled execution throttling rejected', lambda v: v['roles']['host']['receipt'].update(control=1, state=1)),
        ('wrong controlled bit rejected', lambda v: v['roles']['join']['receipt'].update(control=2, state=0)),
        ('Boolean mask rejected', lambda v: v['roles']['join']['receipt'].update(control=True)),
        ('out of range mask rejected', lambda v: v['roles']['host']['receipt'].update(state=2**32)),
        ('wrong PID rejected', lambda v: v['roles']['join']['receipt'].update(pid=111)),
        ('duplicate owned PID rejected', lambda v: v.update(pids=[111, 111])),
        ('missing join receipt rejected', lambda v: v['roles'].pop('join')),
        ('changed helper source rejected', lambda v: v['retained_helper_sources'].update({next(iter(expected)): 'changed'})),
        ('missing input policy rejected', lambda v: v['roles']['join'].update(input_policy=None)),
        ('different run policy rejected', lambda v: v['roles']['join'].update(run_policy={})),
        ('different retained runner rejected', lambda v: v.update(retained_runner_source='changed')),
        ('role-swapped AppID rejected', lambda v: v['roles']['host'].update(appid=v['roles']['join']['appid'])),
        ('descriptor mismatch rejected', lambda v: v['roles']['join'].update(descriptor_sha256='changed')),
    ]
    for label, mutate in mutations:
        bad = deepcopy(evidence)
        mutate(bad)
        rejects(bad, label)
    missing = audit_policy(HERE/'not-created-read-only-check', {}, {}, expected, HERE/'missing-sources', HERE/'missing-runner')
    check(missing['confirmed'] is False and 'error' in missing, 'missing runtime receipt fails explicitly without process access')
    # Normal cleanup removes role/frozen trees; only persisted files below exist.
    # Any attempted reread of those removed paths raises instead of being faked present.
    folder = HERE/run_id
    sources, runner_source = HERE/'retained-sources', HERE/'retained-runner.py'
    hashes = {sources/name: digest for name, digest in expected.items()}
    hashes[runner_source] = expected_runner
    reads, xmls = {}, {}
    native_run = {'pids': [111, 222], 'inputs': {}, 'descriptors': {}}
    native_input = {'inputs': {}, 'descriptors': {}}
    for index, role in enumerate(('host', 'join')):
        native_run['inputs'][role] = {'process_policy': dict(expected)}
        native_input['inputs'][role] = {'process_policy': dict(expected)}
        native_run['descriptors'][role] = native_input['descriptors'][role] = 'descriptor-'+role
        descriptor, receipt = folder/'descriptors'/(role+'.xml'), folder/(role+'.process-policy.json')
        hashes[descriptor], hashes[receipt] = 'descriptor-'+role, 'receipt-'+role
        reads[receipt] = {'pid': [111, 222][index], 'control': 1, 'state': 0}
        xmls[descriptor] = ET.ElementTree(ET.fromstring(
            '<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+
            'pfe-modsettings-rconnect-coop-'+role+'-'+run_id+'</id></application>'))
    original_read = policy.read
    def fixture_read(path):
        return original_read(path) if path == HERE/'inputs.json' else deepcopy(reads[path])
    with patch.object(policy, 'expected_policy', return_value=expected), \
            patch.object(policy, 'sha', side_effect=lambda path: hashes[path]), \
            patch.object(policy, 'read', side_effect=fixture_read), \
            patch.object(policy.ET, 'parse', side_effect=lambda path: xmls[path]):
        complete = audit_policy(folder, native_run, native_input, expected, sources, runner_source)
        check(complete['confirmed'] is True, 'actual auditor accepts persisted proof after game copies were cleaned')
        check(complete['postrun_game_copies_reread'] is False, 'result does not claim a nonexistent postrun reread')
        reads[folder/'join.process-policy.json']['state'] = 1
        check(audit_policy(folder, native_run, native_input, expected, sources, runner_source)['confirmed'] is False,
              'actual post-cleanup auditor rejects wrong retained readback')
        reads.pop(folder/'join.process-policy.json')
        check(audit_policy(folder, native_run, native_input, expected, sources, runner_source)['confirmed'] is False,
              'actual post-cleanup auditor rejects missing retained receipt')
    spec = importlib.util.spec_from_file_location('formal_policy_entry', HERE/'run.py')
    entry = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(entry)
    profile = entry.frozen_inputs()
    check(profile['driver'] == 'build/m52/recovery-density-corridor-drivers-03', 'exact driver03 bound')
    meta = entry.verify((ROOT/profile['driver']).resolve())
    check(meta['compiled'] and meta['compile_exit'] == 0, 'unchanged original driver verification succeeds')
    for role, row in profile['templates'].items():
        check(entry.sha(HERE/row['frozen']) == entry.sha(Path(row['source'])) == row['sha256'], role+' frozen and current RV bytes agree')
    check(entry.audit.__code__.co_filename == str(ROOT/'experimental/recovery-density-corridor-readyfix/audit.py'),
          'unchanged original scene/visual/geometry audit imported')
    print(json.dumps({'assertions': len(labels), 'passed': len(labels), 'failed': 0, 'labels': labels,
                      'air_started': False, 'compiled': False, 'runtime_qualified': False,
                      'check_kind': 'pure-Python-counterexamples-and-static-source'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
