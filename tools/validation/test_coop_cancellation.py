"""Offline cancellation regression; no AIR, JVM or shared registry access.

Run: python -B tools/validation/test_coop_cancellation.py

The runner prints OUTPUT before it queues. Create <OUTPUT>/cancel-request.json
with e.g. {"reason": "yield test slot"}; even empty/incomplete JSON cancels.
While queued the existing registry wait continues; immediately upon acquiring
the slot the runner checks the marker and exits without launching a game.
During preparation it checks before launch; during bootstrap/runtime it checks
each polling iteration. Do not kill the runner: let it reap its own children,
close desktop/stdout handles, preserve logs, then mark the run interrupted.
Exit 130 and cancelled=true/passed=false distinguish this from a passing test.

All process, registration, memory and asset providers below are fakes. Real
runner preparation, polling, finally cleanup and result writing are exercised
in a temporary directory; even test failures cannot launch a native process.
"""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import patch

TOOLS=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(TOOLS))
spec=importlib.util.spec_from_file_location('coop_cancel_runner',TOOLS/'run_coop_regression.py')
runner=importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Harness:
    def __init__(self,base,trigger=None,private=True,timeout=False,natural_exit=False):
        self.root=base/'Remains/mods/RConnect'
        self.game=self.root.parents[1]
        self.storage=base/'AppData'
        self.root.mkdir(parents=True)
        self.trigger=trigger;self.private=private;self.timeout=timeout
        self.natural_exit=natural_exit;self.processes=[];self.events=[]
        self.now=0;self.record=None;self.memory_calls=0;self.sleeps=0
        self.output=self.root/'build/cooperation/fixture000'
        for name,payload in [('src/RConnectMod.as',b'VERSION:String = "fixture"'),
                             ('tools/validation/runtime_memory.py',b'fixture-memory'),
                             ('tools/validation/air_test_inventory.py',b'fixture-inventory'),
                             ('candidate.swf',b'fixture-candidate-not-executable')]:
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(payload)
        (self.game/'pfe.swf').write_bytes(b'fixture-host-not-executable')
        helper=self.game/'mods/ModLoader/tools/air_test_process.py'
        helper.parent.mkdir(parents=True);helper.write_text('# fixture helper hash',encoding='utf-8')
        harness=self
        class FakeRecord:
            def __init__(self,**kwargs):
                harness.record=self;self.id='fixture-registration';self.launching=False
                self.children=[];self.outcome='completed';self.note='';self.kwargs=kwargs
            def __enter__(self):
                harness.events.append('registry acquired')
                if harness.trigger=='queued':harness.cancel('queued request')
                return self
            def before_launch(self,detail):
                self.launching=True;harness.events.append('before launch')
                if harness.trigger=='before_launch':harness.cancel('before process creation')
            def child(self,pid):
                self.children.append(pid);self.launching=False
                harness.events.append(('child',pid))
            def child_stopped(self):
                harness.events.append('child_stopped');self.launching=False
            def __exit__(self,*error):
                harness.events.append('registry exit')
                # Mirrors the ownership invariant without querying Windows.
                assert not self.launching
                assert all(p.stopped for p in harness.processes)
        self.registration=types.SimpleNamespace(Registration=FakeRecord)

    def cancel(self,reason):
        (self.output/'cancel-request.json').write_text(json.dumps({'reason':reason}),encoding='utf-8')

    def memory(self):
        self.memory_calls+=1
        return dict(free_commit_bytes=16*1024**3)

    def sleep(self,seconds):
        self.now+=seconds;self.sleeps+=1
        if self.trigger=='bootstrap' and self.sleeps==1:self.cancel('host boot pending')
        if self.trigger=='runtime' and len(self.processes)==2:
            for proc in self.processes:proc.log.write_text(self.good_log(),encoding='utf-8')
            self.cancel('runtime; passing logs must not override cancellation')

    @staticmethod
    def good_log():
        return ('vfixture initialized\ntick 200\nwelcome id=fixture\nunitsync matched\n'
                'RConnectDbg: tick world=test/0 t_exit=0 allStat=1 onPause=false\n')

    def launch(self,command,**kwargs):
        harness=self
        role=Path(command[-1]).parent.name
        appid='pfe-rconnect-coop-'+role+'-fixture000'
        log=self.storage/appid/'Local Store/RConnect.log'
        log.parent.mkdir(parents=True,exist_ok=True)
        text=self.good_log()
        if self.trigger=='runtime':text=text.replace('tick 200','tick 1')
        log.write_text(text,encoding='utf-8')
        (log.parent/'Fixture.log').write_text('fixture module evidence',encoding='utf-8')
        class FakeProcess:
            def __init__(self):
                self.pid=7000+len(harness.processes);self.stopped=harness.natural_exit
                self.closed=False;self.waits=0;self.stdout=kwargs['stdout'];self.log=log
            def poll(self):return 0 if self.stopped else None
            def terminate(self):harness.events.append(('terminate',self.pid));self.stopped=True
            def kill(self):harness.events.append(('kill',self.pid));self.stopped=True
            def wait(self,timeout=None):
                self.waits+=1;harness.events.append(('wait',self.pid))
                if harness.timeout and self.waits==1:raise subprocess.TimeoutExpired('fake',timeout)
                assert self.stopped
                return 0
            def close(self):
                assert self.stopped and self.waits
                self.closed=True;harness.events.append(('close',self.pid))
        proc=FakeProcess();self.processes.append(proc)
        return proc

    def run(self):
        real_copytree=shutil.copytree
        def copytree(source,destination,*args,**kwargs):
            result=real_copytree(source,destination,*args,**kwargs)
            if self.trigger=='preparation' and Path(destination)==self.output/'join':
                self.cancel('prepared both copies')
            return result
        argv=['run_coop_regression.py','--candidate',str(self.root/'candidate.swf'),
              '--game-root',str(self.game),'--expected-version','fixture',
              '--smoke','--seconds','10','--registry-wait','30','--land','test']
        if self.private:argv.append('--private-desktop')
        if self.trigger!='bootstrap':argv.append('--wait-host-world')
        self.stdout=io.StringIO()
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(runner,'ROOT',self.root))
            stack.enter_context(patch.object(runner,'GAME',self.game))
            stack.enter_context(patch.object(runner,'memory_snapshot',self.memory))
            stack.enter_context(patch.object(runner,'air_processes',lambda:[]))
            stack.enter_context(patch.object(runner,'native_runtime_files',lambda game:[game/'pfe.swf']))
            stack.enter_context(patch.object(runner,'time',types.SimpleNamespace(
                monotonic=lambda:self.now,sleep=self.sleep,time=time.time)))
            stack.enter_context(patch.object(runner,'uuid',types.SimpleNamespace(
                uuid4=lambda:types.SimpleNamespace(hex='fixture0000000'))))
            stack.enter_context(patch.object(runner,'subprocess',types.SimpleNamespace(
                Popen=self.launch,STDOUT=subprocess.STDOUT,CREATE_NO_WINDOW=0,
                TimeoutExpired=subprocess.TimeoutExpired)))
            stack.enter_context(patch.object(runner.shutil,'copytree',copytree))
            stack.enter_context(patch.dict(sys.modules,{'test_registry':self.registration,
                'air_test_process':types.SimpleNamespace(HiddenProcess=self.launch)}))
            stack.enter_context(patch.dict(os.environ,{'APPDATA':str(self.storage)}))
            stack.enter_context(patch.object(sys,'argv',argv))
            stack.enter_context(contextlib.redirect_stdout(self.stdout))
            try:runner.main()
            except SystemExit as result:self.exit_code=result.code
            else:raise AssertionError('runner did not exit')
        return self


