"""Finite source-expression checks for A22's wall-paint receive gate.

This does NOT execute AS3, TCP, the game, or rendered pixels. It extracts the
actual config parser and receive condition, translates their small Boolean
subset, and checks the compatibility contract. Run against frozen fix12 as a
negative control and the overlay/fix13 as the proposed correction.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def extract(pattern, source, label):
    matches = re.findall(pattern, source, re.DOTALL)
    if len(matches) != 1:
        raise ValueError('Expected one ' + label + ', found ' + str(len(matches)))
    return matches[0]


def boolean_expression(source):
    translated = source.replace('msg.wallPaint is Array', 'is_array(wallPaint)')
    translated = translated.replace('sameHostRoom(msg)', 'same_room(msg)')
    translated = translated.replace('&&', ' and ').replace('||', ' or ')
    tree = ast.parse(translated.strip(), mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
               ast.Eq, ast.NotEq, ast.Name, ast.Load, ast.Constant, ast.Call)
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            raise ValueError('Unsupported expression syntax: ' + type(node).__name__)
        if isinstance(node, ast.Name) and node.id not in {
                'wi', '_worldInject', 'wallPaint', 'msg', 'is_array', 'same_room'}:
            raise ValueError('Unexpected expression name: ' + node.id)
        if isinstance(node, ast.Call) and (
                not isinstance(node.func, ast.Name) or
                node.func.id not in {'is_array', 'same_room'} or node.keywords):
            raise ValueError('Unexpected expression call')
    return compile(tree, '<extracted AS3 Boolean expression>', 'eval')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path,
                        default=ROOT / 'experimental/a22-fixes/src')
    args = parser.parse_args()
    source_root = args.source_root.resolve()
    path = source_root / 'rconnect/core/Session.as'
    data = path.read_bytes()
    source = data.decode('utf-8-sig')
    constructor = extract(r'this\._worldInject\s*=\s*\(([^;]+)\);', source,
                          'worldInject config expression')
    worldstate = extract(r'case Protocol\.MSG_WORLDSTATE:(.*?)\bbreak;', source,
                         'worldstate receive branch')
    receive_gate = extract(
        r'if\(([^\r\n]+)\)mod\.game\.applyWallPaint\(msg\.wallPaint as Array\);',
        worldstate, 'fast wall receive condition')
    sender = extract(r'private function broadcastWorldState\(\):void(.*?)'
                     r'private function applyWorldState\(', source, 'worldstate sender')
    config_code = boolean_expression(constructor)
    receive_code = boolean_expression(receive_gate)
    results = []

    def check(label, actual, expected):
        results.append({'case': label, 'expected': expected, 'actual': actual,
                        'passed': actual == expected})

    cases = [('disabled-zero', '0', [], True, False),
             ('disabled-false', 'false', [], True, False),
             ('disabled-no', 'no', [], True, False),
             ('enabled-one', '1', [], True, True),
             ('enabled-true', 'true', [], True, True),
             ('enabled-yes', 'yes', [], True, True),
             ('legacy-empty-default', '', [], True, True),
             ('wrong-room-or-term', '1', [], False, False),
             ('absent-paint', '1', None, True, False),
             ('nonarray-paint', '1', {}, True, False)]
    for label, setting, paint, room, expected in cases:
        enabled = eval(config_code, {'__builtins__': {}}, {'wi': setting})
        actual = eval(receive_code, {'__builtins__': {}}, {
            '_worldInject': enabled, 'wallPaint': paint, 'msg': {},
            'is_array': lambda value: isinstance(value, list),
            'same_room': lambda message: room})
        check(label, bool(actual), expected)
    # The switch controls this receiver. The old sender broadcasts wall paint
    # even when its own receive switch is off; retain that separate contract.
    check('sender-retains-wall-updates', 'readWallPaintUpdates()' in sender, True)
    check('sender-not-gated-by-local-injection', '_worldInject' in sender, False)
    result = {
        'kind': 'source-boolean-semantics-only', 'as3_executed': False,
        'source': str(path), 'source_sha256': hashlib.sha256(data).hexdigest(),
        'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'config_expression': constructor, 'receive_expression': receive_gate,
        'passed': sum(item['passed'] for item in results),
        'failed': sum(not item['passed'] for item in results), 'cases': results}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result['failed'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
