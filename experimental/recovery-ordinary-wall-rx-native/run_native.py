"""Narrow adaptation of frozen ACK entry; independent old/new product checks."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/run_native.py'
PINS = {
    OLD: '720b082c12b3a14a7abcc8388ff0e2ca83dc4ec8ff0ede82663c10bd43c6176b',
    OLD.parent / 'private_runner.py': 'ccf4941f217ca1b2054ba5cb0e2552a99e95b98da5bbdddcce0f37254cfea2fe',
    OLD.parent / 'README.md': 'b8bd4bcf3383437778c7b66f1019fb1c406f5ee1f396851e4e20209c15fe5370',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def prepared_source():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    source = OLD.read_text(encoding='utf-8')
    changes = [
        ("PRODUCT = M52 / 'recovery-ordinary-wall-ack-timing-01'", "PRODUCT = M52 / 'recovery-ordinary-wall-rx-timing-01'"),
        ("OVERLAY = ROOT / 'experimental/recovery-ordinary-wall-ack-timing/src'", "OVERLAY = ROOT / 'experimental/recovery-ordinary-wall-rx-timing/src'"),
        ("VERSION = '0.2.24-wallacktime1'", "VERSION = '0.2.24-wallrxtime1'"),
        ("r'recovery-ordinary-wall-ack-timing-native-\\d{2,}'", "r'recovery-ordinary-wall-rx-native-\\d{2,}'"),
        ("result.update(passed=False, final_verification_error=str(exc))",
         "result.update(passed=False, diagnostic_samples_ready=False, final_verification_error=str(exc))"),
        ("        out.mkdir(exist_ok=True)\n        save(out / 'ack-timing-result.json', result)",
         "        out.mkdir(exist_ok=True)\n        _save_adapter_sources(out)\n        save(out / 'ack-timing-result.json', result)"),
    ]
    for before, after in changes:
        assert source.count(before) == 1 and after not in source, before
        source = source.replace(before, after, 1)
    return source


def rx_proof(out, collection):
    rows, failures = [], []
    order = ('rxCallbackEntryAt', 'rxReadStartAt', 'rxReadDoneAt', 'rxExtractStartAt',
             'rxCodecStartAt', 'rxCodecDoneAt', 'at')
    integers = order + ('rxCallbackId', 'rxCarriedBytes', 'rxBufferAfterRead', 'rxFrameIndex',
        'rxPayloadBytes', 'rxPriorFrames', 'rxPriorBytes', 'rxPriorExtractMs', 'rxPriorCodecMs',
        'rxPriorDispatchCount', 'rxPriorDispatchMs')
    fixed = ('rxCallbackEntryAt', 'rxCallbackEntryWall', 'rxReadStartAt', 'rxReadDoneAt',
             'rxCarriedBytes', 'rxBufferAfterRead')
    for item in collection['files']:
        try:
            data = json.loads((out / item['file']).read_text(encoding='utf-8-sig'))
            for name in ('rxProbeCalls', 'rxProbeTotalMs', 'rxProbeMaxMs'):
                assert type(data[name]) is int and data[name] >= 0, name
            assert data['rxProbeMaxMs'] <= data['rxProbeTotalMs']
            received = [e for e in data['events'] if e.get('kind') in ('rx-report', 'rx-ack', 'rx-paint')]
            assert received and data['rxProbeCalls'] > 0, 'No receiver diagnostic coverage'
            callbacks = {}
            for event in received:
                for name in integers:
                    assert type(event[name]) is int and event[name] >= 0, name
                assert type(event['rxCallbackEntryWall']) in (int, float) and event['rxCallbackEntryWall'] > 0
                assert type(event['rxBinary']) is bool and type(event['rxCarriedFirstFrame']) is bool
                assert event['rxCallbackId'] > 0 and event['rxFrameIndex'] > 0 and event['rxPayloadBytes'] > 0
                assert all(event[a] <= event[b] for a, b in zip(order, order[1:])), 'Receiver stage order'
                assert event['rxPriorFrames'] == event['rxFrameIndex'] - 1
                assert event['rxPriorDispatchCount'] <= event['rxPriorFrames']
                assert event['rxCarriedFirstFrame'] == (event['rxFrameIndex'] == 1 and event['rxCarriedBytes'] > 0)
                assert event['rxCarriedBytes'] <= event['rxBufferAfterRead']
                assert event['rxPriorBytes'] + event['rxPayloadBytes'] + 4 <= event['rxBufferAfterRead']
                previous = callbacks.get(event['rxCallbackId'])
                if previous is not None:
                    assert all(previous[name] == event[name] for name in fixed), 'Callback context changed'
                    assert previous['rxFrameIndex'] < event['rxFrameIndex'], 'Frame order not increasing'
                    assert previous['rxCodecDoneAt'] <= event['rxExtractStartAt']
                    assert previous['rxPriorBytes'] + previous['rxPayloadBytes'] + 4 <= event['rxPriorBytes']
                    for name in ('rxPriorExtractMs', 'rxPriorCodecMs', 'rxPriorDispatchCount', 'rxPriorDispatchMs'):
                        assert previous[name] <= event[name], name
                callbacks[event['rxCallbackId']] = event
            rows.append(dict(role=item['role'], round=item['round'], file=item['file'], sha256=item['sha256'],
                rx_events=len(received), observed_callbacks=len(callbacks),
                rxProbeCalls=data['rxProbeCalls'], rxProbeTotalMs=data['rxProbeTotalMs'], rxProbeMaxMs=data['rxProbeMaxMs']))
        except Exception as exc:
            failures.append(dict(role=item['role'], round=item['round'], error=str(exc)))
    complete = len(rows) == 8 and not failures
    return dict(rx_evidence_complete=complete, rx_samples_ready=complete,
                rx_evidence=rows, rx_failures=failures)


def prepared_module():
    source = prepared_source()
    original = load(OLD, 'rx_original_ack_native_entry')
    private = load(HERE / 'private_runner.py', 'rx_private_candidate_only')
    private_source = private.prepared_source()
    scope = dict(__name__='rx_adapted_ack_native_entry', __file__=str(Path(__file__).resolve()))
    exec(compile(source, '<rx frozen ACK entry narrow adaptation>', 'exec'), scope)
    new_preflight, original_collect = scope['preflight'], scope['collect']

    def preflight():
        # The original 5771 product is independently checked at its real old
        # paths. Only then is the new overlay checked by its own actual build.
        *_, prior, _ = original.preflight()
        wall, shared, run, driver, admission, private_runtime = new_preflight()
        assert admission['current_installation'] == prior['current_installation']
        assert prior['candidate_sha256'] == '57713116a7f4c70e47bed655d9ed80490fb32ecb75f14e7bf964e75db0122c06'
        assert admission['native_host'] == prior['native_host']
        assert admission['native_host']['candidate_sha256'] == '6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b'
        with (scope['PRODUCT'] / 'RConnectMod.swf').open('rb') as stream:
            header = stream.read(4)
        assert header[:3] in (b'FWS', b'CWS', b'ZWS') and header[3] == 38
        with (Path(admission['native_host']['receipt_path']).parent / 'pfe.swf').open('rb') as stream:
            header = stream.read(4)
        assert header[:3] == b'FWS' and header[3] == 41
        assert private_runtime.count('http://ns.adobe.com/air/application/30.0') == 1
        assert 'http://ns.adobe.com/air/application/51.0' not in private_runtime
        assert 'socketNoDelayTrial' not in private_runtime
        pins = admission['inputs']
        for name, digest in prior['inputs'].items():
            assert name not in pins or pins[name] == digest
            pins[name] = digest
        for path, digest in PINS.items():
            assert sha(path) == digest
            pins[str(path)] = digest
        admission.update(prior_ack_candidate_sha256=prior['candidate_sha256'],
            prior_ack_prepared_sha256=prior['prepared_sha256'], prior_ack_compile_sha256=prior['compile_sha256'],
            host_swf_version=41, product_swf_version=38, namespace='30.0',
            adapter_source_sha256=hashlib.sha256(source.encode('utf-8')).hexdigest(),
            private_adapter_source_sha256=hashlib.sha256(private_source.encode('utf-8')).hexdigest())
        original.check_pins(pins)
        return wall, shared, run, driver, admission, private_runtime

    def collect(out, framework, wall, driver, admission):
        value = original_collect(out, framework, wall, driver, admission)
        value['ack_timing_samples_ready'] = value['diagnostic_samples_ready']
        value.update(rx_proof(out, value))
        value['diagnostic_samples_ready'] = bool(value['ack_timing_samples_ready'] and value['rx_samples_ready'])
        return value

    def save_sources(out):
        for name, text in (('rx-adapted-entry.py', source), ('rx-adapted-private-entry.py', private_source)):
            with (out / name).open('x', encoding='utf-8', newline='\n') as stream:
                stream.write(text)

    scope.update(preflight=preflight, collect=collect, _save_adapter_sources=save_sources)
    return scope


if __name__ == '__main__':
    raise SystemExit(prepared_module()['main']())
