"""Bounded read-only audit of one existing native profile; no game process."""
from collections import Counter
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    profile = ROOT / "build/cooperation/a6a7e27789/join.log"
    source = ROOT / "build/m52/recovery-14/src"
    inputs = [profile, ROOT / "build/cooperation/a6a7e27789/run.json"]
    inputs += sorted(source.rglob("*.as"))
    before = {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in inputs}
    records = [json.loads(s[len("PROJECTILE PROFILE "):])
               for s in profile.read_text(encoding="utf-8-sig").splitlines()
               if s.startswith("PROJECTILE PROFILE ")]
    assert len(records) == 1
    all_rows = Counter()
    phases = {}
    for frame in records[0]["frames"]:
        if frame["samples"] <= 0:
            continue
        assert sum(frame["stacks"].values()) == frame["cpu"]
        all_rows.update(frame["stacks"])
        phases.setdefault(str(frame["phase"]), Counter()).update(frame["stacks"])
    rows = Counter({s: n for s, n in all_rows.items() if "GameBridge/tickFrozenAnims" in s})
    methods = ["UnitPresentation/tick", "UnitPresentation/play", "UnitPresentation/apply",
               "UnitPresentation/animateBody", "RemoteMotion/sampleTimed", "RemoteMotion$/blendWeapons",
               "MirrorHitUnit/syncMotion", "GameBridge/captureUnitDamage", "MirrorMasks/",
               "MirrorMasks/maskReferences", "TelekinesisVisuals", "RConnectAnimationAccess",
               "Sprite/constructChildren", "FocusManager", "GameBridge/refreshMirrorCursor"]

    def stats(local):
        return {k: dict(inclusive=sum(n for s, n in local.items() if k in s),
                        reap_leaf=sum(n for s, n in local.items() if k in s and s.startswith("[reap]")))
                for k in methods}

    result = dict(read_only=True, run="a6a7e27789", performance_qualified=False,
                  source="build/m52/recovery-14/src", cpu=sum(all_rows.values()),
                  tick_frozen_cpu=sum(rows.values()), distinct_tick_stacks=len(rows),
                  tick_reap_leaf=sum(n for s, n in rows.items() if s.startswith("[reap]")),
                  methods_within_tick=stats(rows),
                  phases={p: dict(cpu=sum(v.values()), tick=sum(n for s,n in v.items()
                      if "GameBridge/tickFrozenAnims" in s), play=sum(n for s,n in v.items()
                      if "UnitPresentation/play" in s)) for p,v in phases.items()},
                  top_tick_stacks=sorted(rows.items(), key=lambda v: -v[1])[:20],
                  inputs=before)
    assert result["cpu"] == 1259 and result["tick_frozen_cpu"] == 278
    assert before == {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in inputs}
    result["inputs_unchanged"] = True
    (HERE / "evidence.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ["cpu", "tick_frozen_cpu", "tick_reap_leaf", "methods_within_tick", "phases", "inputs_unchanged"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
