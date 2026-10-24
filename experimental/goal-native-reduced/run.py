"""Same compiled native-jump stimulus; officially unselect LAD/RV/CS in copies."""
from pathlib import Path
import argparse, difflib, hashlib, importlib.util, json, sys, traceback

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ORIGINAL = HERE.parent/'goal-three-issues-native/run.py'
ORIGINAL_SHA = '2dc340ab793e95fec7abab6d3061a789255d6b0afe861036b96ee654ac36ed12'
SHARED = ROOT/'tools/run_coop_regression.py'
DRIVERS = ROOT/'build/m52/goal-three-issues-native-drivers-02'
PRODUCT = ROOT/'build/m52/recovery-room-production-05'
DISABLED = {'LightAndDarknessMod', 'RealisticVisionMod', 'ContinuousSceneMod'}
DISABLED_PATHS = {'mods/lightanddarkness/release/lightanddarknessmod.swf',
    'mods/realisticvision/release/realisticvisionmod.swf',
    'mods/continuousscene/release/continuousscenemod.swf'}
CHANGES = (
    (" pins.update(selected['pins'])\n", " pins.update(selected['pins'])\n pins.update(reduced_source_inputs())\n"),
    (" assert sha(RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'\n",
     " assert sha(SHARED_RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'\n reduced_source_inputs()\n"),
    ('   if not settings:\n', "   if not settings and detail != 'Private module selection only; no AIR':\n"),
    ('    assert not record.children and not record.launching;verify_inputs()\n',
     "    selection_process=read(output/'selection/launcher-process.json')\n"
     "    assert selection_process['air_launch'] is False and selection_process['exit_code']==0\n"
     "    assert type(selection_process['pid']) is int and selection_process['pid']>0\n"
     "    assert len(record.children)==1 and record.children[0]['pid']==selection_process['pid']\n"
     "    from test_registry import gone\n"
     "    assert not record.launching and gone(record.children[0]);verify_inputs()\n"),
    ("{n.lower() for n in before if n.lower().startswith('mods/') and n.lower().endswith('.swf')}",
     "{n.lower() for n in before if n.lower().startswith('mods/') and n.lower().endswith('.swf')} - REDUCED_DISABLED_PATHS"),
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source():
    assert sha(ORIGINAL) == ORIGINAL_SHA
    old = ORIGINAL.read_text(encoding='utf-8')
    new = old
    for before, after in CHANGES:
        assert new.count(before) == 1 and after not in new
        new = new.replace(before, after)
    restored = new
    for before, after in reversed(CHANGES):
        restored = restored.replace(after, before)
    assert restored == old
    compile(new, str(ORIGINAL), 'exec')
    return new, ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
        fromfile='frozen/goal-three-issues-native/run.py', tofile='adapted/native-jump-reduced/run.py'))


def inputs():
    manifest = HERE/'source-manifest.json'
    m = read(manifest)
    assert m['kind'] == 'native-jump-official-reduced-v1'
    assert m['original_wrapper_sha256'] == ORIGINAL_SHA
    assert m['native_replacements'] == 5 and m['selector_replacements'] == 2
    for name, digest in m['files'].items():
        assert sha(HERE/name) == digest, name
    for name, digest in m['original'].items():
        assert sha(name) == digest, name
    adapter = load(HERE/'runner.py', 'native_jump_selector_preflight')
    selector = adapter.load()
    selector.source()
    assert selector.DISABLED == DISABLED
    rows = selector.manifest_rows(ROOT.parents[1]/'mods/loader-manifest.txt')
    expected = {n for n, row in rows.items() if row['flags'][0] == '1'} - DISABLED
    assert len(rows) == 14 and len(expected) == 11
    assert {rows[n]['path'].lower() for n in DISABLED} == DISABLED_PATHS
    pins = {str(HERE/name): digest for name, digest in m['files'].items()}
    pins.update(m['original'])
    pins[str(manifest)] = sha(manifest)
    pins.update({str(p): h for p, h in selector.PINS.items()})
    return pins


