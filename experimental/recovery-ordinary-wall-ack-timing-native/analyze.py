"""Supplementary timing extraction; never changes the native pixel verdict.

Packet timings are diagnostic observations, not a performance acceptance test.
Source phases are matched using the complete native and displayed uint maps.
"""
from pathlib import Path
import argparse
from collections import defaultdict, deque
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path, inputs):
    inputs[str(path.resolve())] = sha(path)
    return json.loads(path.read_text(encoding='utf-8-sig'))


def pairs(words):
    assert len(words) % 2 == 0
    result = dict(zip(words[::2], words[1::2]))
    assert len(result) * 2 == len(words), 'Repeated pixel offset'
    return result


def phase_rows(folder, index, inputs):
    proof = {role: read(folder / 'wall-proof' / role / f'round-{index}-proof.json', inputs)
             for role in ('host', 'join')}
    source_role = 'host' if index % 2 == 0 else 'join'
    remote_role = 'join' if source_role == 'host' else 'host'
    source, remote = proof[source_role], proof[remote_role]
    assert source['source'] is True and remote['source'] is False
    assert source['round'] == remote['round'] == index
    assert source['target'] == remote['target'] and source['area'] == remote['area']
    assert source['weapon'] == remote['weapon'] == ('lmg' if index < 2 else 'plamg')
    decoded = {role: [(f, pairs(f['native']), pairs(f['display'])) for f in p['frames']]
               for role, p in proof.items()}
    stages, previous = [], {}
    for frame, native, display in decoded[source_role]:
        if native == previous:
            continue
        assert native and display == native, 'Source native/display phase mismatch'
        stages.append((frame, native))
        previous = native
    # Keep an incomplete observation explicit; never fabricate a missed phase.
    hit_phase_pairing = len(stages) == len(source['hits']) == source['shots']
    rows = []
    for phase, (frame, native) in enumerate(stages):
        matches = [f for f, n, d in decoded[remote_role] if n == native and d == native]
        ambiguous = sum(n == native for _, n in stages) > 1
        row = dict(phase=phase + 1, pixels=len(native), source_render_wall=frame['wall'],
                   source_render_at=frame['at'], remote_phase_observed=bool(matches),
                   repeated_source_pattern_ambiguous=ambiguous)
        if matches and not ambiguous:
            first = matches[0]
            row.update(remote_render_wall=first['wall'], remote_render_at=first['at'],
                       render_to_render_ms=first['wall'] - frame['wall'])
        if hit_phase_pairing:
            hit = source['hits'][phase]
            assert hit['wall'] <= frame['wall']
            if phase + 1 < len(stages):
                assert frame['wall'] < source['hits'][phase + 1]['wall']
            row['hit_wall'] = hit['wall']
            if matches and not ambiguous:
                row['hit_to_remote_ms'] = matches[0]['wall'] - hit['wall']
        rows.append(row)
    return dict(round=index, source=source_role, weapon=source['weapon'], phases=rows,
                hit_phase_pairing=hit_phase_pairing, shots=source['shots'],
                max_observation_gap_ms={role: max(b['wall'] - a['wall'] for a, b in
                    zip(p['frames'], p['frames'][1:])) for role, p in proof.items()})


def room(event):
    return tuple(event.get(k) for k in ('roomKey', 'roomEpoch', 'roomTerm'))


def packet_key(event):
    cells = tuple(tuple(c.get(k) for k in ('x', 'y', 'sv', 'v', 'full', 'needsNative'))
                  for c in event['cells'])
    return (event['kind'][3:], event['type'], *room(event), event.get('seq'),
            event.get('tick'), event['cellCount'], event['prefixEncodedChars'], cells)


def transport_rows(traces):
    output, unmatched = [], []
    for sender, receiver in (('host', 'join'), ('join', 'host')):
        received = defaultdict(deque)
        for event in traces[receiver]['events']:
            if event['kind'].startswith('rx-'):
                received[packet_key(event)].append(event)
        for event in traces[sender]['events']:
            if not event['kind'].startswith('tx-'):
                continue
            candidates = received[packet_key(event)]
            if not candidates:
                unmatched.append(dict(side=sender, kind=event['kind'], seq=event.get('seq'),
                                      tick=event.get('tick'), wall=event['wall']))
                continue
            arrived = candidates.popleft()
            output.append(dict(sender=sender, kind=event['kind'][3:], type=event['type'],
                room=list(room(event)), seq=event.get('seq'), tick=event.get('tick'),
                cellCount=event['cellCount'], tx_wall=event['wall'], rx_wall=arrived['wall'],
                flush_to_decoded_dispatch_ms=arrived['wall'] - event['wall']))
        for candidates in received.values():
            for event in candidates:
                unmatched.append(dict(side=receiver, kind=event['kind'], seq=event.get('seq'),
                                      tick=event.get('tick'), wall=event['wall']))
    return output, unmatched


