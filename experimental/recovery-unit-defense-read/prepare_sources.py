"""Prepare AS/text only. No compiler, game process, or binary-copy operation."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-18/src"
EXPECTED_BRIDGE = "3fe9bb83a16a57300e733806cddbe74ce55bcaf323bec15554814f4714eba967"
FIELDS = ["maxhp", "skin", "armor", "marmor", "armor_hp", "armor_maxhp", "armor_qual",
          "shithp", "shitArmor", "allVulnerMult", "vulner", "dexter", "dexterPlus", "dodge",
          "invulner", "transp", "opt", "mech", "blood", "mat", "maxShok", "showNumbs"]
TYPES = {f: "Number" for f in FIELDS}
TYPES.update(vulner="Array", opt="Object", invulner="Boolean", transp="Boolean", mech="Boolean",
             showNumbs="Boolean", blood="int", mat="int", maxShok="int")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def method(text, name):
    found = re.search(r"(?:public|private) (?:static )?function " + name + r"\(", text)
    assert found, name
    start = text.index("{", found.end())
    depth, end = 1, start + 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[found.start():end]


def write(relative, text):
    path = HERE / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main():
    bridge = BASE / "rconnect/game/GameBridge.as"
    assert sha(bridge) == EXPECTED_BRIDGE
    before = bridge.read_text(encoding="utf-8-sig")
    table = re.search(r"private static const NATIVE_UNIT_FIELDS:Object=\{.*?\};", before, re.S)[0]
    existing = set(re.findall(r"(\w+):true", table))
    added = [field for field in FIELDS if field not in existing]
    assert len(added) == 18
    lines = [",".join(field+":true" for field in added[i:i+6]) for i in range(0,len(added),6)]
    new_table = table[:-2]+",\n         "+",\n         ".join(lines)+"};"
    assert before.count(table) == 1
    after = before.replace(table,new_table,1)
    write("src/rconnect/game/GameBridge.as", after)
    write("proposal.patch", "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                                     "accurate18/GameBridge.as", "unit-defense-read/GameBridge.as")))
    methods = ["probe", "probeOptional", "unitFields"]
    for label, content in [("Before", before), ("After", after)]:
        constants = [re.search(r"private static const "+name+r":Object=\{.*?\};",content,re.S)[0]
                     for name in ["NATIVE_UNIT_FIELDS", "NATIVE_POINT_FIELDS", "NATIVE_INTERACT_FIELDS"]]
        members = "\n\n".join(constants + [method(content, n) for n in methods])
        wrapper = """package defensecheck {
   import flash.display.DisplayObject;
   import fe.unit.Unit;
   import fe.Pt;
   import fe.serv.Interact;
   import rconnect.game.NativeRoomState;
   public class Defense%s {
      public static const FIELDS:Array=%s;
      public static function capture(u:Object):Object {return unitFields(u,FIELDS);}
      public static function other(u:Object,names:Array):Object {return unitFields(u,names);}
%s
   }
}
""" % (label, json.dumps(FIELDS), members)
        write("components/defensecheck/Defense" + label + ".as", wrapper)
    room = (BASE / "rconnect/game/NativeRoomState.as").read_text(encoding="utf-8-sig")
    write("components/rconnect/game/NativeRoomState.as", "package rconnect.game { public class NativeRoomState {\n"
          + method(room, "numbers") + "\n} }\n")
    declarations = []
    for field, kind in TYPES.items():
        value = "null" if kind in ("Object", "Array") else "false" if kind == "Boolean" else "0"
        declarations.append("      public var %s:%s=%s;" % (field, kind, value))
    write("components/fe/unit/Unit.as", """package fe.unit {
   import fe.Obj;
   // Slot/hierarchy fixture only. Not a game constructor or production declaration.
   public class Unit extends Obj {
%s
      public var levit_max:*=0;
      public var massaMove:Number=1;
      public var levit_r:int=0;
      public var t_throw:int=0;
      public var isFly:Boolean=false;
      public var isLaz:int=0;
      public var npc:Boolean=false;
      public var noAgro:Boolean=false;
   }
}
""" % "\n".join(declarations))
    write("components/fe/Pt.as", """package fe { public class Pt {
   public var dx:Number=0; public var dy:Number=0; public var stay:Boolean=false;
} }\n""")
    write("components/fe/Obj.as", """package fe { public class Obj extends Pt {
   public var scX:Number=10; public var scY:Number=10; public var massa:Number=1;
   public var levit:int=0; public var levitPoss:Boolean=true; public var fracLevit:int=0;
} }\n""")
    write("components/fe/serv/Interact.as", "package fe.serv { public class Interact {} }\n")
    metadata = dict(baseline="build/m52/recovery-18/src", bridge_sha256=EXPECTED_BRIDGE,
        change="only 18 verified public variable names appended to existing NATIVE_UNIT_FIELDS",
        added_fields=added,
        native_evidence=dict(host_sha256="befcf0509e11fac9fef7afb834708b8b93752a14ae3d5cd72b42aa6d42f9b82a",
                             source="existing audit_native_slots.inspect_swf, read-only stdout, 2026-10-22",
                             parent="fe::Obj", namespace="", namespace_kind=22, trait_kind=0, fields=TYPES),
        exact_functions={label:{n:hashlib.sha256(method(text,n).encode()).hexdigest() for n in methods}
                         for label,text in [("before",before),("after",after)]},
        numbers_sha256=hashlib.sha256(method(room,"numbers").encode()).hexdigest(),
        production_compiled=False, component_executed=False, performance_qualified=False,
        runtime_stub_limit="Only public slot kinds/hierarchy used by this test; no native world/constructors/third-party modules")
    write("extraction.json", json.dumps(metadata, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(dict(changed_tables=1, added_fields=len(added), native_defense_fields=len(FIELDS), source_sha256=sha(HERE/"src/rconnect/game/GameBridge.as"))))


if __name__ == "__main__":
    main()
