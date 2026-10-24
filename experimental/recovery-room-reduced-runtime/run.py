"""Run the unchanged room comparison with three explicitly unloaded modules."""
from pathlib import Path
import argparse, importlib.util, json, sys, traceback

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REVIEW = HERE.parent/'recovery-room-repair-review'
NATIVE = REVIEW/'run_native_v4.py'
DRIVER_PREPARE = HERE.parent/'recovery-room-reduced-driver/prepare.py'
LAUNCHER = HERE/'launcher.py'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--drivers', type=Path, required=True)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--product', choices=['aura1', 'roomfix4'], required=True)
    ap.add_argument('--mode', choices=['solo', 'dual'], required=True)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    sys.path.insert(0, str(REVIEW))
    prepared = load('reduced_driver_preparation', DRIVER_PREPARE)
    sha, read, save = prepared.sha, prepared.read, prepared.save
    assert sha(NATIVE) == '23819bb8c279d20a94a1a377f3ca838ff268e121911680b49b50758c373fc7ae'
    assert sha(DRIVER_PREPARE) == '9fc42964b003ff24407f2d9e03b7a0043e0c047798f76f2b238d21427f25d1b1'
    assert sha(LAUNCHER) == 'a5d3a120216c7573a4c26c6c923b821b53dbfeb9608ca3a4d5a93f017ab72601'
    driver = (ROOT/args.drivers).resolve()
    assert prepared.verify(driver)['compiled'] is True
    launcher = load('reduced_runtime_launcher_check', LAUNCHER)
    launcher.source()  # Exact two adaptations and official selector pins.
    native = load('reduced_room_native_checks', NATIVE)
    native.verify = prepared.verify
    native.RUNNER = LAUNCHER
    pins = {str(p): sha(p) for p in (Path(__file__), NATIVE, DRIVER_PREPARE, LAUNCHER, driver/'prepared.json')}
    pins.update({str(p): h for p, h in launcher.PINS.items()})
    before = prepared.installation()
    argv = [str(NATIVE), '--drivers', str(driver), '--mode', args.mode, '--scenario', 'timing',
            '--product', args.product, '--registry-wait', str(args.registry_wait)]
    if args.check:
        assert args.output is None
        argv += ['--check']
    else:
        assert args.output is not None
        out = (ROOT/args.output).resolve()
        assert out.parent == prepared.M52 and not out.exists()
        argv += ['--output', str(out)]
    previous = sys.argv
    result = dict(passed=False, performance_qualified=False, installed=False,
                  mode=args.mode, product=args.product, scenario='ordinary-three-travel',
                  disabled=sorted(launcher.DISABLED), inputs=pins)
    try:
        sys.argv = argv
        code = native.main()
        if args.check:
            return code
        raw = read(out/'result.json')
        run = Path(raw['run']).resolve()
        assert run.parent == ROOT/'build/cooperation'
        selection = read(run/'reduced-selection-result.json')
        assert selection['passed'] is True and selection['original_framework_passed'] is True
        assert set(selection['disabled']) == launcher.DISABLED
        roles = ['host'] if args.mode == 'solo' else ['host', 'join']
        assert set(selection['roles']) == set(roles)
        receipt = run/'selection/selection-input.json'
        assert Path(selection['selection_receipt']).resolve() == receipt.resolve()
        assert sha(receipt) == selection['selection_receipt_sha256']
        for role in roles:
            loaded = selection['roles'][role]
            assert loaded['passed'] is True and loaded['err'] == []
            assert set(loaded['requested']) == set(loaded['ok']) == set(selection['enabled'])
            assert sha(run/'selection'/(role+'-ModLoader.sol')) == loaded['status_sha256']
            text = (run/(role+'.log')).read_text(encoding='utf-8-sig')
            assert 'TRAVEL CONFIG ERROR' not in text, 'Native module discovery failed'
            assert 'ContinuousScene is explicitly not loaded' in text
            assert all(r['actualMerged'] is False and r['merged'] is False for r in raw['roles'][role]['rows'])
        result.update(passed=bool(code == 0 and raw['passed']), run=str(run), roles=raw['roles'],
                      native_result_sha256=sha(out/'result.json'), selection_result_sha256=sha(run/'reduced-selection-result.json'),
                      selection_receipt_sha256=selection['selection_receipt_sha256'], enabled=selection['enabled'])
    except Exception as error:
        result.update(passed=False, error=str(error), traceback=traceback.format_exc())
    finally:
        sys.argv = previous
        try:
            assert prepared.installation() == before
            for path, digest in pins.items():
                assert sha(path) == digest, path
            result.update(installation_unchanged=True, inputs_unchanged=True)
        except Exception as error:
            result.update(passed=False, final_verification_error=str(error))
        if not args.check and out.exists():
            save(out/'reduced-result.json', result)
    print(json.dumps(dict(passed=result['passed'], output=str(out), run=result.get('run'), error=result.get('error')), ensure_ascii=False))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
