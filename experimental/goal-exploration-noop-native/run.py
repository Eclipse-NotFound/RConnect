"""Only bind the frozen native measurement runner to the verified exploration-noop-only product.

No new driver, assertion, timing threshold, process launcher or game patch.
"""
from pathlib import Path
import argparse
import ast
import hashlib
import importlib.util
import json
import sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ORIGINAL = ROOT / 'experimental/goal-three-issues-native'
RECIPE = ROOT / 'experimental/goal-exploration-noop'
PRODUCT = ROOT / 'build/m52/goal-exploration-noop-product-01'
DRIVERS = ROOT / 'build/m52/goal-three-issues-native-drivers-02'
VERSION = '0.2.24-explorationnoop1'
MANIFEST_SHA = '941904ac31a3225d8543f089398840c7adfb46f75f367f89751be97abe65c163'


class ProductNotReady(RuntimeError):
    pass


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_check():
    proof = read(HERE / 'source-manifest.json')
    actual = {p.relative_to(HERE).as_posix(): sha(p) for p in HERE.rglob('*')
              if p.is_file() and p.name != 'source-manifest.json'}
    assert actual == proof['files'], 'Adapter source changed'
    for name, digest in proof['inputs'].items():
        assert sha(ROOT / name) == digest, 'Adapter input changed: ' + name
    assert sha(RECIPE / 'source-manifest.json') == MANIFEST_SHA
    candidate = read(RECIPE / 'source-manifest.json')
    assert candidate['version'] == VERSION
    assert {name for name, digest in candidate['candidate_source'].items()
            if candidate['base_source'][name] != digest} == {'RConnectMod.as', 'rconnect/game/ExplorationSync.as'}
    assert candidate['candidate_source']['rconnect/game/RemoteMotion.as'] == candidate['base_source']['rconnect/game/RemoteMotion.as']
    ast.parse((HERE / 'run.py').read_text(encoding='utf-8'))
    return {str(HERE / name): digest for name, digest in actual.items()} | {
        str(HERE / 'source-manifest.json'): sha(HERE / 'source-manifest.json')}


def preserve_failed_measurements(out):
    """Keep original failure untouched; collect every measurement actually logged.

    A killed process may not have flushed its buffered measurements. Such a
    missing record is explicit, not manufactured or reclassified as passing.
    """
    if out is None or not (out / 'result.json').is_file():
        return
    result_path = out / 'result.json'
    original_sha, result = sha(result_path), read(result_path)
    if result.get('passed') is not False:
        return
    run = Path(result['run']).resolve() if result.get('run') else None
    assert run is None or run.parent == ROOT / 'build/cooperation'
    evidence = dict(original_result_sha256=original_sha, original_passed=False,
                    run=str(run) if run else None, roles={}, qualification=False)
    for role in ('host', 'join'):
        log = run / (role + '.log') if run else None
        rows, malformed = [], []
        if log is not None and log.is_file():
            for line_number, line in enumerate(log.read_text('utf-8-sig').splitlines(), 1):
                if line.startswith('NATIVE MOTION MEASURE '):
                    try:
                        rows.append(json.loads(line.split('NATIVE MOTION MEASURE ', 1)[1]))
                    except ValueError as error:
                        malformed.append(dict(line=line_number, error=repr(error), raw=line))
        evidence['roles'][role] = dict(log=str(log) if log else None,
            log_sha256=sha(log) if log is not None and log.is_file() else None,
            emitted_measurements=rows, malformed=malformed, no_emitted_measurements=not rows)
    with (out / 'failure-measurements.json').open('x', encoding='utf-8') as stream:
        json.dump(evidence, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    assert sha(result_path) == original_sha, 'Failure result must remain unchanged'


def main():
    if sys.argv[1:] == ['--source-check']:
        source_check()
        print(json.dumps(dict(source_checked=True, product_compilation_checked=False, air_started=False)))
        return 0
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--drivers', type=Path, required=True)
    parser.add_argument('--product', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args, unused = parser.parse_known_args()
    assert (ROOT / args.drivers).resolve() == DRIVERS
    assert (ROOT / args.product).resolve() == PRODUCT
    out = (ROOT / args.output).resolve() if args.output is not None else None
    assert out is None or (out.parent == ROOT / 'build/m52' and not out.exists())
    source_check()
    absent = object()
    prior = {name: sys.modules.get(name, absent) for name in ('build', 'analyze')}
    old_path = sys.path[:]
    try:
        for name in ('build', 'analyze'):
            sys.modules[name] = load('exploration_original_' + name, ORIGINAL / (name + '.py'))
        native = load('exploration_original_native_runner', ORIGINAL / 'run.py')
        builder = load('exploration_verified_product_builder', RECIPE / 'build.py')
        assert native.CASES == {
            'native-jump': dict(seconds=300, done='native-jump', rounds=[0], checks={'host': 6, 'join': 6}),
            'fast-held': dict(seconds=360, done='tele-motion', rounds=[0, 1, 2, 3], checks={'host': 43, 'join': 42})}

        def product(path):
            assert Path(path).resolve() == PRODUCT
            adapter_pins = source_check()
            if not (PRODUCT / 'compile.json').is_file():
                raise ProductNotReady('Missing actual product compile.json')
            receipt = builder.verify(PRODUCT)
            metadata = read(PRODUCT / 'prepared.json')
            assert metadata['version'] == VERSION
            assert metadata['overlay_manifest_sha256'] == MANIFEST_SHA
            assert receipt['candidate_sha256'] == sha(PRODUCT / 'RConnectMod.swf')
            assert receipt['installation_before'] == native.installed() == receipt['installation_after']
            assert len(receipt['installation_before']) == 22
            paths = list(RECIPE.glob('*.py')) + [RECIPE / 'source-manifest.json'] + [
                PRODUCT / name for name in ('RConnectMod.swf', 'prepared.json', 'compile.json')]
            pins = {str(path): sha(path) for path in paths}
            pins.update(adapter_pins)
            return dict(path=str(PRODUCT), sha256=receipt['candidate_sha256'], version=VERSION,
                        receipt=receipt, pins=pins)

        # This is the only replacement in the original runner. All process,
        # sampling, settings, COOP assertions and finally checks remain there.
        native.product = product
        try:
            return native.main()
        except ProductNotReady as error:
            print(json.dumps(dict(checked=False, ready=False, reason='not-ready',
                detail=str(error), air_started=False)))
            return 2
        finally:
            try:
                preserve_failed_measurements(out)
            except BaseException as error:
                # Never overwrite/reclassify the original result on a logging
                # failure. Surface the extraction problem to the caller.
                print('Failure-measurement extraction error: ' + repr(error), file=sys.stderr)
    finally:
        sys.path[:] = old_path
        for name, value in prior.items():
            if value is absent:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = value


if __name__ == '__main__':
    raise SystemExit(main())
