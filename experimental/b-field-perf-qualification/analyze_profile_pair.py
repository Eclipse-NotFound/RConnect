"""Read-only analysis of the two retained profile runs; never qualification."""
import hashlib
import json
from pathlib import Path
import statistics

import qualify as q

EPOCH = 116444736000000000


def distribution(values):
    return {"min": min(values), "mean": statistics.mean(values), "max": max(values)} if values else None


def analyze(kind, plan):
    directory = q.ROOT / ("build/ab/b-field21-profile-" + kind + "-01")
    cpu_path = q.ROOT / ("experimental/b-field-perf-qualification/profile-" + kind + "-01-cpu.json")
    cpu, receipt = q.read(cpu_path), q.read(directory / "result.json")
    expected = plan["groups"][kind]
    assert receipt["complete"] and receipt["passed"] and receipt["profile"] is True
    assert receipt["candidate_sha256"] == expected["candidate_sha256"]
    assert receipt["candidate_source"] == expected["source_id"]
    assert receipt["native_sha256"] == expected["native_sha256"]
    assert cpu["original_receipt_sha256"] == q.sha(directory / "result.json")
    assert cpu["runner_unchanged"] and cpu["runner_sha256"] == plan["runner"]["sha256"]
    assert not cpu["errors"] and not cpu["truncated"] and not cpu["rejected_roles"]
    rows = []
    for role in ("host", "join"):
        log_path = directory / role / "ABBench.log"
        log = q.log_events(log_path)
        assert log[-1]["kind"] == "done"
        assert [x["data"] for x in log if x["kind"] == "result"] == receipt["roles"][role]["results"]
        ident = cpu["identities"][role]
        assert ident["pid"] == receipt["roles"][role]["pid"] and ident["appid"] == receipt["roles"][role]["appid"]
        # VM getTimer starts during this process lifetime. The preserved last
        # log-write time occurs after its final getTimer timestamp. These bound
        # the origin instead of pretending process creation IS timer zero.
        origin_low = (ident["creation_100ns"] - EPOCH) / 1e7
        origin_high = log_path.stat().st_mtime - log[-1]["at"] / 1000
        assert 0 <= origin_high - origin_low < 2
        process = [x["roles"][role] for x in cpu["samples"] if role in x["roles"]]
        phases = {}
        active = None
        for event in log:
            if event["kind"] == "measure-begin":
                active = {"begin_at": event["at"], "samples": []}
                phases[event["data"]["phase"]] = active
            elif event["kind"] == "sample" and active is not None:
                active["samples"].append(event)
            elif event["kind"] == "result":
                active["result_at"] = event["at"]
                active = None
        for value in receipt["roles"][role]["results"]:
            phase, samples = value["phase"], value["samples"]
            evidence = phases[phase]
            assert [s["data"] for s in evidence["samples"]] == samples
            pre_end = [s for s in evidence["samples"] if s["data"]["ms"] < value["elapsed"]]
            # A logged sample in a strictly earlier ENTER_FRAME precedes the
            # final measured frame. Avoid the result serialization's wall time.
            safe_start = origin_high + evidence["begin_at"] / 1000
            safe_end = origin_low + pre_end[-1]["at"] / 1000
            intervals = [(a, b) for a, b in zip(process, process[1:])
                         if safe_start <= a["wall_time"] and b["wall_time"] <= safe_end]
            assert intervals
            duration = sum((b["monotonic_ns"] - a["monotonic_ns"]) / 1e6 for a, b in intervals)
            user_ms = sum(b["user_100ns"] - a["user_100ns"] for a, b in intervals) / 10000
            kernel_ms = sum(b["kernel_100ns"] - a["kernel_100ns"] for a, b in intervals) / 10000
            drift = max(abs((b["wall_time"] - a["wall_time"]) * 1000 -
                            (b["monotonic_ns"] - a["monotonic_ns"]) / 1e6) for a, b in intervals)
            machine = [x["machine"] for x in cpu["samples"] if "machine" in x]
            system_ticks = [0, 0, 0]
            for a, b in zip(machine, machine[1:]):
                if safe_start <= a["time"] and b["time"] <= safe_end:
                    system_ticks = [total + new - old for total, new, old in zip(system_ticks, b["cpuTicks"], a["cpuTicks"])]
            idle, kernel, user = system_ticks
            clocks = {name: distribution([s[name] for s in samples]) for name in ("queued", "delay") if name in samples[0]}
            if "underflows" in samples[0]:
                clocks["underflow_delta_between_samples"] = samples[-1]["underflows"] - samples[0]["underflows"]
            shots = [[s["shots"][i] - samples[0]["shots"][i] for i in (0, 1)] for s in samples]
            windows = []
            if role == "host":
                for index in range(6):
                    subset = [s for s in samples if index * 10000 <= s["ms"] < (index + 1) * 10000]
                    windows.append({"window": index, "span_ms": subset[-1]["ms"] - subset[0]["ms"],
                                    "shots": [subset[-1]["shots"][i] - subset[0]["shots"][i] for i in (0, 1)]})
            rows.append({"role": role, "phase": phase, "enemies": value["expectedEnemies"],
                "logged_phase_timer_ms": [evidence["begin_at"], evidence["result_at"]],
                "origin_wall_bounds": [origin_low, origin_high], "origin_uncertainty_ms": (origin_high-origin_low)*1000,
                "cpu_safe_phase_interior_wall": [safe_start, safe_end],
                "cpu_interval_count": len(intervals), "cpu_observed_duration_ms": duration,
                "cpu_user_ms": user_ms, "cpu_kernel_ms": kernel_ms,
                "cpu_core_percent": (user_ms + kernel_ms) / duration * 100,
                "cpu_wall_vs_monotonic_max_drift_ms": drift,
                "machine_cpu_percent": (1-idle/(kernel+user))*100,
                "working_set_bytes": distribution([b["memory"]["working_set_bytes"] for a, b in intervals]),
                "private_commit_bytes": distribution([b["memory"]["private_commit_bytes"] for a, b in intervals]),
                "elapsed_ms": value["elapsed"], "frames": value["frames"],
                "mean_frame_ms": value["elapsed"] / value["frames"],
                "p95_frame_ms": value["intervals"][int(value["frames"]*.95)],
                "samples": len(samples), "visible": distribution([s["enemies"]["visible"] for s in samples]),
                "count_attached_exact": all(s["enemies"]["count"] == value["expectedEnemies"] and
                                            s["enemies"]["attached"] == value["expectedEnemies"] for s in samples),
                "shot_delta_first_to_last_sample": shots[-1],
                "ammo_consumed_whole_phase": [a-b for a, b in zip(value["baseAmmo"], value["finalAmmo"])],
                "firing_windows": windows, "clock_samples": clocks,
                "timings": value["timings"]})
    return {"run": str(directory), "result_sha256": q.sha(directory / "result.json"),
            "cpu_sha256": q.sha(cpu_path), "declared_wrapper_sha256": cpu["wrapper_sha256"], "rows": rows}


if __name__ == "__main__":
    plan_path = q.ROOT / "experimental/b-field-perf-qualification/field21-plan.json"
    plan = q.read(plan_path)
    q.verify_plan(plan)
    result = {"schema": "b-field-profile-pair-analysis-1", "diagnostic_only": True, "qualified": False,
              "plan_sha256": q.sha(plan_path), "script_sha256": q.sha(__file__),
              "alignment": "Full CPU sample intervals inside the phase for every timer origin allowed by process creation and preserved final log-write upper bound; not an invented exact clock offset",
              "runs": {kind: analyze(kind, plan) for kind in ("baseline", "candidate")}}
    destination = "experimental/b-field-perf-qualification/profile-pair-analysis-01.json"
    q.output(destination, result)
    for kind, data in result["runs"].items():
        for row in data["rows"]:
            print(kind, json.dumps({k: v for k, v in row.items() if k not in ("timings", "firing_windows")}, ensure_ascii=False))
