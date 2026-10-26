"""Offline malformed-evidence checks; never generates a real passing game receipt."""
import importlib.util
from pathlib import Path
import unittest
import copy
import qualify as q

spec=importlib.util.spec_from_file_location('legacy_qualification_tests',q.ROOT/'experimental/b-field-perf-qualification/test_qualify.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
original_workload=old.workload
def workload(role='host',phase=0):
    value=original_workload(role,phase)
    for index,sample in enumerate(value['samples']):
        sample['weapons']=[dict(id='lmg',capacity=1000,hold=1000-index*10,reserve=9000,reload=0) for _ in sample['ammo']]
    return value
old.workload=workload
old.q=q

class SustainedEvidence(unittest.TestCase):
    def neutral_log(self):
        rows=[]
        for phase in (0,1):
            rows.append(dict(kind='neutral-before-phase',data=dict(phase=phase,
                localEnd=-1 if phase==0 else 100,peerEnd=-1 if phase==0 else 80,
                localConsumed=101,peerConsumed=81,localButtons=0,peerButtons=0,
                localFire=False,peerFire=False)))
            rows.append(dict(kind='magazine-prepared',data=dict(phase=phase)))
        return rows
    def test_consumed_neutral_phase_barriers(self):
        q.verify_neutral_phases(self.neutral_log())
    def test_pending_press_edge_rejected(self):
        rows=self.neutral_log();rows[2]['data']['peerConsumed']=80
        with self.assertRaises(q.InvalidEvidence):q.verify_neutral_phases(rows)
    def test_neutral_flag_without_sequence_rejected(self):
        rows=self.neutral_log();rows[2]['data']['peerEnd']=-1
        with self.assertRaises(q.InvalidEvidence):q.verify_neutral_phases(rows)
    def test_preparation_before_neutral_rejected(self):
        rows=self.neutral_log();rows[2],rows[3]=rows[3],rows[2]
        with self.assertRaises(q.InvalidEvidence):q.verify_neutral_phases(rows)
    def test_actor_still_firing_rejected(self):
        rows=self.neutral_log();rows[2]['data']['peerFire']=True
        with self.assertRaises(q.InvalidEvidence):q.verify_neutral_phases(rows)
    def reject(self,mutate):
        value=workload();mutate(value)
        with self.assertRaises((q.InvalidEvidence,KeyError,TypeError)):q.phase_workload(value,'host',0)
    def test_capacity_changed(self):self.reject(lambda v:v['samples'][20]['weapons'][1].update(capacity=90))
    def test_reload_started(self):self.reject(lambda v:v['samples'][20]['weapons'][1].update(reload=1))
    def test_reserve_refill(self):self.reject(lambda v:v['samples'][20]['weapons'][1].update(reserve=9001))
    def test_empty_magazine(self):self.reject(lambda v:v['samples'][20]['weapons'][0].update(hold=0))
    def test_not_full_initially(self):self.reject(lambda v:v['samples'][0]['weapons'][0].update(hold=999))
    def test_wrong_weapon(self):self.reject(lambda v:v['samples'][20]['weapons'][0].update(id='pistol'))
    def test_old_plan_cannot_be_relabelled(self):
        with self.assertRaises(q.InvalidEvidence):q.verify_plan(q.read(q.ROOT/'experimental/b-field-perf-qualification/field21-plan.json'))
    def test_original_limits_unchanged(self):
        self.assertEqual((q.GATES['maximum_mean_ratio'],q.GATES['maximum_p95_ratio'],q.GATES['maximum_repeat_ratio'],q.GATES['window_span_min_ms']),(1.05,1.05,1.2,8000))
    def test_explicit_field22_plan_verifies(self):
        q.verify_plan(q.freeze('build/ab/b190-field22-build'))
    def test_explicit_plan_does_not_allow_changed_identity(self):
        original=q.freeze('build/ab/b190-field22-build')
        for group,key,value in [('candidate','candidate_sha256','0'*64),('candidate','native_sha256','0'*64),('candidate','source_id','0'*64),('baseline','candidate_sha256','0'*64)]:
            plan=copy.deepcopy(original);plan['groups'][group][key]=value
            with self.assertRaises(q.InvalidEvidence):q.verify_plan(plan)
    def test_new_plan_cannot_omit_source(self):
        plan=q.freeze('build/ab/b190-field22-build')
        del plan['artifacts']['build/ab/b190-field22-build/src/RConnectMod.as']
        with self.assertRaises(q.InvalidEvidence):q.verify_plan(plan)

def load_tests(loader,tests,pattern):
    suite=unittest.TestSuite([loader.loadTestsFromTestCase(SustainedEvidence)])
    # Keep original malformed count/timing/shooting/identity and comparison
    # checks; legacy log fixtures intentionally lack the new workload identity.
    excluded={'test_original_log_must_agree_with_receipt','test_retained_old_real_workload_still_verifies'}
    for name in loader.getTestCaseNames(old.QualificationTests):
        if name not in excluded:suite.addTest(old.QualificationTests(name))
    return suite

if __name__=='__main__':unittest.main()
