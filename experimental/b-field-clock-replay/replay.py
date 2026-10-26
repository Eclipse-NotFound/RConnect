"""Offline B field9 PlaybackClock replay. No game, network, or product edits.

Baseline is a direct Python translation of field9; RecoverClock is a hypothesis,
not production code. All measured times are synthetic milliseconds. See README.
"""
from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass, replace
import hashlib
import json
import math
from pathlib import Path
import random
import statistics


@dataclass(frozen=True)
class Frame:
    id: int
    time: float
    room: str = "one"
    pause_epoch: int = 0
    paused: bool = False
    players: tuple = ((0, 0), (0, 0))
    control: tuple | None = ("normal", 0)

    @property
    def events(self):
        # Every source confirmation has distinguishable synthetic discrete data.
        return ((self.id, "projectile-birth"), (self.id, "wall-delta"),
                (self.id, "projectile-end"))


class Clock:
    """Field9 semantics, including minimum arrival offset and first-frame take."""
    def __init__(self):
        self.delay = 65.0
        self.position = 0.0
        self.current = None
        self.next = None
        self.underflows = 0
        self.pending = deque()
        self.offset = math.nan
        self.last = None
        self.intervals = []
        self.jitter = []

    def pace(self, frame, estimate, boundary):
        if boundary:
            self.intervals = []
            self.jitter = []
            return
        if self.last is None or self.last.paused or frame.paused:
            return
        interval = frame.time - self.last.time
        if interval <= 0 or interval > 1000:
            return
        self.intervals.append(interval)
        self.jitter.append(max(0, estimate - self.offset))
        if len(self.intervals) > 32:
            self.intervals.pop(0)
            self.jitter.pop(0)
        if len(self.intervals) < 4:
            return
        gaps = sorted(self.intervals)
        late = sorted(self.jitter)
        index = int((len(gaps) - 1) * .9)
        wanted = max(65, min(250, gaps[index] + late[index] + 15))
        self.adjust(wanted, gaps[index])

    def adjust(self, wanted, gap):
        self.delay = wanted if wanted > self.delay else max(wanted, self.delay - 2)

    def push(self, frame, now):
        if not math.isfinite(frame.time) or self.last and frame.time < self.last.time:
            raise ValueError("Invalid source presentation time")
        boundary = (self.last is None or frame.room != self.last.room
                    or frame.pause_epoch != self.last.pause_epoch)
        if (self.last and frame.control is not None and self.last.control is not None
                and frame.control != self.last.control):
            boundary = True
        if self.last:
            for i, player in enumerate(frame.players):
                if player != self.last.players[i]:
                    boundary = True
        estimate = now - frame.time
        if math.isnan(self.offset) or estimate < self.offset:
            self.offset = estimate
        self.pace(frame, estimate, boundary)
        self.pending.append(frame)
        self.last = frame
        return boundary

    def take(self, now, flush=False):
        out = []
        if self.last is None:
            return out
        target = self.last.time if flush else min(self.last.time, now - self.offset - self.delay)
        self.position = max(self.position, target)
        while self.pending and (self.current is None or self.pending[0].time <= self.position):
            self.current = self.pending.popleft()
            out.append(self.current)
        self.next = self.pending[0] if self.pending else None
        if self.next is None and not self.last.paused:
            self.underflows += 1
        return out

    @property
    def fraction(self):
        if (self.current is None or self.next is None or self.next.time <= self.current.time
                or self.current.paused):
            return 0.0
        return max(0, min(1, (self.position - self.current.time) /
                          (self.next.time - self.current.time)))


