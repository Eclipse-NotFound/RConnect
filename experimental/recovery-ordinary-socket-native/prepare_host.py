"""Prepare/verify an isolated FWS version-header trial; never compile or run AIR."""
from pathlib import Path
import argparse
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Header proof requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-ordinary-mask-host-02'
HOST = ROOT / 'build/m52/recovery-ordinary-socket-host-01'
BASE_SHA = '6616b1a5d90e541980954ea8831949c5c5f72e945ef8378275567b9ade40289b'
BASE_RECEIPT_SHA = '542d59fb6db55cad9891cb2beaf946921290790df7900112f1038995c7f7044d'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def installation():
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    import run_security_terminals
    assert Path(run_security_terminals.__file__).resolve() == ROOT / 'tools/validation/run_security_terminals.py'
    value = run_security_terminals.installation()
    assert len(value) == 22
    return value


def source():
    assert sha(BASE / 'pfe.swf') == BASE_SHA
    assert sha(BASE / 'runtime-admission.json') == BASE_RECEIPT_SHA
    receipt = json.loads((BASE / 'runtime-admission.json').read_text(encoding='utf-8-sig'))
    assert receipt['candidate_sha256'] == BASE_SHA and receipt['scope'] == 'native-test-only'
    assert receipt['validated'] is True and receipt['installed'] is False
    raw = (BASE / 'pfe.swf').read_bytes()
    assert raw[:3] == b'FWS' and raw[3] == 41
    assert int.from_bytes(raw[4:8], 'little') == len(raw)
    return raw


def verify():
    original = source()
    current = (HOST / 'pfe.swf').read_bytes()
    assert len(current) == len(original) and current[:3] == original[:3]
    assert current[3] == 51 and current[4:] == original[4:]
    receipt = json.loads((HOST / 'receipt.json').read_text(encoding='utf-8'))
    assert receipt['kind'] == 'ordinary-socket-header51-input-proof'
    assert receipt['scope'] == 'isolated-native-test-input-only'
    assert receipt['base_sha256'] == BASE_SHA and receipt['base_receipt_sha256'] == BASE_RECEIPT_SHA
    assert receipt['candidate_sha256'] == sha(HOST / 'pfe.swf')
    assert receipt['changed_offsets'] == [3] and receipt['version_before'] == 41 and receipt['version_after'] == 51
    assert receipt['magic'] == 'FWS' and receipt['length'] == len(current)
    assert receipt['all_other_bytes_identical'] is True and receipt['header_proof_passed'] is True
    assert receipt['runtime_compatibility_verified'] is False and receipt['installed'] is False
    assert receipt['installation_before'] == receipt['installation_after'] == installation()
    for name, digest in receipt['inputs'].items():
        assert sha(name) == digest, name
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        raw = source()
        before = installation()
        assert not HOST.exists(), 'Preserve earlier host proof; never overwrite it'
        HOST.mkdir()
        (HOST / 'pfe.swf').write_bytes(raw[:3] + bytes([51]) + raw[4:])
        after = installation()
        assert before == after
        receipt = dict(kind='ordinary-socket-header51-input-proof', scope='isolated-native-test-input-only',
            base=str(BASE), base_sha256=BASE_SHA, base_receipt_sha256=BASE_RECEIPT_SHA,
            candidate_sha256=sha(HOST / 'pfe.swf'), changed_offsets=[3], version_before=41,
            version_after=51, magic='FWS', length=len(raw), all_other_bytes_identical=True,
            header_proof_passed=True, runtime_compatibility_verified=False, installed=False,
            installation_before=before, installation_after=after,
            inputs={str(p): sha(p) for p in (BASE / 'pfe.swf', BASE / 'runtime-admission.json',
                Path(__file__).resolve(), ROOT / 'tools/validation/run_security_terminals.py')})
        with (HOST / 'receipt.json').open('x', encoding='utf-8') as stream:
            json.dump(receipt, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    proof = verify()
    print(json.dumps(dict(prepared=args.prepare, header_proof_passed=True,
        candidate_sha256=proof['candidate_sha256'], output=str(HOST),
        runtime_compatibility_verified=False, air_started=False, installed=False)))


if __name__ == '__main__':
    main()
