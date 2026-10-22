"""Read completed, frozen motion logs; write only this review's compact JSON.

No launches, binary reads, new assertions, or changes to recorded verdicts.
"""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def records(lines, prefix):
    return [(i + 1, json.loads(line[len(prefix):]))
            for i, line in enumerate(lines) if line.startswith(prefix)]


def stats(values):
    a = sorted(values)
    return None if not a else dict(n=len(a), minimum=a[0],
        median=a[math.ceil(len(a) * .5) - 1],
        p95_nearest_rank=a[math.ceil(len(a) * .95) - 1], maximum=a[-1])


def gaps(a, key="t", predicate=lambda a, b: True, top=1):
    pairs = [(b[key] - a[i][key], i, i + 1)
             for i, b in enumerate(a[1:]) if predicate(a[i], b)]
    biggest = sorted(pairs, reverse=True)[:top]
    return dict(stats=stats([p[0] for p in pairs]), largest=[
        dict(ms=g, indices=[i, j], before=a[i], after=a[j]) for g, i, j in biggest])


def repeat_runs(a, match):
    runs, start = [], None
    for i in range(1, len(a)):
        repeated = match(a[i-1], a[i])
        if repeated and start is None:
            start = i - 1
        if start is not None and (not repeated or i == len(a)-1):
            end = i if repeated else i - 1
            runs.append(dict(pairs=end-start, ms=a[end]["t"]-a[start]["t"],
                indices=[start, end], before=a[start], after=a[end]))
            start = None
    return dict(repeated_pairs=sum(r["pairs"] for r in runs),
        ratio_per_sample=sum(r["pairs"] for r in runs)/len(a),
        longest=max(runs, key=lambda r: r["ms"]) if runs else None)


def fit(metric):
    best = (math.inf, -1, 0)
    source = metric["reference"]
    for lag in range(0, 701, 10):
        squared, count, index = 0., 0, 0
        for shown in metric["render"]:
            stamp = shown["at"] - metric["sourceOffset"] - lag
            if stamp < source[0]["at"]+700 or stamp > source[-1]["at"]:
                continue
            while index+1 < len(source) and source[index+1]["at"] < stamp:
                index += 1
            if index+1 >= len(source):
                continue
            a, b = source[index:index+2]
            expected = a["x"]+(b["x"]-a["x"])*(stamp-a["at"])/(b["at"]-a["at"])
            squared += (shown["x"]-expected)**2
            count += 1
        error = math.sqrt(squared/count) if count >= 12 else math.inf
        if error < best[0]:
            best = error, lag, count
    return dict(rms=best[0], lag_ms=best[1], fit_samples=best[2],
        matches_original=best[1] == metric["lagMs"] and best[2] == metric["samples"]
        and abs(best[0]-metric["rmsPixels"]) < 1e-10)


report = {"scope": "read-only, functional/diagnostic; no performance qualification",
          "smoothness_qualified": False,
          "qualification_reason": "Original runners pass, but held/drop sampled RENDER gaps and SATS entry lag remain; repeated-coordinate checks do not bound time between changed samples.",
          "runs": {}, "input_hashes": {}}
raw = {}
for case in ["fast-held", "continuity", "native-jump"]:
    folder = ROOT / "build/m52" / ("recovery21-formal-"+case+"-01")
    result = json.loads((folder/"result.json").read_text())
    intent = json.loads((folder/"intent.json").read_text())
    native = ROOT / "build/cooperation" / result["run"]
    raw[case] = {}
    for role in ["host", "join"]:
        path = native/(role+".log")
        raw[case][role] = path.read_text(encoding="utf-8-sig").splitlines()
        assert sha(path) == result["roles"][role]["log_sha256"]
    report["runs"][case] = dict(run=result["run"], candidate=intent["candidate_sha256"],
        version=intent["version"], driver_manifest=intent["driver_manifest"],
        wrapper=intent["wrapper_sha256"], runner=intent["runner_sha256"],
        roles=result["roles"], vision_templates=result["vision_config_templates"],
        gate_fields={k: result[k] for k in ["passed", "installation_unchanged",
            "exclusive_air_confirmed", "process_policy_confirmed", "vision_templates_confirmed",
            "vision_templates_unchanged", "performance_qualified", "full_release_qualified"]})
    for p in [folder/"intent.json", folder/"result.json", folder/"installation-inventory.json",
              native/"input.json", native/"host.log", native/"join.log"]:
        report["input_hashes"][p.relative_to(ROOT).as_posix()] = sha(p)

for path in ["build/m52/motion2-native-input-drivers-04/tests/FastHeldTestDoc.as",
             "build/m52/motion2-native-input-drivers-04/tests/NativeJumpNetworkTestDoc.as",
             "build/m52/motion2-continuity-drivers-01/tests/PresentationContinuityTestDoc.as"]:
    report["input_hashes"][path] = sha(ROOT/path)

held = []
held_results = {(role, o["round"]): o for role, lines in raw["fast-held"].items()
                for _, o in records(lines, "TELE MOTION RESULT ")}