class RecoverClock(Clock):
    """Only drain scheduling differs. Confirmation consumption is inherited.

    Delay increases on push exactly as before. Delay decreases on local elapsed
    presentation time, capped at 4 ms/call, with received future data headroom.
    Same-time repeated take calls therefore have no additional recovery credit.
    """
    def __init__(self, rate=90, reserve="screen"):
        super().__init__()
        self.rate = rate
        self.reserve = reserve
        self.wanted = self.delay
        self.gap = 0.0
        self.evidence = False
        self.previous_take = None
        self.max_decrease = 0.0

    def pace(self, frame, estimate, boundary):
        if boundary:
            self.wanted = self.delay
            self.evidence = False
        super().pace(frame, estimate, boundary)

    def adjust(self, wanted, gap):
        self.wanted = wanted
        self.gap = gap
        self.evidence = True
        if wanted > self.delay:
            self.delay = wanted

    def take(self, now, flush=False):
        dt = 0 if self.previous_take is None else max(0, now - self.previous_take)
        self.previous_take = now
        if (not flush and self.last and not self.last.paused and self.evidence
                and self.last.time > self.position and self.wanted < self.delay):
            # A reserve of 16 ms is one nominal 60 Hz screen interval, not a
            # promise that the real joiner runs at 60 Hz. 'source' is deliberately
            # more conservative and reserves a whole observed source gap.
            reserve = self.gap if self.reserve == "source" else 16.0
            floor = max(self.wanted, now - self.offset - self.last.time + reserve)
            decrease = max(0, min(self.delay - floor, self.rate * dt / 1000.0, 4.0))
            self.delay -= decrease
            self.max_decrease = max(self.max_decrease, decrease)
        return super().take(now, flush)


class CadenceRecoverClock(Clock):
    """Conservative second hypothesis: original per-packet drain is retained.

    Additional time-budgeted drain is allowed only when the measured source
    cadence has improved in the same low-jitter segment. A late packet resets
    that evidence. It does not accelerate recovery of a network-only backlog.
    """
    def __init__(self, rate=90):
        super().__init__()
        self.rate = rate
        self.wanted = self.delay
        self.source_peak = 65.0
        self.source_floor = 65.0
        self.eligible = False
        self.previous_take = None
        self.packet_drain = 0.0
        self.credit = 0.0
        self.max_extra_decrease = 0.0

    def pace(self, frame, estimate, boundary):
        if boundary:
            self.wanted = self.delay
            self.source_peak = self.source_floor = 65.0
            self.eligible = False
            self.packet_drain = 0.0
            self.credit = 0.0
        # A late packet is evidence even if it has equal time or a >1000ms gap,
        # both of which the original cadence estimator deliberately ignores.
        if estimate - self.offset > 15:
            self.source_peak = self.source_floor
            self.eligible = False
        super().pace(frame, estimate, boundary)

    def adjust(self, wanted, gap):
        prior = self.delay
        super().adjust(wanted, gap)
        self.packet_drain += max(0, prior - self.delay)
        self.wanted = wanted
        self.source_floor = max(65, min(250, gap + 15))
        late = sorted(self.jitter)[int((len(self.jitter) - 1) * .9)]
        if late > 15 or self.jitter[-1] > 15:
            self.source_peak = self.source_floor
            self.eligible = False
            return
        self.source_peak = max(self.source_peak, self.source_floor)
        self.eligible = self.source_floor < self.source_peak and self.delay > wanted
        if self.delay <= wanted:
            self.source_peak = self.source_floor

    def take(self, now, flush=False):
        dt = 0 if self.previous_take is None else max(0, now - self.previous_take)
        self.previous_take = now
        # Count the baseline drain since the preceding call toward the rate.
        # A source packet burst retains exactly the original per-packet drain,
        # but cannot earn an additional time budget by being a burst.
        # Keep negative credit: a 2ms packet drain can exceed one 16ms screen
        # interval's 1.44ms budget. Forgetting that debt would silently turn
        # the intended 90ms/s recovery into about 105ms/s at a 33ms source rate.
        self.credit = min(6.0, self.credit + self.rate * dt / 1000.0 - self.packet_drain)
        self.packet_drain = 0.0
        if not self.eligible or flush:
            self.credit = 0.0
        if (not flush and self.last and not self.last.paused and self.eligible
                and self.last.time > self.position and self.delay > self.wanted):
            floor = max(self.wanted, now - self.offset - self.last.time + 16.0)
            decrease = max(0, min(self.delay - floor, self.credit, 6.0))
            self.delay -= decrease
            self.credit -= decrease
            self.max_extra_decrease = max(self.max_extra_decrease, decrease)
            if self.delay <= self.wanted:
                self.source_peak = self.source_floor
                self.eligible = False
        return super().take(now, flush)


