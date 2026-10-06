import datetime
import argparse
import hashlib
import json
import re
from pathlib import Path
from run_final_regressions import required_entries
from validation_baseline import verify_protected, read_baseline

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
OUT = ROOT / "build/m46/final"
parser=argparse.ArgumentParser()
parser.add_argument('--snapshot',type=Path,default=OUT)
OUT=parser.parse_args().snapshot.resolve()
assert OUT.parent==ROOT/'build/m46' and OUT.name.startswith('final'),OUT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


manifest = read(OUT / "source-input.json")
REQUIRED = required_entries(manifest)
verify_protected(manifest)
candidate_sha = manifest["candidate_sha256"]
assert sha(OUT / "RConnectMod.swf") == candidate_sha
assert sha(ROOT / "build/GameCombatStubs.swc") == sha(OUT / "GameCombatStubs.swc") == manifest["stub_sha256"]
for name, digest in manifest["source"].items():
    assert sha(ROOT / name) == sha(OUT / name) == digest, name
verification = read(OUT / "verified-test-input.json")
for name, digest in verification.items():
    assert sha(ROOT / name) == digest, name
actual = {line.split()[0] for line in (OUT / "classes.txt").read_text(encoding="utf-8-sig").splitlines() if line.strip()}
expected = {source.relative_to(OUT / "src").with_suffix("").as_posix().replace("/", ".") for source in (OUT / "src").rglob("*.as")}
assert actual == expected and len(actual) == manifest["classes"]
assert "DEBUG-mask-restore" not in (OUT / "src/rconnect/game/MirrorMasks.as").read_text(encoding="utf-8-sig")
control=read(OUT / "old-restore-control.json")
assert control["exit"] != 0 and control["candidate_sha256"] != candidate_sha
assert control["original_test_assertions"] == "unchanged"
assert control["native_empty_masks_observed"] is True
retained_mask_rounds=[]
for number in range(14,39):
    folder=ROOT/"build/m46"/("final-"+str(number))
    result_path=folder/"MirrorMaskRestoreTestDoc-result.json"
    if not result_path.exists():
        retained_mask_rounds.append({"snapshot":folder.relative_to(ROOT).as_posix(),"status":"no completed AIR result; retained compile/setup evidence"})
        continue
    record=read(result_path);run=ROOT/"build/cooperation"/str(record["run"])
    detail={**record,"snapshot":folder.relative_to(ROOT).as_posix(),"roles":{}}
    if (folder/"mask-scene-check.json").exists():
        detail["actual_white_blocks"]=[item for item in read(folder/"mask-scene-check.json") if item["white_block"] is not None]
    for role in ("host","join"):
        log=run/(role+".log")
        if not log.exists():continue
        content=log.read_text(encoding="utf-8-sig",errors="replace")
        detail["roles"][role]={"pass":len(re.findall(r"^COOP PASS ",content,re.M)),
            "fail":len(re.findall(r"^COOP FAIL ",content,re.M)),"done":"COOP EFFECTS DONE" in content,"log_sha256":sha(log)}
    retained_mask_rounds.append(detail)