def ack_rows(traces):
    def events(role, kind):
        result = defaultdict(list)
        for event in traces[role]['events']:
            if event['kind'] == kind:
                result[(*room(event), event['seq'])].append(event)
        return result

    observed = {kind: events(role, kind) for role, kind in (
        ('join', 'tx-report'), ('host', 'rx-report'), ('host', 'tx-ack'),
        ('join', 'rx-ack'), ('join', 'ack-received'),
        ('join', 'pending-released'), ('join', 'ack-processed'))}
    output = []
    reports = [e for e in traces['join']['events'] if e['kind'] == 'tx-report']
    for report in reports:
        identity = (*room(report), report['seq'])
        groups = {kind: rows.get(identity, []) for kind, rows in observed.items()}
        row = dict(room=list(room(report)), seq=report['seq'],
                   event_counts={k: len(v) for k, v in groups.items()})
        if not all(len(v) == 1 for v in groups.values()):
            row['complete_pairing'] = False
            output.append(row)
            continue
        e = {k: v[0] for k, v in groups.items()}
        accepted = e['ack-received']['acceptedRoom'] is True and e['ack-processed']['completed'] is True
        released = e['pending-released']
        assert released['releaseAt'] <= released['completedAt'] <= e['ack-processed']['at']
        row.update(complete_pairing=True, accepted=accepted,
            report_to_ack_received_same_process_ms=e['rx-ack']['at'] - report['at'],
            report_flush_to_host_dispatch_ms=e['rx-report']['wall'] - report['wall'],
            host_settle_and_ack_send_ms=e['tx-ack']['at'] - e['rx-report']['at'],
            ack_flush_to_join_dispatch_ms=e['rx-ack']['wall'] - e['tx-ack']['wall'],
            join_ack_processing_ms=e['ack-processed']['at'] - e['ack-received']['at'],
            release_to_compose_done_ms=released['completedAt'] - released['releaseAt'],
            queued_after_compose=released['queuedFirst'])
        next_reports = [p for p in reports if room(p) == room(report)
                        and p['seq'] > report['seq'] and p['at'] >= e['ack-processed']['at']]
        row['next_report_observed'] = bool(next_reports)
        if next_reports:
            next_report = next_reports[0]
            row.update(next_seq=next_report['seq'],
                       ack_processed_to_next_flush_ms=next_report['at'] - e['ack-processed']['at'])
        row['queued_work_confirmed_after_ack'] = bool(accepted and released['queuedFirst']['found']
                                                     and released['queuedFirst']['eligible'] is True)
        output.append(row)
    return output


def trace_rows(folder, index, inputs):
    traces = {role: read(folder / 'wall-ack-timing' / role / f'round-{index}.json', inputs)
              for role in ('host', 'join')}
    for role, trace in traces.items():
        assert trace['kind'] == 'ordinary-wall-ack-timing-v1'
        assert trace['role'] == role and trace['round'] == index
        assert trace['complete'] is True and trace['bothSampled'] is True
        assert trace['overflow'] is False and trace['dropped'] == trace['faultCount'] == 0
        assert not trace['faults'] and trace['termination'] == 'analyze'
        assert trace['capacity'] == 256 and trace['eventCount'] == len(trace['events']) <= 256
        assert trace['started']['at'] <= trace['localSampled']['at'] <= trace['ended']['at']
        assert trace['started']['at'] <= trace['peerSampled']['at'] <= trace['ended']['at']
        for a, b in zip(trace['events'], trace['events'][1:]):
            assert a['at'] <= b['at'], 'Non-monotonic same-process clock'
    packets, unmatched = transport_rows(traces)
    clocks = {}
    for role, trace in traces.items():
        offsets = [e['wall'] - e['at'] for e in trace['events']]
        clocks[role] = dict(events=trace['eventCount'], probeCalls=trace['probeCalls'],
            probeTotalMs=trace['probeTotalMs'], probeMaxMs=trace['probeMaxMs'],
            wall_minus_timer_min=min(offsets) if offsets else None,
            wall_minus_timer_max=max(offsets) if offsets else None)
    return dict(clocks=clocks, transport=packets, unmatched_transport=unmatched,
                ack_cycles=ack_rows(traces))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    folder = (ROOT / args.input).resolve()
    assert folder.parent == (ROOT / 'build/m52').resolve()
    inputs = {str(Path(__file__).resolve()): sha(Path(__file__).resolve())}
    original = read(folder / 'ack-timing-result.json', inputs)
    assert original['functional_pass'] is True and original['framework_passed'] is True
    assert original['diagnostic_evidence_complete'] is True
    assert original['diagnostic_samples_ready'] is True
    assert read(folder / 'wall-surface-analysis.json', inputs)['passed'] is True
    result = dict(kind='wall-ack-timing-analysis', diagnostic_only=True,
                  performance_qualified=False, original_results_changed=False, inputs=inputs,
                  rounds=[phase_rows(folder, n, inputs) for n in range(4)])
    for index, row in enumerate(result['rounds']):
        row.update(trace_rows(folder, index, inputs))
    result['interpretation'] = [
        'Same-process ACK processing and next-flush durations use getTimer.',
        'Cross-process Date durations include receiver scheduling and decode; they are not pure network latency.',
        'A next report alone does not prove backlog existed at ACK; queued_after_compose must confirm eligible work.',
        'Transport pairing uses room, sequence or tick, cell count and the bounded metadata prefix, not pixels.',
        'Timing instrumentation and bounded rendering observations remain present; this is not production performance acceptance.',
    ]
    output = folder / 'timing-analysis.json'
    with output.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps(dict(output=str(output), rounds=len(result['rounds']),
                         performance_qualified=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
