"""Prepare two unchanged component suites against the same combined real class."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError("Assertions are required")
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WIV = "rconnect/game/WallImpactVisuals.as"
SOURCES = {
    "c6a3": ("build/m52/recovery-ordinary-wall-sv-production-01/src/" + WIV, "12682bff279d35d3dc2181d4832a9d948f9ee68fcfdcf5188ee53dec2c91ff72"),
    "ack_only": ("experimental/recovery-ordinary-wall-ack-flush/src/" + WIV, "2c2b607a94b86922f5fc07021c45337d55bb4856e42d9f8ac2ae4eaae7737c95"),
    "decode_only": ("experimental/recovery-ordinary-wall-decode-reject/src/" + WIV, "b87c0584d233dfd806192aca1dcea437e514bb972acda8f9ff669a7cff2f8f2b"),
}
SUITES = {
    "components20": ("build/m52/recovery-ordinary-wall-ack-component-01", "e3d7393026eb7d2f882403d1270aa59dda79b59d9a0e5095b5c69b9f037d9a76", "457a39ef3195c960544b4739fa728189391c80bb0c0c3b8fe981982f528f60d1", 20),
    "components153": ("build/m52/recovery-ordinary-wall-sv-component-02", "f37acbaff091522b744bd72cbfce3e4c0a5c4b455637b686d4c33e455d03deda", "a148bc5fcfeca83e10f99a8313e19ad6c19fc3e6d3f104306adfbbf930da02b8", 153),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob("*")) if p.is_file()}


def verify():
    meta = json.loads((HERE / "manifest.json").read_text(encoding="utf8"))
    for group in (meta["inputs"], meta["outputs"]):
        for name, digest in group.items():
            assert sha(Path(name)) == digest, name
    for name, spec in meta["suites"].items():
        actual = inventory(HERE / name)
        assert set(actual) == set(spec["original_files"])
        assert {k: v for k, v in actual.items() if k != WIV} == {k: v for k, v in spec["original_files"].items() if k != WIV}
        assert actual[WIV] == meta["combined_sha256"]
    print(json.dumps({"verified": True, "combined_sha256": meta["combined_sha256"], "compiled": False, "air_started": False}))


def prepare():
    assert not (HERE / "manifest.json").exists()
    assert not any((HERE / p).exists() for p in ("src", "components20", "components153"))
    inputs, texts = {}, {}
    for name, (relative, digest) in SOURCES.items():
        path = ROOT / relative
        assert sha(path) == digest, name
        inputs[str(path)] = digest
        texts[name] = path.read_text(encoding="utf8")
    before = '            var words:Array=decodeWords(String(c.d));if(words==null)return null;'
    after = '''            var words:Array;
            // A malformed legacy compressed cell is a rejected packet, not
            // an uncaught exception in the socket message handler.
            try {words=decodeWords(String(c.d));}
            catch(decodeError:Error) {return null;}
            if(words==null)return null;'''
    assert texts["c6a3"].count(before) == texts["ack_only"].count(before) == 1
    assert texts["c6a3"].replace(before, after) == texts["decode_only"]
    combined = texts["ack_only"].replace(before, after)
    raw = combined.replace("\n", "\r\n").encode("utf8")
    outputs = {"src/" + WIV: raw}
    for name, original in texts.items():
        patch = "".join(difflib.unified_diff(original.splitlines(True), combined.splitlines(True), name + "/" + WIV, "combined/" + WIV))
        outputs[name + "-to-combined.diff"] = patch.encode("utf8")
    suites = {}
    for name, (relative, intent_sha, result_sha, expected) in SUITES.items():
        source = ROOT / relative
        assert sha(source / "intent.json") == intent_sha
        assert sha(source / "component-result.json") == result_sha
        intent = json.loads((source / "intent.json").read_text(encoding="utf8"))
        original_files = inventory(source / "src")
        assert original_files == intent["sources"]
        assert intent["expected"] == expected
        for rel, digest in original_files.items():
            path = source / "src" / rel
            inputs[str(path)] = digest
            outputs[name + "/" + rel] = raw if rel == WIV else path.read_bytes()
        inputs[str(source / "intent.json")] = intent_sha
        inputs[str(source / "component-result.json")] = result_sha
        suites[name] = dict(source=str(source / "src"), original_files=original_files,
                            entry=intent["entry"], expected=expected, assertions_changed=False)
    for name, content in outputs.items():
        path = HERE / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as stream:
            stream.write(content)
    outputs = {str(HERE / name): sha(HERE / name) for name in outputs}
    for name in ("prepare.py", "README.md"):
        outputs[str(HERE / name)] = sha(HERE / name)
    meta = dict(origins={k: dict(path=str(ROOT / p), sha256=h) for k, (p, h) in SOURCES.items()},
                inputs=inputs, outputs=outputs, suites=suites, combined_sha256=hashlib.sha256(raw).hexdigest(),
                compiled=False, air_started=False, installed=False, session_transport_tested=False, performance_qualified=False)
    with (HERE / "manifest.json").open("x", encoding="utf8", newline="\n") as stream:
        json.dump(meta, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    verify()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    verify() if args.verify else prepare()
