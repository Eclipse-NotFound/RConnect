"""Read existing frozen profiles only; no runtime, source edits or simulation."""
from collections import Counter
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(rows):
    needles = ["tickFrozenAnims", "RemoteMotion/sampleTimed", "RemoteMotion$/blendWeapons",
               "WeaponDisplay$/interpolate", "RemoteMotion$/blendBodyPose", "UnitPresentation/tick",
               "UnitPresentation/play", "MirrorMasks/", "MirrorMasks/maskReferences",
               "MirrorHitUnit/syncMotion", "RConnectAnimationAccess", "TelekinesisVisuals$/paint"]
    return {key: dict(inclusive=sum(n for s, n in rows.items() if key in s),
                      reap_leaf=sum(n for s, n in rows.items() if key in s and s.startswith("[reap]")),
                      direct_leaf=sum(n for s, n in rows.items() if key in s.split(" <- ")[0]))
            for key in needles}


def main():
    dense_path = ROOT / "build/cooperation/a6a7e27789/join.log"
    dense = [json.loads(line[len("PROJECTILE PROFILE "):])
             for line in dense_path.read_text(encoding="utf-8-sig").splitlines()
             if line.startswith("PROJECTILE PROFILE ")]
    assert len(dense) == 1
    rows = Counter()
    phases = {}
    for frame in dense[0]["frames"]:
        if frame["samples"] > 0:
            assert sum(frame["stacks"].values()) == frame["cpu"]
            rows.update(frame["stacks"])
            phases.setdefault(str(frame["phase"]), Counter()).update(frame["stacks"])
    partial_path = ROOT / "build/m52/recovery-input-cpu-frames-partial-review-01/join-cpu-frames-partial.json"
    partial = json.loads(partial_path.read_text(encoding="utf-8-sig"))
    kept = Counter()
    windows = []
    for w in partial["windows"]:
        if not w["usable_cpu"]:
            windows.append(dict(id=w["id"], valid=False, reasons=w["invalidReasons"]))
            continue
        assert not w["invalidReasons"] and w["nativeScanComplete"]
        local = Counter(" <- ".join(w["stacks"][int(r[2])]) for r in w["cpuRows"])
        kept.update(local)
        windows.append(dict(id=w["id"], valid=True, cpu=sum(local.values()),
                            partial=w["partial_window"], start=w["startAt"], end=w["endAt"],
                            methods=summarize(local)))
    names = ["rconnect/game/GameBridge.as", "rconnect/game/RemoteMotion.as",
             "rconnect/game/UnitPresentation.as", "rconnect/game/WeaponDisplay.as",
             "rconnect/game/MirrorMasks.as", "rconnect/game/MirrorHitUnit.as",
             "fe/unit/RConnectAnimationAccess.as"]
    sources = {}
    for name in names:
        b = ROOT / "build/m52/recovery-14/src" / name
        a = ROOT / "build/m52/recovery-13/src" / name
        assert a.read_bytes() == b.read_bytes()
        sources[name] = dict(sha256=sha(b), same_in_partial13=True)
    report = dict(read_only=True, diagnostic_only=True, performance_qualified=False,
        dense=dict(run="a6a7e27789", sha256=sha(dense_path), cpu=sum(rows.values()),
                   methods=summarize(rows), phases={p:summarize(v) for p,v in phases.items()},
                   focused_stacks=sorted([(s,n) for s,n in rows.items()
                       if "RemoteMotion" in s or "MirrorMasks/maskReferences" in s], key=lambda r:-r[1])[:16]),
        partial=dict(run="398cddcf6b", sha256=sha(partial_path), cpu=sum(kept.values()),
                     methods=summarize(kept), windows=windows), sources=sources)
    assert report["dense"]["cpu"] == 1259 and report["partial"]["cpu"] == 345
    (HERE / "evidence.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({key:dict(cpu=report[key]["cpu"],methods=report[key]["methods"])
                      for key in ["dense","partial"]},ensure_ascii=False))


if __name__ == "__main__":
    main()
