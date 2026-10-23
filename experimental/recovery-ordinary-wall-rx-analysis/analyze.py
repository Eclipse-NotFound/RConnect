"""Read-only receive-stage decomposition of the existing ACK transport matches.

No game execution, pixel verdict changes, clock correction, or network attribution.
"""
from pathlib import Path
from collections import Counter, defaultdict, deque
import argparse
import copy
import hashlib
import importlib.util
import json
import math
import statistics
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
ACK = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/analyze.py'
ACK_SHA = 'f95e28203dfc1dd26e54e25fce371d46c03d5d97e99692131d6ffeae2d42c608'
ROLES = ('host', 'join')
RX_INTS = ('rxCallbackId', 'rxCallbackEntryAt', 'rxCarriedBytes', 'rxBufferAfterRead',
    'rxReadStartAt', 'rxReadDoneAt', 'rxFrameIndex', 'rxPayloadBytes',
    'rxExtractStartAt', 'rxCodecStartAt', 'rxCodecDoneAt', 'rxPriorFrames',
    'rxPriorBytes', 'rxPriorExtractMs', 'rxPriorCodecMs', 'rxPriorDispatchCount', 'rxPriorDispatchMs')
RX_FIELDS = RX_INTS + ('rxCallbackEntryWall', 'rxBinary', 'rxCarriedFirstFrame')


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def original_module():
    require(sha(ACK) == ACK_SHA, 'Original ACK analyzer changed')
    spec = importlib.util.spec_from_file_location('rx_original_ack_analyzer', ACK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read(path, inputs):
    require(path.is_file() and path.stat().st_size <= 8 * 1024**2, 'Missing/oversized input: ' + str(path))
    inputs[str(path.resolve())] = sha(path)
    return json.loads(path.read_text(encoding='utf-8-sig'))


def validate_rx(event):
    for key in RX_INTS + ('at',):
        require(type(event.get(key)) is int and event[key] >= 0, 'Invalid integer ' + key)
    for key in ('wall', 'rxCallbackEntryWall'):
        value = event.get(key)
        require(type(value) in (int, float) and math.isfinite(value) and value == int(value), 'Invalid wall clock ' + key)
    for key in ('rxBinary', 'rxCarriedFirstFrame'):
        require(type(event.get(key)) is bool, 'Missing/non-Boolean ' + key)
    order = [event[k] for k in ('rxCallbackEntryAt', 'rxReadStartAt', 'rxReadDoneAt',
        'rxExtractStartAt', 'rxCodecStartAt', 'rxCodecDoneAt', 'at')]
    require(order == sorted(order), 'Non-monotonic receive stages')
    require(event['rxCallbackId'] > 0 and event['rxFrameIndex'] > 0 and event['rxPayloadBytes'] > 0, 'Invalid receive identity/length')
    require(event['rxPriorFrames'] == event['rxFrameIndex'] - 1, 'Prior frame count differs')
    require(event['rxPriorDispatchCount'] <= event['rxPriorFrames'], 'Too many prior dispatches')
    require(event['rxCarriedBytes'] <= event['rxBufferAfterRead'], 'Carry exceeds received buffer')
    require(event['rxPriorBytes'] + 4 + event['rxPayloadBytes'] <= event['rxBufferAfterRead'], 'Frames exceed received buffer')
    require(event['rxPriorBytes'] >= 4 * event['rxPriorFrames'], 'Prior byte total omits frame headers')
    require(event['rxCarriedFirstFrame'] == (event['rxFrameIndex'] == 1 and event['rxCarriedBytes'] > 0), 'Incorrect carried-first-frame marker')
    if event['rxPriorFrames'] == 0:
        require(all(event[k] == 0 for k in ('rxPriorBytes', 'rxPriorExtractMs', 'rxPriorCodecMs',
            'rxPriorDispatchCount', 'rxPriorDispatchMs')), 'First frame has prior work')


def decompose(tx, rx):
    validate_rx(rx)
    local = rx['at'] - rx['rxCallbackEntryAt']
    parts = dict(entry_pre_read_ms=rx['rxReadStartAt'] - rx['rxCallbackEntryAt'],
        socket_read_ms=rx['rxReadDoneAt'] - rx['rxReadStartAt'],
        prior_extract_ms=rx['rxPriorExtractMs'], prior_codec_ms=rx['rxPriorCodecMs'],
        prior_dispatch_ms=rx['rxPriorDispatchMs'],
        current_extract_ms=rx['rxCodecStartAt'] - rx['rxExtractStartAt'],
        current_codec_ms=rx['rxCodecDoneAt'] - rx['rxCodecStartAt'],
        codec_done_to_original_rx_ms=rx['at'] - rx['rxCodecDoneAt'])
    other = local - sum(parts.values())
    require(other >= 0, 'Overlapping/invalid callback stage totals')
    parts['other_callback_ms'] = other
    before = rx['rxCallbackEntryWall'] - tx['wall']
    wall_total = rx['wall'] - tx['wall']
    residual = (rx['wall'] - rx['rxCallbackEntryWall']) - local
    require(before + local + residual == wall_total, 'Clock decomposition does not reconstruct original interval')
    return dict(tx_flush_to_callback_entry_cross_process_ms=before,
        original_flush_to_rx_cross_process_ms=wall_total,
        callback_entry_to_original_rx_same_process_ms=local,
        entry_to_read_done_same_process_ms=rx['rxReadDoneAt'] - rx['rxCallbackEntryAt'],
        wall_timer_span_residual_ms=residual, negative_cross_process_before=before < 0,
        carried_first_frame=rx['rxCarriedFirstFrame'], components=parts)


def checked_pairs(traces, expected, expected_unmatched, original):
    """Reproduce the exact recorded-key/FIFO rule, preserving raw event indices."""
    actual, unmatched = original.transport_rows(traces)
    require(actual == expected and unmatched == expected_unmatched, 'Original transport analysis differs from raw events')
    matches, missing = [], []
    for sender, receiver in (('host', 'join'), ('join', 'host')):
        queue = defaultdict(deque)
        tx_counts, rx_counts = Counter(), Counter()
        for index, event in enumerate(traces[receiver]['events']):
            if event['kind'].startswith('rx-'):
                key = original.packet_key(event)
                queue[key].append((index, event)); rx_counts[key] += 1
        for event in traces[sender]['events']:
            if event['kind'].startswith('tx-'):
                tx_counts[original.packet_key(event)] += 1
        for index, event in enumerate(traces[sender]['events']):
            if not event['kind'].startswith('tx-'):
                continue
            key = original.packet_key(event)
            if not queue[key]:
                missing.append(dict(role=sender, event_index=index, event=event))
                continue
            rx_index, arrived = queue[key].popleft()
            old = expected[len(matches)]
            require(old['sender'] == sender and old['tx_wall'] == event['wall'] and old['rx_wall'] == arrived['wall'], 'FIFO/source-row mismatch')
            matches.append(dict(original_transport_index=len(matches), original_transport=old,
                sender=sender, receiver=receiver, tx_event_index=index, rx_event_index=rx_index,
                tx_at=event['at'], tx_wall=event['wall'], rx_at=arrived['at'], rx_wall=arrived['wall'],
                recorded_key=json.loads(json.dumps(key)), same_key_tx_count=tx_counts[key], same_key_rx_count=rx_counts[key],
                metadata_prefix_only=bool(event.get('metadataPrefixOnly') or arrived.get('metadataPrefixOnly')),
                rx_observation={k: arrived[k] for k in RX_FIELDS}, stages=decompose(event, arrived)))
        for candidates in queue.values():
            for index, event in candidates:
                missing.append(dict(role=receiver, event_index=index, event=event))
    require(len(matches) == len(expected) and len(missing) == len(expected_unmatched), 'Incomplete source coverage')
    # The original analyzer emits unmatched records in the same deterministic order.
    for row, old in zip(missing, expected_unmatched):
        event = row['event']
        require((old['side'], old['kind'], old.get('seq'), old.get('tick'), old['wall']) ==
                (row['role'], event['kind'], event.get('seq'), event.get('tick'), event['wall']), 'Unmatched event differs')
        row['original_unmatched'] = old
    return matches, missing


def trace_check(trace, role, index):
    require(trace['kind'] == 'ordinary-wall-ack-timing-v1' and trace['role'] == role and trace['round'] == index, 'Trace identity differs')
    require(trace['complete'] is True and trace['bothSampled'] is True and trace['termination'] == 'analyze', 'Incomplete original trace')
    require(trace['overflow'] is False and trace['dropped'] == trace['faultCount'] == 0 and not trace['faults'], 'Original trace fault/truncation')
    require(trace['capacity'] == 256 and trace['eventCount'] == len(trace['events']) <= 256, 'Invalid bounded trace size')
    for sample in ('localSampled', 'peerSampled'):
        require(trace['started']['at'] <= trace[sample]['at'] <= trace['ended']['at'], 'Sample lies outside original trace window')
    for key in ('rxProbeCalls', 'rxProbeTotalMs', 'rxProbeMaxMs'):
        require(type(trace.get(key)) is int and trace[key] >= 0, 'Missing receive probe accounting')
    require(trace['rxProbeMaxMs'] <= trace['rxProbeTotalMs'], 'Invalid receive probe cost')
    callbacks = {}
    previous_at = -1
    for event in trace['events']:
        require(event['at'] >= previous_at and event['round'] == index and event['role'] == role, 'Non-monotonic/wrong event identity')
        previous_at = event['at']
        if not event['kind'].startswith('rx-'):
            continue
        validate_rx(event)
        fixed = tuple(event[k] for k in ('rxCallbackEntryAt', 'rxCallbackEntryWall', 'rxCarriedBytes',
            'rxBufferAfterRead', 'rxReadStartAt', 'rxReadDoneAt'))
        callback = event['rxCallbackId']
        if callback in callbacks:
            old_fixed, old_index = callbacks[callback]
            require(fixed == old_fixed and event['rxFrameIndex'] > old_index, 'Callback identity/ordinal changed')
        callbacks[callback] = (fixed, event['rxFrameIndex'])
    return dict(observed_callbacks=len(callbacks), rxProbeCalls=trace['rxProbeCalls'],
        rxProbeTotalMs=trace['rxProbeTotalMs'], rxProbeMaxMs=trace['rxProbeMaxMs'])


def stats(values):
    if not values:
        return dict(count=0)
    ordered = sorted(values)
    return dict(count=len(values), minimum=ordered[0], median=statistics.median(ordered),
        mean=statistics.mean(ordered), p95=ordered[max(0, math.ceil(len(ordered) * .95) - 1)], maximum=ordered[-1])


def summarize(matches):
    metrics = defaultdict(list)
    for row in matches:
        values = {k: v for k, v in row['stages'].items() if k.endswith('_ms')}
        values.update(row['stages']['components'])
        for key, value in values.items():
            metrics[key].append(value)
    return dict(matches=len(matches), negative_before=sum(r['stages']['negative_cross_process_before'] for r in matches),
        carried_first_frames=sum(r['stages']['carried_first_frame'] for r in matches),
        prefix_only_matches=sum(r['metadata_prefix_only'] for r in matches),
        repeated_key_matches=sum(r['same_key_tx_count'] > 1 or r['same_key_rx_count'] > 1 for r in matches),
        metrics={key: stats(values) for key, values in metrics.items()})


def analyze(folder, supplemental_path=None):
    original = original_module()
    inputs = {str(Path(__file__).resolve()): sha(Path(__file__).resolve()), str(ACK): ACK_SHA}
    result_path = folder / 'ack-timing-result.json'
    result = read(result_path, inputs)
    require(all(result.get(k) is True for k in ('functional_pass', 'framework_passed', 'diagnostic_evidence_complete',
        'inputs_unchanged')), 'Original functional/ACK evidence incomplete')
    require(result.get('ack_timing_samples_ready', result.get('diagnostic_samples_ready')) is True, 'Original ACK samples unavailable')
    pixels_path = folder / 'wall-surface-analysis.json'
    pixels = read(pixels_path, inputs)
    require(pixels['passed'] is True and [r['round'] for r in pixels['rows']] == list(range(4)), 'Missing four-round pixel qualification')
    old = read(folder / 'timing-analysis.json', inputs) if (folder / 'timing-analysis.json').exists() else None
    if old is not None:
        require(old['kind'] == 'wall-ack-timing-analysis' and old['diagnostic_only'] is True and old['performance_qualified'] is False, 'Wrong original analysis')
        require([r['round'] for r in old['rounds']] == list(range(4)), 'Expected four original rounds')
        require(old['inputs'].get(str(ACK)) == ACK_SHA, 'Original analysis uses a different analyzer')
    supplemental = None
    if supplemental_path is not None:
        supplemental = read(supplemental_path, inputs)
        require(supplemental['kind'] == 'ordinary-rx-direction-supplemental-qualification', 'Unexpected supplemental kind')
        require(all(supplemental.get(k) is True for k in ('passed', 'original_result_unchanged', 'functional_pass',
            'framework_passed', 'pixel_passed', 'diagnostic_evidence_complete', 'diagnostic_samples_ready',
            'all_original_scalar_checks_preserved')), 'Supplemental evidence incomplete')
        require(supplemental['original_result_path'] == str(result_path.resolve()) and
            supplemental['original_result_passed'] is result['passed'], 'Supplemental original result differs')
        require(supplemental['run'] == result['run'] and supplemental['candidate_sha256'] == result['admission']['candidate_sha256'], 'Supplemental run/candidate differs')
        require(supplemental['air_started'] is False and supplemental['performance_qualified'] is False, 'Unexpected supplemental scope')
        for path in (result_path, pixels_path):
            require(supplemental['inputs'].get(str(path.resolve())) == inputs[str(path.resolve())], 'Supplemental input changed: ' + str(path))
        validator = supplemental_path.parent / 'scalar-validator.py'
        require(sha(validator) == supplemental['adapted_validator_sha256'], 'Supplemental validator changed')
        inputs[str(validator.resolve())] = sha(validator)
    else:
        require(result.get('diagnostic_samples_ready') is True and result.get('rx_samples_ready') is True, 'Supplemental RX qualification required for original diagnostic failure')
    file_pins = {(f['role'], f['round']): f for f in result['files']}
    require(len(file_pins) == len(result['files']) == 8, 'Expected eight distinct original timing files')
    rounds, all_matches = [], []
    for index, labels in enumerate(pixels['rows']):
        traces, overhead = {}, {}
        for role in ROLES:
            path = folder / 'wall-ack-timing' / role / f'round-{index}.json'
            trace = read(path, inputs)
            digest = inputs[str(path.resolve())]
            pin = file_pins[(role, index)]
            require((folder / pin['file']).resolve() == path.resolve() and pin['sha256'] == digest, 'Original trace pin differs')
            if old is not None:
                require(old['inputs'].get(str(path.resolve())) == digest, 'Trace not pinned by original analysis')
            if supplemental is not None:
                require(supplemental['inputs'].get(str(path.resolve())) == digest, 'Trace not pinned by supplemental qualification')
                coverage = [r for r in supplemental['coverage'] if r['role'] == role and r['round'] == index]
                actual_kinds = sorted({e['kind'] for e in trace['events'] if e['kind'].startswith('rx-')})
                require(len(coverage) == 1 and coverage[0]['actual_rx_kinds'] == actual_kinds and
                    coverage[0]['source_role'] == labels['source'], 'Supplemental direction evidence differs')
            overhead[role] = trace_check(trace, role, index); traces[role] = trace
        if old is not None:
            prior = old['rounds'][index]
        else:
            packets, unmatched = original.transport_rows(traces)
            prior = dict(transport=packets, unmatched_transport=unmatched)
        matched, missing = checked_pairs(traces, prior['transport'], prior['unmatched_transport'], original)
        rounds.append(dict(round=index, source=labels['source'], weapon=labels['weapon'], transport_matches=matched,
            unmatched_transport=missing, original_ack_cycles=original.ack_rows(traces),
            receive_probe_accounting=overhead, summary=summarize(matched)))
        all_matches.extend(matched)
    grouped = {}
    for sender in ROLES:
        for kind in ('paint', 'report', 'ack'):
            selected = [r for r in all_matches if r['sender'] == sender and r['original_transport']['kind'] == kind]
            if selected:
                grouped[sender + ':' + kind] = summarize(selected)
    return dict(kind='ordinary-wall-receive-stage-analysis', analysis_complete=True, diagnostic_only=True,
        performance_qualified=False, original_results_changed=False, inputs=inputs, rounds=rounds,
        qualification=dict(original_result_passed=result['passed'],
            original_diagnostic_samples_ready=result['diagnostic_samples_ready'],
            original_rx_failures=result.get('rx_failures', []), supplemental_used=supplemental is not None,
            supplemental_path=str(supplemental_path) if supplemental_path else None,
            pairing_source='existing-timing-analysis' if old is not None else 'frozen-original-transport_rows-direct'),
        summary=summarize(all_matches), by_sender_and_kind=grouped,
        unmatched_total=sum(len(r['unmatched_transport']) for r in rounds), interpretation=[
            'Original rounds[].transport and unmatched_transport are reproduced exactly using their recorded-key/FIFO rule.',
            'Keys contain at most the recorded three-cell metadata prefix; this is not a full-payload identity proof.',
            'Callback-entry-before intervals use cross-process Date clocks and include output buffering, transport, runtime scheduling and possible partial-frame waits; they are not network latency.',
            'Local stage intervals use receiver getTimer. wall_timer_span_residual_ms is preserved, not corrected or clamped.',
            'Entry-to-read-done is a convenience subtotal. Only components are disjoint and sum to callback-entry-to-original-rx.',
            'Prior-stage distributions are per-message cumulative prefixes and must not be summed as exclusive CPU work.',
            'A carried first frame was already partially buffered; callback entry is never a physical first-byte arrival timestamp.',
            'Codec includes existing validation plus native AMF or JSON parse. Other callback time includes parsing, bookkeeping, diagnostics and unseparated work.',
            'Receive helper accounting omits raw clock/branch overhead; original probe accounting includes extras assembly. This is not production performance acceptance.',
        ])


def self_test():
    original = original_module()
    rx = dict(kind='rx-paint', type='unitsync', roomKey='room', roomEpoch=2, roomTerm=3,
        seq=None, tick=9, cellCount=1, prefixEncodedChars=12,
        cells=[dict(x=1, y=2, sv=0, v=1, full=False, needsNative=False)],
        metadataPrefixOnly=False, at=216, wall=1046, rxCallbackId=1, rxCallbackEntryAt=200,
        rxCallbackEntryWall=1030, rxCarriedBytes=0, rxBufferAfterRead=200,
        rxReadStartAt=201, rxReadDoneAt=202, rxFrameIndex=2, rxPayloadBytes=40, rxBinary=True,
        rxCarriedFirstFrame=False, rxExtractStartAt=212, rxCodecStartAt=213, rxCodecDoneAt=215,
        rxPriorFrames=1, rxPriorBytes=100, rxPriorExtractMs=1, rxPriorCodecMs=2,
        rxPriorDispatchCount=1, rxPriorDispatchMs=4)
    tx = {k: copy.deepcopy(v) for k, v in rx.items() if not k.startswith('rx')}
    tx.update(kind='tx-paint', at=99, wall=1000)
    checked = []
    split = decompose(tx, rx)
    require(split['components']['other_callback_ms'] == 3, 'Known other callback gap')
    require(split['components']['current_codec_ms'] == 2 and sum(split['components'].values()) == 16, 'Known stages')
    require(split['tx_flush_to_callback_entry_cross_process_ms'] == 30 and split['wall_timer_span_residual_ms'] == 0, 'Known clocks')
    checked.append('known-disjoint-stages')
    carried = dict(rx, rxFrameIndex=1, rxPriorFrames=0, rxPriorBytes=0, rxPriorExtractMs=0,
        rxPriorCodecMs=0, rxPriorDispatchCount=0, rxPriorDispatchMs=0, rxCarriedBytes=8, rxCarriedFirstFrame=True)
    require(decompose(tx, carried)['carried_first_frame'], 'Carried prefix lost'); checked.append('carried-prefix')
    require(decompose(dict(tx, wall=1040), rx)['negative_cross_process_before'], 'Negative interval clamped'); checked.append('negative-cross-clock-preserved')
    require(decompose(tx, dict(rx, wall=1053))['wall_timer_span_residual_ms'] == 7, 'Clock residual discarded'); checked.append('wall-timer-residual')
    traces = {'host': {'events': [tx]}, 'join': {'events': [rx]}}
    expected, missing = original.transport_rows(traces)
    matched, unmatched = checked_pairs(traces, expected, missing, original)
    require(len(matched) == 1 and not unmatched and matched[0]['rx_event_index'] == 0, 'Exact raw index'); checked.append('original-fifo-index')
    doubled = {'host': {'events': [tx, dict(tx, wall=1001)]}, 'join': {'events': [rx, dict(rx, wall=1047)]}}
    expected, missing = original.transport_rows(doubled)
    matched, _ = checked_pairs(doubled, expected, missing, original)
    require([r['rx_event_index'] for r in matched] == [0, 1] and all(r['same_key_tx_count'] == 2 for r in matched), 'Duplicate key overwritten'); checked.append('repeated-key-fifo')
    empty = {'host': {'events': [tx]}, 'join': {'events': []}}
    expected, missing = original.transport_rows(empty)
    matched, unmatched = checked_pairs(empty, expected, missing, original)
    require(not matched and len(unmatched) == 1 and unmatched[0]['event'] == tx, 'Unmatched discarded'); checked.append('unmatched-preserved')
    for label, bad in [('missing-extra', {k: v for k, v in rx.items() if k != 'rxCodecDoneAt'}),
                       ('reversed-stage', dict(rx, rxCodecDoneAt=212)),
                       ('false-carried-marker', dict(rx, rxCarriedFirstFrame=True))]:
        try:
            decompose(tx, bad)
        except ValueError:
            checked.append(label + '-rejected')
        else:
            raise ValueError(label + ' accepted')
    expected, missing = original.transport_rows(traces)
    expected[0]['flush_to_decoded_dispatch_ms'] += 1
    try:
        checked_pairs(traces, expected, missing, original)
    except ValueError:
        checked.append('changed-original-match-rejected')
    else:
        raise ValueError('Changed original analysis accepted')
    return dict(kind='offline-synthetic-boundary-checks', passed=True, checks=checked,
        runtime_or_performance_qualification=False, original_analyzer_sha256=ACK_SHA)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--supplemental', type=Path, help='Independent qualification; original result remains unchanged')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        require(args.input is None and args.output is None and args.supplemental is None, 'Self-test uses no run files/output')
        print(json.dumps(self_test(), ensure_ascii=False, indent=2)); return
    require(args.input is not None, '--input is required')
    folder = (ROOT / args.input).resolve()
    require(folder.parent == (ROOT / 'build/m52').resolve(), 'Expected one isolated m52 run directory')
    output = (ROOT / args.output).resolve() if args.output else folder / 'rx-stage-analysis.json'
    require(output.parent == folder and not output.exists(), 'Output must be a new file in the same isolated run')
    supplemental = (ROOT / args.supplemental).resolve() if args.supplemental else None
    result = analyze(folder, supplemental)
    with output.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2); stream.write('\n')
    print(json.dumps(dict(output=str(output), matches=result['summary']['matches'],
        unmatched=result['unmatched_total'], diagnostic_only=True, performance_qualified=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
