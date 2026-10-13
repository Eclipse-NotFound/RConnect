"""Reject incomplete or mismatched external stress evidence before accepting it."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from audit_checkpoint import check_stress_fixture
from common import ROOT, save, sha


class StressEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='stress-audit-unit-',dir=ROOT/'build/ab')
        self.base=Path(self.temp.name).resolve()
        self.assertTrue(self.base.is_relative_to((ROOT/'build/ab').resolve()))
        self.driver=self.base/'driver';self.driver.mkdir()
        self.run=self.base/'run';(self.run/'tools').mkdir(parents=True)
        self.manifest={'source_id':'fixture-source','files':{'driver':'bytes'}}
        save(self.driver/'build-input.json',self.manifest)
        save(self.run/'tools/stress-driver-build-input.json',self.manifest)
        digest=sha(self.driver/'build-input.json')
        self.drivers={digest:(self.driver,self.manifest)}
        self.receipt={'stress_driver':dict(manifest_sha256=digest,source_id='fixture-source',
                        files=self.manifest['files'].copy(),loads_original_B=True),
                      'roles':{r:{'config':dict(scenario='stress',stressExternal=True,stressSeconds=120)}
                               for r in ('host','join')}}
        self.marker={'kind':'installed','data':dict(source='fixture-source',bSource='frozen-b',
                                                   capability='native-hook',originalBBytes=True)}
        self.logs=[{'kind':'continuous-stress-fixture','data':dict(source='fixture-source',seconds=120)},
                   {'kind':'stress-measurements','data':dict(elapsedMs=120001,
                       shootingWindows=[dict(first=[0,0],last=[90,90]),dict(first=[90,90],last=[180,180])])}]
        for role in self.receipt['roles']:
            self.write(role+'.RConnectStressDriver.log',[self.marker])
            self.write(role+'.log',self.logs)

    def tearDown(self):
        self.assertTrue(self.base.is_relative_to((ROOT/'build/ab').resolve()))
        self.temp.cleanup()

    def write(self,name,events):
        (self.run/name).write_text('\n'.join(json.dumps(e) for e in events)+'\n',encoding='utf-8')

    def check(self,drivers=None):
        check_stress_fixture(self.receipt,self.run,self.drivers if drivers is None else drivers,'frozen-b','native-hook')

    def test_valid_both_roles_and_minutes(self):self.check()

    def test_ordinary_core_run_remains_accepted(self):
        del self.receipt['stress_driver']
        for r in self.receipt['roles'].values():r['config'].pop('stressExternal')
        self.check({})

    def test_requires_explicit_driver_selection(self):
        with self.assertRaisesRegex(ValueError,'unselected'):self.check({})

    def test_rejects_unrecorded_fixture(self):
        del self.receipt['stress_driver']
        with self.assertRaisesRegex(ValueError,'Unrecorded'):self.check()

    def test_rejects_different_frozen_source(self):
        self.receipt['stress_driver']['source_id']='changed'
        with self.assertRaisesRegex(ValueError,'receipt differs'):self.check()

    def test_rejects_changed_artifact(self):
        self.receipt['stress_driver']['files']['driver']='changed'
        with self.assertRaisesRegex(ValueError,'receipt differs'):self.check()

    def test_requires_original_b_load(self):
        self.receipt['stress_driver']['loads_original_B']=False
        with self.assertRaisesRegex(ValueError,'receipt differs'):self.check()

    def test_rejects_changed_captured_manifest(self):
        save(self.run/'tools/stress-driver-build-input.json',{'source_id':'changed'})
        with self.assertRaisesRegex(ValueError,'manifest changed'):self.check()

    def test_rejects_wrong_b_domain_on_join(self):
        marker=copy.deepcopy(self.marker);marker['data']['bSource']='another-b'
        self.write('join.RConnectStressDriver.log',[marker])
        with self.assertRaisesRegex(ValueError,'different B inputs'):self.check()

    def test_rejects_bootstrap_error(self):
        self.write('host.RConnectStressDriver.log',[self.marker,{'kind':'error','data':{}}])
        with self.assertRaisesRegex(ValueError,'exactly once'):self.check()

    def test_rejects_duplicate_install(self):
        self.write('join.RConnectStressDriver.log',[self.marker,self.marker])
        with self.assertRaisesRegex(ValueError,'exactly once'):self.check()

    def test_rejects_wrong_fixture_declaration(self):
        logs=copy.deepcopy(self.logs);logs[0]['data']['source']='changed'
        self.write('join.log',logs)
        with self.assertRaisesRegex(ValueError,'declaration differs'):self.check()

    def test_rejects_missing_last_minute(self):
        logs=copy.deepcopy(self.logs);logs[1]['data']['shootingWindows'].pop()
        self.write('join.log',logs)
        with self.assertRaisesRegex(ValueError,'declared duration'):self.check()

    def test_rejects_early_finish(self):
        logs=copy.deepcopy(self.logs);logs[1]['data']['elapsedMs']=119999
        self.write('host.log',logs)
        with self.assertRaisesRegex(ValueError,'declared duration'):self.check()

    def test_rejects_one_player_stopping_in_last_minute(self):
        logs=copy.deepcopy(self.logs);logs[1]['data']['shootingWindows'][1]['last'][1]=90
        self.write('join.log',logs)
        with self.assertRaisesRegex(ValueError,'stopped shooting'):self.check()


if __name__=='__main__':unittest.main()
