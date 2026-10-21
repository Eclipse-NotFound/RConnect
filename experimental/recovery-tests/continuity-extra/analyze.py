"""Summarize final-RENDER flight traces; no AIR/build and no performance pass.

This is additional evidence, not a replacement for the unified runner's exact
binary binding, 22 installed fingerprints, both roles' versions/all-mod logs.
"""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

EXPECTED = (("lmg", "host"), ("lmg", "join"), ("quick", "host"),
            ("quick", "join"), ("plamg", "host"), ("plamg", "join"),
            ("alilight", "host"), ("alilight", "host"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path, role):
    text = path.read_text(encoding="utf-8-sig", errors="strict")
    sources, remotes, failures, duplicates = {}, {}, [], []
    for line in text.splitlines():
        if "COOP FAIL " in line:
            failures.append(line)
        for marker, target in (("FLIGHT SOURCE TRACE ", sources),
                               ("FLIGHT REMOTE TRACE ", remotes)):
            if marker not in line:
                continue
            payload = json.loads(line.split(marker, 1)[1])
            key = int(payload["round"])
            if key in target:
                duplicates.append(f"{role} {marker.strip()} {key}")
            if payload["role"] != role:
                raise ValueError(f"Log role disagrees with trace: {role}, {key}")
            target[key] = payload
    return dict(source=sources, remote=remotes, failures=failures, duplicates=duplicates,
                done=f"COOP EFFECTS DONE native-flight-continuity {role}" in text)


def distance(a, b):
    return math.hypot(float(b["x"]) - float(a["x"]), float(b["y"]) - float(a["y"]))


def metadata_equal(a, b, path="$", roundtrips=None):
    """Strict shape/types; permit at most ONE finite nonintegral binary64 ULP.

    Timestamps/IDs represented as integers, booleans and signed zero remain
    exact. This is solely AIR JSON decimal roundtrip evidence, not a spatial
    tolerance, and never applies to trajectory/pixel/continuity assertions.
    """
    if roundtrips is None:
        roundtrips = []
    if type(a) is bool or type(b) is bool:
        return type(a) is type(b) and a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        if not math.isfinite(a) or not math.isfinite(b):
            return False
        if a == b:
            return a != 0 or math.copysign(1, a) == math.copysign(1, b)
        if float(a).is_integer() or float(b).is_integer():
            return False
        def ordered(value):
            bits = struct.unpack(">Q", struct.pack(">d", float(value)))[0]
            return (~bits & ((1 << 64) - 1)) if bits >> 63 else bits | (1 << 63)
        ulps = abs(ordered(a) - ordered(b))
        if ulps > 1:
            return False
        roundtrips.append(dict(path=path, source=a, remote=b, ulps=ulps))
        return True
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(metadata_equal(a[k], b[k], path + "." + k, roundtrips) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(metadata_equal(x, y, f"{path}[{i}]", roundtrips) for i, (x, y) in enumerate(zip(a, b)))
    return a == b


def visible(rows):
    return [dict(row["clips"][0], at=row["at"], wall=row["wall"], frame=row["frame"],
                 render=row["render"]) for row in rows if row["clips"]]


def summarize(rows):
    points = visible(rows)
    gaps, all_gaps, hold, max_hold, moves, frame_hold, max_frame_hold, changes = [], [], 0, 0, 0, 0, 0, 0
    for a, b in zip(rows, rows[1:]):
        all_gaps.append(b["at"] - a["at"])
    for a, b in zip(points, points[1:]):
        dt = b["at"] - a["at"]
        gaps.append(dt)
        if distance(a, b) <= .25:
            hold += dt
        else:
            hold = 0
            moves += 1
        max_hold = max(max_hold, hold)
        if a["f"] == b["f"]:
            frame_hold += dt
        else:
            frame_hold = 0
            changes += 1
        max_frame_hold = max(max_frame_hold, frame_hold)
    ordered = sorted(gaps)
    return dict(samples=len(points), moves=moves,
                visible_game_frames=len({p["frame"] for p in points}),
                peak=max((len(row["clips"]) for row in rows), default=0),
                max_hold_ms=max_hold, max_visible_gap_ms=max(gaps, default=0),
                p95_visible_gap_ms=ordered[min(len(ordered) - 1, int(len(ordered) * .95))] if ordered else 0,
                max_recorded_render_gap_ms=max(all_gaps, default=0),
                monotonic=all(gap >= 0 for gap in all_gaps),
                unique_render_frames=len({row["frame"] for row in rows}),
                offscreen=sum(not p["viewport"] for p in points),
                animation_changes=changes, max_animation_hold_ms=max_frame_hold,
                first=points[0] if points else None, last=points[-1] if points else None,
                visible_duration_ms=points[-1]["at"] - points[0]["at"] if points else 0,
                pixel_probes=[row["probe"] for row in rows if "probe" in row],
                contact_pixel_probes=[row["contactProbe"] for row in rows if "contactProbe" in row])


def contact_of(source):
    if source.get("contact") is not None:
        return source["contact"]
    # Diagnose older evidence without rewriting it or claiming missing probes.
    row = next((row for row in source["frames"] if row.get("native", {}).get("ended")), None)
    return dict(at=row["at"], wall=row["wall"], x=row["native"]["x"], y=row["native"]["y"]) if row else None


def segments(rows, contact):
    first = next((i for i, row in enumerate(rows) if row["clips"] and contact is not None
                  and distance(row["clips"][0], contact) <= .25), None)
    last = max((i for i, row in enumerate(rows) if row["clips"]), default=-1)
    return (rows, []) if first is None else (rows[:first + 1], rows[first:last + 1])


def phase_timings(trace):
    phases = trace.get("phases", [])
    by_name = {row["name"]: row for row in phases}
    pairs = (("prepare-enter", "prepare-complete"), ("prepare-complete", "armed"),
             ("armed", "first-active-enter"), ("armed", "first-active-render"),
             ("armed", "native-shot"), ("armed", "first-production-flight-received"),
             ("first-production-flight-received", "first-visible-render"),
             ("contact-received", "first-contact-render"))
    return dict(available=bool(phases), raw=phases,
                elapsed_ms={f"{a}->{b}": by_name[b]["at"] - by_name[a]["at"]
                            for a, b in pairs if a in by_name and b in by_name})


def evaluate(source, remote):
    sr, rr = source["frames"], remote["frames"]
    sp, rp = visible(sr), visible(rr)
    ss, rs = summarize(sr), summarize(rr)
    contact = contact_of(source)
    sf_rows, sc_rows = segments(sr, contact)
    rf_rows, rc_rows = segments(rr, contact)
    sf, sc, rf, rc = map(summarize, (sf_rows, sc_rows, rf_rows, rc_rows))
    native = source["info"]
    path = [dict(x=native["begx"], y=native["begy"])] + sp + [source["end"]]
    arc = [0.0]
    for a, b in zip(path, path[1:]):
        arc.append(arc[-1] + distance(a, b))
    max_step = max((b - a for a, b in zip(arc, arc[1:])), default=0)
    errors, progresses = [], []
    for p in rp:
        nearest = (math.inf, 0.0)
        for index, (a, b) in enumerate(zip(path, path[1:])):
            dx, dy = b["x"] - a["x"], b["y"] - a["y"]
            square = dx * dx + dy * dy
            ratio = max(0., min(1., ((p["x"] - a["x"]) * dx + (p["y"] - a["y"]) * dy) / square)) if square else 0.
            error = math.hypot(p["x"] - a["x"] - dx * ratio, p["y"] - a["y"] - dy * ratio)
            if error < nearest[0]:
                nearest = error, arc[index] + math.sqrt(square) * ratio
        errors.append(nearest[0])
        progresses.append(nearest[1])
    tail = max(0., arc[-1] - max(progresses, default=0.))
    coverage = (max(progresses) - min(progresses)) / arc[-1] if progresses and arc[-1] else 0.
    reverse = sum(b < a - 1 for a, b in zip(progresses, progresses[1:]))
    gap_limit = max(85., ss["p95_visible_gap_ms"] * 1.5 + 15)
    source_pixels = source["meta"].get("pixelProof") or {}
    remote_pixels = remote["result"].get("pixelProof") or {}
    source_contact_pixels = source["meta"].get("contactProof") or {}
    remote_contact_pixels = remote["result"].get("contactProof") or {}
    sc_points, rc_points = visible(sc_rows), visible(rc_rows)
    source_contact_frames = {p["f"] for p in sc_points}
    roundtrips = []
    same_metadata = metadata_equal(source["info"], remote["info"], "$.info", roundtrips) and metadata_equal(source["end"], remote["end"], "$.end", roundtrips)
    if "contact" in source or "contact" in remote:
        same_metadata = same_metadata and metadata_equal(source.get("contact"), remote.get("contact"), "$.contact", roundtrips)
    checks = {
        "one_native_shot": source["meta"]["shotCount"] == 1,
        "source_pixels": source_pixels.get("pixels", 0) > 0,
        "remote_pixels": remote_pixels.get("pixels", 0) > 0,
        "enough_real_samples": ss["samples"] >= 3 and rs["samples"] >= 3
            and ss["visible_game_frames"] >= 3 and rs["visible_game_frames"] >= 3,
        "monotonic_render_clock": ss["monotonic"] and rs["monotonic"],
        "one_remote_clip": rs["peak"] == 1,
        "no_reversed_progress": reverse == 0,
        "all_remote_samples_in_viewport": rs["offscreen"] == 0,
        "source_path_error_3px": bool(errors) and max(errors) <= 3,
        "moves_without_85ms_position_stall": rf["moves"] >= 2 and rf["max_hold_ms"] <= 85,
        "final_render_gap_relative_to_source": bool(rp) and rs["max_visible_gap_ms"] <= gap_limit,
        "visible_tail_coverage": bool(arc[-1]) and coverage >= .65 and tail <= max(20, max_step * 1.1),
        "removed_after_native_end": bool(rp) and bool(rr) and rr[-1]["wall"] - rp[-1]["wall"] >= 500,
        "both_sides_same_native_metadata": same_metadata,
        "contact_tail_pixels": contact is not None and source_contact_pixels.get("pixels", 0) > 0 and remote_contact_pixels.get("pixels", 0) > 0,
        "contact_tail_native_position_frame_duration": len({p["frame"] for p in rc_points}) >= 2
            and all(distance(p, contact) <= .25 and p["f"] in source_contact_frames for p in rc_points)
            and abs(rc["visible_duration_ms"] - sc["visible_duration_ms"]) <= gap_limit,
    }
    if sf["animation_changes"] >= 2:
        checks["animated_native_clip_advances"] = rf["animation_changes"] >= 1 and rf["max_animation_hold_ms"] <= sf["max_animation_hold_ms"] * 1.5 + 85
    if sc["animation_changes"] >= 2:
        checks["animated_native_contact_advances"] = rc["animation_changes"] >= 1 and rc["max_animation_hold_ms"] <= sc["max_animation_hold_ms"] * 1.5 + 85
    return dict(checks=checks, sampled_flight_checks_passed=all(checks.values()), source=ss, remote=rs,
                source_flight=sf, remote_flight=rf, source_contact=sc, remote_contact=rc, native_contact=contact,
                metadata_roundtrip_ulps=roundtrips,
                phase_timings=dict(source=phase_timings(source), remote=phase_timings(remote)),
                passive_wire_receipts=remote.get("wire", []),
                source_path_length=arc[-1], max_native_step=max_step,
                max_path_error=max(errors) if errors else None, tail_gap=tail, coverage=coverage,
                reversed_steps=reverse, allowed_visible_render_gap_ms=gap_limit,
                start_lag_ms=rp[0]["wall"] - sp[0]["wall"] if rp and sp else None,
                last_visible_vs_native_end_ms=rp[-1]["wall"] - source["end"]["wall"] if rp else None,
                source_end=source["end"], native_shot=native)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host-log", type=Path, required=True)
    parser.add_argument("--join-log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="New JSON file; never overwrite evidence")
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Output already exists; choose a new file")
    logs = {role: load(path, role) for role, path in (("host", args.host_log), ("join", args.join_log))}
    cases, missing = [], []
    for number, (weapon, source_role) in enumerate(EXPECTED):
        remote_role = "join" if source_role == "host" else "host"
        source = logs[source_role]["source"].get(number)
        remote = logs[remote_role]["remote"].get(number)
        if not source or not remote:
            missing.append(dict(round=number, source_missing=not source, remote_missing=not remote))
            continue
        result = evaluate(source, remote)
        result["checks"]["expected_weapon"] = source["info"]["weapon"] == weapon
        result["sampled_flight_checks_passed"] = all(result["checks"].values())
        cases.append(dict(round=number, source_role=source_role, remote_role=remote_role, weapon=weapon, **result))
    log_failures = [item for values in logs.values() for item in values["failures"]]
    duplicates = [item for values in logs.values() for item in values["duplicates"]]
    done = all(values["done"] for values in logs.values())
    unexpected = [f"{role}/{kind}/{number}" for role, values in logs.items() for kind in ("source", "remote")
                  for number in values[kind] if number not in range(len(EXPECTED))]
    result = dict(kind="real-native-final-render-flight-samples", functional_only=True, performance_qualified=False,
                  dense_fire_qualified=False, wall_clock_scope="same-machine paired isolated processes",
                  expected_cases=len(EXPECTED), missing=missing, duplicates=duplicates, unexpected=unexpected,
                  both_roles_done=done, coop_failures=log_failures, cases=cases,
                  sampled_flight_checks_passed=not (missing or duplicates or unexpected or log_failures) and done
                  and len(cases) == len(EXPECTED) and all(c["sampled_flight_checks_passed"] for c in cases),
                  inputs={str(p.resolve()): digest(p) for p in (args.host_log, args.join_log, Path(__file__))})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
    print(json.dumps(dict(output=str(args.output.resolve()), sampled_flight_checks_passed=result["sampled_flight_checks_passed"],
                          cases=len(cases), missing=len(missing), performance_qualified=False), ensure_ascii=False))
    return 0 if result["sampled_flight_checks_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
