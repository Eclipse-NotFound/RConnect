"""Offline negative evidence fixtures. Does not create a passing game receipt."""
import copy
import contextlib
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import qualify as q


def workload(role="host", phase=0):
    count = 2 if role == "host" else 1
    enemies = {"count": (8, 80)[phase], "attached": (8, 80)[phase], "visible": 3}
    samples = []
    for i in range(60):
        samples.append({"ms": i * 1000, "enemies": copy.deepcopy(enemies),
                        "ammo": [10000 - i * 10] * count, "shots": [i * 10, i * 10],
                        "players": [{}] * count, "weapons": [{}] * count})
    return {"phase": phase, "expectedEnemies": (8, 80)[phase], "samples": samples,
            "timings": None, "frames": 600, "elapsed": 60000, "intervals": [100] * 600,
            "enemies": enemies, "baseAmmo": [10000] * count, "finalAmmo": [9400] * count}


def comparison_runs(candidate_mean=100, candidate_p95=100):
    rows = []
    for group in ("baseline", "candidate", "baseline", "candidate"):
        rows.append({"group": group, "workload": [
            {"role": role, "phase": phase, "mean_ms": candidate_mean if group == "candidate" else 100,
             "p95_ms": candidate_p95 if group == "candidate" else 100}
            for role in ("host", "join") for phase in (0, 1)]})
    return rows


class QualificationTests(unittest.TestCase):
    def rejected(self, mutate):
        value = workload()
        mutate(value)
        with self.assertRaises((q.InvalidEvidence, KeyError, TypeError)):
            q.phase_workload(value, "host", 0)

    def test_complete_native_workload(self):
        for role in ("host", "join"):
            for phase in (0, 1):
                result = q.phase_workload(workload(role, phase), role, phase)
                self.assertEqual(result["mean_ms"], 100)
                self.assertEqual(result["p95_ms"], 100)

    def test_44_samples_fail(self):
        self.rejected(lambda v: v.update(samples=v["samples"][:44]))

    def test_missing_attached_enemy_fails(self):
        self.rejected(lambda v: v["samples"][25]["enemies"].update(attached=7))

    def test_wrong_enemy_count_fails(self):
        self.rejected(lambda v: v["samples"][25]["enemies"].update(count=7))

    def test_no_ammo_does_not_count_as_shooting(self):
        self.rejected(lambda v: v["samples"][25]["ammo"].__setitem__(1, 9751))

    def test_negative_shots_fail(self):
        self.rejected(lambda v: v["samples"][25]["shots"].__setitem__(1, 239))

    def test_matching_ammo_and_shots_but_stopped_firing_fails(self):
        def mutate(v):
            for sample in v["samples"]:
                sample["ammo"][1] = 10000
                sample["shots"][1] = 0
        self.rejected(mutate)

    def test_uncovered_firing_window_is_not_silently_skipped(self):
        def mutate(v):
            v["samples"] = [s for s in v["samples"] if not 30000 <= s["ms"] < 34000]
        self.rejected(mutate)

    def test_frame_count_and_interval_sum(self):
        self.rejected(lambda v: v.update(frames=599))
        self.rejected(lambda v: v.update(elapsed=60001))

    def test_profile_cannot_pass(self):
        self.rejected(lambda v: v.update(timings={"active": True}))

    def test_nonfinite_or_repeated_samples_fail(self):
        self.rejected(lambda v: v.update(elapsed=float("nan")))
        self.rejected(lambda v: v["samples"][2].update(ms=1000))

    def test_five_percent_boundary_and_both_statistics(self):
        self.assertTrue(all(r["no_material_regression"] for r in q.compare(comparison_runs(105, 105))))
        self.assertFalse(all(r["no_material_regression"] for r in q.compare(comparison_runs(105.001, 100))))
        self.assertFalse(all(r["no_material_regression"] for r in q.compare(comparison_runs(100, 106))))

    def test_repeatability_not_hidden_by_median(self):
        runs = comparison_runs()
        runs[3]["workload"][0]["mean_ms"] = 120
        self.assertTrue(q.compare(runs)[0]["repeatable"])
        runs[3]["workload"][0]["mean_ms"] = 120.01
        self.assertFalse(q.compare(runs)[0]["repeatable"])
        runs = comparison_runs()
        runs[2]["workload"][0]["p95_ms"] = 121
        self.assertFalse(q.compare(runs)[0]["repeatable"])

    def test_runtime_paths_are_not_ambiguous(self):
        digest = "a" * 64
        with self.assertRaises(q.InvalidEvidence):
            q.canonical_files({"pfe.swf": digest, "PFE.swf": digest})
        with self.assertRaises(q.InvalidEvidence):
            q.canonical_files({"../pfe.swf": digest})
        with self.assertRaises(q.InvalidEvidence):
            q.canonical_files({"pfe.swf": ""})

    def test_original_log_must_agree_with_receipt(self):
        phase0, phase1 = workload(), workload(phase=1)
        driver = {"source_id": "fixture"}
        logs = [{"kind": "installed", "data": {"variant": "B", "role": "host", "seconds": 60,
                 "source": "fixture", "profile": False}}, {"kind": "ready", "data": {"land": "rbl"}}]
        for phase, value in enumerate((phase0, phase1)):
            logs.append({"kind": "measure-begin", "at": phase * 70000,
                         "data": {"phase": phase, "ammo": value["baseAmmo"], "enemies": value["enemies"]}})
            logs.extend({"kind": "sample", "data": s} for s in value["samples"])
            logs.append({"kind": "result", "at": phase * 70000 + 60000, "data": value})
        logs.append({"kind": "done"})
        entry = {"results": [phase0, phase1]}
        q.verify_log_results(logs, entry, "host", driver)
        changed = copy.deepcopy(entry)
        changed["results"][0]["elapsed"] += 1
        with self.assertRaises(q.InvalidEvidence):
            q.verify_log_results(logs, changed, "host", driver)
        logs[2]["data"]["ammo"] = [1, 1]
        with self.assertRaises(q.InvalidEvidence):
            q.verify_log_results(logs, entry, "host", driver)

    def test_retained_old_real_workload_still_verifies(self):
        # Read only: historical field9 timing is a workload parser fixture,
        # never reused as a field20 baseline/candidate performance qualification.
        path = q.ROOT / "build/ab/b-field-clean-fixed9-01/result.json"
        if not path.exists():
            self.skipTest("historical workload evidence not present")
        receipt = q.read(path)
        driver = q.read(q.ROOT / q.DRIVER / "build-input.json")
        for role in ("host", "join"):
            entry = receipt["roles"][role]
            q.verify_log_results(q.log_events(path.parent / role / "ABBench.log"), entry, role, driver)
            for phase, v in enumerate(entry["results"]):
                q.phase_workload(v, role, phase)


class FrozenIdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.legacy_path = q.ROOT / "experimental/b-field-perf-qualification/field20-plan.json"
        cls.legacy = q.read(cls.legacy_path)
        cls.legacy_hash = q.sha(cls.legacy_path)
        cls.plan = q.freeze("build/ab/b190-field20-build")

    def test_explicit_candidate_required_by_cli(self):
        with patch.object(sys, "argv", ["qualify.py", "freeze", "--out", "unused.json"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as result:
                q.main()
        self.assertEqual(result.exception.code, 2)

    def test_new_plan_and_legacy_plan_both_verify_without_rewriting_legacy(self):
        self.assertEqual(self.plan["schema"], q.PLAN_SCHEMA)
        q.verify_plan(self.plan)
        q.verify_plan(self.legacy)
        self.assertEqual(q.sha(self.legacy_path), self.legacy_hash)

    def test_baseline_or_native_cannot_be_swapped(self):
        for group, key, value in (("baseline", "build", "build/ab/b190-field20-build"),
                                  ("candidate", "native", q.PINNED["baseline"]["native"])):
            plan = copy.deepcopy(self.plan)
            plan["groups"][group][key] = value
            with self.assertRaises(q.InvalidEvidence):
                q.verify_plan(plan)

    def test_source_version_manifest_and_swf_cannot_be_relabelled(self):
        for key, value in (("source_id", "0" * 64), ("version", "B3-0.1-field21"),
                           ("manifest_sha256", "0" * 64), ("candidate_sha256", "0" * 64)):
            plan = copy.deepcopy(self.plan)
            plan["groups"]["candidate"][key] = value
            with self.assertRaises(q.InvalidEvidence):
                q.verify_plan(plan)

    def test_omitted_frozen_source_is_rejected(self):
        plan = copy.deepcopy(self.plan)
        del plan["artifacts"]["build/ab/b190-field20-build/src/RConnectMod.as"]
        with self.assertRaises(q.InvalidEvidence):
            q.verify_plan(plan)

    def test_candidate_outside_build_or_baseline_alias_is_rejected(self):
        with self.assertRaises(q.InvalidEvidence):
            q.freeze("experimental/b-field-perf-qualification")
        with self.assertRaises(q.InvalidEvidence):
            q.freeze(q.PINNED["baseline"]["build"])

    def test_actual_swf_disagrees_with_manifest_is_rejected(self):
        original = q.sha
        target = (q.ROOT / "build/ab/b190-field20-build/RConnectMod.swf").resolve()
        with patch.object(q, "sha", side_effect=lambda p: "0" * 64 if Path(p).resolve() == target else original(p)):
            with self.assertRaises(q.InvalidEvidence):
                q.freeze("build/ab/b190-field20-build")

    def test_manifest_source_id_and_inventory_are_verified(self):
        original = q.read
        target = (q.ROOT / "build/ab/b190-field20-build/build-input.json").resolve()
        for mutation in (lambda v: v.update(source_id="0" * 64),
                         lambda v: v["sources"].pop("src/RConnectMod.as")):
            def changed(path):
                value = original(path)
                if Path(path).resolve() == target:
                    mutation(value)
                return value
            with patch.object(q, "read", side_effect=changed):
                with self.assertRaises(q.InvalidEvidence):
                    q.freeze("build/ab/b190-field20-build")


if __name__ == "__main__":
    unittest.main(verbosity=2)
