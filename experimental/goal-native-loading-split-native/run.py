"""Exact native-UI bundle and original split-room execution; no compilation."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys
import traceback
from types import SimpleNamespace

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
UI = HERE.with_name('goal-native-loading-native-v2')
SPLIT = HERE.with_name('goal-native-loading-split-build')
PROBE = HERE.with_name('goal-native-loading-split-probe')
FRAMEWORK = HERE.with_name('recovery-first-raster-native')
PRIVATE = HERE.with_name('goal-native-loading-hidden-only')
SHARED = ROOT / 'tools/run_coop_regression.py'
TELEMETRY = ROOT.parents[1] / 'mods/ModLoader/release/telemetry.json'
PREFERENCE = b'{"nativeEnabled":false}'
PRODUCT = M52 / 'goal-native-loading-product-01'
HOST = M52 / 'goal-native-loading-host-03'
DRIVER = M52 / 'goal-native-loading-split-driver-01'
UI_DRIVER = M52 / 'goal-native-loading-probe-driver-01'
PRODUCT_SHA = '9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
HOST_SHA = '2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
PINS = {
    UI / 'run.py': 'a5b2ce70fcef52bd5960715fb0d29289f5124acf5139387db92e30aefc1782f3',
    UI / 'source-manifest.json': '7d62b3d6e7f159bdf91427a3543027bab7f5069628364c25ce09d5a4710dc840',
    SPLIT / 'build.py': '36e6eebf1588b2fd2d2af328e78c75d743628ed52be1761f27c8eba0c1c20e87',
    SPLIT / 'README.md': '35206c0362e8d32ac3cba1d762ab16431fb51de527b1bd40e39534de526afadd',
    HOST / 'runtime-admission.json': '4fda39f7ed42338c9f3a7d88bfa35e17e86ea36694bab8bf99e74ac445175ade',
    FRAMEWORK / 'run_native.py': '69d6e237b642821479f6d05c9af9a74f7cd62a4884578d4072fbeb7b7402ea6a',
    FRAMEWORK / 'native_inputs.py': '45091e8cc3a35c225308ee154b3a5bc49a7107f60f2e0f840d14a164e85a3889',
    ROOT / 'tools/run_coop_regression.py': '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
    PRIVATE / 'launcher.py': 'b98c06a9e08795dbe90ea540bf26f55cb05e0985ead301ed8d30d241fc1dbd38',
    PRIVATE / 'run.py': '5406a17baa80485be7de409fcc76e4f5022977c36c466d9195b17a342b22ce0a',
}


class NotReady(Exception):
    pass


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def save(path, value):
    with Path(path).open('x', encoding='utf8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def private_source():
    path = PRIVATE / 'launcher.py'
    assert sha(path) == PINS[path]
    text = path.read_text(encoding='utf8')
    old = "out.name.startswith('goal-native-loading-hidden-')"
    new = "out.name.startswith('goal-native-loading-split-native-')"
    assert text.count(old) == 1
    return text.replace(old, new, 1)


def shared_entry():
    # The exact existing private-settings hooks are reused. The sole source
    # change is the permitted output-directory prefix, not its launch checks.
    bundle, builder, _, pins = preflight()
    bound = dict(bundle, pins=pins)
    namespace = {'__file__': str(PRIVATE / 'launcher.py'), '__name__': 'split_private_settings_launcher'}
    exec(compile(private_source(), str(PRIVATE / 'launcher.py') + ':split-prefix', 'exec'), namespace)
    namespace['adapter'] = SimpleNamespace(ui_bundle=lambda: bound, installation=builder.installation,
        ROOT=ROOT, M52=M52, PRODUCT=PRODUCT, HOST_DIR=HOST, SHARED=SHARED,
        PREFERENCE=PREFERENCE, TELEMETRY=TELEMETRY, load=load, read=read, sha=sha, save=save)
    return namespace['main']()


def ui_bundle():
    ui = load(UI / 'run.py', 'split_existing_native_ui_v2')
    pins = ui.exact_pins()
    # Execute the already frozen expansion as a library, without invoking its
    # main/runner. No new source replacement or historical installed() override.
    namespace = {'__file__': str(ui.SOURCE), '__name__': 'split_existing_ui_bundle',
                 'V2_HOST_BUILDER': ui.V2 / 'build_host.py',
                 'verify_historical_probe': ui.verify_historical_probe,
                 'verify_environment_change': ui.verify_environment_change}
    exec(compile(ui.adapted(), str(UI / 'adapted-entry.py.txt'), 'exec'), namespace)
    namespace['OPTIONS'] = SimpleNamespace(product=PRODUCT, host=HOST, drivers=UI_DRIVER, admission=None)
    bundle = namespace['bundle']()
    assert bundle['product'] == PRODUCT and bundle['host'] == HOST and bundle['driver'] == UI_DRIVER
    assert bundle['compile']['candidate_sha256'] == PRODUCT_SHA
    assert bundle['host_receipt']['candidate_sha256'] == HOST_SHA
    assert bundle['driver_proof']['artifacts']['timing/EffectsDriver.swf'] == ui.DRIVER_SHA
    bundle.update(ui.verify_environment_change(bundle['meta']['installation_before'], bundle['installation']))
    bundle['pins'].update(pins)
    return bundle


def preflight():
    required = [PROBE / 'source-manifest.json', PROBE / 'source.diff',
                DRIVER / 'prepared.json', DRIVER / 'compile.json',
                DRIVER / 'entry-room/EffectsDriver.swf', DRIVER / 'entry-room/EffectsHarness.swf']
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise NotReady('Actual source/compile outputs missing: ' + json.dumps(missing))
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    builder = load(SPLIT / 'build.py', 'split_actual_driver_builder')
    driver = builder.verify(DRIVER)  # Genuine compiled receipt, source and current installation check.
    assert driver['verified'] is True and driver['performance_qualified'] is False
    bundle = ui_bundle()
    assert read(TELEMETRY) == {'enabled': True}
    assert str(TELEMETRY) in bundle['pins'] and bundle['pins'][str(TELEMETRY)] == sha(TELEMETRY)
    private_source()
    assert driver['build_environment'] == bundle['installation']
    assert set(driver['artifacts']) == {'entry-room/EffectsDriver.swf', 'entry-room/EffectsHarness.swf'}
    pins = dict(bundle['pins'])
    pins.update(driver['inputs'])
    pins.update({str(path): digest for path, digest in PINS.items()})
    for path in [HERE / 'run.py', HERE / 'README.md', DRIVER / 'prepared.json', DRIVER / 'compile.json']:
        pins[str(path)] = sha(path)
    for name, digest in driver['artifacts'].items():
        pins[str(DRIVER / name)] = digest
    return bundle, builder, driver, pins


def framework():
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    sys.path.insert(0, str(FRAMEWORK))
    native = load(FRAMEWORK / 'native_inputs.py', 'split_original_native_inputs')
    native.verify_tools()
    previous = sys.modules.get('native_inputs')
    sys.modules['native_inputs'] = native
    try:
        return load(FRAMEWORK / 'run_native.py', 'split_original_room_framework')
    finally:
        if previous is None:
            sys.modules.pop('native_inputs', None)
        else:
            sys.modules['native_inputs'] = previous


def summaries(out, result, bundle, driver):
    assert result['passed'] is True and result['exit_code'] == 0 and result['installation_unchanged'] is True
    assert re.fullmatch(r'[0-9a-f]{10}', result['run'])
    run = M52.parent / 'cooperation' / result['run']
    manifest = read(run / 'run.json')
    input_manifest = read(run / 'input.json')
    assert manifest['input_manifest_sha256'] == sha(run / 'input.json')
    assert manifest['inputs'] == input_manifest['inputs']
    private = load(PRIVATE / 'run.py', 'split_existing_private_settings_validation')
    private.validate_private_settings(run, out)
    proof = {}
    for role in ('host', 'join'):
        path = run / (role + '.log')
        text = path.read_text(encoding='utf-8-sig')
        assert sha(path) == result['roles'][role]['log_sha256']
        assert not result['roles'][role]['errors'] and result['roles'][role]['done']
        assert text.count('COOP EFFECTS DONE rooms ' + role) == 1
        rows = [json.loads(line.split('ROOM ENTRY NATIVE VISIBILITY ', 1)[1])
                for line in text.splitlines() if line.startswith('ROOM ENTRY NATIVE VISIBILITY ')]
        assert len(rows) == 1
        row = rows[0]
        assert row['loadingViewCalled'] is False and row['diagnosticOnly'] is True and row['performanceQualified'] is False
        for name in ('eligibleFrames', 'restoredFrames', 'stationaryFrames', 'observerFaults'):
            assert type(row[name]) is int and row[name] >= 0
        assert row['eligibleFrames'] > 0 and row['restoredFrames'] > 0 and row['observerFaults'] == 0
        assert row['stationaryFrames'] > 0 if role == 'host' else row['stationaryFrames'] == 0
        assert 'COOP PASS room-entry terminal tree has no legacy cover or copied loading object' in text
        if role == 'host':
            assert 'COOP PASS room stationary host observation samples=' in text
        parity = [json.loads(line.split('ROOM SCALAR PARITY ', 1)[1])
                  for line in text.splitlines() if line.startswith('ROOM SCALAR PARITY ')]
        assert len(parity) == 1 and parity[0]['objects'] > 0 and parity[0]['fields'] > 0 and parity[0]['differences'] == []
        inp = manifest['inputs'][role]
        assert inp['game'] == HOST_SHA and inp['production'] == PRODUCT_SHA
        assert inp['driver'] == driver['artifacts']['entry-room/EffectsDriver.swf']
        pictures = {}
        for name in ('waiting', 'ready'):
            image = run / (role + '-presentation-room-entry-' + name + '.png')
            if image.is_file():
                pictures[name] = dict(path=str(image), sha256=sha(image), bytes=image.stat().st_size)
        proof[role] = dict(summary=row, scalar=parity[0], log_sha256=sha(path), pictures=pictures,
                           waiting_pixels_observed='waiting' in pictures)
    memory = read(run / 'memory-timeline.json')
    assert memory['minimum_commit_bytes'] == 512 * 1024 ** 2
    assert memory['stopped_for_pressure'] is False and memory['stopped_for_overlap'] is False
    assert input_manifest['minimum_start_gib'] == 6 and input_manifest['private_desktop'] is True
    assert input_manifest['solo'] is False and input_manifest['require_exclusive_air'] is True
    assert not any((run / name).exists() for name in ('host', 'join', 'frozen'))
    return dict(roles=proof, run_manifest_sha256=sha(run / 'run.json'), memory_sha256=sha(run / 'memory-timeline.json'),
                private_settings_before_sha256=sha(out / 'private-settings-before.json'),
                private_settings_after_sha256=sha(out / 'private-settings-after.json'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--run', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    assert (args.output is None) if args.check else (args.output is not None)
    try:
        bundle, builder, driver, pins = preflight()
        original = framework()
    except (NotReady, FileNotFoundError) as error:
        print(json.dumps(dict(status='not-ready', ready=False, air_started=False, output_created=False, reason=str(error))))
        return 2
    if args.check:
        print(json.dumps(dict(ready=True, driver=str(DRIVER), driver_sha256=driver['artifacts']['entry-room/EffectsDriver.swf'],
              product_sha256=PRODUCT_SHA, host_sha256=HOST_SHA, installation_files=len(bundle['installation']),
              build_environment=bundle['build_environment'], runtime_environment=bundle['runtime_environment'], air_started=False)))
        return 0
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and re.fullmatch(r'goal-native-loading-split-native-\d{2,}', out.name) and not out.exists()
    before = bundle['installation']

    def installed():
        actual = builder.installation()
        assert actual == before
        return actual

    def audit(path):
        assert path.resolve() == PRODUCT
        current, _, current_driver, current_pins = preflight()
        assert current['installation'] == before and current_driver == driver and current_pins == pins

    def host_input(path, actual):
        assert path.resolve() == HOST and actual == installed()
        return dict(directory=str(HOST), candidate_sha256=HOST_SHA, original_sha256=actual['pfe.swf'],
                    manifest_sha256=sha(HOST / 'prepared.json'), recheck=str(HOST / 'runtime-admission.json'),
                    recheck_sha256=PINS[HOST / 'runtime-admission.json'], source_inputs_unchanged=True)

    def host_check(path, intent, actual):
        assert host_input(path, actual) == intent
        audit(PRODUCT)

    def verify_driver(path, meta, scenario):
        assert path.resolve() == DRIVER and scenario == 'entry-room'
        assert meta == read(DRIVER / 'prepared.json') and builder.verify(DRIVER) == driver

    original.audit = audit
    original.host_input = host_input
    original.verify_host_intent = host_check
    original.verify_driver = verify_driver
    original.installation = installed
    native_subprocess = original.subprocess

    def launch_shared(command, **kwargs):
        assert command[:4] == [sys.executable, '-B', '-X', 'utf8']
        assert Path(command[4]).resolve() == SHARED
        bound_command = command[:4] + [str(HERE / 'run.py'), '--shared-runner'] + command[5:]
        return native_subprocess.run(bound_command, **kwargs)

    # Local to the borrowed framework module. Do not mutate global subprocess.
    original.subprocess = SimpleNamespace(**{name: getattr(native_subprocess, name) for name in dir(native_subprocess)})
    original.subprocess.run = launch_shared
    result = dict(passed=False, performance_qualified=False, installed=False, inputs=pins,
                  candidate_sha256=PRODUCT_SHA, host_sha256=HOST_SHA, driver=driver,
                  build_environment=bundle['build_environment'], runtime_environment=before,
                  private_launcher_sha256=hashlib.sha256(private_source().encode('utf8')).hexdigest(),
                  private_launcher_changes='one output-directory prefix; existing hooks otherwise unchanged')
    code = 1
    previous = sys.argv
    try:
        sys.argv = [str(FRAMEWORK / 'run_native.py'), '--candidate', str(PRODUCT), '--drivers', str(DRIVER),
                    '--output', str(out), '--game-candidate', str(HOST), '--scenario', 'entry-room',
                    '--registry-wait', str(args.registry_wait)]
        original.main()
        raw = read(out / 'result.json')
        result.update(summaries(out, raw, bundle, driver))
        result.update(passed=True, run=raw['run'], framework_sha256=sha(out / 'result.json'))
        code = 0
    except (Exception, SystemExit) as error:
        result.update(error_type=type(error).__name__, error=str(error), traceback=traceback.format_exc())
    finally:
        sys.argv = previous
        original.subprocess = native_subprocess
        try:
            audit(PRODUCT)
            result.update(installation_after=installed(), frozen_inputs_unchanged=True)
        except Exception as error:
            result.update(passed=False, final_verification_error=repr(error))
            code = 1
        # No output is created for missing compile evidence or failed preflight.
        # Once the original framework created its output, preserve its result and
        # append only this independent acceptance receipt, including failures.
        if out.exists():
            with (out / 'split-result.json').open('x', encoding='utf8') as stream:
                json.dump(result, stream, ensure_ascii=False, indent=2)
                stream.write('\n')
    print(json.dumps(dict(passed=result['passed'], output=str(out), run=result.get('run'),
                         performance_qualified=False, error=result.get('error')), ensure_ascii=False))
    return code


if __name__ == '__main__':
    if sys.argv[1:2] == ['--shared-runner']:
        del sys.argv[1]
        raise SystemExit(shared_entry())
    raise SystemExit(main())
