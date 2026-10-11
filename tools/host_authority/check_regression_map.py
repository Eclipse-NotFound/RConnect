"""Check coverage bookkeeping only. Never reports a game regression as passed."""
import ast
import json
from pathlib import Path
from common import ROOT, read


def legacy_requirements():
    values = {}

    def resolve(node):
        if isinstance(node, ast.Name):
            return values[node.id]
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
            return resolve(node.left) + resolve(node.right)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'list':
            return list(resolve(node.args[0]))
        if isinstance(node, ast.Subscript) and isinstance(node.slice, ast.Slice):
            return resolve(node.value)[slice(*(ast.literal_eval(x) if x else None for x in
                                               (node.slice.lower, node.slice.upper, node.slice.step)))]
        return ast.literal_eval(node)

    tree = ast.parse((ROOT/'tools/validation/run_final_regressions.py').read_text(encoding='utf-8-sig'))
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            key = node.targets[0].id
            if key in ('CHECKS', 'REQUIRED', 'M50_REQUIRED', 'M51_REQUIRED'):
                values[key] = resolve(node.value)
    return values['M51_REQUIRED']


def scenarios():
    tree = ast.parse((Path(__file__).with_name('run_probe.py')).read_text(encoding='utf-8-sig'))
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr == 'add_argument' and node.args
                and isinstance(node.args[0], ast.Constant) and node.args[0].value == '--scenario'):
            return set(ast.literal_eval(next(k.value for k in node.keywords if k.arg == 'choices')))
    raise ValueError('No scenario list')


def main():
    value = read(ROOT/'design/host-authority-regression-map.json')
    rows = value['entries']
    required, available = legacy_requirements(), scenarios()
    actual = [r['legacy'] for r in rows]
    if actual != required or len(set(actual)) != len(actual):
        raise ValueError('Legacy list changed, duplicated or omitted')
    for row in rows:
        if not row['behavior'] or not isinstance(row['gaps'], list):
            raise ValueError('Missing behavior/gap record: '+row['legacy'])
        if set(row['probes']) - available:
            raise ValueError('Unknown B scenario: '+row['legacy'])
        if not row['probes'] and not row['gaps']:
            raise ValueError('Uncovered requirement has no explicit gap: '+row['legacy'])
    print(json.dumps(dict(bookkeeping_valid=True, runtime_validation=False,
        legacy_requirements=len(rows), available_b_scenarios=len(available),
        requirements_with_probes=sum(bool(r['probes']) for r in rows),
        requirements_with_known_gaps=sum(bool(r['gaps']) for r in rows),
        note='Mapping and compilation do not establish passing gameplay.'), ensure_ascii=False))


if __name__ == '__main__':
    main()
