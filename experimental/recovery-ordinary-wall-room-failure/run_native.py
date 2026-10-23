"""Exact diagnostic overlay, original BF6 room driver and host05; no product qualification."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys
import traceback

if sys.flags.optimize:
    raise RuntimeError('Admission requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
PRODUCT = M52 / 'recovery-ordinary-wall-diagnostic-03'
ROOMS = ROOT / 'experimental/recovery-ordinary-wall-sv-rooms/run_native.py'
BUILDER = ROOT / 'experimental/recovery-isolated-overlay/build.py'
PINS = {
    ROOMS: '10f463eba8cf31622cd49a27b617bcffcd54348ed36c87ea2192063c2b61a2ff',
    BUILDER: '6c6d3ed0cc659f4a6742eca0a2b56898c7361eff7f4d18900afa6dee5c468cee',
    HERE / 'diagnostic-v2/src/rconnect/game/WallImpactVisuals.as': '4c6e69144c3e2316a6085ad071aafea46dbdaa31b1c0b4649089d92e4630199f',
    HERE / 'diagnostic-v2/src/rconnect/game/WallSurfaceBridge.as': '719c1cb98a567eb43bec855969758e8e903236e5fc4455791b427e47ef9504e1',
}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def preflight():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    rooms = load(ROOMS, 'ordinary_diagnostic_room_admission')
    wall, binding, observer, original = rooms.preflight()
    builder = load(BUILDER, 'ordinary_diagnostic_overlay_builder')
    meta = builder.verify(PRODUCT)
    compiled = read(PRODUCT / 'compile.json')
    assert meta['diagnostic_only'] is True and compiled['diagnostic_only'] is True
    assert meta['base_sha256'] == wall.CANDIDATE and Path(meta['base']) == wall.PRODUCT
    assert Path(meta['overlay']).resolve() == HERE / 'diagnostic-v2/src'
    assert meta['version'] == '0.2.24-wallsvdiag1'
    assert set(meta['overlay_inputs']) == {'rconnect/game/WallImpactVisuals.as', 'rconnect/game/WallSurfaceBridge.as'}
    assert meta['installation_before'] == binding['current_installation']
    assert compiled['compiled'] is True and compiled['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf')
    evidence = dict(candidate_sha256=compiled['candidate_sha256'], prepared_sha256=sha(PRODUCT / 'prepared.json'),
                    compile_sha256=sha(PRODUCT / 'compile.json'), host_sha256=rooms.HOST_SHA,
                    actual_installation=binding['current_installation'], product_diagnostic_only=True,
                    driver_diagnostic_only=False, diagnostic_only=True)
    return rooms, wall, binding, observer, original, builder, evidence

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
        assert args.output is None
        *_, evidence = preflight()
        print(json.dumps(dict(checked=True, compiled_by_this_entry=False, air_started=False, **evidence)))
        return 0
    assert args.output is not None
    out = (ROOT / args.output).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-room-diagnostic-\d{2,}', out.name)
    assert not out.exists()
    result = dict(passed=False, diagnostic_only=True, product_diagnostic_only=True, driver_diagnostic_only=False,
                  gameplay_qualified=False, performance_qualified=False, installed=False, driver_recompiled=False)
    code = 1
    try:
        rooms, wall, binding, observer, original, builder, evidence = preflight()
        result['admission'] = evidence
        frozen = {str(p): sha(p) for p in (*PINS, Path(__file__), HERE / 'README.md')}
        result['inputs'] = frozen
        def installed():
            return wall.actual_installation(binding['historical_build_installation'])
        def candidate_audit(path):
            assert path.resolve() == PRODUCT.resolve()
            builder.verify(PRODUCT)
            assert sha(PRODUCT / 'compile.json') == evidence['compile_sha256']
            assert sha(PRODUCT / 'prepared.json') == evidence['prepared_sha256']
            assert sha(PRODUCT / 'RConnectMod.swf') == evidence['candidate_sha256']
            assert installed() == binding['current_installation']
        def host_input(path, actual):
            assert path.resolve() == rooms.HOST.resolve() and actual == installed() == binding['current_installation']
            assert wall.verify_binding() == binding
            return dict(directory=str(rooms.HOST), candidate_sha256=rooms.HOST_SHA,
                        manifest_sha256=sha(rooms.HOST / 'prepared.json'), original_sha256=actual['pfe.swf'],
                        recheck=binding['receipt'], recheck_sha256=binding['native_host']['receipt_sha256'],
                        source_inputs_unchanged=True)
        def host_check(path, intent, actual):
            assert host_input(path, actual) == intent
            candidate_audit(PRODUCT)
        original.audit = candidate_audit
        original.host_input = host_input
        original.verify_host_intent = host_check
        original.verify_driver = observer.verify_driver
        original.installation = installed
        previous = sys.argv
        try:
            sys.argv = [str(rooms.ORIGINAL / 'run_native.py'), '--candidate', str(PRODUCT), '--drivers', str(rooms.DRIVER),
                        '--output', str(out), '--game-candidate', str(rooms.HOST), '--scenario', 'entry-room',
                        '--registry-wait', str(args.registry_wait)]
            original.main()
            code = 0
        finally:
            sys.argv = previous
    except (Exception, SystemExit) as exc:
        result.update(error_type=type(exc).__name__, error=str(exc), traceback=traceback.format_exc())
        code = 1
    finally:
        out.mkdir(exist_ok=True)
        try:
            *_, final_evidence = preflight()
            if 'evidence' in locals():
                assert final_evidence == evidence
            for path, digest in locals().get('frozen', {}).items():
                assert sha(path) == digest, path
            result.update(inputs_unchanged=True, installation_unchanged=True, final_admission=final_evidence)
        except Exception as exc:
            result.update(inputs_unchanged=False, verification_error=str(exc))
            code = 1
        try:
            # Preserve the original framework's driver-only diagnostic flag and checks.
            if (out / 'result.json').exists():
                framework = read(out / 'result.json')
                result.update(framework_sha256=sha(out / 'result.json'), framework_passed=framework['passed'], run=framework.get('run'))
            runner = out / 'runner.log'
            if runner.exists():
                text = runner.read_text(encoding='utf-8', errors='replace')
                queued = re.findall(r'^QUEUED_OUTPUT (.+)\s*$', text, re.M)
                if len(queued) == 1:
                    run = Path(queued[0].strip()).resolve()
                    assert run.parent == (ROOT / 'build/cooperation').resolve() and re.fullmatch(r'[0-9a-f]{10}', run.name)
                    result['run'] = run.name
                    result['first_failures'] = {}
                    result['log_sha256'] = {}
                    for role in ('host', 'join'):
                        log = run / (role + '.log')
                        if log.exists():
                            lines = log.read_text(encoding='utf-8-sig', errors='replace').splitlines()
                            result['first_failures'][role] = [s for s in lines if s.startswith(('RConnectWall FIRST FAILURE ', 'RConnectWall FIRST OBSERVER FAILURE '))][:2]
                            result['log_sha256'][role] = sha(log)
                    result['failure_observed'] = any(result['first_failures'].values())
                    for name in ('cancel-result.json', 'registry-result.json', 'run.json'):
                        if (run / name).exists():
                            result[name] = dict(sha256=sha(run / name), value=read(run / name)) if name != 'run.json' else dict(sha256=sha(run / name))
                    if (run / 'run.json').exists():
                        actual = read(run / 'run.json')
                        assert actual['sha256'] == result['admission']['candidate_sha256']
                        for role, values in actual['inputs'].items():
                            assert role in ('host', 'join')
                            assert values['game'] == result['admission']['host_sha256']
                            assert values['production'] == result['admission']['candidate_sha256']
                            assert values['driver'] == 'bf6c9567010d93dd20b334df3da7ed069e168583a2f45868a8d4352bc0e553ba'
                        result['actual_inputs_verified'] = True
                    result['cancelled'] = (run / 'cancel-result.json').exists()
                    if result['cancelled']:
                        code = 1
        except Exception as exc:
            result.update(evidence_error_type=type(exc).__name__, evidence_error=str(exc))
            code = 1
        with (out / 'diagnostic-result.json').open('x', encoding='utf-8') as stream:
            json.dump(result, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    print(json.dumps(dict(passed=False, diagnostic_only=True, output=str(out), run=result.get('run'),
                         failure_observed=result.get('failure_observed', False), cancelled=result.get('cancelled', False))))
    return code

if __name__ == '__main__':
    raise SystemExit(main())
