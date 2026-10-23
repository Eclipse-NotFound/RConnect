"""Materialize only an isolated three-class ACK-flush proposal. No compiler/AIR."""
import argparse
import difflib
import hashlib
import json
import sys
from pathlib import Path

if sys.flags.optimize:
    raise RuntimeError("Assertions are required")
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-ordinary-wall-sv-production-01/src"
PINS = {
    "rconnect/game/WallImpactVisuals.as": "12682bff279d35d3dc2181d4832a9d948f9ee68fcfdcf5188ee53dec2c91ff72",
    "rconnect/game/GameBridge.as": "10d0b43f988d86dc4f2d0fdd5848f451f94aef47eaed49ee42132f356e75e88a",
    "rconnect/core/Session.as": "e699b9c5a02799367bba8afd924d450d064cab3f0a5e9a36ea7d400b378b10ba",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace(text, old, new):
    assert text.count(old) == 1, old[:120]
    return text.replace(old, new)


def modify(name, text):
    if name.endswith("WallImpactVisuals.as"):
        start = text.index("      public function acknowledge(loc:Object,receipt:Object):void")
        end = text.index("      /** Only changed cell revisions", start)
        section = text[start:end]
        section = replace(section, "):void", "):Boolean")
        section = replace(section, "if(ordinary(loc)){ordinaryAck(loc,receipt);return;}",
                          "if(ordinary(loc))return ordinaryAck(loc,receipt);")
        section = section.replace("return;", "return false;")
        section = replace(section, "s.pending=null;put(loc,decoded,true,false);",
                          "s.pending=null;put(loc,decoded,true,false);\n         // Large-scene ACK behavior stays unchanged; no accelerated drain.\n         return false;")
        text = text[:start] + section + text[end:]
        start = text.index("      private function ordinaryAck(loc:Object,receipt:Object):void")
        end = text.index("      private function ordinaryList", start)
        section = text[start:end].replace("):void", "):Boolean", 1).replace("return;", "return false;")
        section = replace(section, "ordinaryCompose(loc,touched);", "ordinaryCompose(loc,touched);\n         return true;")
        return text[:start] + section + text[end:]
    if name.endswith("GameBridge.as"):
        return replace(text,
            "      public function acknowledgeTiles(receipt:Object):void {\n         if(receipt==null)return;\n         if(receipt.seq!=null)_terrain.acknowledge(loc,receipt);\n         if(receipt.wallReceipt!=null)_wall.acknowledge(loc,receipt.wallReceipt);\n      }",
            "      /** True only when this ACK retired an ordinary wall batch. */\n      public function acknowledgeTiles(receipt:Object):Boolean {\n         if(receipt==null)return false;\n         if(receipt.seq!=null)_terrain.acknowledge(loc,receipt);\n         return receipt.wallReceipt!=null && _wall.acknowledge(loc,receipt.wallReceipt);\n      }")
    text = replace(text, "      private var _nextSceneReport:int=0;",
                   "      private var _nextSceneReport:int=0;\n      private var _wallAckFlushing:Boolean=false;")
    text = replace(text, "               if(sameHostRoom(msg)) mod.game.acknowledgeTiles(msg);",
                   "               if(sameHostRoom(msg) && mod.game.acknowledgeTiles(msg))flushWallAfterAck(msg);")
    helper = """      /** Use only the opportunity opened by a genuinely retired wall batch.
       * Do not rescan damage, mines, terrain, loot or containers here. */
      private function flushWallAfterAck(receipt:Object):void
      {
         if(_wallAckFlushing || mode!=CONNECTED || mod.game==null || link==null
            || !link.isOpen || link.socket==null || !link.socket.connected
            || !rooms.canSyncWorld || rooms.authority || !sameHostRoom(receipt)
            || mod.game.isTransitioning())return;
         _wallAckFlushing=true;
         try
         {
            var info:Object=mod.game.readWorldInfo();
            if(info==null)return;
            var report:Object=mod.game.scanWallReports();
            if(report==null)return;
            report.worldInfo=info;
            link.send(rooms.stamp(Protocol.make(Protocol.MSG_TERRAIN,report)));
         }
         finally {_wallAckFlushing=false;}
      }

"""
    return replace(text, "      public function flushRoomReports(scene:Boolean=true,closing:Boolean=false):void", helper + "      public function flushRoomReports(scene:Boolean=true,closing:Boolean=false):void")


def verify():
    data = json.loads((HERE / "manifest.json").read_text(encoding="utf8"))
    for name, digest in data["base"].items():
        assert sha(BASE / name) == digest, name
    for name, digest in data["files"].items():
        assert sha(HERE / name) == digest, name
    print(json.dumps({"verified": True, "files": len(data["files"]), "compiled": False}))


def prepare():
    assert not (HERE / "src").exists() and not (HERE / "manifest.json").exists()
    for name, digest in PINS.items():
        assert sha(BASE / name) == digest, name
    outputs, diff = {}, []
    for name in PINS:
        original = (BASE / name).read_text(encoding="utf8")
        modified = modify(name, original)
        outputs["src/" + name] = modified.replace("\n", "\r\n").encode("utf8")
        diff.extend(difflib.unified_diff(original.splitlines(True), modified.splitlines(True),
                    "C6A3/" + name, "proposal/" + name))
    component_base = ROOT / "experimental/recovery-ordinary-wall-sv/components"
    names = ["fe/graph/Grafon.as", "fe/weapon/Bullet.as", "rconnect/core/Log.as",
             "rconnect/game/GameBridge.as", "rconnect/game/NativeWallColor.as"]
    dependencies = {}
    for name in names:
        source = component_base / name
        dependencies[str(source)] = sha(source)
        outputs["components/" + name] = source.read_bytes()
    for name in ("rconnect/game/WallSurfaceBridge.as", "rconnect/net/RoomCodec.as", "rconnect/net/WallCellCodec.as"):
        dependencies[str(BASE / name)] = sha(BASE / name)
        outputs["components/" + name] = (BASE / name).read_bytes()
    outputs["components/rconnect/game/WallImpactVisuals.as"] = outputs["src/rconnect/game/WallImpactVisuals.as"]
    outputs["source.diff"] = "".join(diff).encode("utf8")
    for name, content in outputs.items():
        target = HERE / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(content)
    files = {name: sha(HERE / name) for name in outputs}
    for name in ("prepare.py", "components/WallAckChecks.as", "README.md"):
        files[name] = sha(HERE / name)
    data = {"base": PINS, "dependencies": dependencies, "files": files,
            "compiled": False, "air_started": False, "performance_qualified": False}
    (HERE / "manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    verify()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    verify() if args.verify else prepare()
