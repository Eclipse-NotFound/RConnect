"""Standalone AS3 calculation replay; never loads Remains or changes release.

Run both exact current TerrainSync and a renamed immutable baseline. Separate
counter-only copies count snapshot objects (not wall-clock performance). The
unused native checkpoint adapter throws, so this cannot validate native saves,
collision, rendering or network timing.
Motion cases contain neither weapons nor teleport events; those boundaries
fail immediately if accidentally exercised instead of simulating game effects.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
SDK = Path("D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk")
JAVA = "C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--baseline", required=True, help="Immutable source snapshot within build/")
    ap.add_argument("--output", required=True, help="New output directory within build/")
    args = ap.parse_args()
    baseline = (ROOT / args.baseline).resolve()
    out = (ROOT / args.output).resolve()
    assert baseline.is_relative_to(ROOT / "build") and baseline != ROOT / "build"
    assert out.is_relative_to(ROOT / "build") and out != ROOT / "build"
    assert not out.exists(), "Retain previous results; select a new output directory"
    manifest = json.loads((baseline / "source-input.json").read_text(encoding="utf-8-sig"))
    name = "src/rconnect/game/TerrainSync.as"
    assert sha(baseline / name) == manifest["source"][name], "Baseline source changed"
    release_before = sha(ROOT / "release/RConnectMod.swf")
    out.mkdir(parents=True)
    src = out / "src"
    current = (ROOT / name).read_text(encoding="utf-8-sig")
    previous = (baseline / name).read_text(encoding="utf-8-sig")
    inputs = {name: sha(ROOT / name), str(baseline.relative_to(ROOT) / name): sha(baseline / name),
              "src/rconnect/game/RemoteMotion.as": sha(ROOT / "src/rconnect/game/RemoteMotion.as")}

    def terrain(text, package, class_name, counted=False):
        assert text.count("package rconnect.game") == 1
        assert text.count("public class TerrainSync") == 1
        text = text.replace("package rconnect.game", "package " + package)
        text = text.replace("public class TerrainSync", "public class " + class_name)
        if counted:
            declaration = "      private var room:Object;"
            body = "      private function state(t:Object,x:int,y:int):Object\n      {"
            assert text.count(declaration) == text.count(body) == 1
            text = text.replace(declaration, "      public static var snapshotAllocations:int=0;\n" + declaration)
            text = text.replace(body, body + "\n         snapshotAllocations++;")
        directory = src / package.replace(".", "/")
        directory.mkdir(parents=True, exist_ok=True)
        (directory / (class_name + ".as")).write_text(text, encoding="utf-8")
        # A throwing adapter makes the deliberately untested boundary explicit.
        (directory / "NativeRoomState.as").write_text(
            "package " + package + " { public class NativeRoomState {"
            'public static function scalars(t:Object):Object {throw new Error("Native checkpoint outside fixed replay");}'
            'public static function restore(t:Object,s:Object):void {throw new Error("Native checkpoint outside fixed replay");}'
            "}}", encoding="utf-8")

    terrain(current, "rconnect.game", "TerrainSync")
    # Preserve even the original line endings for the production code under test.
    shutil.copy2(ROOT / name, src / "rconnect/game/TerrainSync.as")
    terrain(previous, "rconnect.baseline", "BaselineTerrainSync")
    terrain(previous, "rconnect.countedBefore", "CountedTerrainBefore", counted=True)
    terrain(current, "rconnect.countedAfter", "CountedTerrainAfter", counted=True)
    assert sha(src / "rconnect/game/TerrainSync.as") == sha(ROOT / name), "Exact current source required"
    shutil.copy2(ROOT / "src/rconnect/game/RemoteMotion.as", src / "rconnect/game/RemoteMotion.as")
    (src / "rconnect/game/TeleportVisuals.as").write_text(
        "package rconnect.game { public class TeleportVisuals {"
        "public static function split(a:Object,b:Object,t:Number):Object {"
        'if((a!=null && a.port!=null)||(b!=null && b.port!=null))throw new Error("Teleport outside fixed replay");'
        "return null;}}}", encoding="utf-8")
    (src / "rconnect/game/WeaponDisplay.as").write_text(
        "package rconnect.game { public class WeaponDisplay {"
        'public static function interpolate(a:Array,b:Array,t:Number):Array {throw new Error("Weapon outside fixed replay");}'
        "}}", encoding="utf-8")
    for test in ("TerrainRegression", "TerrainFixedReplayDoc", "HeldMotionBufferRegression", "DropMotionBurstRegression", "NativeEffectRateRegression"):
        path = ROOT / "tests" / (test + ".as")
        inputs[str(path.relative_to(ROOT))] = sha(path)
        shutil.copy2(path, src / path.name)
    inputs[str(Path(__file__).relative_to(ROOT))] = sha(Path(__file__))
    receipt = dict(kind="standalone-fixed-replay", game_loaded=False, inputs=inputs,
                   excluded_boundaries=["native checkpoint", "native rendering/collision", "network timing", "teleport events", "weapons"],
                   baseline_manifest_sha256=sha(baseline / "source-input.json"),
                   copied_sources={str(p.relative_to(out)): sha(p) for p in src.rglob("*.as")},
                   release_before=release_before, status="prepared")
    save(out / "receipt.json", receipt)

    cmd = [JAVA, "-Xmx256m", "-jar", str(SDK / "lib/mxmlc.jar"), "+configname=air",
           "+flexlib=" + str(SDK / "frameworks"), "-swf-version=38", "-debug=true",
           "-source-path=" + str(src), "-output=" + str(out / "TerrainFixedReplay.swf"),
           str(src / "TerrainFixedReplayDoc.as")]
    with (out / "build.log").open("wb") as log:
        built = subprocess.run(cmd, env=dict(os.environ, AIR_HOME=str(SDK)), stdout=log, stderr=subprocess.STDOUT)
    receipt["build_exit"] = built.returncode
    save(out / "receipt.json", receipt)
    if built.returncode:
        raise SystemExit("Replay build failed; inspect retained build.log")

    appid = "rconnect-fixed-terrain-" + uuid.uuid4().hex[:12]
    descriptor = out / "application.xml"
    descriptor.write_text('<?xml version="1.0" encoding="utf-8"?>'
                          '<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid + '</id>'
                          '<versionNumber>1.0.0</versionNumber><filename>TerrainFixedReplay</filename>'
                          '<initialWindow><content>TerrainFixedReplay.swf</content><visible>false</visible>'
                          '</initialWindow></application>', encoding="utf-8")
    receipt.update(appid=appid, swf_sha256=sha(out / "TerrainFixedReplay.swf"), status="running")
    save(out / "receipt.json", receipt)
    with (out / "adl.log").open("wb") as log:
        proc = subprocess.Popen([str(GAME / "adl64.exe"), "-runtime", str(GAME / "runtimes/air/win64"), str(descriptor)],
                                cwd=out, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        receipt["pid"] = proc.pid
        save(out / "receipt.json", receipt)
        try:
            code = proc.wait(timeout=45)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            receipt["status"] = "timeout"
            raise
        finally:
            receipt.update(owned_process_exited=proc.poll() is not None, exit=proc.returncode,
                           release_after=sha(ROOT / "release/RConnectMod.swf"))
            save(out / "receipt.json", receipt)
    result_path = Path(os.environ["APPDATA"]) / appid / "Local Store/result.json"
    shutil.copy2(result_path, out / "result.json")
    result = json.loads(result_path.read_text(encoding="utf-8-sig"))
    assert release_before == receipt["release_after"], "Installed release changed"
    receipt.update(result_sha256=sha(out / "result.json"), status="passed" if code == 0 and result["failures"] == 0 else "failed")
    save(out / "receipt.json", receipt)
    print(json.dumps({k: v for k, v in result.items() if k != "checks"}, ensure_ascii=False))
    for check in result["checks"]:
        if not check["pass"]:
            print(json.dumps(check, ensure_ascii=False))
    raise SystemExit(0 if receipt["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
