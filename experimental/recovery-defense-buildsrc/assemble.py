"""AS-only recovery20 assembly: exact19 plus one reviewed table and version."""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-19"
PROPOSAL = ROOT / "experimental/recovery-unit-defense-read"
RUN = ROOT / "build/m52/recovery-unit-defense-component-01"
VERSION = "0.2.24-recovery20"
BASE_ID = "b9cd3f4800f2e875439b19f9d18969fd195ed039c992df3b0625cf0cf2dfeea5"
COMPONENT_ID = "9f1710742b48c158c9da6b824f3bfad75d25810ab14ecf091433aa69d7d4c4a5"
BRIDGE = "rconnect/game/GameBridge.as"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob("*.as"))}


def main():
    assert not (HERE/"src").exists() and not (HERE/"integration.json").exists(), "Do not overwrite a frozen assembly"
    prepared = read(BASE/"prepared.json")
    ancestor = read(BASE/"integration.json")
    sources = inventory(BASE/"src")
    assert prepared["compiled"] is True and prepared["sha256"] == BASE_ID
    assert prepared["version"] == ancestor["version"] == "0.2.24-recovery19"
    assert sources == prepared["source"] == {r["path"]:r["sha256"] for r in ancestor["source"]}
    assert len(sources) == 90 and not ancestor["static_errors"]

    receipt = read(RUN/"receipt.json")
    raw = read(RUN/"component-result.json")
    intent = read(RUN/"intent.json")
    assert receipt["passed"] and receipt["compiled"] and receipt["air_started"] and receipt["exit_code"] == 0
    assert receipt["observed_checks"] == intent["expected"] == 81 and receipt["checks_failed"] == 0
    assert receipt["installation_unchanged"] and receipt["source_unchanged"]
    assert receipt["component_sha256"] == COMPONENT_ID
    assert raw["passed"] and raw["failed"] == 0 and len(raw["assertions"]) == 81
    assert all(r["passed"] is True for r in raw["assertions"])
    assert inventory(PROPOSAL/"components") == intent["sources"] == inventory(RUN/"src")
    assert not raw["nativeWorld"] and not raw["performanceQualified"]
    bench = raw["benchmarks"]
    assert [r["label"] for r in bench] == ["A1","B1","B2","A2"]
    assert [r["nativeMs"] for r in bench] == [517,275,273,549]
    assert [r["genericMs"] for r in bench] == [242,232,238,260]
    assert all(r["iterations"]==20000 and r["genericIterations"]==10000 for r in bench)

    overlay = PROPOSAL/"src"/BRIDGE
    extraction = read(PROPOSAL/"extraction.json")
    assert sources[BRIDGE] == extraction["bridge_sha256"]
    old = (BASE/"src"/BRIDGE).read_bytes()
    proposed = overlay.read_bytes()
    pattern = rb"private static const NATIVE_UNIT_FIELDS:Object=\{.*?\};"
    old_table = re.search(pattern,old,re.S)[0]
    proposed_table = re.search(pattern,proposed,re.S)[0]
    # The sparse proposal was saved with LF; frozen19 uses CRLF. Compare its
    # text delta, then insert only the table with frozen19's original newline.
    normalize = lambda b:b.replace(b"\r\n",b"\n")
    assert normalize(proposed.replace(proposed_table,old_table)) == normalize(old), "Proposal changes anything beyond this table"
    newline = b"\r\n" if b"\r\n" in old else b"\n"
    new_table = normalize(proposed_table).replace(b"\n",newline)
    old_names = re.findall(rb"(\w+):true",old_table)
    new_names = re.findall(rb"(\w+):true",new_table)
    assert new_names == old_names + [n.encode() for n in extraction["added_fields"]]
    assert len(extraction["added_fields"]) == 18

    inputs = [Path(__file__), BASE/"prepared.json", BASE/"integration.json", PROPOSAL/"source-manifest.json",
              PROPOSAL/"extraction.json", overlay, RUN/"receipt.json", RUN/"component-result.json", RUN/"intent.json"]
    inputs += [BASE/"src"/name for name in sources]
    inputs += [PROPOSAL/"components"/name for name in intent["sources"]]
    frozen = {str(p.resolve()):sha(p) for p in inputs}
    output = {name:(BASE/"src"/name).read_bytes() for name in sources}
    output[BRIDGE] = old.replace(old_table,new_table,1)
    version_old = b'VERSION:String = "0.2.24-recovery19"'
    version_new = b'VERSION:String = "0.2.24-recovery20"'
    assert output["RConnectMod.as"].count(version_old) == 1
    output["RConnectMod.as"] = output["RConnectMod.as"].replace(version_old,version_new,1)
    changed = [name for name,data in output.items() if digest(data) != sources[name]]
    assert set(changed) == {BRIDGE,"RConnectMod.as"}
    assert sum(data == (BASE/"src"/name).read_bytes() for name,data in output.items()) == 88
    assert output[BRIDGE].replace(new_table,old_table) == old
    assert output["RConnectMod.as"].replace(version_new,version_old) == (BASE/"src/RConnectMod.as").read_bytes()

    for name,data in output.items():
        dest=HERE/"src"/name
        assert dest.suffix == ".as"
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(data)
    assert inventory(HERE/"src") == {name:digest(data) for name,data in output.items()}
    assert sources == inventory(BASE/"src")
    assert frozen == {str(p.resolve()):sha(p) for p in inputs}, "Inputs changed during AS assembly"
    manifest = dict(version=VERSION,baseline="build/m52/recovery-19",baseline_sha256=BASE_ID,
        baseline_manifest_sha256=sha(BASE/"prepared.json"),ancestor_integration_sha256=sha(BASE/"integration.json"),
        input_sources=frozen,source=[dict(path=n,sha256=digest(b)) for n,b in sorted(output.items())],
        static_errors=[],changed=changed,added=[],unchanged_class_count=88,complete_class_count=90,
        functional_delta="18 verified native public variables added to existing Unit fast table; no method/call-site changes",
        version_only="RConnectMod.as",component=dict(receipt=str((RUN/"receipt.json").resolve()),
        receipt_sha256=sha(RUN/"receipt.json"),result_sha256=sha(RUN/"component-result.json"),
        component_sha256=COMPONENT_ID,assertions=81,failures=0,native_abba_ms=[r["nativeMs"] for r in bench],
        generic_abba_ms=[r["genericMs"] for r in bench],native_iterations=20000,generic_iterations=10000,
        native_game_tested=False,performance_qualified=False),compiled=False,native_game_tested=False,
        performance_qualified=False,installed=False,diagnostic_only=False)
    (HERE/"integration.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(version=VERSION,classes=90,unchanged=88,changed=changed,
                          integration_sha256=sha(HERE/"integration.json"),bridge_sha256=digest(output[BRIDGE]))))


if __name__ == "__main__":
    main()
