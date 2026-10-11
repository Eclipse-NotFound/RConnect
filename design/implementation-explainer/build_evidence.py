"""Read-only evidence capture for the illustrated explanation, not a game build."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from html.parser import HTMLParser

HERE = Path(__file__).resolve().parent
MOD = HERE.parents[1]
REV = "f81c4d9"
FILES = {
    "S1": ["src/RConnectMod.as", "src/rconnect/net/TcpLink.as"],
    "S2": ["src/rconnect/game/GameBridge.as"],
    "S3": ["src/rconnect/core/RoomSync.as"],
    "S4": ["src/rconnect/game/MirrorHitUnit.as", "src/rconnect/game/RemoteDamageUnit.as", "src/rconnect/game/NativeHit.as"],
    "S5": ["src/rconnect/game/WeaponCapture.as", "src/rconnect/game/UnitPresentation.as", "src/rconnect/game/ProjectileVisuals.as"],
    "S6": ["src/rconnect/core/SnapshotPublisher.as", "src/rconnect/core/Session.as", "src/rconnect/core/Config.as", "src/rconnect/game/ExplorationSync.as"],
    "S7": ["src/rconnect/game/RemoteMotion.as"],
    "S8": ["design/sync-audit-2026-10-10.md"],
    "S9": ["state/architecture-2026-10-10.md", "design/architecture.md"],
    "S10": ["state/MEMORY.md"],
}
sha = lambda data: hashlib.sha256(data).hexdigest()
evidence = {
    "as_of": "2026-10-11 Asia/Shanghai",
    "baseline_commit": subprocess.check_output(["git", "-C", str(MOD), "rev-parse", REV]).decode().strip(),
    "purpose": "Beginner-friendly explanation with technical details; no game changes or new gameplay tests.",
    "sources": [],
    "simulation_notice": "All interactive scenes and motion samples are synthetic illustrations, not measurements.",
}
for group, paths in FILES.items():
    for path in paths:
        data = subprocess.check_output(["git", "-C", str(MOD), "show", f"{REV}:{path}"])
        lines = data.decode("utf-8-sig").splitlines()
        entries = [{"line": n, "text": line.strip()} for n, line in enumerate(lines, 1)
                   if re.search(r"\bfunction\s+(init|onData|send|tick|roster|sendReady|commit|report|applyDamage|damage|apply|capture|pushTimed|sampleTimed|delay|settle|resetRoomPresentation|onPerceptionFrame|onMirrorFrame|onVisForceFrame)\b", line)]
        evidence["sources"].append({"group": group, "path": path, "revision": REV, "sha256": sha(data),
                                    "lines": len(lines), "entry_points": entries})
release = MOD / "release/RConnectMod.swf"
for group, path in [
    ("S11", "state/cooperative-hazards-2026-10-11.md"),
    ("S12", "design/remote-player-entity-2026-10-11.md"),
    ("S11", "state/MEMORY.md"),
]:
    data = subprocess.check_output(["git", "-C", str(MOD), "show", f"0927470:{path}"])
    evidence["sources"].append({"group": group, "path": path, "revision": "0927470", "sha256": sha(data)})
evidence["later_status_note_revision"] = "0927470"
evidence["installed_file"] = {"path": str(release), "sha256": sha(release.read_bytes()), "recorded_version": "0.2.22-dev"}
evidence["html_sha256"] = sha((HERE / "index.html").read_bytes())
(HERE / "evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

class Inspect(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.scripts = [], [], []
        self.script = False
        self.script_text = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag == "script":
            self.script = True
    def handle_endtag(self, tag):
        if tag == "script":
            self.script = False
    def handle_data(self, data):
        if self.script:
            self.script_text.append(data)

parser = Inspect()
html = (HERE / "index.html").read_text(encoding="utf-8")
parser.feed(html)
broken = []
for link in parser.links:
    if link.startswith("#"):
        if link[1:] not in parser.ids:
            broken.append(link)
    elif "://" not in link and not (HERE / link).resolve().exists():
        broken.append(link)
qa = HERE / "qa"
qa.mkdir(exist_ok=True)
checks = {
    "duplicate_ids": sorted({x for x in parser.ids if parser.ids.count(x) > 1}),
    "broken_local_links": broken,
    "replacement_characters": html.count("\ufffd"),
    "external_dependencies": re.findall(r'(?:src|href)="https?://[^"]+', html),
    "source_files": len(evidence["sources"]),
    "interactive_groups": ["stepwise player update", "room ownership", "damage direction", "motion playback and buffer"],
    "synthetic_data_labelled": "教学模型 · 非性能测试" in html,
}
(qa / "static-check.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(checks, ensure_ascii=False))
