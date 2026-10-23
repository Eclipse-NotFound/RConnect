"""Read-only extraction from the already completed 76b2f38ec6 round 3.

No game launch, no original analyzer/threshold changes. Writes only a new summary.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

if sys.flags.optimize:
    raise RuntimeError("Assertions are required")

ROOT = Path(__file__).resolve().parents[2]
PINS = {
    "build/m52/recovery-ordinary-wall-sv-native-01/wall-proof/host/round-3-proof.json": "3f865cee2388e53d81b796b62e039b5c6ded415b5e56284629d3b9681c2243af",
    "build/m52/recovery-ordinary-wall-sv-native-01/wall-proof/join/round-3-proof.json": "f4d4c83590cd1e2986b9bc16bf1988bd9467f019e1c288a3153b552376d55856",
    "build/m52/recovery-ordinary-wall-sv-native-01/wall-surface-result.json": "94a519324ef4fb9c3fd608c9d22a43f9b3ed2ec172dc6166c0db68a46c8c7007",
    "build/cooperation/76b2f38ec6/host.log": "fa3a23b84590a7e7acdd4a45c12d513e67e3486d55323f1682dd9202852a0a12",
    "build/cooperation/76b2f38ec6/join.log": "c9fec2b92e4d9ed1071838c6bfa93880d95baf73878900d46322e2b1284c843a",
    "build/m52/recovery-ordinary-wall-sv-production-01/src/rconnect/game/WallImpactVisuals.as": "12682bff279d35d3dc2181d4832a9d948f9ee68fcfdcf5188ee53dec2c91ff72",
    "build/m52/recovery-ordinary-wall-sv-production-01/src/rconnect/core/Session.as": "e699b9c5a02799367bba8afd924d450d064cab3f0a5e9a36ea7d400b378b10ba",
    "build/m52/recovery-ordinary-wall-sv-production-01/src/rconnect/core/RoomSync.as": "f8d9449de1b9ba10b049013b21215efeb15658562b395d014f85e63f11d7a30f",
    "build/m52/recovery-ordinary-wall-sv-production-01/src/rconnect/net/TcpLink.as": "93aafc0aad7a410107f2eea2cee288d9366c6cacce289c5b2552dc95140e350c",
    "experimental/recovery-ordinary-wall-native/tests/LargeWallSurfaceTestDoc.as": "4681da5c2540b3031a8361da6ac9a2c8127484c2d4378cb7af9a5c1440d7273e",
    "experimental/recovery-wall-surfaces-native/verify_results.py": "a3e8d886772d8facada4363331e79b6277c582b316f05c00e360e7edd247e874",
    "build/cooperation/76b2f38ec6/configuration/join/mods/Rconnect/release/config.txt": "b0b912816b199fb2c012aea4c60d31e378857e71171c47173ca38cf41cdfdb95",
}


def pairs(words):
    assert len(words) % 2 == 0
    result = dict(zip(words[::2], words[1::2]))
    assert len(result) * 2 == len(words), "Duplicate pixel index"
    return result


def stamp(frame):
    return {key: frame[key] for key in ("wall", "at", "cost")}


def main(output):
    for relative, expected in PINS.items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, relative
    proof = ROOT / "build/m52/recovery-ordinary-wall-sv-native-01/wall-proof"
    data = {role: json.loads((proof / role / "round-3-proof.json").read_text(encoding="utf8"))
            for role in ("host", "join")}
    src, dst = data["join"], data["host"]
    assert src["source"] is True and dst["source"] is False
    assert src["weapon"] == dst["weapon"] == "plamg"
    assert src["target"] == dst["target"] and src["round"] == dst["round"] == 3
    decoded = {role: [(f, pairs(f["native"]), pairs(f["display"])) for f in p["frames"]]
               for role, p in data.items()}
    stages, previous = [], {}
    for frame, native, display in decoded["join"]:
        if native == previous:
            continue
        assert native and display == native, "This extraction requires equal channels"
        previous = native
        stages.append((frame, native))
    assert len(stages) == len(src["hits"]) == src["shots"] == 8
    final = pairs(src["nativeOracle"])
    rows = []
    for index, (source_frame, native) in enumerate(stages):
        hit = src["hits"][index]
        assert hit["wall"] <= source_frame["wall"]
        if index + 1 < len(stages):
            assert source_frame["wall"] < src["hits"][index + 1]["wall"]
        matches = [f for f, n, d in decoded["host"] if n == native and d == native]
        assert matches, "Destination never shows the full exact source phase"
        receiver = matches[0]
        rows.append({
            "stage": index + 1, "pixels": len(native),
            "native_hit_wall": hit["wall"], "source_render": stamp(source_frame),
            "destination_exact_render": stamp(receiver),
            "hit_to_destination_ms": receiver["wall"] - hit["wall"],
            "render_to_render_ms": receiver["wall"] - source_frame["wall"],
            "pixels_already_equal_to_final_palette": sum(native.get(i) == c for i, c in final.items()),
        })
    old_match = next(f for f, n, d in decoded["host"] if any(n.get(i) == c for i, c in final.items()))
    assert old_match["wall"] - src["sourceFirst"] == 328
    assert rows[0]["hit_to_destination_ms"] == 129
    summaries = {}
    for role, p in data.items():
        gaps = [{"from_wall": a["wall"], "to_wall": b["wall"], "gap_ms": b["wall"] - a["wall"],
                 "after_last_source_hit": a["wall"] > src["hits"][-1]["wall"]}
                for a, b in zip(p["frames"], p["frames"][1:])]
        summaries[role] = {
            "samples": len(p["frames"]), "max_capture_ms": p["maxCaptureMs"],
            "readback_ms_excluded_from_runtime": p["readbackMs"],
            "largest_sample_gaps": sorted(gaps, key=lambda v: v["gap_ms"], reverse=True)[:5],
            "wire_count": len(p["wire"]),
            "target_cell_wire": [event for event in p["wire"]
                                 if any(c["y"] == 8 and c["x"] in (27, 28) for c in event["cells"])],
        }
    result = {
        "run": "76b2f38ec6", "round": 3, "candidate": "C6A3B1136BDE63C32D23C4E555DFC240F3A573384D19C4FE9636A4138193496D",
        "input_sha256": PINS, "stages": rows, "observations": summaries,
        "original_final_palette_first_match": {
            "wall": old_match["wall"], "from_first_native_hit_ms": 328,
            "meaning": "First destination pixel already equal to the final eight-shot palette, not first visible shot"},
        "unobserved_segments": ["native capture to queued report", "report send", "owner report receive", "ACK send/receive"],
        "qualification": "Read-only supplementary extraction; no analyzer, thresholds, original results or qualification changed",
    }
    with output.open("x", encoding="utf8", newline="\n") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"output": str(output), "stages": len(rows),
                      "first_hit_to_display_ms": rows[0]["hit_to_destination_ms"],
                      "render_lags_ms": [r["render_to_render_ms"] for r in rows]}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("timing-summary.json"))
    main(parser.parse_args().output.resolve())
