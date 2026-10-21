"""Source-only sparse proposal and full-class component; never launches a compiler."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
MOD = HERE.parents[1]
BASE = MOD / "build/m52/recovery-10"
EXPECTED = {
    "rconnect/game/GameBridge.as": "e1cd085795e134ca293a5eb83fe44e22a0bc7edfb172f960a2c6a1e8bdec9260",
    "rconnect/game/ObjectIdentity.as": "0bc4cc3429f78f0e43164dea4af4481e4230fdf335bd0eed6e7090baf0937774",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(source, old, new):
    assert source.count(old) == 1, (old[:100], source.count(old))
    return source.replace(old, new, 1)


def identity_delta(source):
    source = replace_once(source,
        "public function resolve(s:Object, list:Array, used:Dictionary):Object",
        "public function resolve(s:Object, list:Array, used:Dictionary, members:Dictionary=null):Object")
    return replace_once(source,
        '         if(found != null && list.indexOf(found) >= 0 && used[found] != true)',
        '         // A per-call index is only a hint: native callbacks may move/remove entries.\n'
        '         var memberIndex:* = members==null || found==null ? undefined : members[found];\n'
        '         if(found != null && ((memberIndex!==undefined && list[int(memberIndex)]===found)\n'
        '            || list.indexOf(found) >= 0) && used[found] != true)')


def bridge_delta(source):
    source = replace_once(source,
        '         var used:Dictionary = new Dictionary();\n         for each(var e:Object in list)\n         {\n            var eid:String = String(e.id);\n            var target:Object = _units.resolve(e, units as Array, used);',
        '         var used:Dictionary = new Dictionary();\n'
        '         var members:Dictionary = new Dictionary();\n'
        '         var unitList:Array = units as Array;\n'
        '         for(var memberIndex:int=0;memberIndex<unitList.length;memberIndex++)\n'
        '            if(unitList[memberIndex]!=null)members[unitList[memberIndex]]=memberIndex;\n'
        '         for each(var e:Object in list)\n         {\n            var eid:String = String(e.id);\n'
        '            var target:Object = _units.resolve(e, unitList, used, members);')
    source = replace_once(source,
        '               if(validLandPos(Number(e.x), Number(e.y)) == null)',
        '               var safe:Object = validLandPos(Number(e.x), Number(e.y));\n'
        '               if(safe == null)')
    source = replace_once(source,
        '                  var safe:Object = validLandPos(Number(e.x), Number(e.y));\n'
        '                  queueUnitMotion(target, Number(safe.x), Number(safe.y),e.sampleTime,e.bodyEffects,e);',
        '                  queueUnitMotion(target, Number(safe.x), Number(safe.y),e.sampleTime,e.bodyEffects,e);')
    source = replace_once(source,
        '                  _mirrorMasks.prepare(target);\n                  hit.sync();\n                  _mirrorMasks.register(target,hit);',
        '                  _mirrorMasks.prepare(target);\n'
        '                  // A new receiver already syncs at the end of its constructor.\n'
        '                  if(!createdHit)hit.sync();\n'
        '                  _mirrorMasks.register(target,hit);')
    return replace_once(source,
        '                  if(hit == null)\n                  {\n                     _mirrorMasks.prepare(target);',
        '                  var createdHit:Boolean = hit == null;\n'
        '                  if(createdHit)\n                  {\n                     _mirrorMasks.prepare(target);')


def renamed(source, name):
    source = replace_once(source, "public class ObjectIdentity", "public class " + name)
    return replace_once(source, "public function ObjectIdentity(", "public function " + name + "(")


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def prepare():
    patch = []
    sources = {}
    for rel, expected in EXPECTED.items():
        raw = (BASE / "src" / rel).read_bytes()
        assert sha(raw) == expected, "Frozen10 changed: " + rel
        assert raw == (MOD / "build/m52/recovery-09/src" / rel).read_bytes(), "09/10 mismatch"
        before = raw.decode("utf-8")
        after = identity_delta(before) if rel.endswith("ObjectIdentity.as") else bridge_delta(before)
        write(HERE / "src" / rel, after)
        patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile="recovery-10/src/" + rel, tofile="recovery-unit-lookup/src/" + rel))
        sources[rel] = {"base_sha256": sha(raw), "proposal_sha256": sha((HERE / "src" / rel).read_bytes())}
        if rel.endswith("ObjectIdentity.as"):
            folder = HERE / "components/rconnect/game"
            write(folder / "ObjectIdentity.as", after)
            write(folder / "ObjectIdentityControl.as", renamed(before, "ObjectIdentityControl"))
            for code, name, side in [(before, "ObjectIdentityCountControl", "before"),
                                     (after, "ObjectIdentityCountProposal", "after")]:
                instrumented = replace_once(renamed(code, name), "list.indexOf(found)",
                    'LookupCounters.indexOf(list,found,"' + side + '")')
                write(folder / (name + ".as"), instrumented)
    write(HERE / "proposal.patch", "".join(patch))
    component_files = {str(p.relative_to(HERE)).replace("\\", "/"): sha(p.read_bytes())
        for p in sorted((HERE / "components").rglob("*.as"))}
    write(HERE / "inputs.json", json.dumps({
        "base": "build/m52/recovery-10", "version": "0.2.24-recovery10",
        "base_swf_sha256": sha((BASE / "RConnectMod.swf").read_bytes()),
        "sources": sources, "components": component_files,
        "read_only_dependencies": {name: sha((BASE / "src/rconnect/game" / name).read_bytes())
            for name in ["MirrorHitUnit.as", "MirrorMasks.as"]},
        "compiled": False, "air_run": False,
        "measurement_boundary": "Full ObjectIdentity classes; only native GameBridge.probe is a documented fixture. Timings use uninstrumented classes; call counts use separate full-class copies with one indexOf wrapper."
    }, ensure_ascii=False, indent=2) + "\n")
    write(HERE / "component-plan.json", json.dumps({
        "entry": "components/UnitLookupChecks.as", "source_path": "components",
        "result": "File.applicationStorageDirectory/result.json",
        "output_rule": "new build/m52 directory; registry + unique AIR ID + hidden desktop required",
        "do_not_include": ["src/rconnect/game/GameBridge.as", "game SWF", "stub SWC"],
        "native_game": False, "compile_and_run": "parent only; not executed by prepare.py"
    }, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"prepared": True, "overlays": len(sources), "component_files": len(component_files), "compiled": False}))


if __name__ == "__main__":
    prepare()
