"""Offline attribution of DIAGNOSTIC logs. Never a performance/pass gate.

Use the unchanged native_flight.py separately for all original 8-case checks.
"""
from pathlib import Path
import argparse
import base64
import collections
import hashlib
import json
import math
import zlib


def load(path):
    header, done, rows, payloads = None, None, [], []
    for line in Path(path).read_text(encoding='utf-8-sig', errors='replace').splitlines():
        if 'FLIGHT DIAG ' not in line:
            continue
        tail = line.split('FLIGHT DIAG ', 1)[1]
        tag, raw = tail.split(' ', 1)
        value = json.loads(raw)
        if tag == 'HEADER':
            assert header is None, 'duplicate header'
            header = value
        elif tag == 'ROWS':
            assert value['from'] == len(rows), 'missing/out-of-order row chunk'
            rows.extend(value['rows'])
        elif tag == 'PAYLOAD':
            assert value['id'] == len(payloads), 'missing/out-of-order payload'
            payloads.append(value)
        elif tag == 'DONE':
            assert done is None, 'duplicate done'
            done = value
    assert header is not None and done is not None, 'missing diagnostic header/done'
    assert header['schema'] == 1 and header['width'] == 24
    assert header['diagnosticOnly'] is True and header['performanceQualified'] is False
    assert done['diagnosticOnly'] is True and done['performanceQualified'] is False
    assert len(rows) == header['rows'] == done['rows']
    assert len(payloads) == header['payloads'] == done['payloads']
    assert all(len(row) == 24 for row in rows)
    errors = []
    if header.get('complete') is not True or done.get('complete') is not True:
        errors.append('runtime reports incomplete diagnostic collection')
    for key in ['dropped', 'textOverflow', 'payloadOverflow', 'hookErrors', 'identityOverflow', 'timingBusy', 'hookOccupied']:
        if header.get(key):
            errors.append(key + '=' + str(header[key]))
    starts = [int(row[7]) for row in rows if row[0] == 10 and row[6] == 1]
    if starts != list(range(8)):
        errors.append('eight original case starts missing/duplicated: ' + str(starts))
    if header['wallMiss'] != header['wallDecoded'] or header['wallProtect'] != header['wallProtectedDone']:
        errors.append('a wall unpack began without a completed observation')
    return header, rows, payloads, errors


