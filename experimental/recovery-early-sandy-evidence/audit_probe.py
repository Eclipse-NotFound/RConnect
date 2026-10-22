"""Read finalized bounded revisit diagnostics without changing test verdicts."""
from pathlib import Path
import argparse
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RV_OLD = "7852f61e083993e69431d5d8ca2fdf3c07d4068715946d04b3e796cecbe86764"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(mapping):
    return {k.replace("\\", "/").lower(): v for k, v in mapping.items()}


def visible_blockers(row):
    """Only observable conditions, never pretend to inspect private gate fields."""
    reasons = []
    n = row.get("nativeState", {})
    if n.get("curLandId") != n.get("landId"):
        reasons.append("native.curLandId differs from current Land.act.id")
    for key, predicate in (("exit", lambda x: x != 0), ("comLoad", lambda x: x >= 0),
                           ("t_die", lambda x: x > 0), ("ng_wait", lambda x: x > 0)):
        if key in n and predicate(n[key]):
            reasons.append("native:" + key + "=" + str(n[key]))
    if row.get("renderer", {}).get("sceneViewReady") is not True:
        reasons.append("renderer.sceneViewReady is not true")
    for index, ticket in enumerate(row.get("tickets", [])):
        if ticket.get("waiting") is True:
            reasons.append("ticket[%d].waiting is true" % index)
        if ticket.get("unpainted") is not False:
            reasons.append("ticket[%d].unpainted is not false" % index)
        for key, value in ticket.get("currentIdentity", {}).items():
            if value is not True:
                reasons.append("ticket[%d].identity.%s differs" % (index, key))
    reasons.extend("fault:" + value for value in row.get("faults", []))
    return reasons


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wrapper", required=True)
    ap.add_argument("--baseline-run", default="3b3c31c5f5")
    ap.add_argument("--expected-candidate", help="Optional compiled candidate directory; verifies real production slot")
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    directory = ROOT / args.wrapper
    result = read(directory / "result.json")
    run = ROOT / "build/cooperation" / result["run"]
    manifest = read(run / "run.json")
    old = read(ROOT / "build/cooperation" / args.baseline_run / "run.json")
    report = dict(run=result["run"], wrapper=str(directory),
                  wrapper_passed=result["passed"], wrapper_exit_code=result["exit_code"],
                  installation_unchanged=result["installation_unchanged"],
                  wrapper_result_sha256=sha(directory / "result.json"),
                  run_manifest_sha256=sha(run / "run.json"), baseline_run=args.baseline_run,
                  roles={}, performance_qualified=False)
    if args.expected_candidate:
        candidate = ROOT / args.expected_candidate
        candidate_meta = read(candidate / "prepared.json")
        expected = sha(candidate / "RConnectMod.swf")
        assert candidate_meta["compiled"] is True and candidate_meta["sha256"] == expected
        report["expected_candidate"] = dict(path=str(candidate), version=candidate_meta["version"],
            sha256=expected, manifest_sha256=sha(candidate / "prepared.json"))
    for role, actual_inputs in manifest["inputs"].items():
        baseline_inputs = old["inputs"][role]
        if args.expected_candidate:
            assert actual_inputs["production"] == expected, "wrong actual production candidate"
        same_inputs = {key: actual_inputs[key] == baseline_inputs[key]
                       for key in ("game", "assets", "production", "harness", "modules", "mod_assets")}
        modules = canonical(actual_inputs["modules"])
        old_config = canonical(old["configuration_files"][role])
        new_config = canonical(manifest["configuration_files"][role])
        non_rc_config = {k: new_config.get(k) == value for k, value in old_config.items()
                         if k != "mods/rconnect/release/config.txt"}
        lines = (run / (role + ".log")).read_text(encoding="utf-8-sig").splitlines()
        segments = {}
        for line in lines:
            if not line.startswith("EARLY REVISIT PROBE "):
                continue
            row = json.loads(line[len("EARLY REVISIT PROBE "):])
            segments.setdefault(str(row["segment"]), []).append(row)
        summaries = {}
        for segment, rows in segments.items():
            assert len(rows) <= 20, "probe exceeded its fixed per-trip limit"
            assert [r["sequence"] for r in rows] == list(range(1, len(rows) + 1)), "diagnostic sequence gap"
            assert all(r["readOnly"] is True and r["diagnosticOnly"] is True for r in rows)
            tail = rows[-1]
            summaries[segment] = dict(row_count=len(rows), reasons=[r["reason"] for r in rows],
                last_elapsed=tail["elapsed"], last_visible_blockers=visible_blockers(tail),
                last_renderer=tail.get("renderer"), last_native=tail.get("nativeState"),
                last_rooms=tail.get("rooms"), last_permit=tail.get("permit"),
                last_tickets=tail.get("tickets"), bridge_calls=tail.get("bridgeCalls"),
                bridge_nulls=tail.get("bridgeNulls"),
                all_snapshots_have_no_fault=all(not r["faults"] for r in rows),
                rows=rows)
        report["roles"][role] = dict(
            log_sha256=sha(run / (role + ".log")), same_runtime_inputs_as_baseline=same_inputs,
            actual_production=actual_inputs["production"], actual_driver=actual_inputs["driver"],
            actual_rv=modules["mods/realisticvision/release/realisticvisionmod.swf"],
            actual_rv_is_frozen_old=modules["mods/realisticvision/release/realisticvisionmod.swf"] == RV_OLD,
            non_rconnect_config_equal=non_rc_config, segments=summaries,
            framework=result["roles"][role]["checks"], errors=result["roles"][role]["errors"],
            native_phase_lines=[s for s in lines if s.startswith("RConnectEarly:")],
            completed_rows=len(result["roles"][role].get("rows", [])))
    report["private_conditions_not_measured"] = ["paintAllowed", "paintFrame/nativeFrame", "localReady", "RENDER callback count"]
    destination = Path(args.output).resolve()
    destination.relative_to(HERE)
    assert not destination.exists()
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"run": report["run"], "wrapper_passed": report["wrapper_passed"],
        "roles": {role: {"same_inputs": r["same_runtime_inputs_as_baseline"],
            "old_rv": r["actual_rv_is_frozen_old"],
            "segments": {n: {"rows": s["row_count"], "last_blockers": s["last_visible_blockers"]}
                for n, s in r["segments"].items()}}
            for role, r in report["roles"].items()}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
