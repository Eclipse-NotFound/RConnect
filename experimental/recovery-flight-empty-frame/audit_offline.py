"""Read original evidence, test the isolated classifier, write this tree only."""
from pathlib import Path
import hashlib
import importlib.util
import io
import json
import unittest

import analyze
import test_empty_frame

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = HERE.parent / "recovery-tests" / "continuity-extra"
RUNS = ("18f969414e", "7d1c0cb805")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    suite = unittest.defaultTestLoader.loadTestsFromModule(test_empty_frame)
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=1).run(suite)
    evidence = []
    for run in RUNS:
        directory = ROOT / "build" / "cooperation" / run
        logs = {role: analyze.load(directory / (role + ".log"), role) for role in ("host", "join")}
        cases = []
        for index, (weapon, source_role) in enumerate(analyze.EXPECTED):
            remote_role = "join" if source_role == "host" else "host"
            source, remote = logs[source_role]["source"][index], logs[remote_role]["remote"][index]
            before = test_empty_frame.old.evaluate(source, remote)
            after = analyze.evaluate(source, remote)
            changed = [key for key in before["checks"] if before["checks"][key] != after["checks"][key]]
            assert all(key == "all_remote_samples_in_viewport" for key in changed), (run, index, changed)
            for key, value in before.items():
                if key not in ("checks", "sampled_flight_checks_passed"):
                    assert value == after[key], (run, index, key)
            cases.append(dict(round=index, weapon=weapon, changed_checks=changed,
                original_failed_checks=[key for key, value in before["checks"].items() if not value],
                reclassified_failed_checks=[key for key, value in after["checks"].items() if not value],
                viewport_evidence=after["viewport_evidence"],
                remote_samples_retained=after["remote"]["samples"],
                other_checks_and_metrics_identical=True))
        failures = [line for values in logs.values() for line in values["failures"]]
        assert failures, "Historical source failures must be preserved"
        evidence.append(dict(run=run, historical_status_changed=False, historical_coop_failures=failures,
            eligible_for_pass_with_original_logs=False, cases=cases,
            input_sha256={role: digest(directory / (role + ".log")) for role in logs}))
    receipt = dict(kind="offline-fixture-classification-only", tests=result.testsRun,
        failures=len(result.failures), errors=len(result.errors), successful=result.wasSuccessful(),
        historical=evidence, air_run=False, jvm_run=False, production_changed=False,
        source_sha256={name: digest(HERE / name) for name in ("NativeFlightContinuityTestDoc.as",
            "NativeFlightBounds.as", "analyze.py", "bounds_evidence.py", "test_empty_frame.py", "audit_offline.py")},
        baseline_sha256={name: digest(BASE / name) for name in ("NativeFlightContinuityTestDoc.as", "analyze.py", "test_analyze.py")},
        unittest_output=stream.getvalue())
    output = HERE / "offline-receipt.json"
    output.write_text(json.dumps(receipt, ensure_ascii=False, indent=2, allow_nan=False)+"\n", encoding="utf-8")
    print(json.dumps(dict(output=str(output), tests=result.testsRun, failures=len(result.failures),
        errors=len(result.errors), historical_changes=[dict(run=r["run"],
        viewport_only_cases=[c["round"] for c in r["cases"] if c["changed_checks"]]) for r in evidence],
        historical_status_changed=False, air_run=False), ensure_ascii=False))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
