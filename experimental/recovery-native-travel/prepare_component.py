"""Prepare the exact RoomSync component source; never compile or launch a process."""
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-01/src"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--room-source-root", type=Path,
                        help="Optional frozen src for RoomSync/NativeTravelPlan red/green comparison")
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / "build/m52" and not out.exists(), "Use a fresh build/m52 directory"
    inputs = {}
    room_source = HERE / "src" if args.room_source_root is None else (ROOT / args.room_source_root).resolve()
    assert room_source.is_relative_to(ROOT) and room_source.is_dir(), "Room sources must stay in RConnect"
    fixture = HERE / "tests/native-room-component"
    planned = [(p, p.relative_to(fixture)) for p in fixture.rglob("*.as")]
    for rel in ("rconnect/core/RoomSync.as", "rconnect/core/NativeTravelPlan.as",
                "rconnect/ui/RoomEntryView.as", "rconnect/net/RoomCodec.as", "rconnect/net/Protocol.as"):
        source = room_source / rel if rel in ("rconnect/core/RoomSync.as", "rconnect/core/NativeTravelPlan.as") else BASE / rel
        assert source.is_file(), rel
        planned.append((source, Path(rel)))
        inputs[rel] = {"source": str(source), "sha256": sha(source)}
    for source, rel in planned:
        target = out / "src" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read_bytes())
    receipt = dict(kind="native-travel-room-component", entry="NativeTravelRoomChecks.as",
                   production=inputs, files={p.relative_to(out/"src").as_posix(): sha(p) for p in (out/"src").rglob("*.as")},
                   prepared_by_sha256=sha(Path(__file__)), compiled=False, runtime_tested=False,
                   functional_only=True, native_game_test=False)
    (out / "inputs.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"output": str(out), "entry": receipt["entry"], "production_files": len(inputs)}))

if __name__ == "__main__":
    main()
