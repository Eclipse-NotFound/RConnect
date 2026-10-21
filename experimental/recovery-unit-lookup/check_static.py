"""No Java/AIR: validate exact source deltas and generated full-class fixtures."""
import itertools
import json
import re
from pathlib import Path
import prepare

HERE = Path(__file__).resolve().parent
checks = []


def check(ok, label):
    checks.append({"passed": bool(ok), "label": label})
    if not ok:
        raise AssertionError(label)


def text(path):
    return path.read_text(encoding="utf-8")


def body_span(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth, quote, line_comment, block_comment = 0, None, False, False
    i = opening
    while i < len(source):
        c = source[i]
        nxt = source[i:i + 2]
        if line_comment:
            if c == "\n": line_comment = False
        elif block_comment:
            if nxt == "*/": block_comment = False; i += 1
        elif quote:
            if c == "\\": i += 1
            elif c == quote: quote = None
        elif nxt == "//": line_comment = True; i += 1
        elif nxt == "/*": block_comment = True; i += 1
        elif c in "\"'": quote = c
        elif c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: return start, i + 1
        i += 1
    raise AssertionError("Unclosed method " + marker)


def main():
    data = json.loads(text(HERE / "inputs.json"))
    for rel, digest in prepare.EXPECTED.items():
        base = prepare.BASE / "src" / rel
        check(prepare.sha(base.read_bytes()) == digest, "frozen10 unchanged: " + rel)
        check(base.read_bytes() == (prepare.MOD / "build/m52/recovery-09/src" / rel).read_bytes(), "09/10 equal: " + rel)
        before, after = text(base), text(HERE / "src" / rel)
        maker = prepare.identity_delta if rel.endswith("ObjectIdentity.as") else prepare.bridge_delta
        check(after == maker(before), "overlay is exact approved local delta: " + rel)
        check(prepare.sha((HERE / "src" / rel).read_bytes()) == data["sources"][rel]["proposal_sha256"], "overlay hash: " + rel)
        marker = "public function resolve(" if rel.endswith("ObjectIdentity.as") else "public function applyUnitsSync("
        a, b = body_span(before, marker), body_span(after, marker)
        check(before[:a[0]] + before[a[1]:] == after[:b[0]] + after[b[1]:], "all other methods byte-equivalent: " + rel)
    for rel, digest in data["components"].items():
        check(prepare.sha((HERE / rel).read_bytes()) == digest, "component fingerprint: " + rel)
    for name, digest in data["read_only_dependencies"].items():
        check(prepare.sha((prepare.BASE / "src/rconnect/game" / name).read_bytes()) == digest, "readonly dependency: " + name)
    control = text(prepare.BASE / "src/rconnect/game/ObjectIdentity.as")
    proposal = text(HERE / "src/rconnect/game/ObjectIdentity.as")
    folder = HERE / "components/rconnect/game"
    check(text(folder / "ObjectIdentity.as") == proposal, "timed proposal is full real class with no instrumentation")
    check(text(folder / "ObjectIdentityControl.as") == prepare.renamed(control, "ObjectIdentityControl"), "timed control changes class name only")
    for source, name, side in [(control, "ObjectIdentityCountControl", "before"),
                               (proposal, "ObjectIdentityCountProposal", "after")]:
        wanted = prepare.replace_once(prepare.renamed(source, name), "list.indexOf(found)",
            'LookupCounters.indexOf(list,found,"' + side + '")')
        check(text(folder / (name + ".as")) == wanted, "counter full class has only native indexOf wrapper: " + side)
    before = text(prepare.BASE / "src/rconnect/game/GameBridge.as")
    after = text(HERE / "src/rconnect/game/GameBridge.as")
    aa, bb = body_span(before, "public function applyUnitsSync("), body_span(after, "public function applyUnitsSync(")
    old_method, new_method = before[aa[0]:aa[1]], after[bb[0]:bb[1]]
    check(old_method.count("validLandPos(") == 2 and new_method.count("validLandPos(") == 1, "valid position computed once")
    check(old_method.count("_mirrorMasks.prepare(target)") == new_method.count("_mirrorMasks.prepare(target)") == 2,
        "both explicit prepares retained")
    check(old_method.count("_mirrorMasks.register(target,hit)") == new_method.count("_mirrorMasks.register(target,hit)") == 1,
        "register call unchanged")
    # Static callback ordering: delete only the redundant validator occurrence;
    # sync is still at the same position and now conditional for existing hits.
    significant = r"(?:captureUnitDamage|queueUnitMotion|applyUnitFields|applyUnitView|applyUnitAppearance|validLandPos)\(|(?:target|hit|_mirrorMasks|_projectiles|_telekinesis|_presentation|enemyGrip)\.[A-Za-z_]+\("
    old_calls = re.findall(significant, old_method)
    new_calls = re.findall(significant, new_method)
    old_calls.remove("validLandPos(")
    check(old_calls == new_calls, "existing native/effect call order unchanged apart from redundant validator")
    check("if(!createdHit)hit.sync();" in new_method and "var createdHit:Boolean = hit == null;" in new_method,
        "only new receiver skips second sync")
    hit_source = text(prepare.BASE / "src/rconnect/game/MirrorHitUnit.as")
    ca, cb = body_span(hit_source, "public function MirrorHitUnit(")
    check(re.search(r"sync\(\);\s*}$", hit_source[ca:cb]) is not None, "native proxy constructor ends in sync")
    # Guard proof only: this finite membership predicate is NOT the AS3 component.
    examples = 0
    for length in range(6):
        for arr in itertools.product(range(3), repeat=length):
            for found in range(4):
                for hint in [None, -1, 0, 1, 2, 3, 4, 5, 99]:
                    cached = hint is not None and 0 <= hint < len(arr) and arr[hint] == found
                    check_value = cached or found in arr
                    if check_value != (found in arr): raise AssertionError((arr, found, hint))
                    examples += 1
    check(True, "guard-only finite membership equivalence: " + str(examples) + " combinations")
    fixture = text(HERE / "components/UnitLookupChecks.as")
    case_count = len(re.findall(r'runCase\("', fixture))
    check(case_count == 18, "18 declared full-class comparison scenarios")
    result = {"passed": True, "checks": checks, "count": len(checks), "guard_combinations": examples,
              "full_class_as3_executed": False, "compiled": False, "air_run": False,
              "planned_case_count": case_count, "performance_qualified": False}
    (HERE / "static-checks.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"static_passed": True, "checks": len(checks), "guard_combinations": examples,
                      "planned_as3_cases": case_count, "compiled": False, "air_run": False}))


if __name__ == "__main__":
    main()