def percentile(values, p):
    if not values:
        return None
    return round(sorted(values)[int((len(values) - 1) * p)], 3)


def snapshot(clock):
    return (clock.delay, clock.position, clock.current, clock.next, clock.offset,
            tuple(clock.pending), tuple(clock.intervals), tuple(clock.jitter))


def baseline_contracts():
    c = Clock()
    a, b = Frame(0, 100, players=()), Frame(1, 150, players=())
    c.push(a, 1100)
    c.take(1100, True)
    c.push(b, 1157)
    c.take(1190)
    assert c.current is a and c.next is b and abs(c.fraction - .5) < .001
    frozen = Frame(2, 155, pause_epoch=1, paused=True, players=())
    ready = c.take(1200, c.push(frozen, 1200))
    assert ready == [b, frozen] and c.current is frozen and c.fraction == 0
    c = Clock()
    sent = empty = observed = 0
    previous = -1
    ordered = bounded = True
    jitter = [0, 24, 48, 8, 16, 40]
    for now in range(1000, 8200, 16):
        while sent < 60 and 1000 + sent * 120 + jitter[sent % 6] <= now:
            f = Frame(sent, sent * 120, "dense", players=())
            if c.push(f, 1000 + sent * 120 + jitter[sent % 6]):
                c.take(now, True)
            sent += 1
        c.take(now)
        if 2400 < now < 7800:
            observed += 1
            empty += c.next is None
            ordered &= c.position >= previous
            previous = c.position
            bounded &= len(c.pending) < 8 and c.current is not None and c.position <= (sent - 1) * 120
    assert observed > 300 and empty < observed * .05 and ordered and bounded
    stop = Frame(sent, 7200, "dense", pause_epoch=1, paused=True, players=())
    c.take(8300, c.push(stop, 8300))
    assert c.current is stop and c.fraction == 0 and not c.pending
    for i in range(160):
        f = Frame(sent + 1 + i, 7233 + i * 33, "dense", pause_epoch=2, players=())
        c.take(8233 + i * 33, c.push(f, 8233 + i * 33))
    assert c.delay == 65
    return {"copied_field9_contracts": 5, "dense_observed": observed, "dense_empty": empty}


def isolated_safety(factory):
    c = factory()
    first = Frame(0, 100)
    c.take(1100, c.push(first, 1100))
    for bad in [math.nan, math.inf, -math.inf, 99]:
        before = snapshot(c)
        try:
            c.push(Frame(99, bad), 1200)
            raise AssertionError("invalid time was accepted")
        except ValueError:
            pass
        assert snapshot(c) == before
    second = Frame(1, 100)
    assert not c.push(second, 1100)
    assert c.take(1100) == [second]
    # Each exact boundary must flush all earlier confirmations first.
    f = first
    count = 0
    for change in [{"room": "two"}, {"pause_epoch": 1, "paused": True},
                   {"pause_epoch": 2, "paused": False}, {"players": ((1, 0), (0, 0))},
                   {"players": ((1, 0), (0, 1))}, {"control": ("slow", 0)},
                   {"control": ("replay", 0)}, {"control": ("replay", 1)}]:
        previous = replace(f, id=2 + count * 2, time=150 + count * 100)
        c.push(previous, 1100 + count * 100)
        f = replace(previous, id=previous.id + 1, time=previous.time + 1, **change)
        boundary = c.push(f, 1110 + count * 100)
        assert boundary
        ready = c.take(1110 + count * 100, True)
        assert ready == [previous, f] and c.current is f and c.next is None and c.fraction == 0
        assert not c.intervals and not c.jitter
        count += 1
    # Same-clock-time batching gives the timed candidate zero extra drain credit.
    if isinstance(c, RecoverClock):
        c = factory()
        for i in range(40):
            f = Frame(i, i * 240)
            c.take(1000 + f.time, c.push(f, 1000 + f.time))
        for i in range(40):
            f = Frame(40 + i, 9360 + (i + 1) * 33)
            c.push(f, 12000)
        c.take(12000)
        before = c.delay
        for _ in range(20):
            c.take(12000)
        assert c.delay == before
        before = c.delay
        c.take(18000)
        assert before - c.delay <= 4.000001
    return {"invalid_times": 4, "equal_time_event": 1, "boundary_types": count}


