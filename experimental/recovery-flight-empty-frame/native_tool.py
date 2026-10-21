"""Freeze/build only the native flight driver; run the unchanged native gate.

All relative arguments are relative to RConnect. No game or compiler starts
unless the caller explicitly selects prepare --build or run. Existing failed
or compiled evidence is never rebuilt. The fixed 574D control uses the identical
driver/harness bytes, including the same strict empty-frame evidence checks.
"""
import argparse
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GENERIC = ROOT / 'experimental/recovery-tests'
# This directory also has a different prepare.py (the source-only generator).
# Resolve the shared build recipe first and check its identity explicitly.
sys.path.insert(0, str(GENERIC))
import prepare

assert Path(prepare.__file__).resolve() == GENERIC / 'prepare.py'
ENTRY = 'NativeFlightContinuityTestDoc'
KIND = 'native-flight-empty-frame-v1'
FILES = {
    'NativeFlightContinuityTestDoc.as': 'tests/NativeFlightContinuityTestDoc.as',
    'NativeFlightBounds.as': 'tests/NativeFlightBounds.as',
    'analyze.py': 'analysis/native_flight.py',
    'bounds_evidence.py': 'analysis/bounds_evidence.py',
}
# Generic impact components predate the independent explosion dependency.
# This adapter never builds those fixtures; their separate receipts stay valid.
prepare.COMPONENTS = {}


def source_tools():
    paths = [Path(__file__).resolve(), GENERIC / 'prepare.py', GENERIC / 'run.py',
             ROOT / 'tools/host_authority/common.py']
    return {str(p): prepare.sha(p) for p in paths}


def check_tools(expected):
    assert source_tools() == expected, 'Entry adapter/shared source tools changed after freeze'


def check_manifest(manifest):
    ext = manifest['extension']
    assert ext['kind'] == KIND and ext['entry'] == ENTRY
    assert set(manifest['entries']) == {ENTRY} and not manifest['components']
    spec = manifest['entries'][ENTRY]
    assert spec['scenarios'] == 8 and spec['seconds'] == 360
    assert spec['land'] == 'random_mane' and spec['functional_only'] is True
    assert spec['performance_qualified'] is False
    assert manifest['control_sha256'] == prepare.BASE_SHA
    for original, dest in FILES.items():
        assert manifest['inputs'][dest] == ext['fixture_sha256'][original]
    assert ext['installation_files'] == 22
    check_tools(ext['source_tools'])


def freeze(source, out):
    binding = prepare.read(HERE / 'inputs.json')
    assert set(binding['outputs']) == set(FILES)
    for name, digest in binding['outputs'].items():
        assert prepare.sha(HERE / name) == digest, 'Fixture changed: ' + name
    for name, digest in binding['source_sha256'].items():
        assert prepare.sha(Path(binding['baseline']) / name) == digest, 'Baseline changed: ' + name
    tools = source_tools()
    manifest = prepare.freeze(source, out, entry_names=[ENTRY])

    def copy(original, dest, expected=None):
        digest = expected or prepare.sha(original)
        target = out / dest
        assert target.resolve().is_relative_to(out)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
        assert prepare.sha(target) == digest, 'Input changed during freeze: ' + str(original)
        manifest['inputs'][dest] = digest
        manifest['originals'][str(original.resolve())] = digest

    # Only this new output's just-copied old templates are replaced. Old build
    # folders and historical failed receipts remain untouched.
    for name, dest in FILES.items():
        copy(HERE / name, dest, binding['outputs'][name])
    for name in ('inputs.json', 'offline-receipt.json', 'fixture.patch', 'README.md'):
        copy(HERE / name, 'inputs/flight-empty-frame/' + name)
    for name, digest in tools.items():
        original = Path(name)
        copy(original, 'inputs/flight-empty-frame/source-tools/' + original.name, digest)
    manifest['extension'] = dict(kind=KIND, entry=ENTRY,
        fixture_sha256=binding['outputs'], source_tools=tools,
        installation_files=22, historical_failures_preserved=True,
        generic_components_built=False)
    check_manifest(manifest)
    prepare.save(out / 'prepared.json', manifest)
    prepare.verify(out, source)
    return manifest


def run_native(args, drivers):
    manifest = prepare.read(drivers / 'prepared.json')
    check_manifest(manifest)
    assert manifest['compiled'] is True, 'Build this frozen driver first'
    import run
    assert Path(run.__file__).resolve() == GENERIC / 'run.py'
    assert run.EXPECTED_INSTALLATION_FILES == 22
    assert run.SUITES[ENTRY] == 'native-flight-continuity'
    original_tools = run.runtime_tools
    original_argv = sys.argv
    # Add our adapter to the unchanged runner's before/after tool audit. The
    # runner still owns all memory, registry, input, log and trajectory gates.
    run.runtime_tools = lambda: dict(original_tools(), **manifest['extension']['source_tools'])
    sys.argv = [str(Path(__file__)), 'native', '--drivers', str(drivers),
                '--output', str(args.output), '--entry', ENTRY,
                '--registry-wait', str(args.registry_wait)]
    if args.control:
        sys.argv.append('--control')
    try:
        code = run.main()
    finally:
        sys.argv = original_argv
        run.runtime_tools = original_tools
        check_tools(manifest['extension']['source_tools'])
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    ap = modes.add_parser('prepare', help='Freeze new inputs; optionally compile only this entry')
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=900)
    rp = modes.add_parser('run', help='Use unchanged qualified native runner and independent analyzer')
    rp.add_argument('--drivers', type=Path, required=True)
    rp.add_argument('--output', type=Path, required=True)
    rp.add_argument('--entry', choices=[ENTRY], default=ENTRY)
    rp.add_argument('--control', action='store_true')
    rp.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args(argv)
    assert args.registry_wait >= 0, 'Registry wait must be nonnegative'
    out = (ROOT / args.output).resolve()
    assert out.parent == (ROOT / 'build/m52').resolve(), 'Output must be an immediate build/m52 child'
    if args.mode == 'run':
        drivers = (ROOT / args.drivers).resolve()
        assert drivers.parent == (ROOT / 'build/m52').resolve()
        assert not out.exists(), 'Never overwrite historical results'
        args.output = out
        return run_native(args, drivers)
    source = (ROOT / args.source).resolve()
    assert source.is_relative_to(ROOT / 'build') and source.name == 'src'
    assert not source.is_relative_to(out)
    if out.exists():
        assert args.build, 'Existing freeze permits only its first pending build'
        manifest = prepare.verify(out, source)
        check_manifest(manifest)
        assert not manifest['compiled'] and not (out / 'compile.log').exists(), 'Freeze a new output after any build'
    else:
        manifest = freeze(source, out)
    if args.build:
        prepare.build(source, out, args.registry_wait)
        check_manifest(prepare.verify(out, source))
    print(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
