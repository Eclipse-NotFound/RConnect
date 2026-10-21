"""Offline checks only. These are not an AS compiler or game simulation."""
from pathlib import Path
import ast
import base64
import hashlib
import json
import re
import unittest
import zlib
import analyze
import make_overlay
import prepare

HERE = Path(__file__).resolve().parent


class StaticChecks(unittest.TestCase):
    def test_prepare_reads_exact_frozen_inputs(self):
        base = prepare.check_baseline()
        overlay = prepare.check_overlay()
        self.assertEqual(base['candidate_sha256'], prepare.BASE_SHA)
        self.assertEqual(overlay['baseline_binary_sha256'], prepare.BASE_SHA)

    def test_original_inputs_and_operations(self):
        info = json.loads((HERE / 'inputs.json').read_text(encoding='utf-8'))
        for item in info['files'] + [info['driver']]:
            original = Path(item['source'])
            overlay = HERE / item['overlay']
            self.assertEqual(make_overlay.sha(original), item['source_sha256'])
            self.assertEqual(make_overlay.sha(overlay), item['sha256'])
            self.assertEqual(make_overlay.plain(overlay.read_text(encoding='utf-8')),
                             original.read_text(encoding='utf-8'))

    def test_all_original_assertions_and_deadlines_retained(self):
        original = make_overlay.DRIVER.read_text(encoding='utf-8')
        modified = (HERE / 'tests' / make_overlay.DRIVER.name).read_text(encoding='utf-8')
        self.assertEqual(make_overlay.plain(modified), original)
        self.assertEqual(len(re.findall(r'\bcheck\(', modified)), len(re.findall(r'\bcheck\(', original)))
        self.assertIn('rf.maxHoldMs<=85', modified)
        self.assertIn('distinctGameFrames(splitR.contact)>=2', modified)
        self.assertIn('caseSpec:CASES[n]', modified)
        self.assertNotIn('warmup', modified.lower())

    def test_default_null_and_no_hot_io(self):
        helper = (HERE / 'src/rconnect/diagnostics/FlightDiagnostics.as').read_text(encoding='utf-8')
        self.assertIn('public static var sink:Object=null;', helper)
        self.assertNotIn('Log.d(', helper)
        self.assertNotIn('.sample(', helper)
        self.assertNotIn('.settle(', helper)
        recorder = (HERE / 'tests/FlightDiagnosticRecorder.as').read_text(encoding='utf-8')
        hot = recorder.split('      public function finish():void {', 1)[0]
        self.assertNotIn('Log.d(', hot)
        self.assertNotIn('JSON.', hot)
        self.assertNotIn('new Array', hot)
        self.assertIn('if(used>=MAX_ROWS){dropped++;return;}', hot)

    def test_python_parse(self):
        for path in HERE.glob('*.py'):
            ast.parse(path.read_text(encoding='utf-8'), filename=str(path))

    def test_as_delimiters(self):
        # Lexical balance only; no claim that Flex type checking has passed.
        for path in list((HERE / 'src').rglob('*.as')) + list((HERE / 'tests').rglob('*.as')):
            code = path.read_text(encoding='utf-8')
            code = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', code, flags=re.S)
            stack = []
            for char in code:
                if char in '({[':
                    stack.append(char)
                elif char in ')}]':
                    self.assertTrue(stack, str(path))
                    self.assertEqual(stack.pop(), {')': '(', '}': '{', ']': '['}[char], str(path))
            self.assertEqual(stack, [], str(path))

    def test_numeric_payload_exact_offline_decode(self):
        raw = b'[0,4294967295,1599,16711935]'
        encoded = base64.b64encode(zlib.compress(raw)).decode()
        result = analyze.replay_payload({'id': 0, 'chars': len(encoded), 'data': encoded, 'counts': [0]*10})
        self.assertTrue(result['numeric_sparse_cell'])
        self.assertEqual(result['decoded_sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(result['words'], 4)

    def test_invalid_numeric_cells_are_not_equivalent(self):
        for value in [[0, 1, 0, 2], [1600, 1], [1, -1], [True, 123], ['1', 123], [1]]:
            encoded = base64.b64encode(zlib.compress(json.dumps(value).encode())).decode()
            result = analyze.replay_payload({'id': 0, 'chars': len(encoded), 'data': encoded, 'counts': [0]*10})
            self.assertFalse(result['numeric_sparse_cell'], str(value))

    def test_summary_clock_and_log_columns(self):
        def row(kind, now, *values):
            return [kind, now, 1, 8, 0, 1] + list(values) + [None] * (18 - len(values))
        header = {'role': 'join', 'texts': ['visbullightning', 'alilight:0:1']}
        rows = [row(3, 100, 7, 9, 11, 0, 22, 1, 0, 1, 2, 10, 20, 0),
                row(4, 140, 7, 125, 10, 4, 10, 20, 2, 0, 33, 44, 1, 1, 11, 10),
                row(8, 200, 2, 160, 170, 180, 182, 200, 100, 32)]
        result = analyze.summary(header, rows, [], [])
        case = result['cases'][0]
        self.assertEqual(case['projectiles'][0]['receive_to_first_display_ms'], 40)
        self.assertEqual(case['projectiles'][0]['max_tick_argument_age_ms'], 15)
        self.assertFalse(case['projectiles'][0]['player'])
        self.assertEqual(case['codec_before_log_ms'], 10)
        self.assertEqual(case['codec_first_log_ms'], 10)
        self.assertEqual(case['codec_second_log_ms'], 18)
        self.assertEqual(case['codec_inclusive_ms'], 40)
        self.assertFalse(result['performance_qualified'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