@dataclass
class Scenario:
    name: str
    arrivals: list
    recovery_start: float | None = None
    recovery_target: float | None = None
    render_interval: int = 16
    stall: tuple | None = None
    sample_start: float = 2000


def scenario(name, gaps, jitters=(0,), recovery_index=None, target=None,
             render_interval=16, stall=None, mutate=None):
    source = 0.0
    previous_arrival = 0.0
    frames = []
    for i, gap in enumerate([0] + list(gaps)):
        source += gap
        f = Frame(i, source)
        if mutate:
            f = mutate(f)
        arrival = 1000 + source + jitters[i % len(jitters)]
        if stall and stall[0] < arrival < stall[1]:
            arrival = stall[1]
        # TCP order: a later frame cannot overtake one still waiting for delivery.
        arrival = max(previous_arrival, arrival)
        previous_arrival = arrival
        frames.append((arrival, f))
    start = None if recovery_index is None else frames[recovery_index][0]
    return Scenario(name, frames, start, target, render_interval, stall)


def scenarios():
    out = [scenario("stable33", [33] * 420),
           scenario("dense120-jitter48", [120] * 140, [0, 24, 48, 8, 16, 40]),
           scenario("one-long240-then33", [33] * 70 + [240] + [33] * 350,
                    recovery_index=72, target=65),
           scenario("ignored-gap1400", [33] * 70 + [1400] + [33] * 200)]
    for cadence in (33, 66, 100):
        out.append(scenario(f"slow240-to{cadence}", [240] * 40 + [cadence] * 300,
                            recovery_index=41, target=max(65, cadence + 15)))
    for render in (33, 66, 100):
        out.append(scenario(f"slow240-to33-render{render}", [240] * 40 + [33] * 300,
                            recovery_index=41, target=65, render_interval=render))
    out.append(scenario("slow240-to33-jitter48", [240] * 40 + [33] * 350,
                        [0, 24, 48, 8, 16, 40], recovery_index=41, target=88))
    # Repeat 300ms queue stalls at 80-frame spacing, releasing ordered packets in batches.
    burst = [0] * 80
    burst[40:50] = list(range(300, 0, -30))
    out.append(scenario("tcp-release-batches", [33] * 420, burst))
    out.append(scenario("render-and-input-stall", [240] * 40 + [33] * 350,
                        recovery_index=41, target=65, stall=(12500, 13200)))

    def boundaries(f):
        if f.id >= 100:
            f = replace(f, room="two", players=((0, 1), (0, 1)))
        if 150 <= f.id < 180:
            f = replace(f, pause_epoch=1, paused=True)
        elif f.id >= 180:
            f = replace(f, pause_epoch=2)
        if 220 <= f.id < 250:
            f = replace(f, control=("slow", 1))
        elif 250 <= f.id < 290:
            f = replace(f, control=("replay", 1))
        elif f.id >= 290:
            f = replace(f, control=("normal", 1))
        return f
    out.append(scenario("room-pause-replay-boundaries", [120] * 45 + [33] * 320,
                        [0, 24, 48, 8, 16, 40], mutate=boundaries))
    out.append(scenario("duplicate-source-times", [33, 0, 0, 66] * 90))
    return out