class CancellationTests(unittest.TestCase):
    def temporary_directory(self):
        # Keep fixtures inside the allowed workspace. Some sandbox TEMP paths
        # permit creation but do not grant access to the resulting directory.
        parent=(TOOLS.parent/'build').resolve()
        parent.mkdir(exist_ok=True)
        directory=tempfile.TemporaryDirectory(prefix='cancel-fixture-',dir=parent)
        assert Path(directory.name).resolve().parent==parent
        return directory

    def run_fixture(self,**kwargs):
        directory=self.temporary_directory()
        self.addCleanup(directory.cleanup)
        return Harness(Path(directory.name),**kwargs).run()

    def assert_cancelled(self,harness,children):
        self.assertEqual(harness.exit_code,130)
        self.assertEqual(harness.record.outcome,'interrupted')
        result=json.loads((harness.output/'registry-result.json').read_text(encoding='utf-8'))
        evidence=json.loads((harness.output/'cancel-result.json').read_text(encoding='utf-8'))
        self.assertTrue(result['cancelled']);self.assertFalse(result['passed'])
        self.assertTrue(evidence['cancelled']);self.assertFalse(evidence['passed'])
        self.assertNotIn('RESULT PASS',harness.stdout.getvalue())
        self.assertEqual(len(harness.processes),children)
        for proc in harness.processes:
            self.assertTrue(proc.stopped);self.assertGreater(proc.waits,0)
            self.assertTrue(proc.stdout.closed)
            if harness.private:self.assertTrue(proc.closed)
        if children:
            stopped=harness.events.index('child_stopped')
            for proc in harness.processes:
                self.assertLess(harness.events.index(('wait',proc.pid)),stopped)
                if harness.private:self.assertLess(harness.events.index(('close',proc.pid)),stopped)
            self.assertTrue((harness.output/'host.log').is_file())
            self.assertTrue((harness.output/'module-logs/host/Fixture.log').is_file())
            self.assertTrue((harness.output/'memory-timeline.json').is_file())
        return evidence

    def test_queued_marker_checked_before_memory_or_preparation(self):
        h=self.run_fixture(trigger='queued')
        self.assertEqual(self.assert_cancelled(h,0)['phase'],'registration acquired')
        self.assertEqual(h.memory_calls,0)
        self.assertFalse((h.output/'candidate.swf').exists())
        self.assertTrue(h.stdout.getvalue().startswith('OUTPUT '))

    def test_marker_during_copy_preparation_prevents_both_launches(self):
        h=self.run_fixture(trigger='preparation')
        self.assertEqual(self.assert_cancelled(h,0)['phase'],'before host launch')
        self.assertFalse((h.output/'frozen').exists())
        self.assertIn('child_stopped',h.events)

    def test_marker_during_before_launch_releases_launching_state(self):
        h=self.run_fixture(trigger='before_launch')
        self.assertEqual(self.assert_cancelled(h,0)['phase'],'before host process creation')
        self.assertFalse(h.record.launching)
        self.assertIn('child_stopped',h.events)

    def test_bootstrap_cancellation_reaps_host_without_starting_join(self):
        h=self.run_fixture(trigger='bootstrap')
        self.assertEqual(self.assert_cancelled(h,1)['phase'],'host bootstrap')

    def test_runtime_cancellation_reaps_both_even_with_passing_logs(self):
        h=self.run_fixture(trigger='runtime')
        self.assertEqual(self.assert_cancelled(h,2)['phase'],'runtime loop')

    def test_wait_timeout_forces_owned_child_then_waits_and_closes(self):
        h=self.run_fixture(trigger='bootstrap',timeout=True)
        self.assert_cancelled(h,1)
        self.assertEqual(h.processes[0].waits,2)

    def test_regular_process_uses_terminate_and_wait(self):
        h=self.run_fixture(trigger='bootstrap',private=False)
        self.assert_cancelled(h,1)
        self.assertIn(('terminate',h.processes[0].pid),h.events)

    def test_naturally_exited_child_still_waited_and_closed(self):
        h=self.run_fixture(trigger='bootstrap',natural_exit=True)
        self.assert_cancelled(h,1)
        self.assertNotIn(('kill',h.processes[0].pid),h.events)

    def test_no_marker_preserves_success(self):
        h=self.run_fixture()
        self.assertEqual(h.exit_code,0);self.assertEqual(h.record.outcome,'passed')
        result=json.loads((h.output/'registry-result.json').read_text(encoding='utf-8'))
        self.assertTrue(result['passed']);self.assertFalse(result['cancelled'])
        self.assertFalse((h.output/'cancel-result.json').exists())
        self.assertEqual(len(h.processes),2)
        self.assertTrue(all(p.closed and p.stdout.closed for p in h.processes))

    def test_incomplete_marker_is_cancelled_and_preserved(self):
        with self.temporary_directory() as directory:
            output=Path(directory);marker=output/'cancel-request.json';marker.write_bytes(b'{')
            with self.assertRaises(runner.RunCancelled) as failure:
                runner.check_cancel_requested(output,'fixture')
            self.assertFalse(failure.exception.evidence['passed'])
            self.assertIn('request_note',failure.exception.evidence)
            self.assertEqual(marker.read_bytes(),b'{')


if __name__=='__main__':unittest.main(verbosity=2)
