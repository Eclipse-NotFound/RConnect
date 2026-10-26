"""Offline transaction fault checks. Only temporary fixtures in this directory."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('b_field_deploy_test', HERE / 'deploy.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class TransactionChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='offline-fixture-', dir=HERE)
        self.root = Path(self.temp.name)
        self.live, self.out = self.root / 'playable', self.root / 'transaction'
        self.out.mkdir()
        self.receipt = dict(before={}, allowed_after={})
        for name in d.NAMES:
            old, new = ('before:' + name).encode(), ('after:' + name).encode()
            for p in (self.live / name, self.out / 'before' / name):
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(old)
            self.receipt['before'][name] = d.digest(old)
            self.receipt['allowed_after'][name] = [d.digest(new)]
        self.patches = [patch.object(d, 'PLAYABLE', self.live), patch.object(d, 'package', return_value={})]
        for p in self.patches: p.start()

    def tearDown(self):
        for p in reversed(self.patches): p.stop()
        self.temp.cleanup()

    def test_atomic_compare_before_write(self):
        p = self.live / 'README.txt'
        with self.assertRaisesRegex(ValueError, 'Concurrent edit'):
            d.atomic_write(p, b'changed', '0' * 64)
        self.assertEqual(d.sha(p), self.receipt['before']['README.txt'])

    def test_atomic_compare_again_before_replace(self):
        p = self.live / 'README.txt'
        original_sha, calls = d.sha, []
        def race(target):
            if Path(target) == p:
                calls.append(1)
                if len(calls) == 2: p.write_bytes(b'concurrent writer')
            return original_sha(target)
        with patch.object(d, 'sha', side_effect=race):
            with self.assertRaisesRegex(ValueError, 'Concurrent edit before replacement'):
                d.atomic_write(p, b'ours', self.receipt['before']['README.txt'])
        self.assertEqual(p.read_bytes(), b'concurrent writer')
        self.assertFalse(list(p.parent.glob('*.tmp')))

    def test_partial_replace_rolls_back_from_write_ahead_hashes(self):
        for name in d.NAMES[:2]: (self.live / name).write_bytes(('after:' + name).encode())
        d.rollback(self.out, self.receipt)
        self.assertEqual(self.receipt['status'], 'rolled_back')
        for name in d.NAMES: self.assertEqual(d.sha(self.live / name), self.receipt['before'][name])

    def test_foreign_edit_blocks_entire_rollback(self):
        first = d.NAMES[0]
        (self.live / first).write_bytes(('after:' + first).encode())
        (self.live / d.NAMES[-1]).write_bytes(b'foreign')
        with self.assertRaisesRegex(ValueError, 'Concurrent edit blocks rollback'):
            d.rollback(self.out, self.receipt)
        self.assertEqual((self.live / first).read_bytes(), ('after:' + first).encode())
        self.assertEqual(self.receipt['status'], 'rollback_blocked')

    def test_changed_backup_blocks_rollback(self):
        (self.out / 'before' / d.NAMES[-1]).write_bytes(b'bad backup')
        with self.assertRaisesRegex(ValueError, 'Rollback backup changed'):
            d.rollback(self.out, self.receipt)
        self.assertEqual(self.receipt['status'], 'rollback_blocked')

    def test_rollback_rechecks_each_observed_hash(self):
        victim = self.live / d.NAMES[0]
        real_atomic = d.atomic_write
        def race(target, data, expected=None):
            if Path(target) == victim: victim.write_bytes(b'new foreign edit')
            return real_atomic(target, data, expected)
        with patch.object(d, 'atomic_write', side_effect=race):
            with self.assertRaisesRegex(ValueError, 'Concurrent edit'):
                d.rollback(self.out, self.receipt)
        self.assertEqual(victim.read_bytes(), b'new foreign edit')

    def test_finalize_planned_hash_is_recoverable(self):
        name = 'manual-input.json'
        data = b'final metadata'
        self.receipt['allowed_after'][name].append(d.digest(data))
        (self.live / name).write_bytes(data)
        d.rollback(self.out, self.receipt)
        self.assertEqual(d.sha(self.live / name), self.receipt['before'][name])

    def test_required_core_includes_textmotion(self):
        with self.assertRaisesRegex(ValueError, 'All eight'):
            d.assignments([s + '=example' for s in d.CORE if s != 'textmotion'])
        self.assertEqual(len(d.assignments([s + '=example' for s in d.CORE])), 8)

    def test_path_traversal_and_conflicting_alias_rejected(self):
        with self.assertRaises(ValueError): d.member(self.root, '../outside')
        with self.assertRaises(ValueError): d.canonical({'RConnect/x': '0' * 64, 'rconnect/x': '1' * 64})
        self.assertEqual(len(d.canonical({'RConnect/x': '0' * 64, 'rconnect/x': '0' * 64})), 1)

    def test_performance_family_is_fixed_not_a_report_path(self):
        self.assertEqual(d.performance_family('b-field-ab007-qualification-2')[0], d.QUALIFIER)
        self.assertEqual(d.performance_family('b-field-sustained-qualification-1')[0],
                         d.ROOT/'experimental/b-field-sustained-bench/qualify.py')
        for value in (None, 'b-field-ab007-plan-2', '../qualify.py', 'b-field-sustained-qualification-2'):
            with self.assertRaisesRegex(ValueError, 'Unknown performance'):
                d.performance_family(value)

    def test_failed_original_qualification_remains_failed(self):
        with self.assertRaisesRegex(ValueError, 'Performance qualification not passed'):
            d.performance('experimental/b-field-perf-qualification/field21-qualification-01.json', {}, {})

    def test_sustained_gate_cannot_lower_thresholds(self):
        result=dict(schema='b-field-sustained-qualification-1', gates=dict(d.PERFORMANCE_GATES, maximum_mean_ratio=1.06))
        with patch.object(d, 'read', return_value=result), self.assertRaisesRegex(ValueError, 'Performance thresholds changed'):
            d.performance('offline-in-memory-fixture', {}, {})


if __name__ == '__main__':
    unittest.main(verbosity=2)
