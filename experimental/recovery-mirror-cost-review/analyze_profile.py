"""Read one completed cooperation log directory; emit scalar timing only.

No process, sampler, file mutation, threshold changes, or full PROFILE output.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
import re
import statistics


def spread(values: list[int]) -> dict:
    if not values:
        return {"count": 0}
    ordered = sorted(values)
    return {"count": len(values), "min": ordered[0],
            "median": statistics.median(ordered),
            "p95_nearest_rank": ordered[(95 * len(ordered) + 99) // 100 - 1],
            "max": ordered[-1]}


def analyze_directory(directory: Path, role: str = "join", top: int = 8) -> dict:
    """Caller supplies the finished build/cooperation/<run> directory."""
    directory = directory.resolve(strict=True)
    if not directory.is_dir() or role not in ("host", "join") or not 1 <= top <= 25:
        raise ValueError("Expected log directory, host/join, and top in [1,25]")
    path = directory / (role + ".log")
    before = path.stat()
    if before.st_size > 128 * 1024 * 1024:
        raise ValueError("Refuse log larger than 128 MiB")
    raw = path.read_bytes()
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("Log changed while reading; use a completed run")
    records = []
    done = []
    for number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        if "PROJECTILE PROFILE " in line:
            records.append((number, json.loads(line.split("PROJECTILE PROFILE ", 1)[1])))
        if re.search(r"COOP(?: EFFECTS)? DONE\b", line):
            done.append({"line": number, "text": line[:240]})
    if len(records) != 1:
        raise ValueError(f"Expected exactly one PROFILE, found {len(records)}")
    line_number, profile = records[0]
    if profile.get("role") != role:
        raise ValueError("PROFILE role differs from requested log")
    rows = profile["frames"]
    if not isinstance(rows, list) or not rows:
        raise ValueError("Empty/non-array frame rows")
    for index, row in enumerate(rows):
        for key in ("at", "end", "phase", "samples", "cpu"):
            if type(row.get(key)) is not int or row[key] < 0:
                raise ValueError(f"Invalid scalar row[{index}].{key}")
        if row["end"] < row["at"]:
            raise ValueError(f"Negative recorded window row[{index}]")
        if index and row["at"] < rows[index - 1]["at"]:
            raise ValueError(f"Non-monotonic at row[{index}]")
    pairs = []
    phases = defaultdict(list)
    categories = Counter()
    for index in range(1, len(rows)):
        previous, current = rows[index - 1], rows[index]
        if previous["phase"] != current["phase"]:
            continue
        pair = {"phase": current["phase"], "previous_index": index - 1,
                "next_index": index, "previous_at": previous["at"],
                "previous_end": previous["end"], "next_at": current["at"],
                "at_delta_ms": current["at"] - previous["at"],
                "previous_window_ms": previous["end"] - previous["at"],
                "window_after_gap_ms": current["at"] - previous["end"],
                "previous_has_samples": previous["samples"] > 0,
                "next_has_samples": current["samples"] > 0,
                "previous_samples": previous["samples"],
                "next_samples": current["samples"],
                "previous_cpu": previous["cpu"], "next_cpu": current["cpu"]}
        pairs.append(pair)
        phases[current["phase"]].append(pair)
        categories[f"previous={pair['previous_has_samples']},next={pair['next_has_samples']}"] += 1
    metrics = ("at_delta_ms", "previous_window_ms", "window_after_gap_ms")
    sampled = [row for row in rows if row["samples"] > 0]
    return {"schema": 1, "read_only": True, "performance_qualified": False,
            "log": str(path), "sha256": hashlib.sha256(raw).hexdigest(),
            "profile_line": line_number, "role": role, "done_markers": done,
            "row_index_base": 0, "rows": len(rows), "same_phase_pairs": len(pairs),
            "rows_with_samples": len(sampled), "cpu_samples": sum(row["cpu"] for row in rows),
            "recorded_window_ms": spread([row["end"] - row["at"] for row in rows]),
            "sampled_window_ms": spread([row["end"] - row["at"] for row in sampled]),
            "pair_sample_categories": dict(categories),
            "all_pairs": {key: spread([pair[key] for pair in pairs]) for key in metrics},
            "by_phase": {str(phase): {key: spread([pair[key] for pair in group])
                                      for key in metrics} for phase, group in sorted(phases.items())},
            "longest_pairs": sorted(pairs, key=lambda pair: pair["at_delta_ms"], reverse=True)[:top],
            "limits": ["end is diagEnd entry before sample enumeration, not screen submission",
                       "has_samples reports recorded samples, not an independent sampler-enabled flag",
                       "gap is unaccounted wall time; it is not assigned to network, GC, rendering, or waiting",
                       "negative window_after_gap_ms, if present, is retained rather than clamped",
                       "done marker is reported; caller must select a completed run"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Completed build/cooperation/<run> with role.log")
    parser.add_argument("--role", choices=("host", "join"), default="join")
    parser.add_argument("--top", type=int, default=8)
    args = parser.parse_args()
    print(json.dumps(analyze_directory(args.directory, args.role, args.top), ensure_ascii=False, indent=2))