def replay(s, factory, retain_trace=False):
    c = factory()
    arrivals = s.arrivals
    expected = [f.id for _, f in arrivals]
    expected_events = [event for _, f in arrivals for event in f.events]
    consumed = []
    events = []
    received_at = dict((f.id, arrival) for arrival, f in arrivals)
    wait = []
    recovery_wait = []
    before = 0.0
    maximum_queue = maximum_batch = boundary_count = active_samples = empty_samples = 0
    recovery_empty = recovery_samples = 0
    recovery_reached = None
    recovery_first_decrease = None
    all_decreases = []
    trace = []
    received = 0
    end = math.ceil(arrivals[-1][0] + 1200)
    renders = list(range(1000, end + 1, s.render_interval))
    if s.stall:
        renders = [t for t in renders if not s.stall[0] < t < s.stall[1]]
    timeline = sorted(set([t for t, _ in arrivals] + renders))
    render_set = set(renders)
    recovery_delay_at_start = None

    def consume(now, ready):
        nonlocal before, maximum_batch
        assert c.position >= before - 1e-8, (s.name, "source reversed", before, c.position)
        before = c.position
        assert c.position <= c.last.time + 1e-8, (s.name, "extrapolated")
        assert 0 <= c.fraction <= 1
        maximum_batch = max(maximum_batch, len(ready))
        for frame in ready:
            consumed.append(frame.id)
            events.extend(frame.events)
            assert frame.id in received_at and received_at[frame.id] <= now
            latency = now - received_at[frame.id]
            if received_at[frame.id] >= s.sample_start:
                wait.append(latency)
            if s.recovery_start is not None and received_at[frame.id] >= s.recovery_start:
                recovery_wait.append(latency)

    for now in timeline:
        while received < len(arrivals) and arrivals[received][0] == now:
            frame = arrivals[received][1]
            boundary = c.push(frame, now)
            received += 1
            maximum_queue = max(maximum_queue, len(c.pending))
            if boundary:
                ready = c.take(now, True)
                consume(now, ready)
                boundary_count += 1
                assert c.current is frame and c.next is None and not c.pending and c.fraction == 0
        if now in render_set and c.last is not None:
            prior_delay = c.delay
            was_paused = c.last.paused
            no_future = c.last.time <= c.position
            consume(now, c.take(now))
            if was_paused or no_future:
                assert c.delay == prior_delay, (s.name, "drained without future/while paused")
            all_decreases.append(max(0, prior_delay - c.delay))
            active = s.sample_start <= now < arrivals[-1][0] and not c.last.paused
            if active:
                active_samples += 1
                empty_samples += c.next is None
                if s.recovery_start is not None and now >= s.recovery_start:
                    recovery_samples += 1
                    recovery_empty += c.next is None
            if s.recovery_start is not None and now >= s.recovery_start:
                if recovery_delay_at_start is None:
                    recovery_delay_at_start = c.delay
                if recovery_first_decrease is None and c.delay < recovery_delay_at_start - 1e-6:
                    recovery_first_decrease = now - s.recovery_start
                if s.recovery_target is not None and recovery_reached is None and c.delay <= s.recovery_target + 1e-6:
                    recovery_reached = now - s.recovery_start
            if retain_trace:
                trace.append({"now": now, "delay": round(c.delay, 4), "source": round(c.position, 4),
                              "latest": c.last.time, "next": c.next.id if c.next else None,
                              "queued": len(c.pending), "applied": len(consumed)})
    assert consumed == expected, (s.name, "confirmation loss/reorder/duplicate")
    assert events == expected_events, (s.name, "event loss/reorder/duplicate")
    assert not c.pending
    result = {
        "frames": len(expected), "events": len(events), "all_confirmations_in_order": True,
        "no_time_reversal_or_extrapolation": True, "boundary_flushes": boundary_count,
        "received_to_confirm_ms": {"mean": round(statistics.mean(wait), 3),
                                   "p50": percentile(wait, .5), "p95": percentile(wait, .95),
                                   "max": max(wait)},
        "recovery_wait_ms": {"mean": round(statistics.mean(recovery_wait), 3),
                              "p95": percentile(recovery_wait, .95)} if recovery_wait else None,
        "active_samples": active_samples, "empty_samples": empty_samples,
        "empty_percent": round(empty_samples * 100 / max(1, active_samples), 3),
        "recovery_empty_percent": round(recovery_empty * 100 / max(1, recovery_samples), 3),
        "queue_max": maximum_queue, "ready_batch_max": maximum_batch,
        "recovery_first_decrease_ms": recovery_first_decrease,
        "recovery_reached_target_ms": recovery_reached,
        "delay_final_ms": round(c.delay, 3),
    }
    if isinstance(c, RecoverClock):
        result["max_delay_decrease_per_take_ms"] = round(c.max_decrease, 3)
        assert c.max_decrease <= 4.000001
    if isinstance(c, CadenceRecoverClock):
        result["max_extra_delay_decrease_per_take_ms"] = round(c.max_extra_decrease, 3)
        assert c.max_extra_decrease <= 6.000001
    return result, trace


