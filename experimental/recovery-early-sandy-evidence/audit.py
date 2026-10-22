"""Read-only audit of exact early native travel logs; never starts AIR.

The wrapper's pass flag is preserved, not upgraded to a performance verdict.
Run with --dual <wrapper-output> and optionally --solo <wrapper-output>.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def select(row, keys):
    return {key: row.get(key) for key in keys}


def input_check(row):
    data = row.get("inputEvidence", {})
    baseline = data.get("baseline", [])
    pressed = data.get("pressed", [])
    released = data.get("released", [])
    direction = data.get("direction")
    identities = all(r.get("sameActor") is True and r.get("sameCtr") is True
                     for r in baseline + pressed + released)
    released_baseline = len(baseline) >= 4 and all(
        r.get("keyLeft") is False and r.get("keyRight") is False
        and r.get("walk") == 0 and math.isfinite(r.get("dx", math.nan))
        and math.isfinite(r.get("x", math.nan)) for r in baseline)
    tail = baseline[-3:]
    stationary_tail = len(tail) == 3 and all(abs(r["dx"]) <= .1 for r in tail)
    stationary_tail = stationary_tail and max(r["x"] for r in tail) - min(r["x"] for r in tail) <= .1
    pressed_keys = len(pressed) >= 2 and all(
        r.get("keyLeft") == (direction < 0) and r.get("keyRight") == (direction > 0)
        for r in pressed)
    movement = pressed[-1] if pressed else {}
    responded = (bool(pressed) and movement.get("walk") == direction
                 and movement.get("dx", 0) * direction > 0
                 and row.get("inputDisplacement", 0) * direction > .1)
    released_native = len(released) >= 2 and all(
        r.get("keyLeft") is False and r.get("keyRight") is False for r in released)
    release_consumed = bool(released) and released[-1].get("walk") == 0
    windows = (data.get("baselineElapsed", math.inf) <= 1000
               and row.get("inputResponseMs", math.inf) <= 1000)
    checks = dict(identities=identities, released_baseline=released_baseline,
                  stationary_tail=stationary_tail, pressed_keys=pressed_keys,
                  responded=responded, released_native=released_native,
                  release_consumed=release_consumed, original_windows=windows)
    return dict(passed=all(checks.values()), checks=checks,
                baseline_ms=data.get("baselineElapsed"),
                response_ms=row.get("inputResponseMs"),
                release_verified_after_request_ms=row.get("inputReleaseVerifiedWall", 0) - row.get("requestedWall", 0))


def ticket_check(row):
    evidence = row.get("rasterEvidence", {})
    tickets = []
    for ticket in evidence.get("tickets", []):
        # getTimer clocks have separate process origins. Only ticket's paired
        # wall/at observation permits translating its own later local times.
        offset = ticket["wall"] - ticket["at"]
        tickets.append(dict(
            created_wall=ticket["wall"],
            observed_release_wall=offset + ticket["firstReleased"] if ticket["firstReleased"] >= 0 else None,
            observed_painted_wall=offset + ticket["firstPainted"] if ticket["firstPainted"] >= 0 else None,
            observed_release_paint_same_sample=ticket["firstReleased"] == ticket["firstPainted"],
            initial_waiting=ticket["initialWaiting"], initial_unpainted=ticket["initialUnpainted"],
            early_pending=ticket.get("earlyPending"), permit=ticket.get("permit")))
    return dict(passed=evidence.get("passed"), expected=evidence.get("expected"),
                tickets=tickets, start=evidence.get("startPermit"), final=evidence.get("finalPermit"),
                actual_raster_interval_observed=False, no_simulation_asserted=False)


def audit_run(directory):
    directory = directory.resolve()
    result_file = directory / "result.json"
    result = read(result_file)
    raw_dir = ROOT / "build/cooperation" / result["run"]
    raw_manifest = raw_dir / "run.json"
    output = dict(directory=str(directory), run=result["run"], wrapper_passed=result["passed"],
                  installation_unchanged=result["installation_unchanged"],
                  result_sha256=sha(result_file), manifest_sha256=sha(raw_manifest), roles={})
    for role, r in result["roles"].items():
        log = raw_dir / (role + ".log")
        current_round = None
        clocks, phases, receives, restores, errors = [], [], [], [], []
        observed_rows = []
        for line in log.read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("TRAVEL CLOCK "):
                clock = json.loads(line[len("TRAVEL CLOCK "):])
                current_round = clock["round"]
                clocks.append(clock)
            elif line.startswith("TRAVEL RESULT "):
                observed_rows.append(json.loads(line[len("TRAVEL RESULT "):]))
            elif line.startswith("RConnectEarly:"):
                m = re.search(r"RConnectEarly: (\w+) (\S+).* t=(\d+)", line)
                phases.append(dict(round=current_round, phase=m[1] if m else None,
                                   token=m[2] if m else None, local_t=int(m[3]) if m else None,
                                   text=line))
            elif line.startswith("A22 ROOM RECEIVE "):
                receive = json.loads(line[len("A22 ROOM RECEIVE "):])
                receives.append(dict(round=current_round, **select(receive, ("op", "from", "at", "ms", "barrier")),
                                     context=receive.get("context")))
            elif line.startswith("RConnectRoomTiming restore "):
                restore = json.loads(line[len("RConnectRoomTiming restore "):])
                restores.append(dict(round=current_round, **restore))
            elif line.startswith("COOP FAIL ") or "handoff timed out" in line:
                errors.append(dict(round=current_round, text=line))
        assert observed_rows == r["rows"], "wrapper/raw row mismatch"
        assert sha(log) == r["log_sha256"], "wrapper/raw log mismatch"
        rows = []
        for row in observed_rows:
            rows.append(dict(**select(row, ("round", "target", "elapsed", "controlResponseElapsed", "exitStart", "exitEnd", "cover", "paused", "x", "y", "key", "width", "height", "seed", "units", "actualMerged")),
                             common_clock_ready_ms=row["flagsReadyWall"] - row["requestedWall"],
                             input=input_check(row), raster=ticket_check(row)))
        output["roles"][role] = dict(checks=r["checks"], errors=errors,
            wrapper_errors=r["errors"], done=r["done"], rows=rows,
            requested_rounds=clocks, phases=phases, receives=receives,
            restore_timings=restores, raw_log_sha256=sha(log))
    if "join" in output["roles"]:
        joined = {r["round"]: r for r in output["roles"]["join"]["rows"]}
        pairs = []
        for h in output["roles"]["host"]["rows"]:
            j = joined.get(h["round"])
            if j is None:
                pairs.append(dict(round=h["round"], complete_pair=False,
                                  reason="join has no completed TRAVEL RESULT for this round"))
                continue
            distance = math.hypot(h["x"] - j["x"], h["y"] - j["y"])
            pairs.append(dict(round=h["round"], complete_pair=True, spawn_distance_px=distance, spawn_within_original_80px=distance <= 80,
                              exact_same_coordinates=distance == 0, same_room=h["key"] == j["key"],
                              same_dimensions=(h["width"], h["height"]) == (j["width"], j["height"]),
                              same_seed=h["seed"] == j["seed"],
                              actual_drawing_overlap_measured=False))
        output["completed_pairs"] = pairs
    output["three_flows_complete"] = all(len(r["rows"]) == 3 for r in output["roles"].values())
    output["performance_qualified"] = False
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dual", required=True)
    parser.add_argument("--solo")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result = dict(dual=audit_run(ROOT / args.dual))
    if args.solo:
        result["solo"] = audit_run(ROOT / args.solo)
        solo_rows = {r["round"]: r for r in result["solo"]["roles"]["host"]["rows"]}
        comparisons = []
        for role, r in result["dual"]["roles"].items():
            for row in r["rows"]:
                control = solo_rows.get(row["round"])
                if control is None:
                    continue
                comparisons.append(dict(role=role, round=row["round"], target=row["target"],
                    elapsed_delta_ms=row["elapsed"] - control["elapsed"],
                    common_clock_ready_delta_ms=row["common_clock_ready_ms"] - control["common_clock_ready_ms"],
                    control_response_delta_ms=row["controlResponseElapsed"] - control["controlResponseElapsed"],
                    elapsed_ratio=row["elapsed"] / control["elapsed"],
                    common_clock_ready_ratio=row["common_clock_ready_ms"] / control["common_clock_ready_ms"],
                    control_response_ratio=row["controlResponseElapsed"] / control["controlResponseElapsed"],
                    same_dimensions=(row["width"], row["height"]) == (control["width"], control["height"]),
                    same_seed=row["seed"] == control["seed"]))
        result["comparisons"] = comparisons
    result["source_audit_boundaries"] = [
        "Raster ticket creation/release/poll completion are not measured chunk draw start/end intervals.",
        "Failed trip lacks rasterProbe.finish output and therefore lacks final permit/ticket fields.",
        "Permit checked at begin, ticket creation and stable finish; continuous no-step coverage is not measured.",
        "Spawn comparison permits 80 px distance and observes local readiness, not the exact native spawn frame.",
        "Native Stage key dispatch and next-frame key-up consumption are covered; physical OS keyboard is not.",
        "Scene scenario covers shared first entry, base and cached revisit; ordinary split room and active/replay are separate.",
        "Rows report room readiness plus baseline/key response; no phase-aligned peer FPS or pixel equality qualification.",
    ]
    destination = Path(args.output).resolve()
    destination.relative_to(Path(__file__).resolve().parent)
    assert not destination.exists(), "preserve previous audit"
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(dict(output=str(destination), dual=result["dual"]["run"],
                         three_flows_complete=result["dual"]["three_flows_complete"],
                         solo=result.get("solo", {}).get("run"), performance_qualified=False), ensure_ascii=False))


if __name__ == "__main__":
    main()
