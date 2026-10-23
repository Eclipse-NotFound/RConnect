"""Separate malformed-cell rejection proposal; no ACK scheduling changes."""
from pathlib import Path
import difflib
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError("Assertions are required")
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-ordinary-wall-sv-production-01/src/rconnect/game/WallImpactVisuals.as"
PIN = "12682bff279d35d3dc2181d4832a9d948f9ee68fcfdcf5188ee53dec2c91ff72"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert sha(BASE) == PIN
assert not (HERE / "src").exists() and not (HERE / "manifest.json").exists()
old = BASE.read_text(encoding="utf8")
before = '            var words:Array=decodeWords(String(c.d));if(words==null)return null;'
after = '''            var words:Array;
            // A malformed legacy compressed cell is a rejected packet, not
            // an uncaught exception in the socket message handler.
            try {words=decodeWords(String(c.d));}
            catch(decodeError:Error) {return null;}
            if(words==null)return null;'''
assert old.count(before) == 1
new = old.replace(before, after)
target = HERE / "src/rconnect/game/WallImpactVisuals.as"
target.parent.mkdir(parents=True)
with target.open("xb") as stream:
    stream.write(new.replace("\n", "\r\n").encode("utf8"))
patch = "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                "C6A3/rconnect/game/WallImpactVisuals.as", "decode-reject/rconnect/game/WallImpactVisuals.as"))
with (HERE / "source.diff").open("x", encoding="utf8", newline="\n") as stream:
    stream.write(patch)
manifest = {
    "base": str(BASE), "base_sha256": PIN,
    "files": {name: sha(HERE / name) for name in ("src/rconnect/game/WallImpactVisuals.as", "source.diff", "prepare.py", "README.md")},
    "compiled": False, "air_started": False, "combined_with_ack_flush": False,
    "issue": "ordinaryDecode lets malformed legacy compressed cell exceptions escape the socket listener",
}
with (HERE / "manifest.json").open("x", encoding="utf8", newline="\n") as stream:
    json.dump(manifest, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps({"prepared": True, "sha256": sha(target), "combined_with_ack_flush": False}))
