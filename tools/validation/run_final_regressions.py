"""Serial joint-candidate checks; --list only prints the preparation plan."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/m46/final"
JAVA = "C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe"
CHECKS = {
    "TelekinesisMotionTestDoc": (600, "random_mane", True),
    "TelekinesisTestDoc": (180, "random_mane", False),
    "EnemyGrabTestDoc": (280, "random_mane", False),
    "LightningSmartTestDoc": (180, "random_mane", False),
    "BeamTerrainTestDoc": (180, "random_mane", False),
    "SatsTestDoc": (180, "random_mane", False),
    "CoopPauseTestDoc": (300, "random_mane", False),
    "RoomCooperationTestDoc": (300, "random_mane", False),
    "ProjectileNetworkTestDoc": (180, "", False),
    "CombatNetworkTestDoc": (220, "", False),
    "AnimationGapsTestDoc": (180, "", False),
    "GameplayNetworkTestDoc": (280, "", False),
    "MirrorMaskRestoreTestDoc": (180, "random_mane", False),
    "SlowTravelTestDoc": (360, "", False),
    "TeammateNavigationTestDoc": (240, "random_mane", False),
}
REQUIRED = list(CHECKS)[:13]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("entries", nargs="*", choices=list(CHECKS))
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--snapshot", type=Path, default=OUT)
    parser.add_argument("--host-save-template", type=Path)
    parser.add_argument("--join-save-template", type=Path)
    args = parser.parse_args()
    OUT=args.snapshot.resolve()
    assert OUT.parent==ROOT/'build/m46' and OUT.name.startswith('final'),OUT
    if args.list:
        print(json.dumps({"status": "serial-joint-candidate-validation", "required": REQUIRED,
                          "checks": CHECKS, "snapshot": str(OUT), "UI": "design preview only"}, indent=2))
        return
    if not args.entries:
        parser.error("Explicit entries required; list the preparation plan with --list")

    manifest = read(OUT / "source-input.json")
    verification = read(OUT / "verified-test-input.json")
    candidate = OUT / "RConnectMod.swf"

    def verify():
        assert sha(candidate) == manifest["candidate_sha256"]
        for name, digest in manifest["source"].items():
            assert sha(ROOT / name) == digest, name
            assert sha(OUT / name) == digest, name
        for name, digest in verification.items():
            assert sha(ROOT / name) == digest, name
        installed = read(ROOT / "build/m46/integration-baseline/inputs.json")
        for name, digest in installed["protected"].items():
            assert sha(ROOT.parents[1] / name) == digest, name

    verify()
    actual = {line.split()[0] for line in (OUT / "classes.txt").read_text(encoding="utf-8-sig").splitlines() if line.strip()}
    expected = {source.relative_to(OUT / "src").with_suffix("").as_posix().replace("/", ".")
                for source in (OUT / "src").rglob("*.as")}
    assert actual == expected, (expected - actual, actual - expected)

    for entry in args.entries:
        seconds, land, profiles = CHECKS[entry]
        verify()
        profile_args = []
        if profiles:
            for role, profile in (("host", args.host_save_template), ("join", args.join_save_template)):
                assert profile is not None, "Frozen real profiles required for motion/lifecycle"
                path = profile.resolve()
                assert path.is_relative_to(OUT / "profiles"), path
                key = path.relative_to(ROOT).as_posix()
                assert key in verification and sha(path) == verification[key], key
                profile_args += ["--" + role + "-save-template", str(path)]
            profile_args.append("--connect-after-load")
        driver = OUT / (entry + "-driver")
        assert not driver.exists(), "Do not overwrite a previous driver or failed attempt"
        command = [sys.executable, str(ROOT / "tools/build_effects_driver.py"), "--candidate", str(candidate),
                   "--source-root", str(OUT / "src"), "--java", JAVA, "--output", str(driver), "--entry", entry]
        print("BUILD " + entry, flush=True)
        with (OUT / (entry + "-build.log")).open("w", encoding="utf-8") as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        verify()
        command = [sys.executable, str(ROOT / "tools/run_coop_regression.py"), "--candidate", str(candidate),
                   "--effects-driver", str(driver), "--effects", "--all-mods", "--responsive",
                   "--seconds", str(seconds), "--expected-version", manifest["version"]] + profile_args
        if land:
            command += ["--land", land]
        print("RUN " + entry, flush=True)
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        (OUT / (entry + "-runner.log")).write_text(result.stdout + "\n" + result.stderr, encoding="utf-8")
        found = re.search(r"OUTPUT .*?([0-9a-f]{10})\s*$", result.stdout, re.M)
        record = {"entry": entry, "run": found.group(1) if found else None, "exit": result.returncode}
        if entry == "MirrorMaskRestoreTestDoc" and record["run"]:
            sys.path.insert(0, str(ROOT / "tools"))
            from verify_mask_png import inspect
            folder = ROOT / "build/cooperation" / record["run"]
            images = [inspect(folder / (role + "-presentation-mask-restore-" + str(case) + "-leave.png"))
                      for role in ("host", "join") for case in range(7)]
            (OUT / "mask-scene-check.json").write_text(json.dumps(images, indent=2), encoding="utf-8")
            record["runner_exit"] = result.returncode
            record["white_blocks"] = [item for item in images if item["white_block"] is not None]
            if record["white_blocks"]:
                record["exit"] = 1
        (OUT / (entry + "-result.json")).write_text(json.dumps(record, indent=2), encoding="utf-8")
        print(json.dumps(record), flush=True)
        if record["exit"]:
            print(result.stdout[-6000:] + result.stderr[-1500:], flush=True)
            raise SystemExit(record["exit"])
        verify()
    print("REQUESTED JOINT REGRESSIONS PASS", flush=True)


if __name__ == "__main__":
    main()
