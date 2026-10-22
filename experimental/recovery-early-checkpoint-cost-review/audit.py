"""Read-only source/log audit. Never imports runners, compiles, or starts AIR."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "experimental/recovery-early-exit-authorization/src"
FROZEN = ROOT / "build/m52/recovery-early-exit-compile-01/src"
EARLY1 = ROOT / "experimental/recovery-early-buildsrc/src"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def timed_rows(role):
    path = ROOT / "build/cooperation/3b3c31c5f5" / (role + ".log")
    rows, current = [], -1
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if line.startswith("TRAVEL CLOCK "):
            current = json.loads(line[len("TRAVEL CLOCK "):])["round"]
        if current != 0:
            continue
        for kind in ("capture", "restore"):
            prefix = "RConnectRoomTiming " + kind + " "
            if line.startswith(prefix):
                rows.append({"line": line_number, "kind": kind,
                             "record": json.loads(line[len(prefix):])})
    return {"path": str(path), "sha256": sha(path), "first_load_timings": rows}


def main():
    names = ["GameBridge", "ObjectIdentity", "TerrainSync", "NativeTileState",
             "NativeRoomState", "RoomTerrainView"]
    source_rows = {}
    for name in names:
        rel = Path("rconnect/game") / (name + ".as")
        hashes = {"reviewed": sha(SOURCE / rel), "compiled_source": sha(FROZEN / rel),
                  "early1_source": sha(EARLY1 / rel)}
        assert len(set(hashes.values())) == 1, (name, hashes)
        source_rows[str(rel)] = hashes
    bridge = (SOURCE / "rconnect/game/GameBridge.as").read_text(encoding="utf-8-sig")
    identity = (SOURCE / "rconnect/game/ObjectIdentity.as").read_text(encoding="utf-8-sig")
    assert "found != null && list.indexOf(found) >= 0 && used[found] != true" in identity
    assert "for each(var o:Object in list)" in identity
    assert "if(d < distance) { best = o; distance = d; }" in identity
    assert "if(!authority)applyUnitsSync(s.units as Array);" in bridge
    unit_calls = [(i, s.strip()) for i, s in enumerate(bridge.splitlines(), 1)
                  if "_units.resolve(" in s]
    object_calls = [(i, s.strip()) for i, s in enumerate(bridge.splitlines(), 1)
                    if "_objects.resolve(" in s]
    result = {
        "kind": "read_only_source_cost_review",
        "candidate": "0.2.24-early-travel2",
        "production_candidate_sha256": "d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3",
        "source_hashes": source_rows,
        "first_load_review_sha256": sha(ROOT / "experimental/recovery-early-first-load-review/README.md"),
        "logs": {role: timed_rows(role) for role in ("host", "join")},
        "all_explicit_gamebridge_identity_calls": {"units": unit_calls, "objects": object_calls},
        "completed_call_bounds_without_reentrant_callbacks": {
            "checkpoint": "N + M", "join_full_restore": "N_keep + N + 2*M + I <= 2*N + 3*M",
            "single_resolve_logical_elements": "<= 2*L_at_call (indexOf + fallback)",
            "N": "checkpoint unit-entry count; NOT log timing.units or post-load loc.units.length",
            "M": "checkpoint object-entry count; NOT log timing.objects",
            "N_keep": "unit-entry count after isSceneHitClass skip, <= N",
            "I": "second resolve after successful Box construction, <= M",
        },
        "actual_first_load_N_M_and_resolve_count_observed": False,
        "resolver_runtime_share_observed": False,
        "no_candidate_implementation": True,
        "optimization_selected": False,
        "performance_qualified": False,
    }
    target = HERE / "evidence.json"
    if target.exists():
        raise RuntimeError("Keep original evidence; choose a new output rather than overwrite")
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"evidence": str(target), "sha256": sha(target),
                      "six_sources_identical_to_compiled_and_early1": True,
                      "optimization_selected": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
