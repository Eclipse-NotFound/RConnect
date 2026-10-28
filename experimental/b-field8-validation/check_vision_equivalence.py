"""Pure-data mirror of SharedVision's row merge, not AS3/game/performance proof."""
from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

HEX = "0123456789abcdef"


def old_merge(a, b):
    if a is None or a == b:
        return b
    out = []
    for i, bc in enumerate(b):
        ac = a[i:i + 1]
        av, bv = HEX.find(ac), HEX.find(bc)
        out.append(HEX[max(av, bv) if i % 17 == 0 else av | bv])
    return "".join(out)


def new_merge(a, b):
    if a is None or a == b:
        return b
    if len(a) != len(b):
        return old_merge(a, b)
    out = None
    for i, (ac, bc) in enumerate(zip(a, b)):
        if ac == bc:
            continue
        av, bv = HEX.find(ac), HEX.find(bc)
        merged = HEX[max(av, bv) if i % 17 == 0 else av | bv]
        if merged != ac:
            if out is None:
                out = list(a)
            out[i] = merged
    return a if out is None else "".join(out)


def row_at(rows, i):
    return rows[i] if i < len(rows) else None


def remember(old, rows, ret_dark, merge, lazy):
    if ret_dark:
        return old, rows
    changed = old is None
    merged = [] if not lazy or old is None or len(old) != len(rows) else None
    for y, row in enumerate(rows):
        previous = None if old is None else row_at(old, y)
        line = merge(previous, row)
        if lazy and merged is None and previous != line:
            merged = old[:y]
        if merged is not None:
            merged.append(line)
        if old is not None and previous != line:
            changed = True
    if merged is None:
        merged = old
    return (merged if changed else old), merged


def run():
    rng = random.Random(108028)
    counts = {"hex_pair_positions": 0, "random_rows": 0, "remember_steps": 0,
              "immutable_snapshots_checked": 0, "ret_dark": 0}

    def check(a, b):
        assert old_merge(a, b) == new_merge(a, b), (a, b)

    # Every nibble pair at both brightness and pixel-mask positions, including
    # the second 17-character tile boundary.
    for at in (0, 1, 16, 17, 18, 33):
        for ac in HEX:
            for bc in HEX:
                a = "0" * at + ac + "0" * (33 - at)
                b = "0" * at + bc + "0" * (33 - at)
                check(a, b)
                counts["hex_pair_positions"] += 1

    for _ in range(5000):
        n = rng.choice([0, 1, 16, 17, 34, 68, 102, 340, 680, 6800])
        a = "".join(rng.choices(HEX, k=n))
        # Equal, unrelated, subset/dominated, localized and different-size rows.
        mode = rng.randrange(6)
        if mode == 0:
            b = a
        elif mode == 1:
            b = "".join(rng.choices(HEX, k=n))
        elif mode == 2:
            b = "".join(HEX[rng.randrange(HEX.find(c) + 1)] if i % 17 == 0
                        else HEX[HEX.find(c) & rng.randrange(16)]
                        for i, c in enumerate(a))
        elif mode == 3:
            chars = list(a)
            if n:
                chars[rng.randrange(n)] = rng.choice(HEX)
            b = "".join(chars)
        elif mode == 4:
            b = "".join(rng.choices(HEX, k=rng.randrange(100)))
        else:
            a = None
            b = "".join(rng.choices(HEX, k=n))
        check(a, b)
        counts["random_rows"] += 1

    old_own = new_own = None
    old_snapshots, new_snapshots = [], []
    old_sent = new_sent = None
    for step in range(1200):
        height = rng.choice([1, 2, 4, 8]) if step % 29 == 0 else 4
        width = rng.choice([17, 34, 68]) if step % 31 == 0 else 34
        rows = ["".join(rng.choices(HEX, k=width)) for _ in range(height)]
        if step % 7 == 0 and old_own is not None:
            rows = list(old_own)  # No new knowledge; still an independent input.
        if step % 11 == 0 and old_own is not None:
            rows = ["0" * len(r) for r in old_own]  # Entirely dominated.
        input_before = tuple(rows)
        dark = step % 19 == 0
        previous_old, previous_new = old_own, new_own
        old_own, old_rows = remember(old_own, rows, dark, old_merge, False)
        new_own, new_rows = remember(new_own, rows, dark, new_merge, True)
        assert old_rows == new_rows and old_own == new_own
        assert tuple(rows) == input_before
        if dark:
            assert old_rows is rows and new_rows is rows
            assert old_own is previous_old and new_own is previous_new
            counts["ret_dark"] += 1
        else:
            assert old_rows is not rows and new_rows is not rows
        old_changes = [i for i, r in enumerate(old_rows)
                       if old_sent is None or row_at(old_sent, i) != r]
        new_changes = [i for i, r in enumerate(new_rows)
                       if new_sent is None or row_at(new_sent, i) != r]
        assert old_changes == new_changes
        if old_changes:
            # step() records rows.concat(): the sent array must remain separate.
            old_sent, new_sent = list(old_rows), list(new_rows)
            assert old_sent is not old_rows and new_sent is not new_rows
        for ref, expected in old_snapshots + new_snapshots:
            assert tuple(ref) == expected
            counts["immutable_snapshots_checked"] += 1
        if not dark:
            old_snapshots.append((old_rows, tuple(old_rows)))
            new_snapshots.append((new_rows, tuple(new_rows)))
        counts["remember_steps"] += 1

    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    baseline = args.root / "build/ab/b190-scalar04-build/src/authority/SharedVision.as"
    candidate = args.root / "build/ab/b190-local-display-field8-source/src/authority/SharedVision.as"
    counts = run()
    result = {
        "status": "pass", "kind": "pure-data-algorithm-equivalence",
        "seed": 108028, "counts": counts,
        "source_sha256": {str(p.relative_to(args.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in (baseline, candidate)},
        "scope": ["Valid hexadecimal rows at equal and differing lengths",
                  "Brightness max and mask OR at every sampled nibble boundary",
                  "No-growth, localized-growth and repeated exploration",
                  "retDark bypass, immutable earlier results, independent sent-row arrays"],
        "limits": ["Python mirrors the reviewed AS3 algorithms; it does not execute AS3.",
                   "No game, AIR, network, rendering or performance test was run.",
                   "Malformed rows are rejected by the unchanged AS3 validator, not tested as valid merge inputs.",
                   "External exploration API behavior is not simulated."]
    }
    destination = Path(__file__).with_name("vision-equivalence.json")
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "counts": counts, "output": str(destination)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
