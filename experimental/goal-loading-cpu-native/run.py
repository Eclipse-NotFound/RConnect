"""One diagnostic first-generation sample, preserving the real native UI trip checks."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import struct
import sys
import types
import zlib

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
UI = HERE.with_name('goal-native-loading-native-v2')
PRODUCT = M52 / 'goal-native-loading-product-01'
HOST = M52 / 'goal-native-loading-host-03'
DRIVER = M52 / 'goal-loading-cpu-driver-01'
REFERENCE_DRIVER = M52 / 'goal-native-loading-probe-driver-01'
API = (b'startSampling', b'pauseSampling', b'stopSampling', b'clearSamples',
       b'sampleInternalAllocs', b'getSamples', b'getSampleCount', b'setSamplerCallback')
UI_SHA = 'a5b2ce70fcef52bd5960715fb0d29289f5124acf5139387db92e30aefc1782f3'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def ui_namespace():
    assert sha(UI / 'run.py') == UI_SHA
    ui = load(UI / 'run.py', 'loading_cpu_real_ui_v2')
    pins = ui.exact_pins()
    namespace = {'__file__': str(ui.SOURCE), '__name__': 'loading_cpu_real_ui_binding',
                 'V2_HOST_BUILDER': ui.V2 / 'build_host.py',
                 'verify_historical_probe': ui.verify_historical_probe,
                 'verify_environment_change': ui.verify_environment_change}
    exec(compile(ui.adapted(), str(UI / 'adapted-entry.py.txt'), 'exec'), namespace)
    namespace['OPTIONS'] = types.SimpleNamespace(product=PRODUCT, host=HOST,
                                                 drivers=REFERENCE_DRIVER, admission=None)
    bundle = namespace['bundle']()
    bundle.update(ui.verify_environment_change(bundle['meta']['installation_before'], bundle['installation']))
    bundle['pins'].update(pins)
    return namespace, bundle


def sampler_inputs(bundle, driver):
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from native_runtime_assets import native_runtime_files
    paths = {p.resolve() for p in native_runtime_files(GAME) if p.suffix.lower() == '.swf'}
    paths.discard((GAME / 'pfe.swf').resolve())
    paths.update([HOST / 'pfe.swf', PRODUCT / 'RConnectMod.swf', DRIVER / 'timing/EffectsHarness.swf'])
    manifest = GAME / 'mods/loader-manifest.txt'
    for line in manifest.read_text(encoding='utf-8-sig').splitlines():
        if '|' not in line or line.startswith('#'):
            continue
        name, entry = line.split('|')[:2]
        if name.lower() != 'rconnect':
            paths.add((GAME / 'mods' / name / 'release' / (entry + '.swf')).resolve())
    rows = []
    for path in sorted(paths):
        data = path.read_bytes()
        assert data[:3] in (b'FWS', b'CWS') and len(data) >= 8, str(path)
        size = struct.unpack('<I', data[4:8])[0]
        assert 8 <= size <= 256 * 1024 * 1024
        payload = zlib.decompress(data[8:]) if data[:3] == b'CWS' else data[8:]
        assert len(payload) == size - 8, str(path)
        hits = [token.decode('ascii') for token in API if token in payload]
        assert not hits, ('Other explicit sampler API in a runtime input', str(path), hits)
        rows.append(dict(path=str(path), sha256=sha(path), sampler_api_names=hits,
                         namespace_token=b'flash.sampler' in payload))
    return dict(files=rows, manifest=str(manifest), manifest_sha256=sha(manifest),
                driver_sha256=driver['artifacts']['timing/EffectsDriver.swf'],
                driver_is_the_only_known_sampler=True, no_external_profiler_started=True,
                limitation='Exact known files lack explicit sampler API names; no claim about obfuscated names or external profilers')


def admission():
    builder = load(HERE / 'build.py', 'loading_cpu_actual_builder')
    driver = builder.verify(DRIVER)
    namespace, bundle = ui_namespace()
    assert driver['build_environment'] == bundle['installation']
    assert driver['verified'] and driver['performance_qualified'] is False
    scan = sampler_inputs(bundle, driver)
    pins = dict(bundle['pins'])
    pins.update(driver['inputs'])
    for path in [HERE / 'run.py', HERE / 'README-run.md', DRIVER / 'prepared.json', DRIVER / 'compile.json']:
        pins[str(path)] = sha(path)
    for name, digest in driver['artifacts'].items():
        pins[str(DRIVER / name)] = digest
    pins.update({row['path']: row['sha256'] for row in scan['files']})
    pins[scan['manifest']] = scan['manifest_sha256']
    bundle.update(driver=DRIVER, driver_proof=driver, pins=pins)
    return namespace, bundle, scan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    assert args.output is None if args.check else args.output is not None
    namespace, bundle, scan = admission()
    if args.check:
        print(json.dumps(dict(ready=True, air_started=False, driver=bundle['driver_proof']['artifacts'],
                              scanned_runtime_files=len(scan['files']), performance_qualified=False)))
        return 0
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and out.name.startswith('goal-loading-cpu-native-') and not out.exists()
    original_collect = namespace['collect_observer']
    original_validate = namespace['validate_observer']

    def current_bundle():
        _, current, current_scan = admission()
        assert current == bundle and current_scan == scan
        return current

    def bridge(host_path, before, sandy):
        value = current_bundle()
        assert host_path == HOST and before == value['installation'] and sandy is False
        return dict(host=str(HOST / 'pfe.swf'), host_sha256=value['host_receipt']['candidate_sha256'],
                    sandy=None, sandy_sha256=None, pins=value['pins'], scope='native-test-only',
                    base_sha256=value['host_receipt']['base_sha256'],
                    independent_admission_sha256=sha(HOST / 'runtime-admission.json'))

    def collect(output, destination, settings, roles):
        original_collect(output, destination, settings, roles)
        collected = {}
        for role in roles:
            source = Path(settings[role]['preference']).parent / 'initial-loading-cpu.json'
            target = destination / 'observer' / role / source.name
            data = source.read_bytes()
            with target.open('xb') as stream:
                stream.write(data)
            assert sha(source) == sha(target)
            collected[role] = dict(source=str(source), sha256=sha(target), bytes=len(data))
        save(destination / 'cpu-collected.json', dict(before_copy_cleanup=True, roles=collected))

    def validate(destination, run_path, roles, settings, result):
        original_validate(destination, run_path, roles, settings, result)
        collected = read(destination / 'cpu-collected.json')
        assert collected['before_copy_cleanup'] and set(collected['roles']) == set(roles)
        proofs = {}
        for role in roles:
            path = destination / 'observer' / role / 'initial-loading-cpu.json'
            assert sha(path) == collected['roles'][role]['sha256']
            doc = read(path)
            assert doc['kind'] == 'initial-loading-cpu-v1' and doc['role'] == role
            assert doc['appId'] == settings[role]['app_id'] and doc['rounds'] == [0, 1, 2]
            assert doc['diagnosticOnly'] and doc['performanceQualified'] is False
            assert doc['exclusiveInputConfirmed'] and doc['samplerStopped'] and doc['nativeBufferMemoryBounded'] is False
            window = doc['window']
            assert doc['faultCount'] == 0 and doc['faults'] == [] and window['complete']
            assert window['cleanupComplete'] and window['startExit'] == 20 and window['stopExit'] == 19
            assert window['identityPreserved'] and window['ownerPreserved'] and window['clockOrdered']
            assert window['collectionOrigin'] == 'next-enter' and window['cpu'] > 0
            assert window['visited'] <= doc['sampleLimit'] == 32768
            assert sum(window['stacks'].values()) <= window['cpu']
            assert len(window['stacks']) == window['uniqueStacks'] <= doc['stackLimit'] == 1024
            text = (run_path / (role + '.log')).read_text(encoding='utf-8-sig')
            assert text.count('LOADING CPU PROBE DONE ' + role) == 1
            assert 'LOADING CPU PROBE OUTPUT FAILED' not in text
            proofs[role] = dict(json_sha256=sha(path), complete=doc['passed'], cpu=window['cpu'],
                                samples=window['totalSamples'], truncated=window['sampleTruncated'],
                                collect_ms=window['collectMs'], cleanup_ms=window['cleanupMs'],
                                elapsed_ms=window['clocks']['stop']['t'] - window['clocks']['startReturned']['t'])
        save(destination / 'cpu-admission.json', scan)
        result.update(cpu=proofs, cpu_complete=all(p['complete'] for p in proofs.values()),
                      diagnostic_only=True, performance_qualified=False)

    namespace.update(bundle=current_bundle, ui_bridge=bridge, collect_observer=collect, validate_observer=validate)
    previous = sys.argv
    try:
        sys.argv = [str(UI / 'run.py'), '--product', str(PRODUCT), '--host', str(HOST),
                    '--drivers', str(DRIVER), '--output', str(out), '--registry-wait', str(args.registry_wait)]
        return namespace['main']()
    finally:
        sys.argv = previous


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except FileNotFoundError as error:
        print(json.dumps(dict(ready=False, status='not-ready', missing=str(error.filename), air_started=False)))
        raise SystemExit(2)
