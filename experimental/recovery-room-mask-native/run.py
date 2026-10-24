"""Use the original recovery runner, with the original mask driver's DONE contract."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys
import types

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
_spec = importlib.util.spec_from_file_location('mask_native_prepare', HERE/'prepare.py')
prepare = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(prepare)


def audit_mask(engine, run, result):
    registry = prepare.read(run/'registry-result.json')
    assert registry['passed'] is True and registry['cancelled'] is False
    for role in ('host', 'join'):
        text = engine.contents(run/(role+'.log'))
        assert len(re.findall(r'^COOP EFFECTS DONE\s*$', text, re.M)) == 1
        labels = {}
        for label, number in re.findall(r'^COOP PASS mask-restore (.+) case=(\d+)\s*$', text, re.M):
            labels.setdefault(int(number), set()).add(label)
        assert set(labels) == set(range(8)), role+' lacks actual eight-case coverage'
        for case in range(8):
            required = {'native body owns two live display fields',
                        'production mirror pairs the existing native body',
                        'receiver keeps real identity and SATS display references',
                        'leave retains the native body and both live fields'}
            if case < 7:
                for field in ('vis', 'hpbar'):
                    required.update(field+' '+suffix for suffix in (
                        'restores a live clip without borrowing retired or unrelated masks',
                        'preserves the actual alpha clipping bitmap',
                        'preserves the mask transform and stage coordinates',
                        'restores identical clipped field pixels at its real parent coordinates'))
            else:
                required.update({'later white bitmap owner keeps exact mask references and cache state after leave',
                                 'later owner shapes remain attached and visible in the native RV layers'})
            if case in (1, 3):
                required.add('restoration preserves the real native weapon mask reference')
            if case == 5:
                required.update({'RV inactive cleanup runs while roomHold is set',
                                 'inactive renderer leaves both fields without stale clips',
                                 'owned transitional shape is removed after RV becomes inactive'})
            if case == 6:
                required.update({'owned transitional shape is removed after native field replacement',
                                 'new native fields receive live RV masks without being overwritten by old cleanup'})
            assert required <= labels[case], (role, case, sorted(required-labels[case]))
        summaries = []
        for raw in re.findall(r'^MASK RESTORE SUMMARY (.+)$', text, re.M):
            summaries.append(json.loads(raw))
        assert len(summaries) == 5 and {v['caseId'] for v in summaries} == set(range(5))
        assert all(v['liveFields'] == 2 and v['retiredRemoved'] == 2 and v['renderedClipped'] > 0
                   and v['ownedOrphans'] == 0 for v in summaries)
        result[role]['native_mask_summaries'] = summaries
    inspector = prepare.load('mask_native_png_checker', prepare.ROOT/'tools/verify_mask_png.py')
    pictures, sweeps = [], []
    expected = {role+'-presentation-mask-restore-'+str(case)+'-'+phase+'.png'
                for role in ('host', 'join') for phase, cases in (('leave', range(7)), ('sweep', range(5)))
                for case in cases}
    assert {p.name for p in run.glob('*-presentation-mask-restore-*.png')} == expected
    for role in ('host', 'join'):
        for case in range(7):
            path = run/(role+'-presentation-mask-restore-'+str(case)+'-leave.png')
            row = inspector.inspect(path)
            assert row['white_block'] is None, (path.name, row['white_block'])
            pictures.append(row)
        for case in range(5):
            path = run/(role+'-presentation-mask-restore-'+str(case)+'-sweep.png')
            sweeps.append(dict(file=path.name, sha256=prepare.sha(path)))
    result['mask_scene_check'] = pictures
    result['sweep_images'] = sweeps
    result['registry_result_sha256'] = prepare.sha(run/'registry-result.json')
    assert all(not (run/name).exists() for name in ('host', 'join', 'frozen'))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--drivers', type=Path, required=True)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    drivers = (prepare.ROOT/args.drivers).resolve()
    manifest = prepare.verify(drivers, runtime=True)
    assert manifest['compiled'] is True
    bounded = prepare.read(drivers/'bounded-compiler.json')
    assert bounded['wrapper_sha256'] == prepare.sha(prepare.__file__)
    assert bounded['candidate_sha256'] == manifest['candidate_sha256'] and bounded['error'] is None
    assert len(bounded['commands']) == 3 and all(c['exit_code'] == 0 and c['reaped'] for c in bounded['commands'])
    assert args.registry_wait >= 0
    if args.check:
        assert args.output is None
        print('Mask native driver admitted; no AIR started')
        return 0
    assert args.output is not None
    out = (prepare.ROOT/args.output).resolve()
    assert out.parent == prepare.M52 and not out.exists()
    source = prepare.ORIGINAL_RUN.read_text(encoding='utf-8')
    old = "done = 'COOP EFFECTS DONE ' + suite\n            if suite not in ('peer-grip', 'peer-throw-damage'):"
    new = "done = 'COOP EFFECTS DONE' if suite == 'mask-restore' else 'COOP EFFECTS DONE ' + suite\n            if suite not in ('peer-grip', 'peer-throw-damage', 'mask-restore'):"
    assert source.count(old) == 1
    engine = types.ModuleType('mask_native_original_run')
    engine.__file__ = str(prepare.ORIGINAL_RUN)
    previous_prepare = sys.modules.get('prepare')
    try:
        sys.modules['prepare'] = prepare
        exec(compile(source.replace(old, new), str(prepare.ORIGINAL_RUN), 'exec'), engine.__dict__)
    finally:
        if previous_prepare is None:
            sys.modules.pop('prepare', None)
        else:
            sys.modules['prepare'] = previous_prepare
    engine.SUITES = {prepare.ENTRY: 'mask-restore'}
    engine.installation = prepare.current_runtime
    original_native, original_tools = engine.native, engine.runtime_tools

    def native(*values):
        original_native(*values)
        result = values[-1]
        audit_mask(engine, Path(result['run']), result)

    def runtime_tools():
        tools = original_tools()
        tools.update(manifest['mask_native']['tools'])
        tools[str(Path(__file__))] = prepare.sha(__file__)
        tools[str(drivers/'bounded-compiler.json')] = prepare.sha(drivers/'bounded-compiler.json')
        return tools

    engine.native, engine.runtime_tools = native, runtime_tools
    previous = sys.argv
    try:
        sys.argv = [str(prepare.ORIGINAL_RUN), 'native', '--drivers', str(drivers), '--output', str(out),
                    '--entry', prepare.ENTRY, '--registry-wait', str(args.registry_wait)]
        return engine.main()
    finally:
        sys.argv = previous


if __name__ == '__main__':
    raise SystemExit(main())
