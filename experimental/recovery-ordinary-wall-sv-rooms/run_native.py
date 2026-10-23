"""Same frozen entry-room driver/framework; explicit C6A3 + host05 admission.
No source substitutions, compilation, installation, or new gameplay assertions.
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
    raise RuntimeError('Admission assertions require ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
WALL = ROOT / 'experimental/recovery-ordinary-wall-sv-native'
OBSERVER = ROOT / 'experimental/recovery-room-entry-observer'
ORIGINAL = ROOT / 'experimental/recovery-first-raster-native'
DRIVER = M52 / 'recovery-entry-observer-driver-01'
HOST = M52 / 'recovery-ordinary-wall-sv-host-05'
HOST_SHA = '00c7c511ffa51745cb4932e820365091d2540978eedd6dfe726a5cfd7818aa48'
PINS = {
    WALL / 'native_tool.py': 'dd0f2bde44e83df8a39190b1d6aec4486bc3312889660ff166b25bbce9d3a546',
    WALL / 'binding.json': 'e6e454ad80da9d2cf03720e4da6635a7d00b7a8f3667f2edb5fb441cf4c462b7',
    OBSERVER / 'prepare.py': '7188e9c0fb06b80020b50cea6d7f1d5df8eb3aca2506643bf4e0a35f8597f5e2',
    OBSERVER / 'generate.py': 'd58b0d8d92ab5593aebb1b5bc10dd548a7a22d7765ca0b6e3a623614d6887694',
    OBSERVER / 'run_native.py': '1937cfde01b5c2e183b334d0e025c36fe64ef72e12f32222945af3b07a2e3f81',
    ORIGINAL / 'run_native.py': '69d6e237b642821479f6d05c9af9a74f7cd62a4884578d4072fbeb7b7402ea6a',
    ORIGINAL / 'native_inputs.py': '45091e8cc3a35c225308ee154b3a5bc49a7107f60f2e0f840d14a164e85a3889',
    DRIVER / 'prepared.json': 'ae5c4035054e4474baa94a1003b0d9a32261bc8df82be0edd09255bdc69abc55',
    DRIVER / 'entry-room/EffectsDriver.swf': 'bf6c9567010d93dd20b334df3da7ed069e168583a2f45868a8d4352bc0e553ba',
    HOST / 'pfe.swf': HOST_SHA,
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


def preflight():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    wall = load(WALL / 'native_tool.py', 'ordinary_sv_existing_admission')
    binding = wall.verify_binding()  # Full candidate/host proof and actual EB365 22-file inventory.
    assert Path(binding['host']) == HOST and binding['native_host']['candidate_sha256'] == HOST_SHA
    sys.path.insert(0, str(OBSERVER))
    observer = load(OBSERVER / 'prepare.py', 'ordinary_sv_existing_observer_driver')
    assert Path(sys.modules['generate'].__file__).resolve() == OBSERVER / 'generate.py'
    meta = read(DRIVER / 'prepared.json')
    observer.verify_driver(DRIVER, meta, 'entry-room')
    # This verifier reads historical sources/compiled bytes; it does not replace
    # actual installation with the driver's historical 574D/RV7852 inventory.
    sys.path.insert(0, str(ORIGINAL))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    original = load(ORIGINAL / 'run_native.py', 'ordinary_sv_unchanged_room_framework')
    native_inputs = sys.modules['native_inputs']
    assert Path(native_inputs.__file__).resolve() == ORIGINAL / 'native_inputs.py'
    native_inputs.verify_tools()
    return wall, binding, observer, original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--run', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.check:
        assert not args.output
        _, binding, _, _ = preflight()
        print(json.dumps(dict(checked=True, driver=str(DRIVER), candidate='C6A3', host_sha256=HOST_SHA,
              installed_files=len(binding['current_installation']), compiled=False, air_started=False)))
        return 0
    assert args.output
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-rooms-\d{2,}', out.name)
    assert not out.exists(), 'Use a new output; never overwrite original evidence'
    result = dict(passed=False, functional_only=True, performance_qualified=False, installed=False,
                  driver_recompiled=False, validates_sv_pixels=False, validates_sv_old_ack=False)
    code = 1
    try:
        wall, binding, observer, original = preflight()
        pins = dict(binding['inputs'], **{str(p): h for p, h in PINS.items()},
                    **{str(Path(__file__)): sha(__file__), str(HERE / 'README.md'): sha(HERE / 'README.md')})

        def installed():
            return wall.actual_installation(binding['historical_build_installation'])

        def candidate_audit(path):
            assert path.resolve() == wall.PRODUCT.resolve()
            wall.historical_product()
            assert installed() == binding['current_installation']

        def host_input(path, actual):
            assert path.resolve() == HOST.resolve() and actual == installed() == binding['current_installation']
            assert wall.verify_binding() == binding
            return dict(directory=str(HOST), candidate_sha256=HOST_SHA,
                        manifest_sha256=sha(HOST / 'prepared.json'), original_sha256=actual['pfe.swf'],
                        recheck=binding['receipt'], recheck_sha256=binding['native_host']['receipt_sha256'],
                        source_inputs_unchanged=True)

        def host_check(path, intent, actual):
            assert host_input(path, actual) == intent
            candidate_audit(wall.PRODUCT)

        # Existing FD92 wrapper uses these public module callbacks. No inspect,
        # generated main, source rewriting, or historical installation callback.
        original.audit = candidate_audit
        original.host_input = host_input
        original.verify_host_intent = host_check
        original.verify_driver = observer.verify_driver
        original.installation = installed
        previous = sys.argv
        try:
            sys.argv = [str(ORIGINAL / 'run_native.py'), '--candidate', str(wall.PRODUCT), '--drivers', str(DRIVER),
                        '--output', str(out), '--game-candidate', str(HOST), '--scenario', 'entry-room',
                        '--registry-wait', str(args.registry_wait)]
            original.main()  # Original 600s, private desktop, registration, error/DONE/memory gates.
            code = 0
        finally:
            sys.argv = previous
        framework = read(out / 'result.json')
        assert framework['passed'] is True and framework['exit_code'] == 0 and framework['installation_unchanged'] is True
        result.update(passed=True, framework_sha256=sha(out / 'result.json'), run=framework['run'],
                      candidate_sha256=wall.CANDIDATE, host_sha256=HOST_SHA,
                      driver_sha256=sha(DRIVER / 'entry-room/EffectsDriver.swf'),
                      installation_before=binding['current_installation'], inputs={str(p): h for p, h in pins.items()})
    except (Exception, SystemExit) as exc:
        result.update(passed=False, error_type=type(exc).__name__, error=str(exc), traceback=traceback.format_exc())
        code = 1
    finally:
        try:
            wall, current, _, _ = preflight()
            if 'binding' in locals():
                assert current == binding
            if 'pins' in locals():
                for path, digest in pins.items():
                    assert sha(path) == digest, path
            result['installation_after'] = current['current_installation']
            result['frozen_inputs_unchanged'] = True
        except Exception as exc:
            result.update(passed=False, final_verification_error=str(exc))
            code = 1
        out.mkdir(exist_ok=True)
        # Preserve the original framework result, including old failures.
        save(out / 'rooms-result.json', result)
    print(json.dumps(dict(passed=result['passed'], output=str(out), run=result.get('run'),
                         performance_qualified=False, error=result.get('error')), ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
