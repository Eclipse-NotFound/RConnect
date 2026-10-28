"""Summarize existing textmotion evidence; never launch or alter a runtime."""
import argparse
import hashlib
import json
import statistics
from pathlib import Path

STAGES = ["stationary", "walk-right", "walk-left", "walk-right-attack", "walk-left-attack"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stats(values):
    if not values:
        return None
    return {"count": len(values), "mean": statistics.mean(values), "min": min(values), "max": max(values)}


def summarize(directory):
    receipt = json.loads((directory / "result.json").read_text(encoding="utf-8-sig"))
    report = {
        "kind": "archived-textmotion-summary", "directory": str(directory.resolve()),
        "complete": receipt.get("complete"), "passed": receipt.get("passed"),
        "runtime_unchanged": receipt.get("runtime_unchanged"),
        "candidate_sha256": receipt.get("candidate_sha256"),
        "native_sha256": receipt.get("runtime_files", {}).get("pfe.swf"),
        "preparation_sha256": receipt.get("preparation_sha256"),
        "runner_sha256": receipt.get("runner_sha256"),
        "roles": {},
        "metric_definitions": {
            "render_mean_ms": "renderIntervalSumMS / renderIntervals; all de-duplicated observed renders, including pre-confirmation stage wait.",
            "render_p95_ms": "Only calculated if the complete raw renderIntervalsMs array is present; otherwise null.",
            "underflow_render_samples": "Valid observer samples where clock.next is null. Not PlaybackClock.underflows deltas.",
            "root_or_text_error_count": "Root error >0.11px / text error >0.16px against this process's already submitted recipe.",
            "root_or_text_max_error_px": "Join-local native final geometry minus submitted display recipe; does not validate PoseTween or host/join position latency. Host computes no such recipe difference.",
            "timeline_gap_max_px": "Absolute difference between latest received player X and displayed player X; distance, not milliseconds.",
            "socket_pending_max_bytes": "Maximum outgoing socket.bytesPending sampled at render. Not total traffic and not an unsampled burst maximum.",
            "duplicateRenders": "Observer callbacks discarded within the same ENTER_FRAME; not a count of duplicated product renders.",
            "trace_stats": "Throttled at least 35ms, requires a visible text effect, at most 1200 records; not every rendered frame."
        },
        "limits": [
            "Only the joining player receives walking controls; host observes that player's motion while its own camera stays still.",
            "Each stage lasts a short tick-bounded interval, with unequal host/join start-up coverage; this is not the 60-second sustained workload qualification.",
            "Root/text error checks test final local layout, not cross-process coordinate equality or end-to-end latency.",
            "The probe samples world/camera/screen reversal diagnostics after the first 18 host ticks of a walking stage.",
            "No new game/test was run to produce this report."
        ]
    }
    for role in ("host", "join"):
        source = directory / (role + "-text-motion-final.json")
        value = json.loads(source.read_text(encoding="utf-8-sig"))
        result = {"evidence_sha256": sha(source), "render_sampling": value["renderSampling"], "phases": {}}
        for stage in STAGES:
            m = value["phases"][stage]
            rows = [r for r in value["trace"] if r["stage"] == stage]
            intervals = m.get("renderIntervalsMs")
            if intervals is not None:
                assert len(intervals) == m["renderIntervals"]
                assert sum(intervals) == m["renderIntervalSumMS"]
                assert max(intervals) == m["renderIntervalMaxMS"]
            result["phases"][stage] = {
                "render_intervals": m["renderIntervals"], "render_span_ms": m["renderIntervalSumMS"],
                "render_mean_ms": m["renderIntervalSumMS"] / m["renderIntervals"],
                "render_max_ms": m["renderIntervalMaxMS"], "raw_intervals_available": intervals is not None,
                "render_p95_ms": sorted(intervals)[int(len(intervals) * .95)] if intervals else None,
                "observer_valid_samples": m["samples"], "interpolated_samples": m["interpolation"],
                "underflow_render_samples": m["underflow"],
                "reversals": {k: m[k] for k in ("worldReversals", "screenReversals", "cameraReversals", "unshakenCameraReversals")},
                "camera_target_mismatch_samples": m["cameraTargetMismatch"],
                "root_error_count": m["rootError"], "text_error_count": m["textError"],
                "root_max_error_px": m["rootMax"] if role == "join" else None,
                "text_max_error_px": m["textMax"] if role == "join" else None,
                "missing_text": m["missingText"], "missing_recipe": m["missingRecipe"],
                "timeline_gap_max_px": m["timelineGapMax"], "socket_pending_max_bytes": m["socketPendingMaxBytes"],
                "native_effect_observations": {k: m[k] for k in ("numb", "replic", "replic2")},
                "trace_stats": {key: stats([r[key] for r in rows if key in r])
                                for key in ("playerX", "delay", "predictionLead", "observedFrameAgeMS")}
            }
        report["roles"][role] = result
    if all(m.get("workload") == "both-walk-join-fire-v2"
           for role in ("host", "join")
           for m in json.loads((directory / (role + "-text-motion-final.json")).read_text(encoding="utf-8-sig"))["phases"].values()):
        report["limits"][0] = "Both players receive walking controls and move their own camera; only the joining player fires. Native X displacement assertions verify actual movement."
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    report = summarize(args.directory)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "passed": report["passed"], "phases": {
        role: {stage: {k: m[k] for k in ("render_mean_ms", "render_max_ms", "render_p95_ms", "underflow_render_samples")}
               for stage, m in result["phases"].items()} for role, result in report["roles"].items()}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