runs = []
for entry in REQUIRED:
    record = read(OUT / (entry + "-result.json"))
    assert record["entry"] == entry and record["exit"] == 0, record
    folder = ROOT / "build/cooperation" / record["run"]
    data = read(folder / "run.json")
    frozen = read(folder / "input.json")
    assert sha(folder / "input.json") == data["input_manifest_sha256"]
    assert data["inputs"] == frozen["inputs"] and data["configuration_files"] == frozen["configuration_files"]
    assert data["sha256"] == frozen["candidate_sha256"] == sha(folder / "candidate.swf") == candidate_sha
    assert data["inputs"]["host"] == data["inputs"]["join"]
    assert data["inputs"]["host"]["production"] == candidate_sha
    driver=OUT/(entry+'-driver')
    assert read(driver/'driver-input.json')=={'candidate_sha256':candidate_sha,'entry':entry}
    assert data['inputs']['host']['driver']==sha(driver/'EffectsDriver.swf'),entry
    assert data['inputs']['host']['harness']==sha(driver/'EffectsHarness.swf'),entry
    result = {**record, "pids": data["pids"], "inputs": data["inputs"], "save_templates": data["save_templates"],
              "configuration_files": data["configuration_files"], "input_manifest_sha256": data["input_manifest_sha256"],
              "log_sha256": {}, "pass": 0, "fail": 0, "caught_object_spawn_diagnostics": {}, "native_clear_diagnostics": {}}
    for role in ("host", "join"):
        configurations = data["configuration_files"][role]
        assert "mods/Rconnect/release/config.txt" in configurations, (entry, role)
        for name, digest in configurations.items():
            assert sha(folder / "configuration" / role / name) == digest, (entry, role, name)
        log = folder / (role + ".log")
        content = log.read_text(encoding="utf-8-sig", errors="replace")
        assert "COOP EFFECTS DONE" in content and ("v" + manifest["version"] + " initialized") in content, (entry, role)
        for bad in ("COOP FAIL", "game error dialog", "RConnectRoom: ERROR", "handoff timed out", "RConnectPause: failed", "RConnectGrip: failed", "Error #1009"):
            assert bad not in content, (entry, role, bad)
        result["pass"] += len(re.findall(r"^COOP PASS ", content, re.M))
        result["log_sha256"][role] = sha(log)
        result["caught_object_spawn_diagnostics"][role] = list(dict.fromkeys(re.findall(r"^RConnectGame: obj spawn .* failed:.*$", content, re.M)))
        result["native_clear_diagnostics"][role] = [json.loads(line.split("TELE MOTION EARLY NATIVE CLEAR ", 1)[1])
                                                     for line in content.splitlines() if "TELE MOTION EARLY NATIVE CLEAR " in line]
    assert result["pass"] > 0
    if entry == "MirrorMaskRestoreTestDoc":
        scene_checks=read(OUT/"mask-scene-check.json")
        assert len(scene_checks)==14 and all(item["white_block"] is None for item in scene_checks)
        result["actual_whole_scene_white_rectangle_checks"]=scene_checks
        for role in ("host", "join"):
            content=(folder/(role+".log")).read_text(encoding="utf-8-sig")
            for case in range(8):
                assert re.search(r"COOP PASS mask-restore leave retains the native body and both live fields case="+str(case)+r"\b",content),(role,case)
            assert "RV inactive cleanup runs while roomHold is set case=5" in content,role
            assert "owned transitional shape is removed after native field replacement case=6" in content,role
            assert "later white bitmap owner keeps exact mask references and cache state after leave case=7" in content,role
    if entry == "TelekinesisMotionTestDoc":
        for role in ("host", "join"):
            assert data["save_templates"][role]["source_sha256"] == manifest["profiles"][role]["sha256"], role
    if entry == "HudTestDoc":
        result['hud_images'] = {}
        for role in ('host', 'join'):
            images = {p.name: sha(p) for p in folder.glob(role + '-hud-*.png')}
            assert len(images) >= 11, (role, 'HUD evidence missing')
            result['hud_images'][role] = images
            text = (folder / (role + '.log')).read_text(encoding='utf-8-sig')
            for marker in ('new production HUD restores saved bottom anchor and expansion',
                           'real co-op pause notice survives F10 hiding',
                           'title drag follows event coordinates and persists free position',
                           'releasing Shift in chat clears the previous native run state'):
                assert marker in text, (role, marker)
    runs.append(result)
