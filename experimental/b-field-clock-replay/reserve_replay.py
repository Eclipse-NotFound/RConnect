"""Synthetic guard experiment; never changes or qualifies the product clock.

Keep replay.py/results.json as historical evidence. Compare received-frame
reserves added to cadence90-extra-cap6 against exactly the same 15 + 100 inputs.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
import hashlib
import json
from pathlib import Path

import replay as old


class ReservedCadenceClock(old.CadenceRecoverClock):
    def __init__(self, mode="both", future_count=3):
        super().__init__()
        self.mode = mode
        self.future_count = future_count
        self.reserve_allowed = 0
        self.reserve_blocked = 0
        self.total_extra = 0.0

    def take(self, now, flush=False):
        dt = 0 if self.previous_take is None else max(0, now - self.previous_take)
        self.previous_take = now
        self.credit = min(6.0, self.credit + self.rate * dt / 1000.0 - self.packet_drain)
        self.packet_drain = 0.0
        if not self.eligible or flush:
            self.credit = 0.0
        if (not flush and self.last and not self.last.paused and self.eligible
                and self.last.time > self.position and self.delay > self.wanted):
            floor = max(self.wanted, now - self.offset - self.last.time + 16.0)
            decrease = max(0, min(self.delay - floor, self.credit, 6.0))
            # Check reserves AFTER the proposed decrease and ordinary advance.
            # Pending frames already due at that point do not count as future.
            proposed = max(self.position, min(self.last.time, now - self.offset - self.delay + decrease))
            future = sum(frame.time > proposed for frame in self.pending)
            count_ok = future >= self.future_count
            horizon_ok = self.last.time - proposed >= self.wanted
            allowed = {"count": count_ok, "horizon": horizon_ok,
                       "both": count_ok and horizon_ok,
                       "either": count_ok or horizon_ok}[self.mode]
            if decrease > 0:
                if allowed:
                    self.reserve_allowed += 1
                    self.delay -= decrease
                    self.credit -= decrease
                    self.total_extra += decrease
                    self.max_extra_decrease = max(self.max_extra_decrease, decrease)
                else:
                    self.reserve_blocked += 1
            if self.delay <= self.wanted:
                self.source_peak = self.source_floor
                self.eligible = False
        return old.Clock.take(self, now, flush)


def measured(scenario, factory):
    made = []

    def create():
        value = factory()
        made.append(value)
        return value

    result, trace = old.replay(scenario, create, retain_trace=True)
    c = made[0]
    if isinstance(c, ReservedCadenceClock):
        result.update(reserve_allowed=c.reserve_allowed, reserve_blocked=c.reserve_blocked,
                      total_extra_decrease_ms=round(c.total_extra, 6))
    arrival_times = [now for now, frame in scenario.arrivals]
    empty = set()
    for row in trace:
        now = row["now"]
        last_index = bisect_right(arrival_times, now) - 1
        if (last_index >= 0 and scenario.sample_start <= now < arrival_times[-1]
                and not scenario.arrivals[last_index][1].paused and row["next"] is None):
            empty.add(now)
    assert len(empty) == result["empty_samples"]
    return result, empty


def exact_safety(factory):
    result = old.isolated_safety(factory)
    c = factory()
    for i in range(40):
        f = old.Frame(i, i * 240)
        c.take(1000 + f.time, c.push(f, 1000 + f.time))
    for i in range(40):
        f = old.Frame(40 + i, 9360 + (i + 1) * 33)
        c.push(f, 12000)
    c.take(12000)
    before = c.delay
    for _ in range(20):
        c.take(12000)
    assert c.delay == before
    before = c.delay
    c.take(18000)
    assert before - c.delay <= 6.000001
    assert 65 <= c.delay <= 250
    return dict(result, same_time_takes=20, large_gap_extra_limit_ms=6)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--fuzz", default=100, type=int)
    parser.add_argument("--holdout", default=1000, type=int,
                        help="Additional unseen seeds for the received7 guard; reported separately")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    output = args.out.resolve()
    if not output.is_relative_to(root) or output.exists() or not output.parent.is_dir():
        raise ValueError("Use a new result file inside this experiment directory")
    source = root.parents[1] / "build/ab/b190-field9-build/src/authority/PlaybackClock.as"
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    assert source_hash == "15965e2d1ad1501717343083be4ea46a7fe91437a4eaf9a01506f0d70df0cc21"
    factories = {"field9": old.Clock, "cadence90-extra-cap6": old.CadenceRecoverClock,
                 "received3": lambda: ReservedCadenceClock("count", 3),
                 "received4": lambda: ReservedCadenceClock("count", 4),
                 "received6": lambda: ReservedCadenceClock("count", 6),
                 "received7": lambda: ReservedCadenceClock("count", 7),
                 "received8": lambda: ReservedCadenceClock("count", 8),
                 "received12": lambda: ReservedCadenceClock("count", 12),
                 "horizon-wanted": lambda: ReservedCadenceClock("horizon"),
                 "received3-and-horizon": lambda: ReservedCadenceClock("both"),
                 "received3-or-horizon": lambda: ReservedCadenceClock("either")}
    report = {"kind": "synthetic_offline_guard_replay_not_AIR_or_product_qualification",
              "baseline_sha256": source_hash,
              "scripts": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in (Path(__file__), root / "replay.py")},
              "baseline_contracts": old.baseline_contracts(),
              "safety": {name: exact_safety(factory) for name, factory in factories.items()},
              "scenarios": {}, "fuzz": {"count": args.fuzz, "comparisons": {}},
              "no_product_qualification": True}
    for s in old.scenarios():
        base, base_empty = measured(s, old.Clock)
        rows = {"field9": base}
        for name, factory in factories.items():
            if name == "field9":
                continue
            value, empty = measured(s, factory)
            value.update(extra_empty_samples=len(empty - base_empty),
                         removed_empty_samples=len(base_empty - empty))
            rows[name] = value
        report["scenarios"][s.name] = rows
    for name in factories:
        if name != "field9":
            report["fuzz"]["comparisons"][name] = {
                "accelerated_cases": 0, "net_more_empty_cases": 0,
                "any_new_empty_cases": 0, "extra_empty_samples": 0,
                "removed_empty_samples": 0, "negative_cases": [],
                "max_batch_increase": 0}
    frames = 0
    for s in old.fuzz_scenarios(args.fuzz):
        frames += len(s.arrivals)
        base, base_empty = measured(s, old.Clock)
        for name, factory in factories.items():
            if name == "field9":
                continue
            value, empty = measured(s, factory)
            summary = report["fuzz"]["comparisons"][name]
            extra, removed = empty - base_empty, base_empty - empty
            summary["accelerated_cases"] += value.get("max_extra_delay_decrease_per_take_ms", 0) > 0
            summary["net_more_empty_cases"] += len(empty) > len(base_empty)
            summary["any_new_empty_cases"] += bool(extra)
            summary["extra_empty_samples"] += len(extra)
            summary["removed_empty_samples"] += len(removed)
            summary["max_batch_increase"] = max(summary["max_batch_increase"],
                                                 value["ready_batch_max"] - base["ready_batch_max"])
            if extra:
                summary["negative_cases"].append({"scenario": s.name,
                    "seed": 41000 + int(s.name.split("-")[1]), "render_interval": s.render_interval,
                    "field9_empty_samples": len(base_empty), "candidate_empty_samples": len(empty),
                    "extra_empty_times": sorted(extra), "removed_empty_times": sorted(removed),
                    "field9_wait": base["received_to_confirm_ms"],
                    "candidate_wait": value["received_to_confirm_ms"]})
    report["fuzz"]["frames_per_algorithm"] = frames
    report["fuzz"]["event_markers_per_algorithm"] = frames * 3
    # Seven was the first threshold without new empty samples in the existing
    # 100 seeds. Do not count this selection exercise as independent evidence.
    holdout = {"candidate": "received7", "cases": args.holdout,
               "first_seed": 41000 + args.fuzz, "accelerated_cases": 0,
               "negative_cases": [], "frames_per_algorithm": 0}
    for i, s in enumerate(old.fuzz_scenarios(args.fuzz + args.holdout)):
        if i < args.fuzz:
            continue
        base, base_empty = measured(s, old.Clock)
        value, empty = measured(s, factories["received7"])
        holdout["frames_per_algorithm"] += len(s.arrivals)
        holdout["accelerated_cases"] += value["total_extra_decrease_ms"] > 0
        if empty - base_empty:
            holdout["negative_cases"].append({"scenario": s.name, "seed": 41000 + i,
                "render_interval": s.render_interval, "field9_empty_samples": len(base_empty),
                "candidate_empty_samples": len(empty), "extra_empty_times": sorted(empty - base_empty),
                "total_extra_decrease_ms": value["total_extra_decrease_ms"],
                "field9_wait": base["received_to_confirm_ms"],
                "candidate_wait": value["received_to_confirm_ms"]})
    holdout["event_markers_per_algorithm"] = holdout["frames_per_algorithm"] * 3
    report["holdout"] = holdout
    report["all_queue_contracts_passed"] = True
    with output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps({"output": str(output), "scenarios": len(report["scenarios"]),
                      "fuzz": args.fuzz, "algorithms": len(factories), "queue_contracts": True}))
    for name, summary in report["fuzz"]["comparisons"].items():
        print(name, {k: v for k, v in summary.items() if k != "negative_cases"})
    for scenario in ("slow240-to33", "slow240-to66", "slow240-to100", "slow240-to33-render66"):
        print(scenario, {name: row["recovery_reached_target_ms"]
                         for name, row in report["scenarios"][scenario].items()})
    print("holdout", holdout)


if __name__ == "__main__":
    main()
