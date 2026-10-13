"""Negative checks for evidence selection, not simulated game acceptance."""
import shutil
import tempfile
import unittest
from pathlib import Path
from audit_suite import REQUIRED, select_runs
from common import BUILD, read, save, sha


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

    def stopped_pair(self):
        plan = sorted(REQUIRED)
        original = self.collection('stopped', plan[:4], failed=[plan[3]], complete=False)
        continuation = self.collection('continuation', plan[3:])
        for path, names in ((original, plan), (continuation, plan[3:])):
            data = read(path/'suite.json')
            data.update(runner_sha256='driver', arguments=dict(scenarios=names,
                candidate='build/candidate', seconds=700, archive=True, stop_on_failure=True, output=str(path)))
            if path == original:
                data['stopped_after'] = plan[3]
            save(path/'suite.json', data)
        return original, continuation

    def edit_collection(self, directory, change):
        data = read(directory/'suite.json'); change(data); save(directory/'suite.json', data)

    def test_stopped_continuation_retains_failure_and_complete_coverage(self):
        original, continuation = self.stopped_pair()
        before = {p:sha(p) for p in original.rglob('*.json')}
        selected, retained = select_runs(original, [], [continuation])
        self.assertEqual(len(selected), 44)
        self.assertEqual(len(retained), 1)
        self.assertFalse(retained[0]['original_row']['complete'])
        self.assertEqual(before, {p:sha(p) for p in before})

    def test_continuation_cannot_skip_failed_category(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(continuation, lambda d: d['arguments']['scenarios'].pop(0))
        with self.assertRaisesRegex(ValueError, 'every remaining category'):
            select_runs(original, [], [continuation])

    def test_continuation_cannot_claim_partial_collection_complete(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(continuation, lambda d: d['results'].pop())
        with self.assertRaisesRegex(ValueError, 'omits planned'):
            select_runs(original, [], [continuation])

    def test_continuation_cannot_include_active_original(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(original, lambda d: d.pop('stopped_after'))
        with self.assertRaisesRegex(ValueError, 'safely stopped'):
            select_runs(original, [], [continuation])

    def test_continuation_requires_same_options(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(continuation, lambda d: d['arguments'].update(seconds=701))
        with self.assertRaisesRegex(ValueError, 'changed frozen options'):
            select_runs(original, [], [continuation])

    def test_continuation_cannot_be_appended_to_complete_original(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(original, lambda d: d.update(complete=True))
        with self.assertRaisesRegex(ValueError, 'stopped full regression'):
            select_runs(original, [], [continuation])

    def test_continuation_checks_new_categories_input_tuple(self):
        original, continuation = self.stopped_pair()
        data = read(continuation/'suite.json'); row = data['results'][-1]
        path = continuation/row['scenario']/'run.json'; receipt=read(path)
        receipt['build_manifest_sha256']='changed'; save(path,receipt)
        row['run_receipt_sha256']=sha(path); save(continuation/'suite.json',data)
        with self.assertRaisesRegex(ValueError, 'changed frozen inputs'):
            select_runs(original, [], [continuation])

    def test_continuation_rejects_cleanup_not_confirmed(self):
        original, continuation = self.stopped_pair()
        data=read(original/'suite.json'); row=data['results'][-1]
        path=original/row['scenario']/'run.json'; receipt=read(path)
        receipt['owned_processes_exited']=False; save(path,receipt)
        row.update(run_receipt_sha256=sha(path),safe_cleanup=False); save(original/'suite.json',data)
        with self.assertRaisesRegex(ValueError, 'Unconfirmed input protection'):
            select_runs(original, [], [continuation])

    def test_two_stopped_segments_keep_both_failed_attempts(self):
        original, first = self.stopped_pair()
        data=read(first/'suite.json'); plan=data['arguments']['scenarios']; data['results']=data['results'][:3]
        row=data['results'][-1]; path=first/row['scenario']/'run.json'; receipt=read(path)
        receipt['complete']=False
        for role in receipt['roles'].values(): role['done']=False
        save(path,receipt)
        row.update(complete=False,runner_exit=1,run_receipt_sha256=sha(path))
        for role in row['roles'].values(): role['done']=False
        data.update(complete=False,stopped_after=row['scenario']); save(first/'suite.json',data)
        second=self.collection('second',plan[2:]); final=read(second/'suite.json')
        final.update(runner_sha256='driver',arguments={**data['arguments'],'scenarios':plan[2:],'output':str(second)})
        save(second/'suite.json',final)
        before={p:sha(p) for directory in (original,first) for p in directory.rglob('*.json')}
        selected,retained=select_runs(original,[],[first,second])
        self.assertEqual(len(selected),44);self.assertEqual(len(retained),2)
        self.assertEqual(before,{p:sha(p) for p in before})

    def test_no_completion_while_continuation_is_running(self):
        original, continuation = self.stopped_pair()
        self.edit_collection(continuation,lambda d:d.update(complete=False))
        with self.assertRaisesRegex(ValueError, 'safely stopped'):
            select_runs(original,[],[continuation])


if __name__ == '__main__':
    unittest.main()