def numeric(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def replay_payload(value):
    """Decode original wire text independently; no rewritten/repacked input.

    This checks the ordinary numeric sparse-cell subset, NOT AIR round-trip
    or render equivalence. A weird legacy payload is retained as unsupported.
    """
    text = value['data']
    result = {'id': value['id'], 'chars': len(text), 'utf8_bytes': len(text.encode()),
              'sha256': hashlib.sha256(text.encode()).hexdigest(), 'counts': value['counts']}
    assert value['chars'] == len(text)
    try:
        stream = zlib.decompressobj()
        raw = stream.decompress(base64.b64decode(text, validate=True), 16000001)
        assert len(raw) <= 16000000 and stream.eof and not stream.unconsumed_tail
    except (ValueError, zlib.error) as exc:
        return {**result, 'offline_decode_error': type(exc).__name__ + ': ' + str(exc)}
    assert len(raw) <= 16000000
    words = json.loads(raw)
    numeric_pairs = isinstance(words, list) and len(words) % 2 == 0 and len(words) <= 3200
    previous = -1
    if numeric_pairs:
        for index, color in zip(words[::2], words[1::2]):
            if not (numeric(index) and int(index) == index and previous < index < 1600 and
                    numeric(color) and int(color) == color and 0 <= color <= 4294967295):
                numeric_pairs = False
                break
            previous = index
    return {**result, 'decoded_bytes': len(raw), 'decoded_sha256': hashlib.sha256(raw).hexdigest(),
            'numeric_sparse_cell': numeric_pairs, 'words': len(words) if isinstance(words, list) else None}


def summary(header, rows, payloads, errors):
    # Row common prefix = kind/local getTimer/frame/current bracket/round/render.
    kinds = collections.Counter(int(r[0]) for r in rows)
    results = []
    for case in range(8):
        part = [r for r in rows if r[4] == case]
        boundaries = [r for r in part if r[0] == 9]
        enter = [r for r in boundaries if r[3] == 1]
        final = [r for r in boundaries if r[3] == 8]
        intervals = [{'from_frame': a[2], 'to_frame': b[2], 'ms': b[1] - a[1], 'at': b[1]}
                     for a, b in zip(enter, enter[1:])]
        brackets = [{'from_phase': a[3], 'to_phase': b[3], 'from_frame': a[2], 'to_frame': b[2],
                     'ms': b[1] - a[1], 'at': b[1]}
                    for a, b in zip(boundaries, boundaries[1:]) if a[2] == b[2] and b[1] - a[1] >= 8]
        clock_records = [r for r in part if r[0] == 2]
        motion_records = [r for r in part if r[0] == 1]
        receives = collections.defaultdict(list)
        ticks = collections.defaultdict(list)
        for r in part:
            if r[0] == 3:
                receives[int(r[6])].append(r)
            if r[0] == 4:
                ticks[int(r[6])].append(r)
        projectile_results = []
        for identity, received in receives.items():
            first = received[0]
            pt = ticks.get(identity, [])
            shown = [r for r in pt if r[9] == 4]
            waits = [r for r in pt if r[9] == 0]
            classes = {header['texts'][int(r[12])] for r in received if r[12] is not None and r[12] >= 0}
            weapons = {header['texts'][int(r[13])] for r in received if r[13] is not None and r[13] >= 0}
            first_shown = shown[0] if shown else None
            at = first_shown[1] if first_shown else float('inf')
            matching_motion = [r for r in motion_records if r[6] == first[8] and r[1] <= at]
            matching_clock = [r for r in clock_records if r[6] == identity and r[1] <= at]
            projectile_results.append({
                'id': identity, 'owner_id': first[7], 'motion_id': first[8],
                'player': bool(first[9]), 'classes': sorted(classes), 'weapons': sorted(weapons),
                'receive_at': first[1], 'first_display_at': None if first_shown is None else first_shown[1],
                'receive_to_first_display_ms': None if first_shown is None else first_shown[1] - first[1],
                'waiting_tick_calls': len(waits), 'actual_display_tick_calls': len(shown),
                'first_receive_row': first, 'first_display_row': first_shown,
                'last_motion_row_before_first_display': matching_motion[-1] if matching_motion else None,
                'last_clock_row_before_first_display': matching_clock[-1] if matching_clock else None,
                'max_tick_argument_age_ms': max((r[1] - r[7] for r in pt if numeric(r[7]) and r[7] >= 0), default=None),
                'end_decisions': [r for r in pt if r[9] in (2, 3, 5)],
            })
        codec = [r for r in part if r[0] == 8]
        wall = [r for r in part if r[0] == 7]
        wall_bins = [r for r in part if r[0] == 6]
        results.append({
            'case': case, 'enter_frames': len(enter), 'final_renders': len(final),
            'largest_enter_intervals': sorted(intervals, key=lambda v: v['ms'], reverse=True)[:10],
            'largest_phase_brackets': sorted(brackets, key=lambda v: v['ms'], reverse=True)[:15],
            'projectiles': projectile_results,
            'wall_counters_delta': [b - a for a, b in zip(wall_bins[0][6:18], wall_bins[-1][6:18])] if len(wall_bins) >= 2 else None,
            'wall_cache_evictions': sum(r[7] == 4 for r in wall),
            'wall_unpack_completed': sum(r[7] == 8 for r in wall),
            'protected_unpack_completed': sum(r[7] == 9 for r in wall),
            'slow_wall_calls': sorted([r for r in wall if r[7] in (8, 9)], key=lambda r: r[10], reverse=True)[:15],
            'codec_pack_calls': sum(r[6] == 1 for r in codec),
            'codec_unpack_calls': sum(r[6] == 2 for r in codec),
            'codec_before_log_ms': sum(r[8] - r[7] for r in codec),
            'codec_first_log_ms': sum(r[9] - r[8] for r in codec),
            'codec_second_log_ms': sum(r[11] - r[10] for r in codec),
            'codec_inclusive_ms': sum(r[11] - r[7] for r in codec),
        })
    return {'role': header['role'], 'diagnostic_complete': not errors, 'errors': errors,
            'performance_qualified': False, 'functional_qualification': 'use unchanged original 8-case analyzer separately',
            'header': header, 'kind_counts': dict(kinds), 'cases': results,
            'payloads': [replay_payload(p) for p in payloads]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host-log', required=True, type=Path)
    parser.add_argument('--join-log', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Use a new output file; original failures must remain unchanged'
    sides = [summary(*load(p)) for p in [args.host_log, args.join_log]]
    assert [s['role'] for s in sides] == ['host', 'join']
    report = {'schema': 1, 'diagnostic_only': True, 'performance_qualified': False,
              'diagnostic_complete': all(s['diagnostic_complete'] for s in sides), 'sides': sides,
              'inputs': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [args.host_log, args.join_log]}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False, allow_nan=False) + '\n', encoding='utf-8')
    print(json.dumps({'diagnostic_complete': report['diagnostic_complete'], 'performance_qualified': False,
                      'output': str(args.output)}, ensure_ascii=False))
    raise SystemExit(0 if report['diagnostic_complete'] else 2)


if __name__ == '__main__':
    main()