def main():
    expanded, diff = source()
    pins = inputs()
    sys.path.insert(0, str(ORIGINAL.parent))
    spec = importlib.util.spec_from_loader('native_jump_reduced_original', loader=None)
    outer = importlib.util.module_from_spec(spec)
    outer.__file__ = str(ORIGINAL)
    exec(compile(expanded, str(ORIGINAL), 'exec'), outer.__dict__)
    outer.RUNNER = HERE/'runner.py'
    outer.SHARED_RUNNER = SHARED
    outer.REDUCED_DISABLED_PATHS = DISABLED_PATHS
    outer.reduced_source_inputs = inputs
    outer.CASES = {'native-jump': outer.CASES['native-jump']}
    original_product = outer.product
    def baseline_product(path):
        assert Path(path).resolve() == PRODUCT
        return original_product(path)
    outer.product = baseline_product
    if '-h' in sys.argv or '--help' in sys.argv:
        return outer.main()
    peek = argparse.ArgumentParser(add_help=False)
    peek.add_argument('--drivers', type=Path, required=True)
    peek.add_argument('--product', type=Path, required=True)
    peek.add_argument('--case', required=True)
    peek.add_argument('--output', type=Path)
    peek.add_argument('--check', action='store_true')
    args, _ = peek.parse_known_args()
    assert (ROOT/args.drivers).resolve() == DRIVERS
    assert (ROOT/args.product).resolve() == PRODUCT and args.case == 'native-jump'
    if args.check:
        return outer.main()
    assert args.output is not None
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    report = dict(kind='ordinary-native-jump-reduced-v1', passed=False, installed=False,
        disabled=sorted(DISABLED), performanceQualified=False, smoothnessQualified=False,
        driver_recompiled=False, source_inputs=pins)
    try:
        code = outer.main()
        native = read(out/'result.json')
        report.update(original_exit_code=code, original_functional_passed=native['passed'] is True,
            native_result_sha256=sha(out/'result.json'))
        assert code == 0 and native['passed'] is True
        run = Path(native['run']).resolve()
        assert run.parent == ROOT/'build/cooperation'
        selection = read(run/'reduced-selection-result.json')
        assert selection['passed'] is True and selection['original_framework_passed'] is True
        assert set(selection['disabled']) == DISABLED and len(selection['enabled']) == 11
        assert set(selection['roles']) == set(native['roles']) == {'host', 'join'}
        receipt = run/'selection/selection-input.json'
        assert Path(selection['selection_receipt']).resolve() == receipt.resolve()
        assert sha(receipt) == selection['selection_receipt_sha256']
        actual = read(receipt)
        assert set(actual['enabled']) == set(selection['enabled'])
        assert actual['physical_files_retained'] is True and len(actual['physical_modules']) == 14
        assert len(actual['enabled_paths']) == 11
        for role in ('host', 'join'):
            row = selection['roles'][role]
            assert row['passed'] is True and row['err'] == []
            assert set(row['requested']) == set(row['ok']) == set(selection['enabled'])
            assert not set(row['requested']) & DISABLED
            assert sha(run/'selection'/(role+'-ModLoader.sol')) == row['status_sha256']
            assert native['roles'][role]['checks'] == 6
        report.update(passed=True, run=str(run), enabled=selection['enabled'], roles=selection['roles'],
            selection_result_sha256=sha(run/'reduced-selection-result.json'),
            selection_receipt=str(receipt), selection_receipt_sha256=sha(receipt))
    except BaseException as error:
        report.update(error=repr(error), traceback=traceback.format_exc())
    finally:
        try:
            assert inputs() == pins
            report['source_inputs_unchanged'] = True
        except Exception as error:
            report.update(passed=False, final_error=repr(error))
        if out.is_dir():
            adapter = load(HERE/'runner.py', 'native_jump_selector_evidence')
            selector_expanded, selector_diff = adapter.source()
            for name, text in (('native-adapted.py', expanded), ('native-source.diff', diff),
                ('selector-adapted.py', selector_expanded), ('selector-source.diff', selector_diff)):
                with (out/name).open('x', encoding='utf-8', newline='\n') as stream:
                    stream.write(text)
            report['adapted_sources'] = {name: sha(out/name) for name in
                ('native-adapted.py', 'native-source.diff', 'selector-adapted.py', 'selector-source.diff')}
            outer.save(out/'reduced-result.json', report)
    print(json.dumps({k: report.get(k) for k in ('passed', 'original_functional_passed', 'run', 'error')}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
