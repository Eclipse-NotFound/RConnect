"""Offline identity/API fakes only. Never opens an actual process or runs AIR."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import profile_cpu as p


class FakeQueries:
    def __init__(self, workspace, created):
        self.workspace, self.created = workspace, created
        self.opened, self.closed = [], []
        self.exits, self.kernel, self.user = {}, 100000, 200000
        self.bad_image = False
        self.bad_query = False

    def open(self, pid):
        self.opened.append(pid)
        return pid

    def close(self, handle):
        self.closed.append(handle)

    def image(self, handle):
        if self.bad_image:
            return str(self.workspace / "unrelated.exe")
        return str(self.workspace / ("host" if handle == 101 else "join") / "adl64.exe")

    def times(self, handle):
        if self.bad_query:
            raise OSError("fake process-query error")
        return {"creation_100ns": self.created, "exit_100ns": self.exits.get(handle, 0),
                "kernel_100ns": self.kernel, "user_100ns": self.user}

    def memory(self, handle):
        return {"available": False, "winerror": 5}


class ProcessSamplerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cpu-wrapper-fixture-", dir=Path(__file__).parent)
        self.root = Path(self.temporary.name)
        self.workspace, self.result, self.appdata = self.root / "runtime", self.root / "result", self.root / "appdata"
        self.created = p.filetime_now()
        self.api = FakeQueries(self.workspace, self.created)
        self.observer = p.Observer(self.workspace, self.result, self.appdata, self.api,
                                   lambda: {"time": 1, "free_gib": 8, "cpuTicks": [1, 2, 3]}, self.created)
        self.entries = {}
        for role, pid in (("host", 101), ("join", 202)):
            game = self.workspace / role
            game.mkdir(parents=True)
            appid = "pfe-modsettings-rconnect-b-ab-" + role + "-123456abcdef"
            raw = ('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid
                   + '</id><initialWindow><content>pfe.swf</content></initialWindow></application>').encode()
            (game / "ab-test.xml").write_bytes(raw)
            self.entries[role] = {"pid": pid, "appid": appid,
                "storage": str(self.appdata / appid / "Local Store"),
                "files": {"ab-test.xml": hashlib.sha256(raw).hexdigest()}}

    def tearDown(self):
        self.observer.stop()
        for role in list(self.observer.handles):
            self.observer.close_role(role)
        self.temporary.cleanup()

    def ready(self):
        self.observer.receipt = {"roles": self.entries}

    def test_valid_descriptor_identity(self):
        for role in ("host", "join"):
            value = p.identity(self.entries[role], role, self.workspace, self.appdata)
            self.assertEqual(value["session"], "123456abcdef")
            self.assertEqual(value["pid"], self.entries[role]["pid"])

    def test_wrong_role_or_hash_or_storage_rejected(self):
        for key, value in (("appid", self.entries["join"]["appid"]),
                           ("files", {"ab-test.xml": "0" * 64}),
                           ("storage", str(self.root / "unrelated")), ("pid", True)):
            entry = copy.deepcopy(self.entries["host"])
            entry[key] = value
            with self.assertRaises(ValueError):
                p.identity(entry, "host", self.workspace, self.appdata)

    def test_descriptor_entry_must_match_even_if_hash_matches(self):
        descriptor = self.workspace / "host/ab-test.xml"
        raw = descriptor.read_bytes().replace(b"pfe.swf", b"other.swf")
        descriptor.write_bytes(raw)
        self.entries["host"]["files"]["ab-test.xml"] = hashlib.sha256(raw).hexdigest()
        with self.assertRaises(ValueError):
            p.identity(self.entries["host"], "host", self.workspace, self.appdata)

    def test_save_forwards_once_same_objects_args_return_and_does_not_mutate(self):
        calls = []
        token, extra = object(), object()
        receipt = {"roles": self.entries}
        before = copy.deepcopy(receipt)
        original = lambda *a, **k: calls.append((a, k)) or token
        wrapped = self.observer.save_wrapper(original)
        path = self.result / "result.json"
        self.assertIs(wrapped(path, receipt, extra, flag=extra), token)
        self.assertEqual(len(calls), 1)
        self.assertIs(calls[0][0][0], path)
        self.assertIs(calls[0][0][1], receipt)
        self.assertIs(calls[0][0][2], extra)
        self.assertIs(calls[0][1]["flag"], extra)
        self.assertIs(self.observer.receipt, receipt)
        self.observer.tick()
        self.assertEqual(receipt, before)

    def test_original_save_exception_is_preserved_and_no_observation(self):
        calls = []
        def failing(*args, **kwargs):
            calls.append(args)
            raise OSError("original failure")
        with self.assertRaisesRegex(OSError, "original failure"):
            self.observer.save_wrapper(failing)(self.result / "result.json", {"roles": self.entries})
        self.assertEqual(len(calls), 1)
        self.assertIsNone(self.observer.receipt)

    def test_unrelated_save_not_observed(self):
        self.observer.save_wrapper(lambda *a: None)(self.result / "other.json", {"roles": self.entries})
        self.assertIsNone(self.observer.receipt)

    def test_pid_added_later_to_live_receipt_only_observes_explicit_pids(self):
        receipt = {"roles": {"host": dict(self.entries["host"])}}
        del receipt["roles"]["host"]["pid"]
        self.observer.save_wrapper(lambda *a: None)(self.result / "result.json", receipt)
        self.observer.tick()
        self.assertEqual(self.api.opened, [])
        receipt["roles"]["host"]["pid"] = 101
        self.observer.tick()
        receipt["roles"]["join"] = self.entries["join"]
        self.observer.tick()
        self.assertEqual(self.api.opened, [101, 202])

    def test_identity_failure_never_queries_guessed_pid(self):
        self.entries["host"]["appid"] = "pfe"
        self.ready()
        self.observer.tick()
        self.assertEqual(self.api.opened, [202])
        self.assertIn("host", self.observer.rejected)

    def test_wrong_process_image_closes_query_handles(self):
        self.api.bad_image = True
        self.ready()
        self.observer.tick()
        self.assertEqual(self.api.opened, [101, 202])
        self.assertEqual(self.api.closed, [101, 202])
        self.assertFalse(self.observer.identities)

    def test_old_pid_creation_rejected(self):
        self.api.created -= 20000000
        self.ready()
        self.observer.tick()
        self.assertEqual(self.api.closed, [101, 202])
        self.assertFalse(self.observer.identities)

    def test_recorded_pid_changes_never_attaches_replacement(self):
        self.ready()
        self.observer.tick()
        self.entries["host"]["pid"] = 999
        self.observer.tick()
        self.assertEqual(self.api.opened, [101, 202])
        self.assertIn(101, self.api.closed)
        self.assertIn("host", self.observer.rejected)

    def test_natural_exit_is_normal_and_never_reopened(self):
        self.ready()
        self.observer.tick()
        self.api.exits[101] = self.created + 10000000
        self.observer.tick()
        self.observer.tick()
        self.assertIn("host", self.observer.exited)
        self.assertEqual(self.api.opened, [101, 202])
        self.assertEqual(self.observer.errors, [])

    def test_memory_unavailable_is_recorded_not_escalated(self):
        self.ready()
        self.observer.tick()
        self.assertEqual(self.observer.samples[0]["roles"]["host"]["memory"],
                         {"available": False, "winerror": 5})
        self.assertEqual(self.api.opened, [101, 202])

    def test_query_error_is_bounded_and_does_not_change_receipt(self):
        self.ready()
        self.observer.tick()
        before = copy.deepcopy(self.observer.receipt)
        self.api.bad_query = True
        self.observer.tick()
        self.observer.tick()
        self.assertEqual(self.observer.receipt, before)
        self.assertEqual(self.api.closed, [101, 202])
        self.assertEqual(len(self.observer.errors), 2)

    def test_cpu_units_one_core_and_machine_share(self):
        prior = {"monotonic_ns": 0, "kernel_100ns": 0, "user_100ns": 0}
        value = {"monotonic_ns": 1000000000, "kernel_100ns": 2000000, "user_100ns": 8000000}
        delta = p.cpu_delta(prior, value, 8)
        self.assertEqual(delta["cpu_core_percent"], 100)
        self.assertEqual(delta["cpu_machine_percent"], 12.5)
        self.assertEqual(delta["user_ms"], 800)
        self.assertIsNone(p.cpu_delta(None, value, 8))
        with self.assertRaises(ValueError):
            p.cpu_delta(value, prior, 8)

    def test_sample_limit_closes_handles_and_thread_stops(self):
        self.ready()
        self.observer.max_samples = 1
        self.observer.tick()
        self.observer.start()
        self.observer.thread.join(timeout=2)
        self.assertFalse(self.observer.thread.is_alive())
        self.assertTrue(self.observer.truncated)
        self.assertEqual(self.api.closed, [101, 202])
        self.assertEqual(len(self.observer.samples), 1)

    def test_windows_open_uses_query_limited_access_only(self):
        calls = []
        class Kernel:
            @staticmethod
            def OpenProcess(*args):
                calls.append(args)
                return 123
        query = object.__new__(p.WindowsQueries)
        query.api = Kernel()
        self.assertEqual(query.open(101), 123)
        self.assertEqual(calls, [(0x1000, False, 101)])


if __name__ == "__main__":
    unittest.main(verbosity=2)
