"""Read-only analysis of NativeProjectileProbe output; JSON goes to stdout.

Never treats a source-native stationary phase as a network regression. Remote
clips have no event ID: tail matches are compatibility evidence, not identity.
No runtime launch, product modification, or input-file rewriting is performed.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import statistics

EPS = 0.05
GEOMETRY = ("rot", "sx", "sy", "a", "frame", "ls", "lf")


def numeric(value):
    return isinstance(value, (int, float)) and math.isfinite(value)


def stats(values):
    values = sorted(float(x) for x in values if numeric(x))
    if not values:
        return {"n": 0}
    def q(p):
        k = (len(values) - 1) * p
        a, b = math.floor(k), math.ceil(k)
        return round(values[a] + (values[b] - values[a]) * (k - a), 4)
    return {"n": len(values), "min": q(0), "p50": q(.5), "p95": q(.95),
            "p99": q(.99), "max": q(1), "mean": round(statistics.fmean(values), 4)}


def xy(value):
    return value is not None and numeric(value.get("x")) and numeric(value.get("y"))


def distance(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def same_geometry(a, b):
    for field in GEOMETRY:
        x, y = a.get(field), b.get(field)
        if x == y:
            continue
        if not numeric(x) or not numeric(y) or abs(x-y) > .00001:
            return False
    return True


def native_index(phase):
    result = {}
    for row in phase.get("sourceRows", []):
        for bullet in row.get("bullets", []):
            result[(row["at"], bullet.get("owner"), bullet["ordinal"])] = bullet
    return result


class Tails:
    def __init__(self):
        self.points = defaultdict(list)
        self.segments = defaultdict(list)

    def add(self, cls, point, evidence):
        if cls and xy(point):
            self.points[cls].append((point, evidence))

    def match(self, cls, point):
        if any(distance(point, candidate) <= EPS for candidate, _ in self.points.get(cls, [])):
            return True
        # A native fading beam follows its muzzle. Candidate interpolation can
        # land between confirmed terminal samples, not exactly on an endpoint.
        for a,b in self.segments.get(cls, []):
            dx,dy = b["x"]-a["x"], b["y"]-a["y"]
            length2 = dx*dx+dy*dy
            if length2 <= EPS*EPS:
                continue
            t = ((point["x"]-a["x"])*dx+(point["y"]-a["y"])*dy)/length2
            if 0 <= t <= 1 and distance(point, {"x":a["x"]+t*dx, "y":a["y"]+t*dy}) <= EPS:
                return True
        return False

    def summary(self):
        return {cls: {**dict(Counter(kind for _, kind in points)),
                      "native-babah-segments":len(self.segments.get(cls, []))} for cls, points in self.points.items()}


def tails_for(source_phase, receiver_phase):
    tails = Tails()
    if source_phase:
        births = {b["ordinal"]: b for b in source_phase.get("births", [])}
        previous = {}
        for row in source_phase.get("sourceRows", []):
            for bullet in row.get("bullets", []):
                visual = bullet.get("visual")
                if bullet.get("babah") and visual:
                    cls = births.get(bullet["ordinal"], {}).get("cls")
                    tails.add(cls, visual, "native-babah")
                    last = previous.get(bullet["ordinal"])
                    if last and last.get("babah") and xy(last.get("visual")) and xy(visual):
                        tails.segments[cls].append((last["visual"], visual))
                previous[bullet["ordinal"]] = bullet
        for end in source_phase.get("sourceEnds", []):
            tails.add(births.get(end["ordinal"], {}).get("cls"),
                      {"x": end.get("visualX"), "y": end.get("visualY")}, "native-end")
    for event in receiver_phase.get("wire", []):
        history = [p for p in event.get("history", []) if xy(p)]
        if len(history) >= 2 and distance(history[-2], history[-1]) <= EPS:
            tails.add(event.get("cls"), history[-1], "wire-final-stationary-pair")
    return tails


def motion_groups(phase, source_phase):
    tracks = defaultdict(list)
    source = native_index(phase)
    tails = tails_for(source_phase, phase)
    for index, row in enumerate(phase.get("rows", [])):
        for clip in row.get("clips", []):
            if xy(clip):
                tracks[(bool(clip.get("native")), clip.get("cls"), clip["id"])].append((index, row["at"], clip))
    groups = {}
    for (native, cls, identity), samples in tracks.items():
        key = ("native" if native else "remote") + ":" + str(cls)
        group = groups.setdefault(key, {"clips": 0, "samples": 0, "pairs": 0, "gapsAcrossHiddenFrames": 0,
            "repeatedPositionPairs": 0, "identicalVisualPairs": 0, "nativeTerminalRepeatPairs": 0,
            "nativeActiveRepeatPairs": 0, "remoteTailCompatibleRepeatPairs": 0,
            "remoteOutsideKnownTailRepeatPairs": 0, "remoteOutsideKnownTailIdenticalPairs": 0,
            "nativePhysicsMovedWhileVisualRepeated": 0,
            "_steps": [], "_speeds": [], "_gaps": [], "_runs": []})
        group["clips"] += 1
        group["samples"] += len(samples)
        run = None
        for previous, current in zip(samples, samples[1:]):
            pi, pt, a = previous
            ci, ct, b = current
            dt = ct - pt
            if ci != pi + 1 or dt <= 0:
                group["gapsAcrossHiddenFrames"] += 1
                if run:
                    group["_runs"].append(run)
                    run = None
                continue
            step = distance(a, b)
            group["pairs"] += 1
            group["_steps"].append(step)
            group["_speeds"].append(step * 1000 / dt)
            group["_gaps"].append(dt)
            if step > EPS:
                if run:
                    group["_runs"].append(run)
                    run = None
                continue
            group["repeatedPositionPairs"] += 1
            identical = same_geometry(a, b)
            if identical:
                group["identicalVisualPairs"] += 1
            if native:
                sa = source.get((pt, a.get("owner"), a.get("ordinal")))
                sb = source.get((ct, b.get("owner"), b.get("ordinal")))
                terminal = bool((sa and sa.get("babah")) or (sb and sb.get("babah")))
                label = "native-terminal" if terminal else "native-active"
                group["nativeTerminalRepeatPairs" if terminal else "nativeActiveRepeatPairs"] += 1
                if sa and sb and xy(sa) and xy(sb) and distance(sa, sb) > EPS:
                    group["nativePhysicsMovedWhileVisualRepeated"] += 1
            else:
                compatible = tails.match(cls, b)
                label = "remote-tail-compatible" if compatible else "remote-outside-known-tail"
                group["remoteTailCompatibleRepeatPairs" if compatible else "remoteOutsideKnownTailRepeatPairs"] += 1
                if not compatible and identical:
                    group["remoteOutsideKnownTailIdenticalPairs"] += 1
            if run and run["kind"] != label:
                group["_runs"].append(run)
                run = None
            if run is None:
                run = {"clip": identity, "kind": label, "from": pt, "to": ct, "ms": dt,
                       "pairs": 1, "identicalPairs": int(identical), "x": round(b["x"], 3), "y": round(b["y"], 3)}
            else:
                run.update(to=ct, ms=ct-run["from"], pairs=run["pairs"]+1,
                           identicalPairs=run["identicalPairs"]+int(identical))
        if run:
            group["_runs"].append(run)
    for group in groups.values():
        group["stepPx"] = stats(group.pop("_steps"))
        group["speedPxPerSecond"] = stats(group.pop("_speeds"))
        group["sampleGapMs"] = stats(group.pop("_gaps"))
        runs = group.pop("_runs")
        group["repeatRunMs"] = stats(r["ms"] for r in runs)
        group["repeatRunsOver100ms"] = sum(r["ms"] > 100 for r in runs)
        group["longestRepeatRuns"] = sorted(runs, key=lambda r:r["ms"], reverse=True)[:8]
        group["longestOutsideKnownTailRuns"] = sorted(
            (r for r in runs if r["kind"]=="remote-outside-known-tail"), key=lambda r:r["ms"], reverse=True)[:8]
        group["positionRepeatFraction"] = round(group["repeatedPositionPairs"] / max(1, group["pairs"]), 5)
    return groups, tails.summary()


def network(phase):
    streams = defaultdict(lambda: {"received": set(), "advancedReceived": set(), "source": set(), "offset": [], "events": 0,
                                  "withinReceived": [], "withinAdvanced": [], "withinSource": []})
    for event in phase.get("wire", []):
        key = event.get("shot", "unknown").rsplit(":", 1)[0]
        stream = streams[key]
        stream["events"] += 1
        event_source = []
        for point in event.get("history", []):
            if numeric(point.get("at")):
                stream["source"].add(point["at"])
                event_source.append(point["at"])
        previous_last = None
        event_received, event_advanced = [], []
        for update in event.get("receiveUpdates", []):
            received, stamp = update.get("at"), update.get("sent")
            if numeric(received):
                stream["received"].add(received)
                event_received.append(received)
                if numeric(update.get("last")) and update["last"] != previous_last:
                    stream["advancedReceived"].add(received)
                    event_advanced.append(received)
                    previous_last = update["last"]
            if numeric(received) and numeric(stamp):
                stream["offset"].append(received-stamp)
        for field, values in (("withinReceived", event_received), ("withinAdvanced", event_advanced), ("withinSource", event_source)):
            values = sorted(set(values))
            stream[field].extend(b-a for a,b in zip(values,values[1:]))
    result = {}
    for key, stream in streams.items():
        def gaps(field):
            times = sorted(stream[field])
            return stats(b-a for a,b in zip(times,times[1:]))
        offsets = stream["offset"]
        center = statistics.median(offsets) if offsets else 0
        result[key] = {"events": stream["events"], "streamReceiveGapIncludingInterShotIdleMs": gaps("received"),
            "withinEventReceiveGapMs": stats(stream["withinReceived"]),
            "withinEventAdvancingUpdateGapMs": stats(stream["withinAdvanced"]),
            "withinEventSourceSampleGapMs": stats(stream["withinSource"]),
            "receiveMinusSentCenteredMs": stats(x-center for x in offsets)}
    return {"allMessages": phase.get("messages"), "allBytes": phase.get("bytes"),
        "packetEventReferences": phase.get("packetEvents"), "packetFrameReferences": phase.get("packetFrames"),
        "streams": result, "limit": "Detailed timestamps cover first 12 events per stream; centered offsets are jitter, not one-way latency."}


def analyze_phase(phase, peer_phase, rate):
    rows = phase.get("rows", [])
    frame_ms = 1000 / rate if rate > 0 else None
    render = [r.get("renderGap", 0) for r in rows if r.get("renderGap", 0) > 0]
    native = [r["at"] for r in rows if any(c.get("native") for c in r.get("clips", []))]
    remote = [r["at"] for r in rows if any(not c.get("native") for c in r.get("clips", []))]
    motion, tails = motion_groups(phase, peer_phase)
    duration = rows[-1]["at"]-rows[0]["at"] if len(rows)>1 else 0
    return {"name": phase.get("name"), "weapon": phase.get("weapon"), "weaponNative": phase.get("weaponNative"),
        "coverage": {"localShots": phase.get("localShots"), "enemyShots": phase.get("enemyShots"),
            "nativeObjects": len(phase.get("births", [])), "wireEvents": len(phase.get("wire", [])),
            "nativeVisibleRows": len(native), "remoteVisibleRows": len(remote),
            "nativeVisibleSpanMs": native[-1]-native[0] if native else 0,
            "remoteVisibleSpanMs": remote[-1]-remote[0] if remote else 0, "checks": phase.get("checks")},
        "render": {"rows": len(rows), "durationMs": duration,
            "observedFps": round((len(rows)-1)*1000/duration, 3) if duration else None,
            "nativeTargetFrameMs": frame_ms, "gapMs": stats(render),
            "over1_5NativeFrames": sum(x>frame_ms*1.5 for x in render) if frame_ms else None,
            "over2NativeFrames": sum(x>frame_ms*2 for x in render) if frame_ms else None,
            "over100ms": sum(x>100 for x in render), "over250ms": sum(x>250 for x in render),
            "workMs": stats(r.get("work") for r in rows)},
        "motion": motion, "knownTailEvidence": tails, "network": network(phase)}


def locate(root):
    for base in (root / "logs", root):
        found = {role:base/role/"stutter-result.json" for role in ("host", "join")}
        if all(p.is_file() for p in found.values()):
            return found
    raise FileNotFoundError(f"No host/join stutter-result.json under {root}")


def analyze_run(path):
    paths = locate(Path(path))
    raw = {role:json.loads(p.read_text(encoding="utf-8-sig")) for role,p in paths.items()}
    result = {"path":str(Path(path).resolve()), "roles":{}}
    manifest = Path(path)/"input.json"
    if manifest.is_file():
        metadata = json.loads(manifest.read_text(encoding="utf-8-sig"))
        result["runtimeInputs"] = {"candidateSha256":metadata.get("candidate_sha256"),
            "driverSha256":metadata.get("driver_sha256"), "harnessSha256":metadata.get("harness_sha256"),
            "gameSha256":metadata.get("assets", {}).get("pfe.swf")}
    for role, data in raw.items():
        peer = raw["join" if role=="host" else "host"]
        peers = {p["name"]:p for p in peer.get("phases", [])}
        result["roles"][role] = {"inputSha256":hashlib.sha256(paths[role].read_bytes()).hexdigest(),
            "probe":data.get("probe"), "completed":data.get("completed"), "passed":data.get("passed"),
            "error":data.get("error"), "targetRate":data.get("targetRate"),
            "phases":[analyze_phase(p, peers.get(p["name"]), data.get("targetRate", 0)) for p in data.get("phases", [])]}
    return result


def comparison(baseline, candidate):
    output = []
    for role in ("host", "join"):
        bp = {p["name"]:p for p in baseline["roles"][role]["phases"]}
        for cp in candidate["roles"][role]["phases"]:
            if cp["name"] not in bp:
                continue
            old = bp[cp["name"]]
            row = {"role":role, "phase":cp["name"], "render":{}, "motion":{}}
            for field in ("observedFps", "over100ms", "over250ms"):
                row["render"][field] = {"baseline":old["render"][field], "candidate":cp["render"][field]}
            for key in cp["motion"].keys() & old["motion"].keys():
                row["motion"][key] = {field:{"baseline":old["motion"][key][field], "candidate":cp["motion"][key][field]}
                    for field in ("pairs", "positionRepeatFraction", "identicalVisualPairs", "nativeActiveRepeatPairs",
                                  "remoteOutsideKnownTailRepeatPairs", "remoteOutsideKnownTailIdenticalPairs", "repeatRunsOver100ms")}
            output.append(row)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", help="Candidate run directory containing logs/host and logs/join")
    parser.add_argument("--baseline", help="Optional same-driver baseline run directory")
    args = parser.parse_args()
    candidate = analyze_run(args.run)
    output = {"method": {"positionEpsilonPx":EPS,
        "nativeQuantum": "Use each run's targetRate; a normal 30 FPS frame is approximately 33.3 ms, not a stall.",
        "tailClassification": "Native terminal uses actual babah; remote tail compatibility uses paired native terminal points/segments, endpoints and received histories. No remote event identity is exposed.",
        "verdict": "Metrics only. Unknown-tail repeats require inspection; not an automatic regression or pass."},
        "candidate":candidate}
    if args.baseline:
        output["baseline"] = analyze_run(args.baseline)
        a,b = output["baseline"].get("runtimeInputs", {}), candidate.get("runtimeInputs", {})
        output["comparisonInputs"] = {key:a.get(key)==b.get(key) and a.get(key) is not None
                                      for key in ("driverSha256", "harnessSha256", "gameSha256")}
        output["comparison"] = comparison(output["baseline"], candidate)
    print(json.dumps(output, ensure_ascii=False, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
