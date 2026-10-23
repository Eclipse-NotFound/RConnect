"""Run unchanged C6A3/BF6 rooms or ordinary pixel tests with only the mask host changed.

Requires root's separate native-only admission of the actual new host. No build,
deployment, old binding rewrite, test-source substitution, or relaxed assertion.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys
import traceback

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python; -O is forbidden')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
ROOMS = ROOT / 'experimental/recovery-ordinary-wall-sv-rooms/run_native.py'
BUILDER = ROOT / 'experimental/recovery-ordinary-mask-host-fix-v2/build.py'
HOST = M52 / 'recovery-ordinary-mask-host-02'
RECEIPT = HOST / 'runtime-admission.json'
TARGET = 'fe.graph.Grafon::0:1:ordinaryMaskBounds'
PINS = {
    ROOMS: '10f463eba8cf31622cd49a27b617bcffcd54348ed36c87ea2192063c2b61a2ff',
    ROOMS.parent / 'README.md': '25025acd77e119ac1cfe41db158563ef8add101259b879ff8b4f4bd77f2e8955',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_pins(pins):
    for path, digest in pins.items():
        assert sha(path) == digest, str(path)


def new_host_admission():
    # Missing root receipt is a hard failure, including --check. The builder's
    # compiled=true / validated=false can never stand in for this admission.
    receipt = read(RECEIPT)
    assert receipt['kind'] == 'ordinary-mask-host-runtime-admission'
    assert receipt['validated'] is True and receipt['scope'] == 'native-test-only'
    assert receipt['installed'] is False
    check_pins(receipt['inputs'])
    assert receipt['inputs'][str(BUILDER)] == sha(BUILDER)
    builder = load(BUILDER, 'ordinary_mask_actual_host_builder')
    build = builder.verify_result(HOST)
    assert build['compiled'] is True and build['build_checks_passed'] is True
    assert build['validated'] is False
    assert receipt['candidate_sha256'] == build['candidate_sha256'] == sha(HOST / 'pfe.swf')
    assert receipt['build_manifest_sha256'] == sha(HOST / 'build.json')
    assert receipt['readback_audit_sha256'] == sha(HOST / 'readback-audit.json')
    assert receipt['method_audit_sha256'] == sha(HOST / 'method-audit.json')
    for name in ('pfe.swf', 'prepared.json', 'build.json', 'readback-audit.json', 'method-audit.json'):
        path = HOST / name
        assert receipt['inputs'][str(path)] == sha(path), 'Actual new host proof missing from root admission: ' + name
    for name, digest in build['artifacts'].items():
        path = (HOST / name).resolve()
        assert path.is_relative_to(HOST.resolve()), 'Build artifact escaped candidate directory'
        assert receipt['inputs'][str(path)] == digest == sha(path), name
    audit = read(HOST / 'method-audit.json')
    assert audit['passed'] is True and audit['target'] == TARGET
    for name in ('exactRetainedRoundTrip', 'nonTargetBodiesByteExact',
                 'classTraitsScriptsPreserved', 'oldConstantPrefixPreserved'):
        assert audit[name] is True, 'Actual method transplant audit: ' + name
    proof = audit['targetProof']
    assert isinstance(proof, dict)
    for name in ('flags', 'frame', 'privateMappings', 'oldAndAddedMasks', 'geometryTailUnchanged'):
        assert name in proof, 'Missing exact target evidence: ' + name
    assert proof['geometryTailUnchanged'] is True
    return dict(candidate_sha256=receipt['candidate_sha256'], validated=True,
        scope='native-test-only', receipt_path=str(RECEIPT), receipt_sha256=sha(RECEIPT),
        build=build, method_audit_sha256=sha(HOST / 'method-audit.json'), target=TARGET,
        target_proof=proof), receipt


def preflight():
    check_pins(PINS)
    rooms = load(ROOMS, 'ordinary_mask_existing_room_admission')
    wall, historical, observer, original = rooms.preflight()
    # This is intentionally still the exact old host05 binding, not a callback
    # returning our new binding under the old verifier's name.
    assert Path(historical['host']) == rooms.HOST and historical['native_host']['candidate_sha256'] == rooms.HOST_SHA
    native_host, receipt = new_host_admission()
    pins = dict(historical['inputs'])
    pins.update({str(p): h for p, h in PINS.items()})
    pins.update(receipt['inputs'])
    for path in (Path(__file__), HERE / 'README.md', RECEIPT):
        pins[str(path.resolve())] = sha(path)
    check_pins(pins)
    binding = dict(historical, kind='ordinary-mask-native-binding', inputs=pins,
        host=str(HOST), receipt=str(RECEIPT), native_host=native_host,
        historical_binding_host=historical['host'], historical_host_sha256=rooms.HOST_SHA,
        historical_binding_unchanged=True, new_host_admission_independent=True)
    return rooms, wall, observer, original, binding


def run_rooms(out, wait, rooms, wall, observer, original, binding):
    def installed():
        return wall.actual_installation(binding['historical_build_installation'])

    def candidate_audit(path):
        assert path.resolve() == wall.PRODUCT.resolve()
        wall.historical_product()
        assert installed() == binding['current_installation']

    def host_input(path, actual):
        assert path.resolve() == HOST.resolve() and actual == installed() == binding['current_installation']
        current, _ = new_host_admission()
        assert current == binding['native_host']
        return dict(directory=str(HOST), candidate_sha256=current['candidate_sha256'],
            manifest_sha256=sha(HOST / 'prepared.json'), original_sha256=actual['pfe.swf'],
            recheck=str(RECEIPT), recheck_sha256=sha(RECEIPT), source_inputs_unchanged=True,
            scope='native-test-only', target=TARGET)

    def host_check(path, intent, actual):
        assert host_input(path, actual) == intent
        candidate_audit(wall.PRODUCT)

    # Existing entry-room framework public callbacks only. Keep its original
    # error parser, 600s command, actual-input checks, memory and cleanup path.
    original.audit = candidate_audit
    original.host_input = host_input
    original.verify_host_intent = host_check
    original.verify_driver = observer.verify_driver
    original.installation = installed
    previous = sys.argv
    try:
        sys.argv = [str(rooms.ORIGINAL / 'run_native.py'), '--candidate', str(wall.PRODUCT),
            '--drivers', str(rooms.DRIVER), '--output', str(out), '--game-candidate', str(HOST),
            '--scenario', 'entry-room', '--registry-wait', str(wait)]
        original.main()
    finally:
        sys.argv = previous
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--scenario', choices=('rooms', 'pixels'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.check:
        assert args.scenario is None and args.output is None
        rooms, wall, _, _, binding = preflight()
        print(json.dumps(dict(checked=True, air_started=False, compiled=False, installed=False,
            candidate_sha256=wall.CANDIDATE, new_host_sha256=binding['native_host']['candidate_sha256'],
            host_receipt=str(RECEIPT), old_binding_host=rooms.HOST_SHA,
            old_binding_is_historical_only=True, installed_files=len(binding['current_installation']))))
        return 0
    assert args.scenario and args.output
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve()
    assert re.fullmatch(r'recovery-ordinary-mask-' + args.scenario + r'-\d{2,}', out.name)
    assert not out.exists(), 'Use a fresh output; preserve earlier evidence'
    result = dict(passed=False, scenario=args.scenario, functional_only=True,
        performance_qualified=False, gameplay_qualified=False, installed=False, driver_recompiled=False,
        product_changed=False, host_only_change=True, old_binding_not_rewritten=True)
    code = 1
    try:
        rooms, wall, observer, original, binding = preflight()
        result.update(candidate_sha256=wall.CANDIDATE, native_host=binding['native_host'],
            installation_before=binding['current_installation'], inputs=binding['inputs'],
            historical_binding_host=binding['historical_binding_host'])
        if args.scenario == 'rooms':
            code = run_rooms(out, args.registry_wait, rooms, wall, observer, original, binding)
        else:
            # execute accepts explicit host evidence. Its own final old
            # verify_binding() remains a real host05 check, not new-host proof.
            # Our separate preflight below verifies this new host again.
            code = wall.execute(out, args.registry_wait, binding)
        framework = read(out / 'result.json')
        assert framework['passed'] is True and code == 0
        result.update(framework_sha256=sha(out / 'result.json'), run=framework.get('run'))
        if args.scenario == 'rooms':
            assert framework['exit_code'] == 0 and framework['installation_unchanged'] is True
        else:
            pixels = read(out / 'wall-surface-result.json')
            assert pixels['passed'] is True and pixels['framework_passed'] is True
            assert pixels['native_host_sha256'] == binding['native_host']['candidate_sha256']
            assert pixels['candidate_sha256'] == wall.CANDIDATE
            result['pixel_result_sha256'] = sha(out / 'wall-surface-result.json')
        result['passed'] = True
    except (Exception, SystemExit) as exc:
        result.update(passed=False, error_type=type(exc).__name__, error=str(exc), traceback=traceback.format_exc())
        code = 1
    finally:
        try:
            *_, after = preflight()
            if 'binding' in locals():
                assert after == binding, 'New host, historical binding or actual installation drifted'
                check_pins(binding['inputs'])
            result.update(installation_after=after['current_installation'],
                inputs_unchanged=True, new_host_verified_after=True)
        except Exception as exc:
            result.update(passed=False, final_verification_error=str(exc))
            code = 1
        out.mkdir(exist_ok=True)
        # Never replace either original framework or exact pixel-analyzer result.
        save(out / 'mask-adapter-result.json', result)
    print(json.dumps(dict(passed=result['passed'], output=str(out), run=result.get('run'),
        scenario=args.scenario, performance_qualified=False, error=result.get('error')), ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
