"""Existing ordinary three-trip fixture, with LAD/RV/CS officially unselected."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, sys, traceback

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ORDINARY = HERE.parent/'goal-ordinary-loading/run.py'
ORDINARY_SHA = '5613e8bca191116797bac42af1d7054cfe99516dd5a32d8f1b44168d896b3502'
DRIVER = ROOT/'build/m52/recovery-room-reduced-driver-01'
DRIVER_MANIFEST_SHA = '9dff291611b3596585c85f88bf3ca0145923b6c15c7c92a78bc7f542db06e0e6'
DRIVER_SHA = '80e56d6ed142a46bbe86972ea1349f0df9bd78d412c94e5fa34c2f379b8ad7f9'
OLD = '            if not settings:\n'
NEW = "            if not settings and detail != 'Private module selection only; no AIR':\n"
CHILD_OLD = '                assert not record.children and not record.launching\n'
CHILD_NEW = '''                selection_process = read(output/'selection/launcher-process.json')
                assert selection_process['air_launch'] is False and selection_process['exit_code'] == 0
                assert type(selection_process['pid']) is int and selection_process['pid'] > 0
                assert len(record.children) == 1 and record.children[0]['pid'] == selection_process['pid']
                from test_registry import gone
                assert not record.launching and gone(record.children[0])
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    assert sha(ORDINARY) == ORDINARY_SHA
    source = ORDINARY.read_text(encoding='utf-8')
    assert source.count(OLD) == 1 and source.count(CHILD_OLD) == 1
    adapted = source.replace(OLD, NEW).replace(CHILD_OLD, CHILD_NEW)
    assert adapted.replace(CHILD_NEW, CHILD_OLD).replace(NEW, OLD) == source
    spec = importlib.util.spec_from_loader('ordinary_reduced_shared_execution', loader=None)
    outer = importlib.util.module_from_spec(spec)
    outer.__file__ = str(ORDINARY)
    exec(compile(adapted, str(ORDINARY), 'exec'), outer.__dict__)
    adapter = load(HERE/'runner.py', 'ordinary_reduced_selector_binding')
    selector = adapter.load()
    selector.source()  # Only verify the existing two adaptations and official-tool pins.
    outer.DRIVER, outer.DRIVER_SHA = DRIVER, DRIVER_SHA
    outer.RUNNER = HERE/'runner.py'
    original_pins = {}

    def inputs(path):
        assert path == outer.BASELINE and outer.DIAGNOSTIC is None
        assert sha(ORDINARY) == ORDINARY_SHA
        assert sha(outer.SHARED/'run.py') == outer.ORIGINAL_WRAPPER_SHA
        meta, built = outer.product(path)
        assert sha(DRIVER/'prepared.json') == DRIVER_MANIFEST_SHA
        driver = outer.read(DRIVER/'prepared.json')
        assert driver['kind'] == 'room-reduced-unloaded-scene-driver'
        assert all(driver[k] is True for k in ('compiled', 'external', 'installation_unchanged',
            'metrics_byte_exact', 'cs_explicitly_unloaded', 'original_compare_and_travel_assertions_preserved'))
        assert len(driver['commands']) == 1
        assert driver['commands'][0]['exit_code'] == 0 and driver['commands'][0]['reaped'] is True
        for name, digest in driver['inputs'].items():
            assert sha(name) == digest, name
        for name, digest in driver['files'].items():
            assert sha(DRIVER/name) == digest, name
        assert sha(DRIVER/'timing/EffectsDriver.swf') == driver['driver_sha256'] == DRIVER_SHA
        assert sha(DRIVER/'timing/EffectsHarness.swf') == outer.HARNESS_SHA
        assert outer.read(outer.TELEMETRY) == {'enabled': True}
        selector.source()
        files = [Path(__file__), HERE/'runner.py', ORDINARY, adapter.BASE, outer.SHARED/'run.py',
            outer.SHARED/'bridge_inputs.py', DRIVER/'prepared.json', DRIVER/'timing/EffectsDriver.swf',
            DRIVER/'timing/EffectsHarness.swf', outer.TELEMETRY, path/'prepared.json', path/'compile.json',
            path/'RConnectMod.swf', ROOT/'tools/validation/runtime_memory.py',
            ROOT/'tools/validation/air_test_inventory.py', outer.GAME/'mods/ModLoader/tools/test_registry.py',
            outer.GAME/'mods/ModLoader/tools/air_test_process.py']
        pins = {str(p): sha(p) for p in files}
        pins.update({str(p): digest for p, digest in selector.PINS.items()})
        if original_pins:
            assert pins == original_pins
        else:
            original_pins.update(pins)
        return meta, built, pins

    outer.inputs = inputs
    parsed = argparse.ArgumentParser(add_help=False)
    parsed.add_argument('--output', type=Path)
    parsed.add_argument('--check', action='store_true')
    args, _ = parsed.parse_known_args()
    if args.check:
        return outer.main()
    assert args.output is not None
    out = (ROOT/args.output).resolve()
    result = dict(passed=False, performance_qualified=False, installed=False,
        disabled=sorted(selector.DISABLED), execution_source_sha256=ORDINARY_SHA,
        selection_source_sha256=adapter.BASE_SHA, driver_sha256=DRIVER_SHA)
    try:
        code = outer.main()
        native = outer.read(out/'result.json')
        assert code == 0 and native['passed'] is True
        run = Path(native['run']).resolve()
        assert run.parent == ROOT/'build/cooperation'
        selection = outer.read(run/'reduced-selection-result.json')
        assert selection['passed'] is True and selection['original_framework_passed'] is True
        assert set(selection['disabled']) == selector.DISABLED
        assert set(selection['roles']) == set(native['roles'])
        receipt = run/'selection/selection-input.json'
        assert Path(selection['selection_receipt']).resolve() == receipt.resolve()
        assert sha(receipt) == selection['selection_receipt_sha256']
        for role, row in native['roles'].items():
            loaded = selection['roles'][role]
            assert loaded['passed'] is True and loaded['err'] == []
            assert set(loaded['requested']) == set(loaded['ok']) == set(selection['enabled'])
            assert not set(loaded['ok']) & selector.DISABLED
            assert sha(run/'selection'/(role+'-ModLoader.sol')) == loaded['status_sha256']
            text = (run/(role+'.log')).read_text(encoding='utf-8-sig')
            assert 'ContinuousScene is explicitly not loaded' in text and 'TRAVEL CONFIG ERROR' not in text
            assert all(r['merged'] is False and r['actualMerged'] is False for r in row['rows'])
        result.update(passed=True, run=str(run), enabled=selection['enabled'],
            native_result_sha256=sha(out/'result.json'), selection_result_sha256=sha(run/'reduced-selection-result.json'))
    except BaseException as error:
        result.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        if out.is_dir():
            outer.save(out/'reduced-result.json', result)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
