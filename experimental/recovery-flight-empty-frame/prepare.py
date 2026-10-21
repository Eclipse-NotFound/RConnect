"""Create only this isolated fixture overlay; no compiler/runtime/deployment."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "recovery-tests" / "continuity-extra"
PINNED = {
    "NativeFlightContinuityTestDoc.as": "e530e573a67a4e0ed6c5d231be9c134806de999b677adf5b4c1bae12ff26c5bf",
    "analyze.py": "33f031f53db510ea7d2efae188397c811e93ea0d49f66a19747c2687805fde00",
}


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected one replacement: {old[:100]}")
    return text.replace(old, new, 1)


def main():
    original = {}
    for name, expected in PINNED.items():
        data = (BASE / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(f"Frozen input mismatch: {name}")
        original[name] = data.decode("utf-8-sig").replace("\r\n", "\n")
    driver = original["NativeFlightContinuityTestDoc.as"]
    driver = replace_once(driver,
        '         var hit:Rectangle=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));\n',
        '         var hit:Rectangle=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));\n'
        '         var screen:Object={x:r.x,y:r.y,w:r.width,h:r.height},emptyBounds:Boolean=NativeFlightBounds.empty(screen);\n')
    driver = replace_once(driver,
        '            screen:{x:r.x,y:r.y,w:r.width,h:r.height}};',
        '            screen:screen,emptyBounds:emptyBounds,outsideViewport:!emptyBounds && !(hit.width>0 && hit.height>0)};')
    driver = replace_once(driver,
        '         var result:Object={source:ss,remote:rs,sourceFlight:sf,remoteFlight:rf,sourceContact:sc,remoteContact:rc,',
        '         var viewportEvidence:Object=NativeFlightBounds.evaluate(nativeFrames,frames);\n'
        '         var result:Object={source:ss,remote:rs,sourceFlight:sf,remoteFlight:rf,sourceContact:sc,remoteContact:rc,viewportEvidence:viewportEvidence,')
    driver = replace_once(driver,
        '         check(pixelProof!=null && pixelProof.pixels>0 && rs.offscreen==0,"remote final-composite native artwork "+JSON.stringify(pixelProof)+" offscreen="+rs.offscreen);',
        '         check(pixelProof!=null && pixelProof.pixels>0 && viewportEvidence.passed,"remote final-composite native artwork "+JSON.stringify(pixelProof)+" rawOffscreen="+rs.offscreen+" viewportEvidence="+JSON.stringify(viewportEvidence));')
    analyzer = original["analyze.py"]
    analyzer = replace_once(analyzer, 'from pathlib import Path\n', 'from pathlib import Path\n\nimport bounds_evidence\n')
    analyzer = replace_once(analyzer, '    checks = {\n', '    viewport_evidence = bounds_evidence.evaluate(sr, rr)\n    checks = {\n')
    analyzer = replace_once(analyzer,
        '        "all_remote_samples_in_viewport": rs["offscreen"] == 0,',
        '        "all_remote_samples_in_viewport": viewport_evidence["passed"],')
    analyzer = replace_once(analyzer,
        '                metadata_roundtrip_ulps=roundtrips,',
        '                viewport_evidence=viewport_evidence,metadata_roundtrip_ulps=roundtrips,')
    analyzer = replace_once(analyzer,
        'inputs={str(p.resolve()): digest(p) for p in (args.host_log, args.join_log, Path(__file__))}',
        'inputs={str(p.resolve()): digest(p) for p in (args.host_log, args.join_log, Path(__file__), Path(bounds_evidence.__file__))}')
    outputs = {"NativeFlightContinuityTestDoc.as": driver, "analyze.py": analyzer}
    differences = []
    for name, source in outputs.items():
        (HERE / name).write_text(source, encoding="utf-8", newline="\n")
        differences.extend(difflib.unified_diff(original[name].splitlines(True), source.splitlines(True),
                           fromfile=f"continuity-extra/{name}", tofile=f"recovery-flight-empty-frame/{name}"))
    (HERE / "fixture.patch").write_text("".join(differences), encoding="utf-8")
    (HERE / "inputs.json").write_text(json.dumps({"baseline": str(BASE), "source_sha256": PINNED,
        "status": "source only; AIR/JVM not run; historical failures preserved",
        "outputs": {name: hashlib.sha256((HERE / name).read_bytes()).hexdigest()
                    for name in (*outputs, "NativeFlightBounds.as", "bounds_evidence.py")}}, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"output": str(HERE), "overrides": list(outputs), "production_modified": False}))


if __name__ == "__main__":
    main()
