"""Negative checks for evidence selection, not simulated game acceptance."""
import shutil
import tempfile
import unittest
from pathlib import Path
from audit_suite import REQUIRED, select_runs
from common import BUILD, save, sha


class EvidenceSelection(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='audit-selection-test-', dir=BUILD)).resolve()
        self.assertTrue(self.root.is_relative_to(BUILD.resolve()))

    def tearDown(self):
        # The only recursive cleanup is this uniquely owned, verified test folder.
        self.assertTrue(self.root.is_relative_to(BUILD.resolve()))
        self.assertNotEqual(self.root, BUILD.resolve())
        shutil.rmtree(self.root)

    def collection(self, name, names, failed=(), mutate=None, complete=True):
        root = self.root/name
        root.mkdir()
        rows = []
        for scenario in names:
            good = scenario not in failed
            receipt = dict(complete=good, installation_unchanged=True, owned_processes_exited=True,
                script_sha256='driver', roles={})
            for key in ('baseline', 'build', 'native', 'tdfc', 'rv', 'msw', 'sandy'):
                receipt[key+'_manifest_sha256'] = key
            for role in ('host', 'join'):
                receipt['roles'][role] = dict(passed=3, failed=0, done=good, fatal=[], runtime_unchanged=True,
                    config=dict(scenario=scenario, role=role, session=name, port=23000, probe=True))
            if mutate:
                mutate(receipt)
            path = root/scenario
            path.mkdir()
            save(path/'run.json', receipt)
            rows.append(dict(scenario=scenario, runner_exit=0 if good else 1, complete=receipt['complete'],
                run_receipt_sha256=sha(path/'run.json'), safe_cleanup=True,
                roles={role:{key:value[key] for key in ('passed', 'failed', 'done', 'fatal')}
                       for role,value in receipt['roles'].items()}))
        save(root/'suite.json', dict(complete=complete, all_passed=not failed, results=rows))
        return root

    def initial_failure(self):
        return self.collection('original', sorted(REQUIRED), failed=('friendly-melee',))

    def test_all_original_categories_succeed(self):
        selected, retained = select_runs(self.collection('green', sorted(REQUIRED)), [])
        self.assertEqual(len(selected), 44)
        self.assertEqual(retained, [])

    def test_explicit_same_input_rerun_preserves_failed_receipts(self):
        original = self.initial_failure()
        before = {p:sha(p) for p in original.rglob('*.json')}
        replacement = self.collection('repeat', ['friendly-melee'])
        selected, retained = select_runs(original, [replacement])
        self.assertEqual(len(selected), 44)
        self.assertEqual(len(retained), 1)
        self.assertFalse(retained[0]['original_row']['complete'])
        self.assertEqual(before, {p:sha(p) for p in before})
        self.assertEqual(next(r['path'] for r in selected if r['row']['scenario']=='friendly-melee'),
                         replacement/'friendly-melee')

    def test_partial_completion_does_not_pass(self):
        with self.assertRaisesRegex(ValueError, 'lack a successful'):
            select_runs(self.initial_failure(), [])

    def test_active_suite_does_not_pass(self):
        with self.assertRaisesRegex(ValueError, 'still running'):
            select_runs(self.collection('active', sorted(REQUIRED), complete=False), [])

    def test_failed_rerun_does_not_pass(self):
        with self.assertRaisesRegex(ValueError, 'previously failed'):
            select_runs(self.initial_failure(),
                        [self.collection('repeat', ['friendly-melee'], failed=('friendly-melee',))])

    def test_different_build_or_driver_is_rejected(self):
        original = self.initial_failure()
        for key in ('build_manifest_sha256', 'sandy_manifest_sha256', 'script_sha256'):
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'changed frozen'):
                select_runs(original, [self.collection(key, ['friendly-melee'],
                            mutate=lambda r: r.update({key:'different'}))])

    def test_different_gameplay_options_are_rejected(self):
        def changed(receipt):
            receipt['roles']['join']['config']['probe'] = False
        with self.assertRaisesRegex(ValueError, 'gameplay options'):
            select_runs(self.initial_failure(), [self.collection('repeat', ['friendly-melee'], mutate=changed)])

    def test_mislabeled_category_is_rejected(self):
        def changed(receipt):
            receipt['roles']['host']['config']['scenario'] = 'native-gun'
        with self.assertRaisesRegex(ValueError, 'declared category'):
            select_runs(self.initial_failure(), [self.collection('repeat', ['friendly-melee'], mutate=changed)])

    def test_cannot_replace_a_successful_category(self):
        with self.assertRaisesRegex(ValueError, 'previously failed'):
            select_runs(self.collection('green', sorted(REQUIRED)), [self.collection('repeat', ['friendly-melee'])])


if __name__ == '__main__':
    unittest.main()
