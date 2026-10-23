"""Reuse the frozen ordinary native driver; bind only wallsv1 and a reviewed host.
No compiler, deployment, assertion relaxation, or additional source rewriting.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys
import traceback

if sys.flags.optimize:
    raise RuntimeError('Assertions are admission checks; optimized Python is forbidden')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
DRIVERS = M52 / 'recovery-ordinary-wall-driver-01'
PRODUCT = M52 / 'recovery-ordinary-wall-sv-production-01'
RECIPE = ROOT / 'experimental/recovery-ordinary-wall-sv'
HOST_RECIPE = ROOT / 'experimental/recovery-ordinary-method-transplant/build_final.py'
GENERIC = ROOT / 'experimental/recovery-tests'
SHARED = ROOT / 'experimental/recovery-wall-surfaces-native/native_tool.py'
ENTRY = 'LargeWallSurfaceTestDoc'
RC_KEY = 'mods/Rconnect/release/RConnectMod.swf'
OLD_RC = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
INSTALLED_RC = 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
CANDIDATE = 'c6a3b1136bde63c32d23c4e555dfc240f3a573384d19c4fe9636a4138193496d'
PINS = {
    SHARED: '3516f0a9a1daa1290391908b74d91ba9cad159bcd049ff5cdb6d2a461984cb5f',
    GENERIC / 'prepare.py': '57adca102a8ecbb0c1996dcee405782eced622fea63917d27238d27e81539ac3',
    GENERIC / 'run.py': '1beca86ca91f5346f56136afd58e071646a57506570ed4b58d857c48270301da',
    DRIVERS / 'prepared.json': '085a9dba649eda91460e45a6810dab81ca787fae10fc6bb7c5e7bd7b22ebdb17',
    RECIPE / 'prepare_product.py': 'c74a4f4aae790b39c09131a12ba258feca4b69153090736c4f320e64e2b085bf',
    PRODUCT / 'prepared.json': '707718036263940c4f63ee1babe3f913735e81aee4e181f95f9b6cb4dad30083',
    PRODUCT / 'RConnectMod.swf': CANDIDATE,
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


def historical_product():
    # This is deliberately not recipe.verify(): that function requires the
    # installation to still equal the historical build. No callback is faked.
    check_pins(PINS)
    p = load(RECIPE / 'prepare_product.py', 'wallsv_historical_product')
    source, inputs = p.reviewed_inputs()
    meta, compiled = read(PRODUCT / 'prepared.json'), read(PRODUCT / 'compile.json')
    assert meta['kind'] == 'isolated-ordinary-wall-sv-production' and meta['version'] == p.VERSION
    assert meta['recipe_sha256'] == sha(p.__file__) and meta['base_manifest_sha256'] == p.MANIFEST_SHA
    assert meta['base_sha256'] == p.BASE_SHA and meta['base_integration_sha256'] == p.BASE_INTEGRATION_SHA
    assert meta['terrain_unchanged'] is True and meta['base_source'] == source and meta['overlay'] == p.OVERLAY
    assert meta['component_evidence'] == p.EVIDENCE and meta['toolchain_inputs'] == {str(k): v for k, v in p.PINS.items()}
    assert p.inventory(PRODUCT / 'tools', PRODUCT) == meta['inputs'] == inputs
    assert len(meta['source']) == 90 and p.inventory(PRODUCT / 'src', PRODUCT) == meta['source']
    assert sorted(n for n in source if source[n] != meta['source'][n]) == sorted([*p.OVERLAY, 'src/RConnectMod.as'])
    for name in source:
        assert (PRODUCT / name).read_bytes() == p.source_bytes(name), name
    assert (PRODUCT / 'wall-sv.patch').read_bytes() == p.proposal_patch(source)
    assert sha(PRODUCT / 'wall-sv.patch') == meta['patch_sha256']
    assert meta['compiled'] is False and meta['air_started'] is False and meta['installed'] is False
    assert compiled['compiled'] is True and compiled['compile_exit'] == 0
    assert compiled['prepared_sha256'] == sha(PRODUCT / 'prepared.json')
    historical = meta['installation_before']
    assert len(historical) == 22 and historical[RC_KEY] == OLD_RC
    assert historical == p.read(p.COMPONENT / 'intent.json')['installation_before']
    assert compiled['installation_before'] == compiled['installation_after'] == historical
    assert all(x is True for x in (meta['installation_unchanged'], compiled['installation_unchanged'], compiled['sources_unchanged']))
    assert compiled['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf') == CANDIDATE
    assert compiled['air_started'] is False and compiled['installed'] is False
    for name, digest in compiled['artifacts'].items():
        assert sha(PRODUCT / name) == digest, name
    return historical


def actual_installation(historical):
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    import run_security_terminals
    assert Path(run_security_terminals.__file__).resolve() == ROOT / 'tools/validation/run_security_terminals.py'
    actual = run_security_terminals.installation()
    expected = dict(historical, **{RC_KEY: INSTALLED_RC})
    # Same inventory spelling as the original framework; all 22 actual files.
    norm = lambda m: {k.replace('\\', '/').lower(): v for k, v in m.items()}
    assert len(actual) == 22 and norm(actual) == norm(expected), 'Only the exact RC574D -> EB365 installation change is admitted'
    return actual


def driver_modules():
    check_pins(PINS)
    shared = load(SHARED, 'wallsv_existing_five_anchor_adapter')
    meta = shared.prepare.verify(DRIVERS, M52 / 'recovery-22/src', runtime=True)
    assert meta['compiled'] is True and meta['extension']['kind'] == 'ordinary-native-wall-surfaces'
    assert set(meta['entries']) == {ENTRY} and not meta['components']
    assert meta['entries'][ENTRY] == dict(scenarios=4, seconds=600,
        purpose='普通房真实原生墙痕：双向轻机枪/速射等离子、持久前景精确像素',
        land='rbl', functional_only=True, performance_qualified=False)
    check_pins(meta['extension']['tools'])
    run = load(GENERIC / 'run.py', 'wallsv_original_native_framework')
    assert run.EXPECTED_INSTALLATION_FILES == 22
    return shared, run, meta


def host_admission(folder, receipt_path):
    folder, receipt_path = Path(folder).resolve(), Path(receipt_path).resolve()
    assert folder.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-host-\d{2,}', folder.name)
    assert receipt_path.parent.parent == M52.resolve() and receipt_path.name == 'receipt.json'
    builder = load(HOST_RECIPE, 'wallsv_final_host_builder')
    build = builder.verify_result(folder)  # Read-only; compiled is not semantic qualification.
    assert build['compiled'] and build['build_checks_passed'] and build['validated'] is False
    receipt = read(receipt_path)
    for key in ('compiled', 'source_readback_passed', 'pcode_bindings_passed', 'exception_cfg_passed', 'validated'):
        assert receipt[key] is True, 'Independent host review: ' + key
    assert receipt['candidate_sha256'] == build['candidate_sha256'] == sha(folder / 'pfe.swf')
    assert receipt['build_manifest_sha256'] == sha(folder / 'build.json')
    assert receipt['readback_audit_sha256'] == sha(folder / 'readback-audit.json')
    files = dict(receipt['inputs'], **receipt['readback_files'])
    check_pins(files)
    for path in (folder / 'pfe.swf', folder / 'after/scripts/fe/graph/Grafon.as',
                 folder / 'after/scripts/fe/loc/Location.as', folder / 'pcode/scripts/fe/graph/Grafon.pcode',
                 folder / 'pcode/scripts/fe/loc/Location.pcode'):
        assert files[str(path)] == sha(path), 'Actual host/readback missing from independent proof'
    return dict(candidate_sha256=receipt['candidate_sha256'], validated=True,
        receipt_path=str(receipt_path), receipt_sha256=sha(receipt_path), build=build)


def inputs(host, receipt):
    historical = historical_product()
    actual = actual_installation(historical)
    shared, run, meta = driver_modules()
    native_host = host_admission(host, receipt)
    pins = {str(p): h for p, h in PINS.items()}
    pins.update(meta['extension']['tools'])
    pins.update(run.runtime_tools())
    for path in (Path(__file__), HERE / 'README.md', HOST_RECIPE, PRODUCT / 'compile.json',
                 Path(host) / 'prepared.json', Path(host) / 'build.json', Path(host) / 'readback-audit.json', Path(receipt)):
        pins[str(path.resolve())] = sha(path)
    pins.update(read(Path(host) / 'prepared.json')['inputs'])
    pins.update(read(receipt)['inputs'])
    pins.update(read(receipt)['readback_files'])
    for name, digest in read(Path(host) / 'build.json')['artifacts'].items():
        pins[str((Path(host) / name).resolve())] = digest
    check_pins(pins)
    return dict(kind='ordinary-wall-sv-frozen-native-binding', inputs=pins,
        host=str(Path(host).resolve()), receipt=str(Path(receipt).resolve()), native_host=native_host,
        historical_build_installation=historical, current_installation=actual,
        driver_recompiled=False, functional_only=True, performance_qualified=False)


def verify_binding():
    binding = read(HERE / 'binding.json')
    check_pins(binding['inputs'])
    assert binding == inputs(binding['host'], binding['receipt']), 'Frozen native binding changed'
    return binding


def execute(out, wait, binding):
    shared, run, meta = driver_modules()
    host = Path(binding['host'])
    native_host = dict(binding['native_host'], installation=binding['current_installation'])
    run.SUITES[ENTRY] = 'large-wall-surfaces'
    native, source, scope = shared.adapted_native(run)  # The existing five substitutions, unchanged.
    scope.update(_wall_candidate=PRODUCT, _wall_binding=shared.bind, _wall_host=host, _wall_host_evidence=native_host)
    run.native = native
    original_inputs = run.native_inputs

    def native_inputs(folder, info, intent, spec):
        assert intent['installation_before'] == binding['current_installation']
        adjusted = dict(intent, installation_before=dict(intent['installation_before']))
        adjusted['installation_before']['pfe.swf'] = native_host['candidate_sha256']
        value = original_inputs(folder, info, adjusted, spec)
        for role in ('host', 'join'):
            value[role]['pfe.swf']['installed'] = intent['installation_before']['pfe.swf']
            value[role]['pfe.swf']['override'] = 'Exact independently reviewed ordinary-wall-sv host: ' + str(host)
        return value

    run.native_inputs = native_inputs
    scope['native_inputs'] = native_inputs
    # This callback always reads the REAL installation, never historical state.
    run.installation = lambda: actual_installation(binding['historical_build_installation'])
    pinned = dict(binding['inputs'], **{str(HERE / 'binding.json'): sha(HERE / 'binding.json')})
    prior_tools = run.runtime_tools
    run.runtime_tools = lambda: dict(prior_tools(), **pinned)
    previous = sys.argv
    try:
        sys.argv = [str(__file__), 'native', '--drivers', str(DRIVERS), '--output', str(out),
                    '--entry', ENTRY, '--registry-wait', str(wait)]
        code = run.main()  # Original errors, 6 GiB/512 MiB, registry and cleanup remain intact.
    finally:
        sys.argv = previous
    (out / 'framework-adapted-native.py').write_text(source, encoding='utf-8')
    verify_binding()
    framework = read(out / 'result.json')  # Never rewrite the original result, even on failure.
    result = dict(passed=False, functional_only=True, performance_qualified=False,
                  framework_passed=framework['passed'], framework_sha256=sha(out / 'result.json'),
                  candidate_sha256=CANDIDATE, native_host_sha256=native_host['candidate_sha256'],
                  driver_recompiled=False, installed=False)
    if framework.get('run'):
        folder = Path(framework['run']).resolve()
        assert folder.parent == (ROOT / 'build/cooperation').resolve()
        for role in ('host', 'join'):
            storage = Path(os.environ['APPDATA']) / ('pfe-modsettings-rconnect-coop-' + role + '-' + folder.name) / 'Local Store/large-wall-proof'
            for n in range(4):
                for suffix in ('proof.json', 'before-native.png', 'after-native.png', 'before-display.png', 'after-display.png'):
                    file = storage / f'round-{n}-{suffix}'
                    if not file.is_file():
                        continue
                    assert file.stat().st_size <= 32 * 1024 ** 2, 'Oversized bounded crop evidence'
                    dest = out / 'wall-proof' / role / file.name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(file, dest)
        analyzer = DRIVERS / 'inputs/large-wall/verify_results.py'
        assert sha(analyzer) == meta['inputs']['inputs/large-wall/verify_results.py']
        measured = load(analyzer, 'wallsv_frozen_ordinary_uint_analyzer').analyze(
            out / 'wall-proof', {role: folder / (role + '.log') for role in ('host', 'join')})
        result.update(measured, framework_passed=framework['passed'], source_analyzer_sha256=sha(analyzer), native_run=str(folder))
        result['passed'] = bool(code == 0 and framework['passed'] and measured['passed'])
    save(out / 'wall-surface-result.json', result)
    return 0 if result['passed'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--freeze', action='store_true')
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--run', action='store_true')
    parser.add_argument('--host', type=Path)
    parser.add_argument('--host-receipt', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    if args.freeze:
        assert args.host and args.host_receipt and not args.output
        save(HERE / 'binding.json', inputs((ROOT / args.host).resolve(), (ROOT / args.host_receipt).resolve()))
        print('Frozen exact runtime binding; no AIR/compiler/deployment')
        return 0
    assert not args.host and not args.host_receipt
    if args.check:
        assert not args.output
        verify_binding()
        print('Binding verified; no native/performance claim')
        return 0
    assert args.output
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-native-\d{2,}', out.name)
    assert not out.exists(), 'Use a new output; preserve all old evidence'
    try:
        return execute(out, args.registry_wait, verify_binding())
    except BaseException as error:
        out.mkdir(exist_ok=True)
        save(out / 'binding-failure.json', dict(passed=False, error_type=type(error).__name__, error=str(error),
             traceback=traceback.format_exc(), functional_only=True, performance_qualified=False, installed=False))
        raise


if __name__ == '__main__':
    raise SystemExit(main())
