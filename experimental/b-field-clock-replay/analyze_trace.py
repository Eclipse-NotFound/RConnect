"""Diagnose external B join-clock traces using only one process's timestamps.

Supports BClockTrace.writeTrace JSONL and the root driver's {header,rows,footer}
JSON envelope. Does not estimate network latency or alter the playback model.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
import hashlib
import json
import math
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[2]


class TraceError(ValueError):
    pass


def require(value, message):
    if not value:
        raise TraceError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def root_path(value):
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    require(path.is_relative_to(ROOT), "Trace path must remain inside RConnect")
    return path


def stats(values):
    if not values:
        return {"n": 0}
    require(all(finite(x) for x in values), "Nonfinite statistic")
    values = sorted(values)
    n = len(values)
    return {"n": n, "min": values[0], "mean": round(statistics.mean(values), 4),
            "median": round(statistics.median(values), 4),
            "p95": values[min(n - 1, int(n * .95))], "max": values[-1]}


def decode(text):
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        lines = [json.loads(line) for line in text.splitlines() if line.strip()]
        require(len(lines) >= 2, "Incomplete JSONL trace")
        value = {"header": lines[0], "rows": lines[1:-1], "footer": lines[-1]}
    require(isinstance(value, dict) and all(k in value for k in ("header", "rows", "footer")),
            "Trace is neither a BClockTrace envelope nor JSONL")
    return value


def key(frame):
    require(isinstance(frame, dict) and finite(frame.get("time")) and finite(frame.get("tick")),
            "Missing source frame time/tick")
    # Presentation IDs were not captured by the first external helper. Same
    # tick/time can occur during paused publications; match these in FIFO order,
    # never overwrite one in a dictionary keyed only by source tick.
    players = tuple((p.get("epoch"), p.get("roomEpoch")) for p in frame.get("players", []))
    control = frame.get("timeControl")
    return (frame["tick"], frame["time"], frame.get("room"), frame.get("pauseEpoch"),
            frame.get("paused") is True, players,
            None if control is None else (control.get("phase"), control.get("cycle")))


def same_active_epoch(a, b):
    aa, bb = key(a), key(b)
    return not a.get("paused") and not b.get("paused") and aa[2:] == bb[2:]


def analyze(payload):
    header, rows, footer = payload["header"], payload["rows"], payload["footer"]
    require(header.get("schema") == "rconnect-b-clock-trace-1" and header.get("role") == "join", "Wrong trace schema or role")
    require(header.get("kind") == "header" and footer.get("kind") == "footer", "Missing header/footer")
    require(isinstance(rows, list) and len(rows) + 2 <= 20000, "Trace row limit exceeded")
    require(footer.get("recordedRows") == len(rows), "Footer row count differs")
    require(finite(header.get("at")) and finite(footer.get("at")), "Invalid collection times")
    for index, row in enumerate(rows, 1):
        require(row.get("seq") == index and finite(row.get("at")), "Non-contiguous sequence or invalid timestamp")
        require(row["kind"] in ("arrival", "confirmed", "screen", "mark"), "Unsupported trace record")
    require(all(b["at"] >= a["at"] for a, b in zip(rows, rows[1:])), "Join-process time reversed")

    quality, pairing_notes = [], []
    reason = footer.get("reason")
    if reason == "scenario completed":
        stop_status = "scenario_completed"
    elif reason in ("caller stopped", "caller wrote trace"):
        stop_status = "caller_stopped_without_scene_completion_evidence"
    elif reason == "another owner replaced a diagnostic callback":
        stop_status = "callback_ownership_lost"
    elif reason == "session/link/replica identity changed":
        stop_status = "identity_changed"
    elif reason == "trace row limit reached":
        stop_status = "row_limit_reached"
    else:
        stop_status = "unspecified_or_unrecognized"
    stopped_normally = stop_status == "scenario_completed"
    if not stopped_normally:
        quality.append("Collector did not report scene completion: " + str(reason))
    if not header.get("completeHistory"):
        quality.append("Capture started after initial private clock history; exact replay is not possible")
    for field in ("truncated", "faults", "arrivalAnomalies", "unpairedScreens", "pendingDelivery", "pendingScreen"):
        if footer.get(field):
            quality.append("Collector reported " + field + "=" + str(footer[field]))
    arrivals, pending, matched, unmatched, skipped = [], deque(), [], [], []
    screens, marks, rejected = [], [], 0
    all_confirmations = 0
    for row in rows:
        if row["kind"] == "arrival":
            if row.get("complete") is not True or row.get("queueAccounting") is not True:
                pairing_notes.append(f"Arrival {row['seq']} has incomplete queue accounting")
            require(all(finite(row.get(k)) for k in ("forwardAt", "returnAt")), "Unusable arrival time bracket")
            require(row["at"] <= row["forwardAt"] <= row["returnAt"], "Invalid arrival time bracket")
            if not row.get("accepted"):
                rejected += 1
                continue
            require(row.get("acceptedCount") == 1, "Cannot pair a callback accepting more than one frame")
            key(row["frame"])
            arrivals.append(row)
            pending.append(row)
        elif row["kind"] == "confirmed":
            all_confirmations += 1
            wanted = key(row.get("frame"))
            if not pending or key(pending[0]["frame"]) != wanted:
                index = next((i for i, arrival in enumerate(pending) if key(arrival["frame"]) == wanted), -1)
                if index < 0:
                    unmatched.append({"seq": row["seq"], "tick": row["frame"]["tick"], "time": row["frame"]["time"]})
                    continue
                # Keep evidence of the gap instead of silently pairing forward.
                for _ in range(index):
                    missing = pending.popleft()
                    skipped.append({"seq": missing["seq"], "tick": missing["frame"]["tick"], "time": missing["frame"]["time"]})
            arrival = pending.popleft()
            require(row["at"] >= arrival["forwardAt"], "Confirmation precedes its own original receive call")
            mode = "delivery_flush" if row.get("arrivalSeq") is not None else "screen" if row.get("screenSeq") is not None else "unattributed"
            matched.append({"arrival_seq": arrival["seq"], "confirmation_seq": row["seq"],
                            "arrival_at": arrival["at"], "confirmed_at": row["at"],
                            "tick": row["frame"]["tick"], "source_time": row["frame"]["time"],
                            "mode": mode, "entry_to_confirm_ms": row["at"] - arrival["at"],
                            "return_to_confirm_signed_ms": row["at"] - arrival["returnAt"],
                            "push_to_confirm_lower_ms": max(0, row["at"] - arrival["returnAt"]),
                            "push_to_confirm_upper_ms": row["at"] - arrival["forwardAt"],
                            "receive_callback_ms": arrival["returnAt"] - arrival["forwardAt"],
                            "projectile_events": row["frame"].get("projectileEventCount", 0),
                            "projectile_count": row["frame"].get("projectileCount", 0),
                            "terrain_revision": row["frame"].get("terrainRevision")})
        elif row["kind"] == "screen":
            if row.get("complete") is not True:
                quality.append(f"Screen bracket {row['seq']} has no end")
                continue
            require(finite(row.get("endAt")) and row["endAt"] >= row["at"], "Invalid screen bracket")
            screens.append(row)
        elif row["kind"] == "mark":
            marks.append({"seq": row["seq"], "at": row["at"], "label": row.get("label")})

    if unmatched:
        pairing_notes.append(f"{len(unmatched)} confirmations had no captured matching arrival (possibly pre-capture pending state)")
    if skipped:
        pairing_notes.append(f"{len(skipped)} captured arrivals were skipped before a later matching confirmation; inspect trace")
    if footer.get("acceptedFrames") != len(arrivals) or footer.get("confirmations") != all_confirmations:
        pairing_notes.append("Collector totals differ from recorded accepted/confirmed rows; collected prefix may be truncated")
    if any(x["mode"] == "unattributed" for x in matched):
        pairing_notes.append("Some confirmations were outside both observed delivery and screen contexts")
    require(all(b["frame"]["time"] >= a["frame"]["time"] for a, b in zip(arrivals, arrivals[1:])),
            "Accepted source time reversed")
    require(all(b["source_time"] >= a["source_time"] for a, b in zip(matched, matched[1:])),
            "Confirmed source time reversed")

    source_gaps, arrival_gaps, active_source, active_arrival = [], [], [], []
    ignored = Counter()
    changed_terrain_arrivals = set()
    for a, b in zip(arrivals, arrivals[1:]):
        source_gap, arrival_gap = b["frame"]["time"] - a["frame"]["time"], b["at"] - a["at"]
        source_gaps.append(source_gap)
        arrival_gaps.append(arrival_gap)
        if same_active_epoch(a["frame"], b["frame"]):
            if 0 < source_gap <= 1000:
                active_source.append(source_gap)
                active_arrival.append(arrival_gap)
            else:
                ignored["equal_source_time" if source_gap == 0 else "source_gap_over_1000ms"] += 1
        else:
            ignored["paused_or_identity_phase_boundary"] += 1
        # A revision change may cover many terrain mutations. It is not proof
        # of a particular wall destruction or an identified weapon event.
        if (key(a["frame"])[2:] == key(b["frame"])[2:] and
                a["frame"].get("terrainRevision") != b["frame"].get("terrainRevision")):
            changed_terrain_arrivals.add(b["seq"])

    def waits(items):
        return {"entry_to_confirm_ms": stats([x["entry_to_confirm_ms"] for x in items]),
                "return_to_confirm_signed_ms": stats([x["return_to_confirm_signed_ms"] for x in items]),
                "push_to_confirm_lower_ms": stats([x["push_to_confirm_lower_ms"] for x in items]),
                "push_to_confirm_upper_ms": stats([x["push_to_confirm_upper_ms"] for x in items])}

    windows = defaultdict(list)
    for item in matched:
        windows[int((item["arrival_at"] - header["at"]) / 10000)].append(item)
    time_windows = [{"from_ms": w * 10000, "to_ms": (w + 1) * 10000,
                     "matched": len(items), **waits(items)} for w, items in sorted(windows.items())]
    clock_points = []
    for row in arrivals + screens:
        for which in ("clockBefore", "clockAfter"):
            point = row.get(which)
            if isinstance(point, dict):
                clock_points.append(point)
    underflow_samples = []
    for row in screens:
        before, after = row["clockBefore"], row["clockAfter"]
        require(all(finite(before.get(k)) and finite(after.get(k)) for k in ("underflows", "position", "queued", "delay")),
                "Screen clock sample missing numeric values")
        require(after["underflows"] >= before["underflows"] and after["position"] >= before["position"],
                "Clock changed backwards inside a screen bracket")
        underflow_samples.append(after["underflows"] - before["underflows"])
    coincident = Counter(row["at"] for row in arrivals)
    initial, final = header.get("initialClock", {}), footer.get("finalClock", {}) or {}
    require(finite(initial.get("underflows")) and finite(final.get("underflows")), "Missing initial/final clock counter")
    underflow_total = final["underflows"] - initial["underflows"]
    require(finite(underflow_total) and underflow_total >= 0, "Invalid cumulative underflow count")
    # The helper's footer() reads live state when data() is exported, which may
    # happen long after stop(). Do not attribute later clock counters to the
    # captured interval, or misdiagnose later received states as network loss.
    footer_beyond_history = False
    final_frame = footer.get("finalFrame")
    if final_frame is not None:
        footer_beyond_history = not arrivals or key(final_frame) != key(arrivals[-1]["frame"])
    if arrivals:
        last_source = arrivals[-1]["frame"]["time"]
        footer_beyond_history |= any(finite(final.get(field)) and final[field] > last_source
                                     for field in ("position", "currentTime", "nextTime"))
    if footer_beyond_history:
        quality.append("Footer live state lies beyond captured arrivals; its cumulative counters are not scoped to this collection")
    initial_pairs = [item for item in matched if item["tick"] == 0]
    later_pairs = [item for item in matched if item["tick"] > 0]
    event_pairs = [item for item in matched if item["projectile_events"] > 0]
    terrain_pairs = [item for item in matched if item["arrival_seq"] in changed_terrain_arrivals]
    coverage_notes = []
    if not stopped_normally or any(footer.get(k) for k in ("truncated", "faults", "pendingDelivery", "pendingScreen")):
        coverage_notes.append("Capture did not complete cleanly through the scenario end")
    if len(arrivals) < 2 or not active_source:
        coverage_notes.append("Insufficient accepted active frame sequence to characterize scene cadence")
    if not later_pairs:
        coverage_notes.append("No post-initialization confirmation was captured; tick-zero loading is not combat latency")
    if not event_pairs and not terrain_pairs:
        coverage_notes.append("No matched projectile event or terrain revision change was captured; event-scene coverage is insufficient")
    event_notes = []
    if not event_pairs:
        event_notes.append("No matched projectile-event frame was captured; no projectile-event waiting sample is available")
    if not terrain_pairs:
        event_notes.append("No matched same-identity terrain revision change was captured; no wall-change waiting sample is available")
    quality.extend(pairing_notes)
    quality.extend(coverage_notes)
    quality.extend(event_notes)
    coverage = {"status": "insufficient" if coverage_notes else "aggregate_events_observed_full_scene_unverified",
                "full_scene_coverage_established": False,
                "collector_reported_scenario_completed": stopped_normally,
                "initial_tick_zero_pairs": len(initial_pairs), "post_initial_pairs": len(later_pairs),
                "matched_projectile_event_frames": len(event_pairs),
                "matched_terrain_revision_change_frames": len(terrain_pairs),
                "supports_observed_projectile_event_waits": not pairing_notes and bool(event_pairs),
                "supports_observed_terrain_revision_waits": not pairing_notes and bool(terrain_pairs),
                "supports_weapon_specific_latency": False,
                "notes": coverage_notes + event_notes + ["Current format has no per-weapon identity/lifecycle coverage contract; a normal stop alone cannot prove a full weapon scenario"]}
    return {"schema": "rconnect-b-clock-diagnostic-2", "valid_structure": True,
            "complete_history": header.get("completeHistory") is True,
            "clean_pairing": not pairing_notes, "pairing_valid": not pairing_notes,
            "pairing_quality_notes": pairing_notes, "quality_notes": list(dict.fromkeys(quality)),
            "termination": {"reason": reason, "status": stop_status,
                            "collector_reported_scenario_completed": stopped_normally},
            "scene_coverage": coverage,
            "footer_state_within_captured_history": not footer_beyond_history,
            "metric_scope": "Captured matching pairs only; not a complete scene or weapon latency claim",
            "build_label": header.get("build"), "session": header.get("session"),
            "collection_ms": footer["at"] - header["at"],
            "counts": {"accepted_arrivals": len(arrivals), "rejected_frame_messages": rejected,
                       "confirmations": all_confirmations, "matched": len(matched),
                       "unmatched_confirmations": len(unmatched), "skipped_captured_arrivals": len(skipped),
                       "tail_arrivals_not_yet_confirmed": len(pending), "screen_brackets": len(screens)},
            "waits": {"all": waits(matched),
                      "initial_tick_zero": waits(initial_pairs),
                      "post_initial": waits(later_pairs),
                      "screen": waits([x for x in matched if x["mode"] == "screen"]),
                      "delivery_flush": waits([x for x in matched if x["mode"] == "delivery_flush"]),
                      "with_projectile_events": waits([x for x in matched if x["projectile_events"] > 0]),
                      "terrain_revision_changed": waits([x for x in matched if x["arrival_seq"] in changed_terrain_arrivals])},
            "cadence": {"source_gap_all_ms": stats(source_gaps), "callback_entry_gap_all_ms": stats(arrival_gaps),
                        "active_same_epoch_source_gap_ms": stats(active_source),
                        "active_same_epoch_callback_gap_ms": stats(active_arrival), "excluded_from_estimator": dict(ignored),
                        "maximum_callback_entries_in_one_ms": max(coincident.values(), default=0)},
            "application_callback_ms": stats([x["returnAt"] - x["forwardAt"] for x in arrivals]),
            "screen_bracket_ms": stats([x["endAt"] - x["at"] for x in screens]),
            "screen_start_gap_ms": stats([b["at"] - a["at"] for a, b in zip(screens, screens[1:])]),
            "clock": {"sampled_delay_ms": stats([p["delay"] for p in clock_points]),
                      "sampled_queued": stats([p["queued"] for p in clock_points]),
                      "underflow_counter_delta": None if footer_beyond_history else underflow_total,
                      "footer_underflow_counter_delta_unscoped": underflow_total if footer_beyond_history else None,
                      "underflow_in_screen_brackets": sum(underflow_samples),
                      "screens_with_underflow_increment": sum(x > 0 for x in underflow_samples),
                      "final_queued": final.get("queued")},
            "windows": time_windows, "slowest_matched": sorted(matched, key=lambda x: x["entry_to_confirm_ms"], reverse=True)[:12],
            "unmatched_confirmation_examples": unmatched[:12], "skipped_arrival_examples": skipped[:12], "marks": marks,
            "observer_ms_quantized": footer.get("observerMs"),
            "interpretation": [
                "All arrival/confirmation/screen times use the same join-process getTimer.",
                "Arrival starts after WireCodec.decode and before the original receive callback; it is not socket byte arrival.",
                "Entry-to-confirm includes decode, queueing, render and observer overhead; it is not pure buffer or network latency.",
                "Push-to-confirm values are lower/upper bounds because internal push/take times are not exposed.",
                "Negative return-to-confirm is normal when a boundary flush confirms before the receive callback returns.",
                "Underflow is the existing take counter with no next state, including flush cases; it is not a dropped-packet count.",
                "A pending tail at collection end is censored evidence, not proof of event loss.",
                "Valid captured-pair matching does not establish normal capture termination or representative scene coverage.",
                "Tick-zero loading waits are separated from post-initialization samples; neither is automatically a weapon event.",
                "This script neither replays candidate clock algorithms nor grants runtime/performance/deployment qualification."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--receipt", help="Optional same-run result.json, recorded as contextual evidence only")
    args = parser.parse_args()
    destination = root_path(args.out)
    require(not destination.exists() and destination.parent.is_dir(), "Output needs a new file in an existing directory")
    path = root_path(args.input)
    require(path.stat().st_size <= 64 * 1024 * 1024, "Trace exceeds bounded input size")
    raw = path.read_bytes()
    result = analyze(decode(raw.decode("utf-8-sig")))
    result["input"] = {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
    result["analyzer_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    if args.receipt:
        receipt_path = root_path(args.receipt)
        receipt_bytes = receipt_path.read_bytes()
        receipt = json.loads(receipt_bytes.decode("utf-8-sig"))
        result["contextual_receipt"] = {"path": str(receipt_path), "sha256": hashlib.sha256(receipt_bytes).hexdigest(),
                                        "candidate_sha256": receipt.get("candidate_sha256"),
                                        "native_sha256": receipt.get("native_sha256"), "scenario": receipt.get("scenario"),
                                        "note": "Recorded context; this analyzer does not requalify the entire runtime receipt"}
    with destination.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"output": str(destination), "clean_pairing": result["clean_pairing"], "counts": result["counts"],
                      "termination": result["termination"], "scene_coverage": result["scene_coverage"],
                      "observed_pairs_entry_to_confirm_ms": result["waits"]["all"]["entry_to_confirm_ms"],
                      "notes": result["quality_notes"]}, ensure_ascii=False))
    return 0 if result["clean_pairing"] and not result["quality_notes"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (TraceError, ValueError, TypeError, KeyError, OSError) as error:
        print(json.dumps({"valid_structure": False, "error": str(error)}, ensure_ascii=False))
        raise SystemExit(2)
