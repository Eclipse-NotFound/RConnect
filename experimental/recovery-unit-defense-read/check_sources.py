"""Static checks/fingerprints only; no compiler, VM or generated binaries."""
from pathlib import Path
import hashlib
import json
import re
from prepare_sources import HERE, BASE, EXPECTED_BRIDGE, FIELDS, TYPES, method, sha


def main():
    checks = []
    def check(ok, label):
        checks.append(dict(passed=bool(ok), label=label))
        assert ok, label
    base = BASE / "rconnect/game/GameBridge.as"
    old = base.read_text(encoding="utf-8-sig")
    new = (HERE / "src/rconnect/game/GameBridge.as").read_text(encoding="utf-8-sig")
    check(sha(base) == EXPECTED_BRIDGE, "accurate18 baseline unchanged")
    table_pattern = r"private static const NATIVE_UNIT_FIELDS:Object=\{.*?\};"
    before_table = re.search(table_pattern,old,re.S)[0]
    after_table = re.search(table_pattern,new,re.S)[0]
    check(new.replace(after_table,before_table) == old, "full production class has only native Unit table additions")
    before_fields = re.findall(r"(\w+):true",before_table)
    after_fields = re.findall(r"(\w+):true",after_table)
    added = [f for f in FIELDS if f not in before_fields]
    check(after_fields == before_fields+added and len(added)==18, "exactly 18 verified variables appended without changing existing entries")
    check(method(old,"unitFields") == method(new,"unitFields") and method(old,"readUnitsSnapshot") == method(new,"readUnitsSnapshot"), "entire unitFields and snapshot call sites unchanged")
    check(method(old, "readEnemyMotion") == method(new, "readEnemyMotion"), "high frequency capture unchanged")
    check(method(old, "probe") == method(new, "probe") and method(old, "probeOptional") == method(new, "probeOptional"), "global probe and protected fallback unchanged")
    for label, text in [("Before", old), ("After", new)]:
        comp = (HERE / ("components/defensecheck/Defense"+label+".as")).read_text(encoding="utf-8")
        for name in ["probe", "probeOptional", "unitFields"]:
            check(method(text,name) == method(comp,name), "exact actual function "+label+" "+name)
        for name in ["NATIVE_UNIT_FIELDS", "NATIVE_POINT_FIELDS", "NATIVE_INTERACT_FIELDS"]:
            pattern = r"private static const "+name+r":Object=\{.*?\};"
            check(re.search(pattern,text,re.S)[0] == re.search(pattern,comp,re.S)[0], "exact original table "+label+" "+name)
        check(json.loads(re.search(r"FIELDS:Array=(\[.*?\]);",comp)[1]) == FIELDS, "exact 22 defense field order "+label)
    stub = (HERE/"components/fe/unit/Unit.as").read_text(encoding="utf-8")
    for field, kind in TYPES.items():
        check("public var "+field+":"+kind+"=" in stub, "native public declaration "+field)
    numbers = (HERE/"components/rconnect/game/NativeRoomState.as").read_text(encoding="utf-8")
    check(method(numbers,"numbers") == method((BASE/"rconnect/game/NativeRoomState.as").read_text(encoding="utf-8-sig"),"numbers"), "full native numbers conversion extracted exactly")
    entry = (HERE/"components/DefenseReadChecks.as").read_text(encoding="utf-8")
    counts = {}
    for name in ["basic","edgeValues","fallbacks","ordering","otherGroups","mutableNames","verifyBench"]:
        text = method(entry,name)
        counts[name] = len(re.findall(r"\b(?:check|same)\(",text))
    counts["basic"] += len(FIELDS)-1  # slot assertion repeated 22 times
    counts["fallbacks"] += 8  # two repeated assertions in five Proxy modes
    expected = sum(counts.values())
    check(expected == 81, "planned 81 runtime assertions, not an execution claim")
    timed = method(entry,"run")
    check("sink=f(u)" in timed and all(x not in timed for x in ["check(","same(","JSON","new "]), "timed loop is complete capture without setup/assertion/encoding")
    check('"A1"' in entry and '"B1"' in entry and '"B2"' in entry and '"A2"' in entry, "explicit ABBA sequence retained")
    check("u.dexter=77" in entry and "value.valueOf=function" in entry and "conversion exceptions propagate" in entry, "valueOf read-order and exception counterexamples present")
    check("performanceQualified:false" in entry and "nativeWorld:false" in entry, "component cannot claim native/performance pass")
    check("FIELDS.push" in method(entry,"mutableNames") and "failingExtension" in method(entry,"mutableNames"), "public mutable field list retains unknown getter fallback")
    for path in HERE.glob("*.py"):
        compile(path.read_text(encoding="utf-8"), str(path), "exec")
    result = dict(passed=len(checks), failed=0, checks=checks, expected_runtime_assertions=expected,
                  assertion_plan=counts, compiled=False, runtime_tested=False)
    (HERE/"static-checks.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    files = {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob("*"))
             if p.is_file() and p.name != "source-manifest.json" and "__pycache__" not in p.parts}
    manifest = dict(baseline_sha256=EXPECTED_BRIDGE, expected_runtime_assertions=expected,
                    compiled=False, runtime_tested=False, files=files)
    (HERE/"source-manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(static_pass=len(checks), expected_runtime_assertions=expected, assertion_plan=counts)))


if __name__ == "__main__":
    main()