def fuzz_scenarios(count):
    for seed in range(count):
        rng = random.Random(41000 + seed)
        if seed % 2 == 0:
            # Exercise actual accelerated recovery, then a possible renewed
            # slowdown; the high-jitter half alone mostly disables the guard.
            gaps = ([240] * 40 + [rng.choice([33, 33, 66]) for _ in range(120)]
                    + [rng.choice([16, 33, 240, 500]) for _ in range(40)] + [33] * 20)
            jitters = [rng.choice([0, 1, 4, 8, 12]) for _ in range(29)]
            boundary_chance = .015
        else:
            gaps = [rng.choice([0, 16, 33, 66, 100, 120, 240, 500, 1200]) for _ in range(220)]
            jitters = [rng.choice([0, 8, 16, 48, 160, 350]) for _ in range(29)]
            boundary_chance = .07
        changes = {}
        room, pause_epoch, player_epoch, room_epoch, cycle = "one", 0, 0, 0, 0
        paused = False
        phase = "normal"
        for i in range(221):
            if i and rng.random() < boundary_chance:
                kind = rng.randrange(5)
                if kind == 0:
                    room = "two" if room == "one" else "one"
                    room_epoch += 1
                elif kind == 1:
                    pause_epoch += 1
                    paused = not paused
                elif kind == 2:
                    player_epoch += 1
                elif kind == 3:
                    phase = "slow" if phase == "normal" else "normal"
                else:
                    cycle += 1
            changes[i] = dict(room=room, pause_epoch=pause_epoch, paused=paused,
                              players=((player_epoch, room_epoch), (0, room_epoch)),
                              control=(phase, cycle))
        yield scenario(f"fuzz-{seed:03}", gaps, jitters,
                       render_interval=rng.choice([16, 33, 66, 100]),
                       mutate=lambda f, changes=changes: replace(f, **changes[f.id]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path(__file__).with_name("results.json"))
    parser.add_argument("--fuzz", type=int, default=100)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    baseline_path = root / "build/ab/b190-field9-build/src/authority/PlaybackClock.as"
    source = baseline_path.read_bytes()
    # A changed baseline must not silently reuse this hand-checked translation.
    expected_hash = "15965e2d1ad1501717343083be4ea46a7fe91437a4eaf9a01506f0d70df0cc21"
    actual_hash = hashlib.sha256(source).hexdigest()
    assert actual_hash == expected_hash, "field9 PlaybackClock bytes changed; re-audit translation"
    factories = {"field9": Clock,
                 "timed60-reserve16": lambda: RecoverClock(60),
                 "timed90-reserve16": lambda: RecoverClock(90),
                 "timed120-reserve16": lambda: RecoverClock(120),
                 "timed90-reserve-source-gap": lambda: RecoverClock(90, "source"),
                 "cadence90-extra-cap6": CadenceRecoverClock}
    result = {"kind": "synthetic_offline_formula_replay_not_AIR_test",
              "baseline": str(baseline_path), "baseline_sha256": actual_hash,
              "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "baseline_contracts": baseline_contracts(),
              "safety": {name: isolated_safety(factory) for name, factory in factories.items()},
              "scenarios": {}, "fuzz": {"cases_per_algorithm": args.fuzz, "passed": True,
                                         "cadence_candidate_negative_cases": []}}
    for s in scenarios():
        result["scenarios"][s.name] = {name: replay(s, factory)[0] for name, factory in factories.items()}
    fuzz_frames = 0
    differences = {name: {"more_empty_cases": 0, "fewer_empty_cases": 0,
                          "same_empty_cases": 0, "largest_empty_percentage_point_increase": 0,
                          "largest_ready_batch_increase": 0, "accelerated_cases": 0}
                   for name in factories if name != "field9"}
    for s in fuzz_scenarios(args.fuzz):
        fuzz_frames += len(s.arrivals)
        base, _ = replay(s, Clock)
        for name, factory in factories.items():
            if name == "field9":
                continue
            row, _ = replay(s, factory)
            delta = row["empty_samples"] - base["empty_samples"]
            if name == "cadence90-extra-cap6" and delta > 0:
                result["fuzz"]["cadence_candidate_negative_cases"].append({
                    "scenario": s.name, "seed": 41000 + int(s.name.split("-")[1]),
                    "render_interval": s.render_interval,
                    "field9_empty_samples": base["empty_samples"],
                    "candidate_empty_samples": row["empty_samples"],
                    "active_samples": row["active_samples"],
                    "field9_mean_wait": base["received_to_confirm_ms"]["mean"],
                    "candidate_mean_wait": row["received_to_confirm_ms"]["mean"]})
            entry = differences[name]
            if row.get("max_extra_delay_decrease_per_take_ms", row.get("max_delay_decrease_per_take_ms", 0)) > 0:
                entry["accelerated_cases"] += 1
            entry["more_empty_cases" if delta > 0 else "fewer_empty_cases" if delta < 0 else "same_empty_cases"] += 1
            entry["largest_empty_percentage_point_increase"] = round(max(
                entry["largest_empty_percentage_point_increase"], row["empty_percent"] - base["empty_percent"]), 3)
            entry["largest_ready_batch_increase"] = max(entry["largest_ready_batch_increase"],
                                                        row["ready_batch_max"] - base["ready_batch_max"])
    result["fuzz"]["frames_per_algorithm"] = fuzz_frames
    result["fuzz"]["events_per_algorithm"] = fuzz_frames * 3
    result["fuzz"]["comparison_to_field9"] = differences
    result["all_assertions_passed"] = True
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.out), "scenarios": len(result["scenarios"]),
                      "algorithms": len(factories), "fuzz_cases": args.fuzz, "passed": True}))
    for name in ("slow240-to33", "slow240-to66", "slow240-to100", "slow240-to33-render66", "tcp-release-batches"):
        print(name)
        for key, row in result["scenarios"][name].items():
            print("  {} recover={}ms wait={}ms empty={}% batch={}".format(
                key, row["recovery_reached_target_ms"], row["received_to_confirm_ms"]["mean"],
                row["empty_percent"], row["ready_batch_max"]))


if __name__ == "__main__":
    main()
