"""Static source checks and pure template-comparison counterexamples; no process launch."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    labels = []
    def check(ok, label):
        assert ok, label
        labels.append(label)
    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    profile = json.loads((HERE/'inputs.json').read_text('utf-8'))
    original = (ROOT/'tools/validation/run_motion_comparison.py').read_text('utf-8-sig')
    expected = original
    edits = json.loads((HERE/'wrapper-edits.json').read_text('utf-8'))
    for i, edit in enumerate(edits):
        check(expected.count(edit['before']) == 1, 'unique exact edit '+str(i+1))
        expected = expected.replace(edit['before'], edit['after'])
    actual = (HERE/'run_motion_comparison.py').read_text('utf-8')
    check(expected == actual, 'full wrapper differs only at declared sites')
    for name in ('run.py', 'run_motion_comparison.py', 'check.py'):
        compile((HERE/name).read_text('utf-8'), name, 'exec')
        check(True, 'Python syntax '+name)
    before, after = ast.parse(original), ast.parse(actual)
    for name in ('summary', 'signature', 'exclusive_air_evidence'):
        def function(tree):
            return next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == name)
        check(ast.dump(function(before)) == ast.dump(function(after)), 'original function unchanged '+name)
    def cases(tree):
        return next(n for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CASES' for t in n.targets))
    check(ast.dump(cases(before)) == ast.dump(cases(after)), 'all scenarios and durations unchanged')
    fn = next(n for n in after.body if isinstance(n, ast.FunctionDef) and n.name == 'vision_signature_matches')
    namespace = {}
    exec(compile(ast.Module(body=[fn], type_ignores=[]), '<pure-comparison>', 'exec'), namespace)
    matches = namespace['vision_signature_matches']
    hashes = {r: row['sha256'] for r, row in profile['templates'].items()}
    entry_main = next(n for n in ast.parse((HERE/'run.py').read_text('utf-8')).body
                      if isinstance(n, ast.FunctionDef) and n.name == 'main')
    guards = [n for n in entry_main.body if isinstance(n, ast.Assert) and isinstance(n.msg, ast.Constant)
              and n.msg.value == 'Live user settings changed since capture; freeze a new profile before testing']
    check(len(guards) == 1, 'live settings guard exists exactly once')
    guard_index = entry_main.body.index(guards[0])
    prior = entry_main.body[guard_index-1]
    check(isinstance(prior, ast.Assign) and any(isinstance(n, ast.Name) and n.id == 'user_before' for n in prior.targets),
          'live settings guard immediately follows prelaunch read')
    guard = compile(ast.Module(body=guards, type_ignores=[]), '<actual-entry-guard>', 'exec')
    def accepts(values):
        try:
            exec(guard, {'user_before': values, 'profile': profile})
            return True
        except AssertionError:
            return False
    check(accepts(dict(hashes)), 'unchanged live settings accepted by actual guard')
    check(not accepts(dict(hashes, host='different')), 'host changed after freeze rejected before launch')
    check(not accepts(dict(hashes, join='different')), 'join changed after freeze rejected before launch')
    check(not accepts({'host': hashes['host']}), 'missing live join identity rejected before launch')
    evidence = {'vision_config_templates': dict(hashes)}
    check(matches(evidence, evidence, hashes), 'same bytes in lower run and input accepted')
    swapped = {'vision_config_templates': {'host': hashes['join'], 'join': hashes['host']}}
    check(not matches(swapped, evidence, hashes), 'role-swapped config rejected')
    check(not matches({}, evidence, hashes), 'missing lower run evidence rejected')
    check(not matches(evidence, {}, hashes), 'missing prelaunch input evidence rejected')
    changed = {'vision_config_templates': dict(hashes, host='different')}
    check(not matches(evidence, changed, hashes), 'changed single config rejected')
    check(not matches({'vision_config_templates': {}}, {'vision_config_templates': {}}, hashes), 'default no-template run rejected')
    for name, digest in profile['dependencies'].items():
        check(sha(Path(name)) == digest, 'pinned dependency '+str(Path(name).relative_to(ROOT)))
    for role, row in profile['templates'].items():
        check(sha(HERE/row['frozen']) == row['sha256'], role+' frozen bytes match captured source')
        check(sha(Path(row['source'])) == row['sha256'], role+' live source unchanged since capture')
    spec = importlib.util.spec_from_file_location('density_profile_entry', HERE/'run.py')
    entry = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(entry)
    meta = entry.verify((ROOT/profile['driver']).resolve())
    check(meta['compiled'] and meta['compile_exit'] == 0, 'original formal driver03 verification succeeds')
    check(entry.audit.__code__.co_filename == str(ROOT/'experimental/recovery-density-corridor-readyfix/audit.py'), 'original strict corridor audit imported unchanged')
    result = dict(assertions=len(labels), passed=len(labels), failed=0, labels=labels,
                  checks_kind='static-plus-pure-Python-counterexamples', air_started=False, runtime_qualified=False)
    (HERE/'static-check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', 'utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'labels'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
