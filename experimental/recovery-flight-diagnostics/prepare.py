"""Freeze exact recovery-05 plus diagnostic overlay and external driver.

No AIR launcher. Only --build starts JVM, under the shared game registration.
Uses the frozen build_mod.py and the existing external-declarations recipe.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-05'
BASE_SHA = 'bf15665a7457eb5997009b45717524512a6622bd8efccc7388e269f14ab045ae'
DRIVERS = ROOT / 'build/m52/recovery-drivers-09'
ENTRY = 'NativeFlightContinuityTestDoc'
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK, sha, read, save


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}


def check_files(folder, values):
    folder = folder.resolve()
    for name, digest in values.items():
        p = (folder / name).resolve()
        assert p.is_relative_to(folder) and p.is_file() and sha(p) == digest, 'Changed input: ' + str(p)


def check_baseline():
    assert sha(BASE / 'RConnectMod.swf') == BASE_SHA, 'Incorrect recovery-05 binary'
    manifest = read(BASE / 'prepared.json')
    assert manifest['version'] == '0.2.24-recovery5' and manifest['candidate_sha256'] == BASE_SHA
    check_files(BASE / 'src', manifest['source'])
    check_files(BASE / 'tools', manifest['inputs'])
    assert inventory(BASE / 'src') == manifest['source'], 'Unlisted recovery-05 source input'
    assert inventory(BASE / 'tools') == manifest['inputs'], 'Unlisted recovery-05 tool/stub input'
    return manifest


def check_overlay():
    # Importing the recipe neither materializes files nor launches a process.
    spec = importlib.util.spec_from_file_location('flight_diagnostic_materializer', HERE / 'make_overlay.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    manifest = read(HERE / 'inputs.json')
    assert manifest['baseline_binary_sha256'] == BASE_SHA
    assert manifest['baseline_prepared_sha256'] == sha(BASE / 'prepared.json')
    for item in manifest['files'] + [manifest['driver']]:
        original, overlay = Path(item['source']).resolve(), (HERE / item['overlay']).resolve()
        assert overlay.is_relative_to(HERE) and sha(original) == item['source_sha256'] and sha(overlay) == item['sha256']
        assert module.plain(overlay.read_text(encoding='utf-8')) == original.read_text(encoding='utf-8')
    check_files(HERE, manifest['new_files'])
    check_files(HERE, manifest['method_files'])
    return manifest


def freeze(out):
    assert not out.exists(), 'Use a new output folder; never overwrite evidence'
    baseline = check_baseline()
    overlay = check_overlay()
    originals = {}
    # Validate compiler/tool paths before creating a partial output directory.
    tool_inputs = [Path(sys.executable), JAVA, SDK / 'bin/amxmlc.bat', SDK / 'lib/mxmlc.jar',
                   SDK / 'lib/compc.jar', SDK / 'frameworks/air-config.xml',
                   SDK / 'frameworks/libs/air/airglobal.swc', ROOT / 'tools/host_authority/common.py',
                   ROOT.parent / 'ModLoader/tools/test_registry.py']
    for p in tool_inputs:
        assert p.is_file(), 'Missing build input: ' + str(p)
        originals[str(p.resolve())] = sha(p)
    out.mkdir()

    def copy(source, relative):
        source, dest = source.resolve(), out / relative
        assert source.is_file() and dest.resolve().is_relative_to(out)
        originals[str(source)] = sha(source)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        assert sha(dest) == originals[str(source)]

    # Copy all source/stub/build inputs from frozen 05, not mutable root src.
    for p in sorted((BASE / 'src').rglob('*.as')):
        copy(p, Path('src') / p.relative_to(BASE / 'src'))
    for p in sorted((BASE / 'tools').rglob('*')):
        if p.is_file():
            copy(p, Path('tools') / p.relative_to(BASE / 'tools'))
    for p in sorted((HERE / 'src').rglob('*.as')):
        copy(p, Path('src') / p.relative_to(HERE / 'src'))
    for p in sorted((HERE / 'tests').rglob('*.as')):
        copy(p, Path('tests') / p.relative_to(HERE / 'tests'))
    for name in ['inputs.json', 'make_overlay.py', 'prepare.py', 'analyze.py', 'test_static.py', 'README.md']:
        copy(HERE / name, Path('recipe') / name)
    copy(BASE / 'prepared.json', Path('inputs/recovery-05-prepared.json'))
    copy(DRIVERS / 'tests' / (ENTRY + '.as'), Path('inputs/original-driver.as'))
    copy(DRIVERS / 'analysis/native_flight.py', Path('analysis/native_flight.py'))
    copy(HERE / 'analyze.py', Path('analysis/diagnostics.py'))
    copy(DRIVERS / 'EffectsHarness.swf', Path('EffectsHarness.swf'))
    for p in sorted((DRIVERS / 'harness').rglob('*')):
        if p.is_file():
            copy(p, Path('harness') / p.relative_to(DRIVERS / 'harness'))
    originals[str(BASE / 'RConnectMod.swf')] = BASE_SHA
    meta = {
        'kind': 'recovery-flight-diagnostics', 'schema': 1, 'diagnostic_only': True,
        'functional_only': True, 'performance_qualified': False, 'native_qualified': False,
        'installed': False, 'air_started': False, 'compiled': False,
        'baseline_sha256': BASE_SHA, 'baseline': str(BASE), 'version': baseline['version'],
        'recipe_sha256': sha(HERE / 'prepare.py'), 'overlay_manifest_sha256': sha(HERE / 'inputs.json'),
        'source_root': str(out / 'src'), 'originals': originals, 'inputs': inventory(out),
        'toolchain': {'python': str(Path(sys.executable).resolve()), 'java': str(JAVA), 'sdk': str(SDK)},
        'entries': {ENTRY: {'scenarios': 8, 'seconds': 360, 'land': 'random_mane',
                            'diagnostic_only': True, 'performance_qualified': False}},
        'notes': ['Exact recovery-05 including its unchanged synchronous RoomCodec logs.',
                  'The original eight-case assertions and deadlines are unchanged.',
                  'Requires this diagnostic production binary; no 574D/original-05 driver binding.'],
    }
    save(out / 'prepared.json', meta)
    # Read-only metadata also named meta.json for isolated diagnostic consumers.
    save(out / 'meta.json', meta)
    verify(out)
    return meta


def verify(out):
    meta = read(out / 'prepared.json')
    assert meta['kind'] == 'recovery-flight-diagnostics' and meta['diagnostic_only'] is True
    assert meta['baseline_sha256'] == BASE_SHA and meta['performance_qualified'] is False
    assert meta['source_root'] == str(out / 'src')
    assert sha(out / 'prepared.json') == sha(out / 'meta.json'), 'Manifest copies diverged'
    check_files(out, meta['inputs'])
    if meta['compiled']:
        check_files(out, meta['artifacts'])
    for path, digest in meta['originals'].items():
        assert sha(Path(path)) == digest, 'Original input changed: ' + path
    return meta


def build(out, registry_wait):
    meta = verify(out)
    assert not meta['compiled'] and not (out / 'compile.log').exists(), 'Never rebuild successful or failed evidence'
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 高速弹体只读归因副本', purpose='编译准确05诊断生产副本与外部驱动；不运行AIR',
                      resource='game', run_dir=out, evidence=out / 'compile.log', wait=registry_wait) as record:
        # Recheck every frozen and external input after waiting for shared game.
        meta = verify(out)
        sdk, java = Path(meta['toolchain']['sdk']), Path(meta['toolchain']['java'])
        env = dict(os.environ, AIR_HOME=str(sdk))
        commands = []
        with (out / 'compile.log').open('w', encoding='utf-8') as log:
            def call(command):
                commands.append(command)
                save(out / 'commands.json', commands)
                subprocess.run(command, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)

            # This unmodified frozen script owns the normal stub and mod builds;
            # its MOD_ROOT resolves ONLY to this isolated output directory.
            call([meta['toolchain']['python'], '-B', '-X', 'utf8', str(out / 'tools/build_mod.py'),
                  '--amxmlc', str(sdk / 'bin/amxmlc.bat'), '--java', str(java),
                  '--output', str(out / 'RConnectMod.swf')])
            compiler = [str(java), '-Xmx384m', '-jar', str(sdk / 'lib/mxmlc.jar'), '+configname=air',
                        '+flexlib=' + str(sdk / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true']
            declarations = compiler.copy()
            declarations[3] = str(sdk / 'lib/compc.jar')
            stub, extern = out / 'build/GameCombatStubs.swc', out / 'ProductionDeclarations.swc'
            classes = ['.'.join(p.relative_to(out / 'src').with_suffix('').parts) for p in sorted((out / 'src').rglob('*.as'))]
            assert 'rconnect.diagnostics.FlightDiagnostics' in classes
            call(declarations + ['-source-path=' + str(out / 'src'), '-external-library-path+=' + str(stub),
                                 '-include-classes=' + ','.join(classes), '-output=' + str(extern)])
            dest = out / 'drivers' / ENTRY
            dest.mkdir(parents=True)
            call(compiler + ['-source-path=' + str(out / 'tests'), '-external-library-path+=' + str(extern),
                             '-external-library-path+=' + str(stub), '-output=' + str(dest / 'EffectsDriver.swf'),
                             str(out / 'tests' / (ENTRY + '.as'))])
            shutil.copyfile(out / 'EffectsHarness.swf', dest / 'EffectsHarness.swf')
        # Source, frozen recipes, baseline, harness and actual tools all checked
        # again before acknowledging a build or binding the driver to its mod.
        verify(out)
        binding = {
            'candidate_sha256': sha(out / 'RConnectMod.swf'), 'entry': ENTRY,
            'driver_sha256': sha(dest / 'EffectsDriver.swf'), 'harness_sha256': sha(dest / 'EffectsHarness.swf'),
            'declarations_sha256': sha(extern), 'stubs_sha256': sha(stub),
            'source_recipe_sha256': meta['recipe_sha256'], 'baseline_sha256': BASE_SHA,
            'overlay_manifest_sha256': meta['overlay_manifest_sha256'],
            'input_sha256': meta['inputs'], 'original_input_sha256': meta['originals'],
            'diagnostic_only': True, 'functional_only': True, 'performance_qualified': False,
            'expected_version': meta['version'], 'purpose': 'motion clock/frame stages/wall decode attribution only',
        }
        save(dest / 'driver-input.json', binding)
        meta['compiled'] = True
        meta['candidate_sha256'] = binding['candidate_sha256']
        meta['artifacts'] = {p.relative_to(out).as_posix(): sha(p) for p in [out / 'RConnectMod.swf', stub, extern,
                             dest / 'EffectsDriver.swf', dest / 'EffectsHarness.swf', dest / 'driver-input.json',
                             out / 'commands.json', out / 'compile.log']}
        save(out / 'prepared.json', meta)
        save(out / 'meta.json', meta)
        verify(out)
        record.outcome = 'passed'
        record.note = '诊断副本与外部驱动编译通过；未运行AIR，不形成原生或性能资格'
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', action='store_true', help='Compile under shared game registration; never starts AIR')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == (ROOT / 'build/m52').resolve() and out != BASE, 'Output must be a new direct child of build/m52'
    assert 0 <= args.registry_wait <= 3600
    if out.exists():
        assert args.build, 'Existing freeze is immutable; only its first pending build may continue'
        meta = verify(out)
    else:
        meta = freeze(out)
    if args.build:
        meta = build(out, args.registry_wait)
    print(json.dumps({'output': str(out), 'compiled': meta['compiled'], 'air_started': False,
                      'diagnostic_only': True, 'performance_qualified': False,
                      'candidate_sha256': meta.get('candidate_sha256')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
