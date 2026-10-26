"""Read-only AB007 qualification: fixed field9/native019 vs an explicit build/native021.

Never runs a process or changes a runtime. Freeze inputs before the four runs,
then evaluate their archived receipts and original JSON logs. No tunable gates.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import statistics

ROOT = Path(__file__).resolve().parents[2]
PINNED = {
    "baseline": {
        "build": "build/ab/b190-field9-build",
        "candidate_sha256": "fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd",
        "native": "build/ab/native-hooks-019/pfe.swf",
        "native_sha256": "1028a49a4af4d8e1b4bd215a44d38a742723438e24056e2336ea875d82efdba9",
    },
    "candidate": {
        "build": "build/ab/b190-field20-build",
        "candidate_sha256": "663005a8e7c5cf30692da78b8f19f11a214b78b36ab15e57b6ba93ac7787fb5e",
        "native": "build/ab/native-hooks-021/pfe.swf",
        "native_sha256": "eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063",
    },
}
PLAN_SCHEMA = "b-field-ab007-plan-2"
LEGACY_PLAN_SCHEMA = "b-field20-ab007-plan-1"
REPORT_SCHEMA = "b-field-ab007-qualification-2"
RUNNER = "tools/host_authority/field2_driver/bench.py"
DRIVER = "build/ab/ab-driver-007"
MANUAL = "build/ab/b3-playable-190/manual-input.json"
GATES = {"seconds_per_phase": 60, "samples_per_phase_min": 45,
         "enemies": [8, 80], "maximum_mean_ratio": 1.05,
         "maximum_p95_ratio": 1.05, "maximum_repeat_ratio": 1.2,
         "required_firing_windows": 6, "window_span_min_ms": 8000}
MUTABLE_RUNTIME = {"pfe.swf", "mods/rconnect/release/rconnectmod.swf",
                   "mods/rconnect/release/config.txt", "ab-bench.json", "ab-test.xml"}
BACKUP_NAME = re.compile(r"mods/modloader/work/manifest-backups/loader-manifest-[0-9]{8}-[0-9]{6}-[0-9]{3}-[0-9a-f]+\.txt")


class InvalidEvidence(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def number(v):
    return type(v) in (int, float) and math.isfinite(v)


def integer(v, minimum=0):
    return number(v) and v >= minimum and int(v) == v


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def root_path(value):
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    require(path.is_relative_to(ROOT), "Input/output is outside RConnect: " + str(path))
    return path


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def output(path, data):
    path = root_path(path)
    require(not path.exists(), "Output already exists: " + str(path))
    require(path.parent.is_dir(), "Output parent must already exist: " + str(path.parent))
    with path.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def relative_files(root, files):
    require(isinstance(files, dict) and files, "Empty artifact manifest")
    out = {}
    for name, digest in files.items():
        path = (root / name).resolve()
        require(path.is_relative_to(root.resolve()), "Manifest path escaped artifact: " + name)
        require(sha(path) == digest, "Artifact differs from manifest: " + str(path))
        out[rel(path)] = digest
    return out


def build_identity(build_value, native, native_hash, exact_hash=None):
    build = root_path(build_value)
    require(build.parent == (ROOT / "build/ab").resolve() and build.is_dir(),
            "Candidate must be an existing direct build/ab directory")
    manifest = build / "build-input.json"
    info = read(manifest)
    require(info.get("family") == "host-authority-b" and info.get("experimental_only") is True
            and info.get("optimized") is True and info.get("native_capability") == "b3-v12",
            "Build must be optimized host-authority-b with b3-v12 native capability")
    source_id = info.get("source_id")
    require(isinstance(source_id, str) and re.fullmatch(r"[0-9a-f]{64}", source_id), "Invalid build source ID")
    source_root = root_path(info["source_root"])
    require(source_root.is_relative_to((ROOT / "build/ab").resolve()), "Unexpected build source_root")
    actual_sources = {p.relative_to(build).as_posix() for folder in ("src", "stubs")
                      for p in (build / folder).rglob("*.as")}
    require(actual_sources == set(info["sources"]), "Build AS source inventory is incomplete or has extras")
    artifacts = relative_files(build, info["sources"])
    stamp = (build / "src/authority/BuildInfo.as").read_bytes()
    stamped_source = re.search(rb'const\s+SOURCE:String\s*=\s*"([0-9a-f]{64})"', stamp)
    require(stamped_source is not None and stamped_source.group(1).decode() == source_id,
            "BuildInfo source ID differs from manifest")
    require(stamp.count(source_id.encode()) == 1, "Ambiguous BuildInfo source stamp")
    template = stamp.replace(source_id.encode(), b"__SOURCE_HASH__")
    # build.py hashes copied input bytes before replacing the stamp. Its text
    # write normalizes newlines on Windows, so check both possible input forms.
    variants = {template, template.replace(b"\r\n", b"\n"),
                template.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")}
    reconstructed = set()
    for data in variants:
        sources = dict(info["sources"])
        sources["src/authority/BuildInfo.as"] = hashlib.sha256(data).hexdigest()
        reconstructed.add(hashlib.sha256(json.dumps(sources, sort_keys=True).encode("utf-8")).hexdigest())
    require(source_id in reconstructed, "Build source ID does not describe its source inventory")
    candidate_hash = sha(build / "RConnectMod.swf")
    require(candidate_hash == info.get("candidate_sha256"), "Build SWF differs from manifest")
    require(exact_hash is None or candidate_hash == exact_hash, "Build SWF differs from exact pin")
    require(sha(ROOT / native) == native_hash, "Native differs from exact pin")
    source = (build / "src/RConnectMod.as").read_text(encoding="utf-8-sig")
    match = re.search(r'const\s+VERSION:String\s*=\s*"([^"]+)"', source)
    require(match is not None, "Missing native build version")
    artifacts.update({rel(manifest): sha(manifest), rel(build / "RConnectMod.swf"): candidate_hash,
                      native: native_hash})
    return {"build": rel(build), "candidate_sha256": candidate_hash, "native": native,
            "native_sha256": native_hash, "source_id": source_id, "version": match.group(1),
            "manifest_sha256": sha(manifest)}, artifacts


def freeze(candidate_build):
    artifacts = {}
    groups = {}
    for group, pin in PINNED.items():
        build = pin["build"] if group == "baseline" else candidate_build
        identity, files = build_identity(build, pin["native"], pin["native_sha256"],
                                         pin["candidate_sha256"] if group == "baseline" else None)
        groups[group] = identity
        artifacts.update(files)
    require(groups["baseline"]["build"] != groups["candidate"]["build"], "Candidate cannot be baseline")
    driver = read(ROOT / DRIVER / "build-input.json")
    artifacts.update(relative_files(ROOT / DRIVER, driver["sources"]))
    artifacts.update(relative_files(ROOT / DRIVER, driver["files"]))
    artifacts[DRIVER + "/build-input.json"] = sha(ROOT / DRIVER / "build-input.json")
    artifacts[RUNNER] = sha(ROOT / RUNNER)
    artifacts[MANUAL] = sha(ROOT / MANUAL)
    return {"schema": PLAN_SCHEMA, "created_utc": datetime.now(timezone.utc).isoformat(),
            "groups": groups, "gates": GATES, "artifacts": artifacts,
            "runner": {"path": RUNNER, "sha256": artifacts[RUNNER]},
            "driver": {"path": DRIVER, "manifest_sha256": artifacts[DRIVER + "/build-input.json"],
                       "source_id": driver["source_id"], "files": driver["files"]},
            "manual": {"path": MANUAL, "sha256": artifacts[MANUAL]},
            "scope": "Read-only performance evidence; no game launch, simulation or deployment qualification"}


def verify_plan(plan):
    require(plan["schema"] in (PLAN_SCHEMA, LEGACY_PLAN_SCHEMA) and plan["gates"] == GATES,
            "Plan schema/gates changed")
    require(set(plan["groups"]) == {"baseline", "candidate"}, "Unexpected plan build groups")
    pins = PINNED if plan["schema"] == LEGACY_PLAN_SCHEMA else {"baseline": PINNED["baseline"]}
    for group, pin in pins.items():
        require(all(plan["groups"][group].get(k) == v for k, v in pin.items()), "Plan changed exact build pins")
    for name, digest in plan["artifacts"].items():
        require(sha(root_path(name)) == digest, "Frozen input changed: " + name)
    current = freeze(plan["groups"]["candidate"]["build"])
    for key in ("groups", "gates", "artifacts", "runner", "driver", "manual"):
        require(plan[key] == current[key], "Frozen plan differs from verified build inputs: " + key)


def canonical_files(files):
    out = {}
    require(isinstance(files, dict) and files, "Missing runtime file inventory")
    for name, digest in files.items():
        normalized = name.replace("\\", "/").lower()
        path = PurePosixPath(normalized)
        require(not path.is_absolute() and ".." not in path.parts and ":" not in normalized,
                "Invalid runtime manifest path: " + name)
        require(normalized not in out, "Duplicate runtime path differing only by case")
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest), "Invalid runtime hash")
        out[normalized] = digest
    return out


def windows_json_hash(value):
    # common.save uses text mode with the Windows default newline translation.
    text = json.dumps(value, ensure_ascii=False, indent=2).replace("\n", "\r\n")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def log_events(path):
    rows = []
    for index, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except ValueError as error:
            raise InvalidEvidence(f"Corrupt JSON log {path}:{index}") from error
        require(isinstance(row, dict) and isinstance(row.get("kind"), str), "Invalid JSON log row")
        require(number(row.get("at")), "Log missing event timestamp")
        rows.append(row)
    require(rows, "Empty log: " + str(path))
    require(all(a["at"] <= b["at"] for a, b in zip(rows, rows[1:])), "Log event times moved backwards")
    return rows


def population(value, expected):
    require(isinstance(value, dict), "Missing native enemy population")
    require(value.get("count") == expected and value.get("attached") == expected,
            "Native enemy count/attached differs from measured workload")
    require(integer(value.get("visible")) and value["visible"] <= expected, "Invalid visible enemy count")


def phase_workload(v, role, phase):
    expected = GATES["enemies"][phase]
    require(v["phase"] == phase and v["expectedEnemies"] == expected, "Wrong phase/workload order")
    samples = v["samples"]
    require(isinstance(samples, list) and len(samples) >= 45, "Fewer than 45 actual workload samples")
    require(v.get("timings") is None, "Profile counters enabled in clean performance result")
    frames, elapsed, intervals = v["frames"], v["elapsed"], v["intervals"]
    require(integer(frames, 1) and number(elapsed) and elapsed >= 60000, "Incomplete 60-second phase")
    require(isinstance(intervals, list) and len(intervals) == frames and all(integer(x) for x in intervals),
            "Frame interval list does not match actual frame count")
    require(intervals == sorted(intervals) and sum(intervals) == elapsed, "Intervals do not reconstruct measured duration")
    require(samples[0]["ms"] == 0 and samples[-1]["ms"] >= 55000, "Samples do not cover the measured phase")
    require(all(number(s["ms"]) and 0 <= s["ms"] <= elapsed for s in samples), "Sample outside phase")
    require(all(b["ms"] > a["ms"] for a, b in zip(samples, samples[1:])), "Repeated/unordered workload samples")
    population(v["enemies"], expected)
    count = 2 if role == "host" else 1
    for sample in samples:
        population(sample["enemies"], expected)
        require(len(sample["ammo"]) == count and all(integer(x) for x in sample["ammo"]), "Missing native ammo")
        require(len(sample["shots"]) == 2 and all(integer(x) for x in sample["shots"]), "Missing actual projectile counts")
        require(len(sample["players"]) == count and len(sample["weapons"]) == count, "Missing actual actors/weapons")
    require(len(v["baseAmmo"]) == count and len(v["finalAmmo"]) == count, "Missing phase ammo endpoints")
    firing = []
    if role == "host":
        for before, after in zip(samples, samples[1:]):
            for player in (0, 1):
                used = before["ammo"][player] - after["ammo"][player]
                fired = after["shots"][player] - before["shots"][player]
                require(used >= 0 and fired >= 0 and used == fired,
                        "Native ammo use differs from actual projectile generation")
        windows = defaultdict(list)
        for sample in samples:
            windows[int(sample["ms"] / 10000)].append(sample)
        for window in range(6):
            rows = windows[window]
            require(rows and rows[-1]["ms"] - rows[0]["ms"] >= 8000,
                    "A ten-second firing window has insufficient actual coverage")
            shots = [rows[-1]["shots"][p] - rows[0]["shots"][p] for p in (0, 1)]
            require(all(x > 0 for x in shots), "A player stopped firing during a measured ten-second window")
            firing.append({"window": window, "span_ms": rows[-1]["ms"] - rows[0]["ms"], "shots": shots})
        require(all(v["baseAmmo"][p] > v["finalAmmo"][p] for p in (0, 1)), "A host actor consumed no ammo")
    p95 = intervals[int(frames * .95)]
    require(p95 > 0, "Invalid zero P95")
    return {"role": role, "phase": phase, "enemies": expected, "samples": len(samples),
            "frames": frames, "elapsed": elapsed, "mean_ms": elapsed / frames,
            "p95_ms": p95, "firing_windows": firing}


def verify_log_results(bench, entry, role, driver):
    installed = [v["data"] for v in bench if v["kind"] == "installed"]
    require(len(installed) == 1 and installed[0] == {
        "variant": "B", "role": role, "seconds": 60, "source": driver["source_id"], "profile": False},
        "Actual benchmark installation/config does not match frozen clean AB007")
    require(not any(v["kind"] == "fatal" for v in bench) and sum(v["kind"] == "done" for v in bench) == 1,
            "Benchmark fatal or missing/duplicate completion")
    results = [v["data"] for v in bench if v["kind"] == "result"]
    require(results == entry["results"] and len(results) == 2, "Receipt differs from original result log")
    ready = [v["data"] for v in bench if v["kind"] == "ready"]
    require(len(ready) == 1 and ready[0]["land"] == "rbl", "Wrong actual scene")
    starts, sample_rows, active = {}, defaultdict(list), None
    for event in bench:
        if event["kind"] == "measure-begin":
            active = event["data"]["phase"]
            require(active in (0, 1) and active not in starts, "Repeated/invalid measured phase")
            starts[active] = event
        elif event["kind"] == "sample":
            require(active in (0, 1), "Sample outside a measured phase")
            sample_rows[active].append(event["data"])
        elif event["kind"] == "result":
            phase = event["data"]["phase"]
            require(active == phase and phase in starts, "Result outside its measured phase")
            require(event["data"]["samples"] == sample_rows[phase], "Embedded samples differ from original sample events")
            require(starts[phase]["data"]["ammo"] == event["data"]["baseAmmo"], "Base ammo differs from real begin event")
            population(starts[phase]["data"]["enemies"], GATES["enemies"][phase])
            # Logging itself can take time; source sample.ms and interval sum
            # are the timing truth. Event.at is only an ordering cross-check.
            require(event["at"] >= starts[phase]["at"], "Measured event order reversed")
            active = None
    require(set(starts) == {0, 1}, "Missing measurement phase")
    return ready[0]


def run_evidence(directory, group, plan):
    path = root_path(directory)
    receipt_path = path / "result.json"
    r = read(receipt_path)
    expected = plan["groups"][group]
    require(r.get("complete") is True and r.get("passed") is True and not r.get("error"), "Incomplete/failed benchmark")
    require(r.get("seconds") == 60 and r.get("profile") is False and r.get("private_desktop") is True,
            "Different duration/profile/window policy")
    for key in ("candidate_sha256", "native_sha256"):
        require(r.get(key) == expected[key], "Wrong actual " + group + " " + key)
    require(r.get("candidate_source") == expected["source_id"], "Wrong source ID")
    require(Path(r["native_source"]).resolve() == (ROOT / expected["native"]).resolve(), "Unexpected native source path")
    require(r.get("driver_sha256") == plan["driver"]["manifest_sha256"], "Wrong driver build receipt")
    require(r.get("manual_sha256") == plan["manual"]["sha256"], "Different playable base package")
    require(sha(path / "runner.py") == plan["runner"]["sha256"], "Actual runner differs from frozen field2 bench")
    require(set(r["roles"]) == {"host", "join"}, "Missing or extra role")
    hashes = {"result.json": sha(receipt_path), "runner.py": sha(path / "runner.py"), "machine.json": sha(path / "machine.json")}
    host_events = log_events(path / "host/RConnect-B.log")
    ports = [v["data"].get("port") for v in host_events if v["kind"] == "listening"]
    require(len(ports) == 1 and integer(ports[0], 1) and ports[0] <= 65535, "Missing actual host listen port")
    manual_config = read(ROOT / plan["manual"]["path"])["config"]
    workload, inventories, backups, scenes, appids = [], {}, {}, {}, []
    for role in ("host", "join"):
        entry = r["roles"][role]
        require(entry.get("done") is True and entry.get("fatal") == [] and entry.get("runtime_changes") == [],
                role + " did not complete cleanly with unchanged runtime files")
        prefix = "pfe-modsettings-rconnect-b-ab-" + role + "-"
        require(isinstance(entry["appid"], str) and entry["appid"].startswith(prefix), "Nonisolated AIR identity")
        appids.append(entry["appid"])
        session = entry["appid"][len(prefix):]
        files = canonical_files(entry["files"])
        require(files.get("pfe.swf") == expected["native_sha256"] and
                files.get("mods/rconnect/release/rconnectmod.swf") == expected["candidate_sha256"],
                "Actual role files do not match exact mod/native combination")
        for name, digest in plan["driver"]["files"].items():
            require(files.get("mods/abbench/release/" + name.lower()) == digest, "Wrong actual benchmark payload")
        config = dict(manual_config)
        config.update(experimental=True, role=role, session=session, port=ports[0], autoGame=True,
                      land="rbl", probe=True, scenario="stress", stressExternal=True)
        bench_config = dict(variant="B", role=role, seconds=60, source=plan["driver"]["source_id"], profile=False)
        require(files.get("mods/rconnect/release/config.txt") == windows_json_hash(config), "Actual RConnect test config differs from frozen runner setup")
        require(files.get("ab-bench.json") == windows_json_hash(bench_config), "Actual benchmark config differs from clean AB007")
        descriptor = ('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'
                      + entry["appid"] + '</id><versionNumber>1.0</versionNumber><filename>B Performance Test</filename>'
                      '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height>'
                      '</initialWindow></application>')
        require(files.get("ab-test.xml") == hashlib.sha256(descriptor.encode("utf-8")).hexdigest(),
                "Actual AIR descriptor differs from the frozen tested entry/window settings")
        inventories[role] = {k: v for k, v in files.items() if k not in MUTABLE_RUNTIME and not BACKUP_NAME.fullmatch(k)}
        backups[role] = sorted(v for k, v in files.items() if BACKUP_NAME.fullmatch(k))
        bench_path, game_path = path / role / "ABBench.log", path / role / "RConnect-B.log"
        bench, game = log_events(bench_path), host_events if role == "host" else log_events(game_path)
        hashes[role + "/ABBench.log"], hashes[role + "/RConnect-B.log"] = sha(bench_path), sha(game_path)
        require(not any(v["kind"] in ("FATAL", "error") for v in game), "Actual RConnect error/fatal log")
        boots = [v["data"] for v in game if v["kind"] == "boot"]
        require(len(boots) == 1 and boots[0]["source"] == expected["source_id"] and
                boots[0]["version"] == expected["version"] and boots[0]["role"] == role and
                boots[0]["session"] == entry["appid"][len(prefix):], "Actual loaded B identity differs from receipt")
        scenes[role] = verify_log_results(bench, entry, role, plan["driver"])
        for phase, value in enumerate(entry["results"]):
            try:
                workload.append(phase_workload(value, role, phase))
            except (InvalidEvidence, KeyError, TypeError, ValueError) as error:
                raise InvalidEvidence(f"{role}/phase-{phase}: {error}") from error
    require(appids[0].split("-host-")[-1] == appids[1].split("-join-")[-1], "Host and join belong to different runs")
    require(inventories["host"] == inventories["join"], "Host/join common runtime files differ")
    require(backups["host"] == backups["join"], "Host/join archived pre-selection manifest contents differ")
    environment = read(path / "machine.json")
    require(isinstance(environment, list) and len(environment) >= 2, "Missing environmental sampling")
    require(all(number(v.get("time")) and number(v.get("free_gib")) and v["free_gib"] >= .5 for v in environment),
            "Invalid environment or memory protection breach")
    require(all(b["time"] > a["time"] for a, b in zip(environment, environment[1:])), "Machine sample time reversed")
    return {"path": rel(path), "hashes": hashes, "group": group, "workload": workload,
            "common_runtime": inventories["host"], "manifest_backup_hashes": backups["host"], "scene": scenes, "appids": appids,
            "machine_first": environment[0]["time"], "machine_last": environment[-1]["time"],
            "minimum_free_gib": min(v["free_gib"] for v in environment)}


def compare(runs):
    rows = []
    for role in ("host", "join"):
        for phase, count in enumerate((8, 80)):
            groups = {}
            for group in ("baseline", "candidate"):
                data = [next(v for v in run["workload"] if v["role"] == role and v["phase"] == phase)
                        for run in runs if run["group"] == group]
                require(len(data) == 2, "Need two distinct valid repeats of each build")
                means, p95s = [v["mean_ms"] for v in data], [v["p95_ms"] for v in data]
                groups[group] = {"mean_ms": statistics.median(means), "p95_ms": statistics.median(p95s),
                                 "mean_repeats_ms": means, "p95_repeats_ms": p95s,
                                 "repeat_ratio": max(means) / min(means),
                                 "p95_repeat_ratio": max(p95s) / min(p95s)}
            b, c = groups["baseline"], groups["candidate"]
            rows.append({"role": role, "enemies": count, **groups,
                         "mean_ratio": c["mean_ms"] / b["mean_ms"], "p95_ratio": c["p95_ms"] / b["p95_ms"],
                         "no_material_regression": c["mean_ms"] <= b["mean_ms"] * 1.05 and c["p95_ms"] <= b["p95_ms"] * 1.05,
                         "repeatable": all(v["repeat_ratio"] <= 1.2 and v["p95_repeat_ratio"] <= 1.2 for v in groups.values())})
    return rows


def evaluate(plan_path, baseline, candidate):
    plan_path = root_path(plan_path)
    plan = read(plan_path)
    verify_plan(plan)
    ordered = [(baseline[0], "baseline"), (candidate[0], "candidate"),
               (baseline[1], "baseline"), (candidate[1], "candidate")]
    require(len({str(root_path(p)).lower() for p, _ in ordered}) == 4, "A run directory was reused")
    runs = []
    for path, group in ordered:
        try:
            runs.append(run_evidence(path, group, plan))
        except (InvalidEvidence, KeyError, TypeError, ValueError, OSError) as error:
            raise InvalidEvidence(f"{group} {path}: {error}") from error
    require(len({appid for run in runs for appid in run["appids"]}) == 8, "An AIR session was reused")
    for before, after in zip(runs, runs[1:]):
        require(before["machine_last"] < after["machine_first"], "Runs overlapped or were not baseline/candidate/baseline/candidate")
    for run in runs[1:]:
        require(run["common_runtime"] == runs[0]["common_runtime"], "Unrelated runtime file changed between compared runs")
        require(run["manifest_backup_hashes"] == runs[0]["manifest_backup_hashes"], "Manifest backup contents/count changed between runs")
        require(run["scene"] == runs[0]["scene"], "Actual scene geometry/stage/frame-rate differs between runs")
    comparisons = compare(runs)
    passed = all(row["no_material_regression"] and row["repeatable"] for row in comparisons)
    return {"schema": REPORT_SCHEMA, "valid_inputs": True, "qualified": passed,
            "no_material_regression": passed, "gates": GATES,
            "candidate_sha256": plan["groups"]["candidate"]["candidate_sha256"],
            "source": plan["groups"]["candidate"]["source_id"], "combinations": plan["groups"],
            "plan": {"path": rel(plan_path), "sha256": sha(plan_path)},
            "qualifier_sha256": sha(Path(__file__)), "comparisons": comparisons, "inputs": runs,
            "scope": "Stage event frame intervals only; not GPU output, end-to-end latency, functional completion or deployment approval"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("freeze")
    p.add_argument("--candidate-build", required=True, help="Explicit immutable candidate directory under build/ab")
    p.add_argument("--out", required=True)
    p = sub.add_parser("evaluate")
    p.add_argument("--plan", required=True)
    p.add_argument("--baseline", nargs=2, required=True, metavar=("BASELINE_1", "BASELINE_2"))
    p.add_argument("--candidate", nargs=2, required=True, metavar=("CANDIDATE_1", "CANDIDATE_2"))
    p.add_argument("--out", required=True)
    args = parser.parse_args()
    try:
        if args.command == "freeze":
            result = freeze(args.candidate_build)
            output(args.out, result)
            print(json.dumps({"plan": str(root_path(args.out)), "groups": result["groups"]}, ensure_ascii=False))
            return 0
        try:
            result = evaluate(args.plan, args.baseline, args.candidate)
        except (InvalidEvidence, KeyError, TypeError, ValueError, OSError) as error:
            result = {"schema": REPORT_SCHEMA, "valid_inputs": False,
                      "qualified": False, "no_material_regression": False, "error": str(error),
                      "qualifier_sha256": sha(Path(__file__)), "gates": GATES}
        output(args.out, result)
        print(json.dumps({"output": str(root_path(args.out)), "valid_inputs": result["valid_inputs"],
                          "qualified": result["qualified"], "error": result.get("error")}, ensure_ascii=False))
        return 0 if result["qualified"] else 1 if result["valid_inputs"] else 2
    except (InvalidEvidence, KeyError, TypeError, ValueError, OSError) as error:
        print(json.dumps({"error": str(error), "qualified": False}, ensure_ascii=False))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
