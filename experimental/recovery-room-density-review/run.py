"""Exact existing corridor03 comparison; only candidate metadata admission adapts.

--check performs read-only validation without processes, compilation or AIR.
The original motion runner, native runner and corridor audit remain unchanged.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
DRIVERS = M52 / 'recovery-density-corridor-drivers-03'
READY = ROOT / 'experimental/recovery-density-corridor-readyfix'
WRAPPER = ROOT / 'tools/validation/run_motion_comparison.py'
sys.path.insert(0, str(READY))
sys.path.insert(1, str(ROOT / 'tools/validation'))
import prepare as corridor_prepare
import audit as corridor_audit
from run_security_terminals import installation

CANDIDATES = {
    '574d': dict(folder='coop-bundle-04', version='0.2.23-coop-bundle2',
        binary='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe',
        prepared='4d0743b2fdd61586b22193c431e5d5fba534d77ca33e0bc5483b2f286ae112b1',
        legacy_audit='1c927d97ab3389e94b634ddcd2e431ef5c75762359f91f757eda985b6af04c94'),
    'aura1': dict(folder='recovery-aura-offline-01', version='0.2.24-aura1',
        binary='df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7',
        prepared='a9e24c2cf4d629947e3cfbb230a4875dba342aa5f0bb71083b7e6f5bd2a65f13',
        compile='01e223598ab8b4c9ba9be0aebe9a9029bb685feadecda5532fd1b36858d679aa'),
    'roomfix4': dict(folder='recovery-room-production-04', version='0.2.24-roomfix4',
        binary='34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703',
        prepared='093916cf37eb1502fbc3b63f88da208d680e8314a4903840807fc0e09a775807',
        compile='3cde928e206d5083ea826c8b62b05ad206ea2ad311e2c2e0875ae7e2e994e370'),
}
ENVIRONMENT = {
    'pfe.swf': 'abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a',
    'mods/RealisticVision/release/RealisticVisionMod.swf': '0dbe0d7a95b8e496fb393d7fcd75f88d60c34a1d0fabb33266b122e3fa04f2bf',
    'mods/Rconnect/release/RConnectMod.swf': CANDIDATES['aura1']['binary'],
}
PINS = {
    GAME / 'mods/ContinuousScene/state/vertical-camera-band-deployment-20261023.json': 'df8ffe32a96488b3efc839d50bce86f7b6c44456ab682987b69df4ac91dc8dd1',
    WRAPPER: '5cdf11696f6e839336ebf812145640ea74cc55630eb791ee7234e7cd583f922b',
    ROOT / 'tools/run_coop_regression.py': '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3',
    ROOT / 'tools/validation/air_test_inventory.py': '3d4c6160cfb8ee766ad77463da9e5e7a67b10af30170b4ca5a876af1d4a9cd4c',
    DRIVERS / 'prepared.json': '5a8dbb9395c8dba8b6e980c49b112c6df3ae2e19e2f4950769d29756f8e1735c',
    DRIVERS / 'density/EffectsDriver.swf': 'cfca757c22052f0efd29afca1f76fe717e79d436b03a264413add2e4c8c9150a',
    DRIVERS / 'density/EffectsHarness.swf': 'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086',
    READY / 'prepare.py': '418b9bd1d6d0aea6890c4f5437aeb99f052206a80a70896d7eb7bb8f2a081a6a',
    READY / 'audit.py': 'eaa386f674d94a2400bbb5fc6eb527a580111a991ac64c3a87cc23f89a73b932',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8') as f:
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write('\n')


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def candidate(name):
    spec = CANDIDATES[name]
    folder = M52 / spec['folder']
    prepared, binary = folder / 'prepared.json', folder / 'RConnectMod.swf'
    assert sha(prepared) == spec['prepared'] and sha(binary) == spec['binary']
    meta = read(prepared)
    assert meta['version'] == spec['version']
    source = meta['source'] if name == '574d' else {'src/' + k: v for k, v in meta['source'].items()}
    inputs = meta['inputs'] if name == '574d' else {'tools/' + k: v for k, v in meta['inputs'].items()}
    assert inventory(folder / 'src') == {k[4:]: v for k, v in source.items()}
    assert inventory(folder / 'tools') == {k[6:]: v for k, v in inputs.items()}
    for rel, digest in {**source, **inputs}.items():
        path = (folder / rel).resolve()
        assert path.is_relative_to(folder.resolve()) and sha(path) == digest
    version = re.search(r'VERSION:String\s*=\s*"([^"]+)"', (folder / 'src/RConnectMod.as').read_text('utf-8'))
    assert version and version[1] == spec['version']
    proof = dict(name=name, folder=str(folder), candidate_sha256=spec['binary'],
                 prepared_sha256=sha(prepared), version=spec['version'])
    if name == '574d':
        # This historical build stored its compile flag/hash in prepared.json;
        # no separate compile.json exists. Never invent a modern compile receipt.
        assert meta['compiled'] is True and meta['candidate_sha256'] == meta['sha256'] == spec['binary']
        evidence = folder / 'user-deployment-audit.json'
        assert sha(evidence) == spec['legacy_audit']
        old = read(evidence)
        assert old['candidate_sha256'] == spec['binary'] and old['prepared_sha256'] == spec['prepared']
        proof.update(compile_evidence='historical prepared compiled/hash fields',
                     separate_compile_receipt=False, legacy_audit_sha256=sha(evidence))
    else:
        evidence = folder / 'compile.json'
        assert sha(evidence) == spec['compile']
        compiled = read(evidence)
        assert compiled['compiled'] is True and compiled['candidate_sha256'] == spec['binary']
        assert compiled['sources_unchanged'] and compiled['installation_unchanged']
        assert len(compiled['commands']) == 2 and all(c['exit_code'] == 0 for c in compiled['commands'])
        if name == 'aura1':
            assert compiled['compile_exit'] == 0 and compiled['prepared_sha256'] == spec['prepared']
        else:
            overlay = ROOT / 'experimental/recovery-room-production-v4/source-manifest.json'
            assert meta['overlay_manifest_sha256'] == sha(overlay)
            for rel, row in read(overlay)['changes'].items():
                assert sha(folder / 'src' / rel) == row['candidate_sha256']
        proof.update(compile_evidence=str(evidence), compile_sha256=sha(evidence), separate_compile_receipt=True)
    view = dict(kind='verified-existing-product-view', version=spec['version'], source=source,
                inputs=inputs, compiled=True, candidate_sha256=spec['binary'])
    proof['in_memory_admission_view_sha256'] = hashlib.sha256(json.dumps(view, sort_keys=True).encode()).hexdigest()
    return folder, view, proof


def admission():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    drivers = corridor_prepare.verify(DRIVERS)
    assert drivers['compiled'] and drivers['compile_exit'] == 0 and drivers['diagnostic_only'] is False
    assert drivers['entry'] == 'ProjectileLoadTestDoc' and drivers['fixture'] == 'native-open-corridor-v1'
    installed = installation()
    assert len(installed) == 22
    for rel, digest in ENVIRONMENT.items():
        assert installed[rel] == digest and sha(GAME / rel) == digest, rel
    host_update = read(GAME / 'mods/ContinuousScene/state/vertical-camera-band-deployment-20261023.json')
    assert host_update['status'] == 'verified' and host_update['after'].lower() == ENVIRONMENT['pfe.swf']
    runtime_baseline = {k.lower(): v.lower() for k, v in host_update['baseline'].items()}
    runtime_baseline['pfe.swf'] = host_update['after'].lower()
    assert all(runtime_baseline[k.lower()] == v for k, v in installed.items())
    products = {name: candidate(name)[2] for name in CANDIDATES}
    return dict(kind='exact-corridor03-existing-products', adapter_sha256=sha(__file__),
        inputs={str(p): h for p, h in PINS.items()}, products=products, installation=installed,
        diagnostics=False, driver_recompiled=False, thresholds_changed=False,
        configuration='installed release defaults; no historic disabled RV profile')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate', choices=CANDIDATES)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--reference', type=Path)
    ap.add_argument('--registry-wait', type=int, default=900)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    proof = admission()
    if args.check:
        assert args.output is None and args.reference is None
        print(json.dumps(dict(admitted=True, products=proof['products'], driver=PINS[DRIVERS / 'density/EffectsDriver.swf'],
                             processes_started=False, compiled=False), ensure_ascii=False))
        return 0
    assert args.candidate and args.output and args.registry_wait >= 0
    out = (ROOT / args.output).resolve()
    ref = (ROOT / args.reference).resolve() if args.reference else None
    assert out.parent == M52 and not out.exists()
    assert ref is None or ref.parent == M52
    if ref:
        prior = read(ref / 'admission.json')
        assert prior['adapter_sha256'] == proof['adapter_sha256'] and prior['inputs'] == proof['inputs']
        assert prior['installation'] == proof['installation']
    selected, view, selected_proof = candidate(args.candidate)
    proof['selected'] = selected_proof
    spec = importlib.util.spec_from_file_location('exact_density_original_wrapper', WRAPPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    original_read = module.read

    def admitted_read(path):
        if Path(path).resolve() == selected / 'prepared.json':
            current, current_view, current_proof = candidate(args.candidate)
            assert current == selected and current_proof == selected_proof
            return current_view
        return original_read(path)

    # Only the read view of this one legacy/new candidate manifest changes.
    # No metadata file, native driver, subprocess call, parser or limit changes.
    module.read = admitted_read
    argv = sys.argv
    code = 1
    try:
        sys.argv = [str(WRAPPER), '--candidate', str(selected), '--drivers', str(DRIVERS),
                    '--output', str(out), '--case', 'density', '--registry-wait', str(args.registry_wait)]
        if ref:
            sys.argv += ['--reference', str(ref)]
        try:
            module.main()
            code = 0
        except SystemExit as exit_request:
            code = int(exit_request.code or 0)
        if (out / 'result.json').is_file():
            report = corridor_audit.audit(out, ref)
            report.update(adapter_sha256=proof['adapter_sha256'], original_result_unchanged=True,
                          delegated_exit=code)
            save(out / 'fixture-audit.json', report)
            if not report['passed']:
                code = 1
        else:
            code = 1
    finally:
        sys.argv = argv
        after_error = None
        selected_after = None
        try:
            unchanged = admission() == {k: v for k, v in proof.items() if k != 'selected'}
            selected_after = candidate(args.candidate)[2]
        except (AssertionError, KeyError, OSError, ValueError) as error:
            unchanged = False
            after_error = str(error)
        if out.exists():
            save(out / 'admission.json', proof)
            save(out / 'admission-after.json', dict(inputs_unchanged=unchanged, selected=selected_after,
                 delegated_exit=code, error=after_error, historical_manifests_unchanged=unchanged))
        assert unchanged, 'Inputs or installation changed during paired run'
    return code


if __name__ == '__main__':
    raise SystemExit(main())
