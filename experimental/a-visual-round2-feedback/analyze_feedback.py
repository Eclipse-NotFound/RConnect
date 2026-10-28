"""Compare actual native feedback Parts and wire messages from FeedbackProbe.

Read-only unless --output is supplied; output must stay beside this script.
Exit 0: all required checks passed; 1: contradiction/failure; 2: incomplete evidence.
This is feedback-path evidence, never proof of the player's E-key input route.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
from pathlib import Path
from typing import Any

SPEECH = "RConnect 原生话语"
DUPLICATE = "去重测试"
FIXTURE_ID = 900000


def finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def samples(data: dict, kind: str, text: str | None = None, start: int = 0, end: int = 100000) -> list[dict]:
    result = []
    for row in data.get("rows", []):
        age = row.get("age")
        if not finite(age) or not start <= age <= end:
            continue
        for part in row.get("parts", []):
            if part.get("kind") == kind and (text is None or part.get("txt") == text):
                result.append({**part, "age": age})
    return result


def count_per_sample(data: dict, kind: str, text: str, start: int = 0) -> list[dict]:
    return [
        {"age": row["age"], "count": sum(p.get("kind") == kind and p.get("txt") == text for p in row.get("parts", []))}
        for row in data.get("rows", []) if finite(row.get("age")) and row["age"] >= start
    ]


def signature(item: dict, number: bool = True) -> tuple | None:
    fields = ("color", "frame") if number else ("color",)
    if not isinstance(item.get("txt"), str) or any(not finite(item.get(k)) for k in fields):
        return None
    return (item["txt"], *(int(item[k]) for k in fields))


def describe(sig: tuple) -> dict:
    result = {"text": sig[0], "color": sig[1]}
    if len(sig) == 3:
        result["frame"] = sig[2]
    return result


def analyze(run: Path) -> dict:
    checks: list[dict] = []
    evidence: dict[str, dict] = {}
    data: dict[str, dict] = {}

    def add(name: str, status: str, explanation: str, **details: Any) -> None:
        checks.append({"id": name, "status": status, "explanation": explanation, "evidence": details})

    for role in ("host", "join"):
        path = run / "logs" / role / "stutter-result.json"
        try:
            raw = path.read_bytes()
            parsed = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(parsed, dict):
                raise ValueError("result is not an object")
            data[role] = parsed
            evidence[role] = {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest()}
        except (OSError, ValueError) as error:
            add(role + "_result", "insufficient", "缺少可读取的真实运行结果。", error=str(error), path=str(path))

    if len(data) != 2:
        return finish(run, evidence, checks)
    host, join = data["host"], data["join"]

    for role, d in data.items():
        failed = [c for c in d.get("checks", []) if c.get("ok") is not True]
        execution_ok = d.get("completed") is True and not d.get("error") and not failed and d.get("role") == role
        add(role + "_execution", "pass" if execution_ok else "fail", "运行结束与驱动断言；此项单独通过不代表功能通过。",
            completed=d.get("completed"), error=d.get("error"), failed_checks=failed, reported_role=d.get("role"))
        volume = d.get("audioVolume")
        add(role + "_muted", "pass" if finite(volume) and volume == 0 else "fail" if finite(volume) else "insufficient",
            "隔离实例静音状态。", audio_volume=volume)
        rows = d.get("rows", [])
        ages = [r.get("age") for r in rows if finite(r.get("age"))]
        gaps = [later - earlier for earlier, later in zip(ages, ages[1:])]
        coverage = len(ages) > 50 and min(ages) < 1000 and max(ages) > 10500 and ages == sorted(ages)
        add(role + "_sample_coverage", "pass" if coverage else "insufficient", "样本应覆盖话语、两种数字、取消及最后消失阶段。",
            count=len(ages), first=min(ages, default=None), last=max(ages, default=None),
            sample_gap_median_ms=statistics.median(gaps) if gaps else None,
            sample_gap_max_ms=max(gaps, default=None))

    items = [item for packet in join.get("packets", []) if isinstance(packet, dict) and packet.get("type") == "native-text"
             for item in packet.get("items", []) if isinstance(item, dict)]
    speech_items = [s for s in items if s.get("kind") in ("replic", "replic2") and s.get("txt") == SPEECH and not s.get("ended")]
    source_speech = samples(host, "speech", SPEECH)
    remote_speech = samples(join, "speech", SPEECH)
    source_colors = {signature(s, False) for s in source_speech} - {None}
    remote_colors = {signature(s, False) for s in remote_speech} - {None}
    wire_colors = {signature(s, False) for s in speech_items} - {None}
    unexpected_colors = remote_colors - source_colors
    speech_status = "fail" if unexpected_colors and source_colors else "pass" if source_colors and remote_colors and wire_colors and remote_colors <= source_colors and wire_colors <= source_colors else "insufficient"
    add("native_speech_text_color", speech_status, "实际主侧原生气泡、传输内容及加入侧原生气泡的文本/颜色一致。",
        source_samples=len(source_speech), remote_samples=len(remote_speech), packets=len(speech_items),
        source=[describe(s) for s in sorted(source_colors)], remote=[describe(s) for s in sorted(remote_colors)], wire=[describe(s) for s in sorted(wire_colors)])

    speech_ids = {s.get("id") for s in speech_items}
    ends = [s for s in items if s.get("ended") is True and s.get("id") in speech_ids]
    host_late = samples(host, "speech", SPEECH, start=2300)
    join_late = samples(join, "speech", SPEECH, start=2300)
    cancel_ready = source_speech and remote_speech and ends and any(r.get("age", 0) >= 2300 for r in host.get("rows", [])) and any(r.get("age", 0) >= 2300 for r in join.get("rows", []))
    cancel_status = "fail" if host_late or join_late else "pass" if cancel_ready else "insufficient"
    add("early_speech_cancel", cancel_status, "驱动在约1800ms提前取消；按2300ms进入下阶段前已消失核查，并要求真实结束包。此项不是精确网络取消延迟指标。",
        ids=sorted(speech_ids), ending_messages=ends, host_late_samples=host_late[:6], join_late_samples=join_late[:6], absence_cutoff_ms=2300)

    duplicate_items = [s for s in items if s.get("id") == FIXTURE_ID and s.get("revision") == 1 and not s.get("ended")]
    same_payload = len({json.dumps(s, sort_keys=True, ensure_ascii=False) for s in duplicate_items}) == 1
    counts = count_per_sample(join, "speech", DUPLICATE)
    maximum = max((r["count"] for r in counts), default=0)
    late_duplicates = [r for r in counts if r["age"] >= 9500 and r["count"]]
    duplicate_status = "fail" if maximum > 1 or late_duplicates else "pass" if len(duplicate_items) >= 2 and same_payload and maximum == 1 else "insufficient"
    add("duplicate_fixture_once", duplicate_status, "同一fixture确经TCP收到至少两次，实际显示样本最多一份，并按原生寿命消失。定时采样不能排除采样间的极短重叠。",
        wire_copies=len(duplicate_items), identical_payload=same_payload, max_simultaneous=maximum,
        visible_samples=sum(r["count"] > 0 for r in counts), late_samples=late_duplicates[:6])

    number_items = [s for s in items if s.get("kind") == "numb" and not s.get("ended")]
    source_numbers = samples(host, "numb", start=2100, end=6500)
    remote_numbers = samples(join, "numb", start=2100, end=9000)
    source_sigs = {signature(s) for s in source_numbers} - {None}
    remote_sigs = {signature(s) for s in remote_numbers} - {None}
    wire_sigs = {signature(s) for s in number_items} - {None}
    missing_source = wire_sigs - source_sigs
    missing_remote = wire_sigs - remote_sigs
    # A short-lived intermediate revision can fall between timer samples. Missing
    # observations are therefore insufficient evidence, not fabricated failures.
    add("throw_number_native_values", "pass" if wire_sigs and not missing_source and not missing_remote else "insufficient",
        "每个真实数字修订的文本、颜色及frame必须同时出现在主侧原生Part、传输包和加入侧Part；不拿HP差替代。",
        source=[describe(s) for s in sorted(source_sigs)], wire=[describe(s) for s in sorted(wire_sigs)],
        remote=[describe(s) for s in sorted(remote_sigs)], missing_source=[describe(s) for s in sorted(missing_source)],
        missing_remote=[describe(s) for s in sorted(missing_remote)])

    first_sigs = {signature(s) for s in samples(host, "numb", start=2300, end=4250)} - {None}
    first_matched = first_sigs & wire_sigs & remote_sigs
    add("ordinary_collision_number", "pass" if first_matched else "insufficient", "showHit=1的第一轮真实碰撞数字在双方及网络上均有相同样本。",
        matched=[describe(s) for s in sorted(first_matched)])

    groups: dict[str, list[dict]] = {}
    for item in number_items:
        groups.setdefault(str(item.get("id")), []).append(item)
    aggregate_source = {signature(s) for s in samples(host, "numb", start=4700, end=6500)} - {None}
    aggregate_groups = []
    for identity, group in groups.items():
        by_rev = {int(s["revision"]): s for s in group if finite(s.get("revision")) and s["revision"] > 0}
        if len(by_rev) < 2:
            continue
        ordered = [by_rev[k] for k in sorted(by_rev)]
        sigs = {signature(s) for s in ordered} - {None}
        if sigs & aggregate_source:
            aggregate_groups.append({"id": identity, "revisions": sorted(by_rev),
                                     "values": [describe(s) for s in sorted(sigs)],
                                     "all_source_observed": sigs <= aggregate_source,
                                     "all_remote_observed": sigs <= remote_sigs,
                                     "text_changed": len({s["txt"] for s in ordered}) > 1})
    aggregate_pass = any(g["all_source_observed"] and g["all_remote_observed"] and g["text_changed"] for g in aggregate_groups)
    add("aggregate_high_revision", "pass" if aggregate_pass else "insufficient", "同一原生聚合数字以更高修订号更新文本，两个真实状态在双方均可见。",
        groups=aggregate_groups)

    # driver01 intentionally did not serialize its action inputs. Newer probes
    # may supply this explicit trace; source text alone is not runtime evidence.
    actions = host.get("actions", [])
    final_frame = [a for a in actions if a.get("op") == "damageWall" and a.get("tThrowBefore") == 1 and a.get("showHit") == 2]
    final_frame_damage = [a for a in final_frame if finite(a.get("hpBefore")) and finite(a.get("hpAfter")) and a["hpAfter"] < a["hpBefore"]]
    add("aggregate_last_throw_frame", "pass" if aggregate_pass and final_frame_damage else "fail" if final_frame and not final_frame_damage else "insufficient",
        "必须有运行时记录证明聚合模式在t_throw=1调用真实碰撞且扣血，并已观察聚合修订；driver01未记录此动作字段时不能单凭源码赋值判通过。",
        matching_actions=final_frame, aggregate_display_passed=aggregate_pass)

    return finish(run, evidence, checks)


def finish(run: Path, evidence: dict, checks: list[dict]) -> dict:
    failed = [c["id"] for c in checks if c["status"] == "fail"]
    missing = [c["id"] for c in checks if c["status"] == "insufficient"]
    return {"schema": 1, "run": str(run), "inputs": evidence,
            "status": "fail" if failed else "insufficient" if missing else "pass",
            "failed": failed, "insufficient": missing, "checks": checks,
            "limits": ["仅原生反馈显示通道；未验证玩家E键抓取/释放输入。",
                       "定时采样而非每帧采样，实际间隔见coverage项；遗漏的短暂状态不假报成功，也不直接判功能失败。",
                       "不评价整体性能、加载速度或其他动画问题。"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path, help="run folder containing logs/{host,join}/stutter-result.json")
    parser.add_argument("--output", type=Path, help="optional result JSON, restricted to this script's directory")
    args = parser.parse_args()
    result = analyze(args.run.resolve())
    rendered = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        dest = args.output.resolve()
        if not dest.is_relative_to(Path(__file__).resolve().parent):
            parser.error("--output must remain under this independent feedback directory")
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 1 if result["status"] == "fail" else 2 if result["status"] == "insufficient" else 0


if __name__ == "__main__":
    raise SystemExit(main())