baseline = read_baseline(manifest)
protected = {name: digest for name, digest in baseline["protected"].items() if name.lower() != "mods/rconnect/release/rconnectmod.swf"}
changed = [name for name, digest in protected.items() if not (GAME / name).is_file() or sha(GAME / name) != digest]
assert not changed, changed
evidence = {"generated_at": datetime.datetime.now().astimezone().isoformat(), "version": manifest["version"],
            "candidate": {"sha256": candidate_sha, "size": manifest["size"], "classes": len(expected),
                          "source_manifest_sha256": sha(OUT / "source-input.json"), "verification_manifest_sha256": sha(OUT / "verified-test-input.json")},
            "required_entries": REQUIRED, "runs": runs, "pass": sum(run["pass"] for run in runs), "fail": 0,
            "protected": {"count": len(protected), "changed": changed, "hashes": protected},
            "source_merge_audit_sha256": sha(ROOT / "build/m46/source-merge-audit.json"),
            "baseline_path": manifest.get('baseline_path', 'build/m46/integration-baseline'),
            "scope": "Joint movable telekinesis/native release and leases, numeric enemy resistance, native lightning frames/end delivery, mirrored targeting and native mask restoration; post-UI snapshots also require the production compact HUD regression.",
            "retained_failures": [
                {"run": "0533f0415d", "pass": 179, "fail": 2, "cause": "Early source Q pointer clear before planned release lacks native pre-frame fields; no causal production-fix claim."},
                {"run": "d8ea183f0c", "pass": 179, "fail": 2, "cause": "Local Q clear on first post-leave frame lacks pinok/control pre-frame fields; exact cause remains unassigned."},
                {"run": "d88300c9bc", "pass": 178, "fail": 3, "cause": "Incidental native knockdown crossed 60 during box-host hold (21.537 to 65.234), invalidating the later stationary release premise."},
                {"run":"531c0edabc","pass":108,"fail":66,"cause":"Anonymous Timer #1009 around automatic rejoin; provenance retained and cause unassigned. Explicit Session.leave tests do not prove stable reconnect."},
                {"run":"d173763da3","cause":"Old 905 candidate reproduced empty surviving vis/hpbar masks immediately after leave with a real native weapon holding the native body mask. Geometry-only mistaken ownership remained a static review risk."},
                {"run":"ca6f995755","cause":"First restoration candidate failed clipping/role assertions; the old test wrote live mask fields and assumed every shared mask was retired. No full-scene proof claim."},
                {"run":"2f710ab3a0","cause":"Readonly clipping comparison reached all three cases but immediate native mask restoration still failed before latest unreleased-alias/early-leave fix."}],
            "test_isolation": {"caster": "invulner plus native transp guard isolates incidental bullets; no production immunity/hold enforcement",
                "original_assertions": "Motion/lifecycle timings, Q/E, resistance, movement, release and floor thresholds unchanged",
                "native_knockdown_control": "Original damage call crosses pinok 60 and must clear actual Q, glow/CT and return to native floor",
                "evidence": "knowledge/experiments/2026-10-06-m46-joint-validation.md"},
            "mask_restoration": {"driver":"tests/MirrorMaskRestoreTestDoc.as", "cases":8,
                "oracle":"Readonly graphics rasterization and detached field clipping at actual parent coordinates; real whole-scene PNGs retained separately, not equated with the detached hash",
                "lifecycle":"Native fixtures survive Session.leave; actual RV retired-mask sweep, native weapon holder, early leave and inactive/roomHold/field replacement cleanup checked",
                "bitmap_disposal":"Only own BitmapData disposal is statically audited; no runtime disposed-storage introspection claim",
                "old_candidate_negative_control":control,
                "retained_rounds":retained_mask_rounds,
                "sampling_format":"Installed RV uses 40px tiles / 8 subcells; whole-tile 5px fallback is a format assumption, not native ownership proof. Metadata must cover the full rectangle at 5px or 1px scale.",
                "later_owner_case":"Case7 replaces the mask after the last frame observation; masks assigned before observation and all third-party timing combinations are not covered.",
                "legacy_evidence":"build/m46/r2-handoff-mask-grip.json; restoration failures final-14 through final-32 and journal preserved; final-33 diagnostic build green is not the deployed byte"},
            "limits": ["Dense combat FPS not benchmarked here", "IR class-specific branch and all boss/third-party states not exhausted", "1.02 only; stable reconnect/public network/more than two players excluded", "Hidden-background-room report not reproduced or assigned a root cause", "Mask restoration does not claim full object graph, full-visible-to-partial transitions or all world-change paths are exhausted", "Orphan duplicate suppression still uses the installed RV bitmap-format signature; arbitrary third-party drawing and earlier replacement masks are not comprehensively proven"]}
receipt = OUT / "deployment.json"
if receipt.exists():
    evidence["deployment"] = read(receipt)
(ROOT / "knowledge/experiments/m46-validation-evidence.json").write_text(json.dumps(evidence, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps({"runs": len(runs), "pass": evidence["pass"], "classes": len(expected), "protected": len(protected), "sha256": candidate_sha}))
