"""Independent read-only provenance and negative/positive component audit."""
from pathlib import Path
import collections
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "experimental/recovery-early-exit-authorization"
M52 = ROOT / "build/m52"


def read(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))


def text(p):
    return p.read_text(encoding="utf-8-sig")


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def inventory(p):
    return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob("*.as"))}


def main():
    pairs = {}
    for kind in ("baseline", "fixed"):
        folder = M52 / ("recovery-early-exit-" + kind + "-component-01")
        intent = read(folder / "intent.json")
        receipt = read(folder / "receipt.json")
        result = read(folder / "component-result.json")
        actual = inventory(SOURCE / "components" / ("guard-" + kind))
        assert actual == intent["sources"]
        assert receipt["source_unchanged"] and receipt["installation_unchanged"]
        assert sha(folder / "Checks.swf") == receipt["component_sha256"]
        assert len(result["assertions"]) == receipt["observed_checks"]
        assert sum(not r["passed"] for r in result["assertions"]) == receipt["checks_failed"]
        pairs[kind] = dict(receipt=receipt, result=result, source=actual,
                           result_sha256=sha(folder / "component-result.json"))
    old, new = pairs["baseline"], pairs["fixed"]
    assert set(old["source"]) == set(new["source"])
    changes = [p for p in old["source"] if old["source"][p] != new["source"][p]]
    assert changes == ["rconnect/core/RoomSync.as"]
    assert old["source"]["EarlyExitAuthorizationChecks.as"] == sha(SOURCE / "tests/EarlyExitAuthorizationChecks.as")
    old_rows, new_rows = old["result"]["assertions"], new["result"]["assertions"]
    # Baseline returns from each lifecycle when the broken code produces no
    # ACK; those omitted later checks account for 6 x 4 = 24 extra fixed rows.
    cursor = iter(new_rows)
    for row in old_rows:
        assert any(r["label"] == row["label"] for r in cursor), "old assertion order changed"
    assert (len(old_rows), old["receipt"]["checks_failed"]) == (55, 26)
    assert (len(new_rows), new["receipt"]["checks_failed"]) == (79, 0)
    failures = collections.Counter(re.sub(r" grant@\d+ cached=(false|true)$", "", r["label"])
                                   for r in old_rows if not r["passed"])
    prior = M52 / "recovery-early-compile-01"
    candidate = M52 / "recovery-early-exit-compile-01"
    before, after = inventory(prior / "src"), inventory(candidate / "src")
    assert after == inventory(SOURCE / "src")
    production_changes = sorted(p for p in after if after[p] != before[p])
    assert production_changes == ["RConnectMod.as", "rconnect/core/RoomSync.as"]
    changed = text(candidate / "src/rconnect/core/RoomSync.as")
    reverted = changed.replace("         TravelGuard.endTravel();\n         if(nativeTravel.current!=null)nativeTravel.finish(nativeTravel.id);",
                               "         if(nativeTravel.current!=null)nativeTravel.finish(nativeTravel.id);", 1)
    reverted = reverted.replace("               if(!completingEarly)TravelGuard.endTravel();", "               TravelGuard.endTravel();", 1)
    assert reverted == text(prior / "src/rconnect/core/RoomSync.as")
    assert text(candidate / "src/RConnectMod.as").replace("0.2.24-early-travel2", "0.2.24-early-travel1", 1) == text(prior / "src/RConnectMod.as")
    bridge = ROOT / "experimental/recovery-early-exit-native"
    pins = read(bridge / "inputs.json")
    for name, digest in pins["sources"].items():
        assert sha(bridge / name) == digest
    for name, digest in pins["originals"].items():
        assert sha(Path(name)) == digest
    assert sha(candidate / "RConnectMod.swf") == pins["candidate_sha256"]
    assert sha(candidate / "prepared.json") == pins["candidate_manifest"]
    inherited = text(ROOT / "experimental/recovery-early-revisit-frozen-rv/run_native.py")
    inherited = inherited.replace('RUNNER=Path(__file__).with_name("native_runner.py")',
                                  'RUNNER=Path(__file__).resolve().parent.parent/"recovery-early-revisit-frozen-rv/native_runner.py"', 1)
    inherited = inherited.replace('assert a.sand_mode=="bridge" and not a.solo', 'assert a.sand_mode=="bridge"', 1)
    assert inherited == text(bridge / "run_native.py")
    result = dict(candidate_sha256=pins["candidate_sha256"],
        same_fixture_sha256=old["source"]["EarlyExitAuthorizationChecks.as"],
        component_source_changes=changes, production_source_changes=production_changes,
        actual_component_results={k: {"observed": v["receipt"]["observed_checks"], "failed": v["receipt"]["checks_failed"],
            "component_sha256": v["receipt"]["component_sha256"], "result_sha256": v["result_sha256"]} for k, v in pairs.items()},
        baseline_failed_labels=dict(failures), new_rows_from_later_lifecycle_branches=len(new_rows) - len(old_rows),
        wrapper_differences_only_runner_path_and_solo_guard=True, native_runtime_qualified=False,
        limitations=["Native world/countdown and network are fixtures; not actual generation or rendering.",
                     "MapGeneration/Sand permit access is a stub; release failure is not exercised in this fixture.",
                     "Host and join share one component process; native multi-process runtime remains necessary.",
                     "Cached preparation is a flag in this component, not a cached native Land construction.",
                     "Old six component entry assertions are retained but not re-executed by this 79-check result."])
    target = HERE / "authorization-components-audit.json"
    assert not target.exists()
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"component_counts": result["actual_component_results"], "source_changes": changes,
                      "baseline_failed_labels": dict(failures), "native_runtime_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
