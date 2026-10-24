"""Thin roomload2 binding to the frozen first-raster bounded compiler."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import sys
import types

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load_prepare():
    spec = importlib.util.spec_from_file_location('roomload2_source_prepare', HERE/'prepare.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def bound():
    prepared = load_prepare()
    prepared.verify()
    source, _ = prepared.adapted_builder()
    module = types.ModuleType('roomload2_bound_first_raster_builder')
    module.__file__ = str(prepared.DELEGATE)
    exec(compile(source, str(prepared.DELEGATE)+' [roomload2 installed-base binding]', 'exec'), module.__dict__)
    module.HERE, module.BASE, module.BASE_SHA = HERE, prepared.BASE, prepared.BASE_SHA
    module.VERSION, module.INSTALLED_SHA = prepared.VERSION, prepared.INSTALLED_SHA

    def source_check():
        manifest = prepared.verify()
        return dict(source=manifest['candidate_source'], inputs=prepared.read(prepared.BASE/'prepared.json')['inputs']), (HERE/'src/RConnectMod.as').read_bytes()

    def recipe_inputs():
        paths = list(prepared.PINS) + [HERE/'prepare.py', HERE/'build.py', HERE/'README.md',
            HERE/'manifest.json', HERE/'source.diff', HERE/'builder-adaptation.diff', module.JAVA,
            module.SDK/'lib/compc.jar', module.SDK/'lib/mxmlc.jar',
            prepared.ROOT/'tools/validation/run_security_terminals.py',
            prepared.ROOT/'tools/validation/prepare_security_terminals.py',
            prepared.ROOT/'tools/validation/runtime_memory.py',
            prepared.ROOT.parent/'ModLoader/tools/test_registry.py']
        return {str(path): prepared.sha(path) for path in paths}

    module.source_check, module.recipe_inputs = source_check, recipe_inputs
    assert module.ROOT == prepared.ROOT
    return prepared, module


def verify(folder):
    """Read-only: source/base provenance and actual compile receipt; no live-test claim."""
    prepared, module = bound()
    result = module.verify(Path(folder).resolve())
    assert result['installation_before']['mods/Rconnect/release/RConnectMod.swf'] == prepared.INSTALLED_SHA
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--build', metavar='OUTPUT')
    mode.add_argument('--verify', metavar='OUTPUT')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    prepared, module = bound()
    if args.check:
        print(json.dumps(dict(source_check_passed=True, version=prepared.VERSION,
            base_sha256=prepared.BASE_SHA, installed_rc_required=prepared.INSTALLED_SHA,
            manifest_sha256=prepared.sha(HERE/'manifest.json'), source_count=82,
            unchanged_source_count=79, compiled=False, air_started=False)))
    elif args.verify:
        verify(prepared.ROOT/args.verify)
        print(json.dumps(dict(verified=True, runtimeValidated=False, performanceQualified=False)))
    else:
        # Original two-JVM registration, memory, timeout, process cleanup and
        # installation/source equality checks execute unchanged. Only the live
        # RC requirement differs from the isolated source product's SHA.
        try:
            module.build(args.build, args.registry_wait)
        finally:
            prepared.verify()


if __name__ == '__main__':
    main()