for role, lines in raw["fast-held"].items():
    for line, metric in records(lines, "FAST HELD METRIC "):
        rnd = metric["round"]
        source_role = "join" if role == "host" else "host"
        shown, src = held_results[role, rnd], held_results[source_role, rnd]
        repetition = repeat_runs(shown["trace"], lambda a, b:
            math.hypot(a["x"]-b["x"], a["y"]-b["y"]) < .01)
        assert repetition["repeated_pairs"] == shown["stalls"]
        held.append(dict(round=rnd, observer=role, source_role=source_role, metric_line=line,
            original={k: v for k, v in metric.items() if k not in ["reference", "render"]},
            recomputed_fit=fit(metric), repeat=repetition,
            source_trace_gap=gaps(src["trace"]), source_reference_gap=gaps(metric["reference"], "at"),
            observer_gap=gaps(metric["render"], "at"), observer_trace_gap=gaps(shown["trace"]),
            release_wire_ms=shown["releaseWireAt"], floor_supported=shown["floorSupported"],
            source_samples=len(src["trace"]), observer_samples=len(shown["trace"]),
            source_span=max(p["x"] for p in src["trace"])-min(p["x"] for p in src["trace"]),
            observer_span=max(p["x"] for p in shown["trace"])-min(p["x"] for p in shown["trace"])))
report["fast_held"] = sorted(held, key=lambda o: o["round"])

drops = []
for line, o in records(raw["continuity"]["join"], "CONTINUITY DROP "):
    item = {k: v for k, v in o.items() if k not in ["source", "display", "arrivals"]}
    item["line"] = line
    for key in ["source", "display"]:
        a, end = o[key], o[key][-1]["y"]
        item[key] = dict(samples=len(a), gaps=gaps(a),
            air_gaps=gaps(a, predicate=lambda a, b: abs(a["y"]-end)>3 or abs(b["y"]-end)>3),
            repeated=repeat_runs(a, lambda a, b: abs(b["y"]-end)>3
                and abs(a["x"]-b["x"])+abs(a["y"]-b["y"])<.05))
    assert (item["display"]["repeated"]["longest"] or {"ms": 0})["ms"] == o["longestStillMs"]
    item["arrivals"] = dict(samples=len(o["arrivals"]), gaps=gaps(o["arrivals"], "received"))
    drops.append(item)
report["drops"] = drops
line, pause = records(raw["continuity"]["join"], "CONTINUITY PAUSE ")[0]
trace = pause["trace"]
report["pause"] = {k: v for k, v in pause.items() if k != "trace"}
report["pause"].update(line=line, samples=len(trace), gaps=gaps(trace, top=3),
    flags_edges=[dict(index=i, sample=s) for i, s in enumerate(trace) if i == 0
        or (s["paused"], s["sats"]) != (trace[i-1]["paused"], trace[i-1]["sats"])],
    final=trace[-1])

jumps = {}
for role, lines in raw["native-jump"].items():
    trace = records(lines, "NATIVE JUMP TRACE "+role+" ")[0][1]
    arena = records(lines, "NATIVE JUMP ARENA ")[0][1]
    metric = records(lines, "COOP METRIC native-jump ")[0][1]
    repetition = repeat_runs(trace, lambda a, b: b["peerY"] < arena["y"]-20
                             and abs(b["peerY"]-a["peerY"]) < .01)
    assert repetition["repeated_pairs"] == metric["airborneRepeatedPositions"]
    pictures = []
    for threshold in [3000, 9000]:
        i = next(i for i, s in enumerate(trace) if s["t"] > threshold)
        pictures.append(dict(index=i, frame_start=trace[i]["t"],
            next_frame_start=trace[i+1]["t"], gap_ms=trace[i+1]["t"]-trace[i]["t"]))
    jumps[role] = dict(original=metric, frame_start_gaps=gaps(trace, top=3), repeats=repetition,
        dt_matches_trace_times=all(trace[i]["dt"] == trace[i]["t"]-trace[i-1]["t"]
                                   for i in range(1, len(trace))),
        screenshot_call_frame_starts=pictures,
        largest_gap_excluding_exact_picture_following_intervals=max(
            s["dt"] for i, s in enumerate(trace) if i not in [p["index"]+1 for p in pictures]),
        timestamp_scope="ENTER_FRAME begin; coordinates later read in deduped final RENDER")
report["jumps"] = jumps
(OUT/"summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"output": str(OUT/"summary.json"), "runs": [x["run"] for x in report["runs"].values()],
    "held_fit_matches": all(x["recomputed_fit"]["matches_original"] for x in held),
    "held_round3_gap_source_observer": [held_results["join", 3]["frames"], held_results["host", 3]["frames"]],
    "drop_max_air_gap": [x["display"]["air_gaps"]["stats"]["maximum"] for x in drops],
    "jump_non_picture_max_frame_start_gap": {k: v["largest_gap_excluding_exact_picture_following_intervals"] for k, v in jumps.items()}}, ensure_ascii=False))
