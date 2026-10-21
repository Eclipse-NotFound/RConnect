"""Prepare/optionally compile one NEW external cold fixed-map travel driver.

No AIR, installation or production-source changes. --compile explicitly invokes
the AIR compiler under the shared game registration; default only freezes input
files. This recipe has not been executed by its author.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
GAME = ROOT.parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('output')
    parser.add_argument('--compile', action='store_true')
    bridge = parser.add_mutually_exclusive_group(required=True)
    bridge.add_argument('--require-bridge', action='store_true',
                        help='Candidate qualification: require both native bridges and real join adoption')
    bridge.add_argument('--baseline-no-bridge', action='store_true',
                        help='Explicit 574D control: require bridge absence; adoption is not applicable')
    parser.add_argument('--registry-wait', type=float, default=300)
    args = parser.parse_args()
    bridge_mode = 'required-native-plan' if args.require_bridge else '574D-no-bridge-control'
    driver_config = dict(requireBridge=args.require_bridge, bridgeMode=bridge_mode)
    out = (ROOT / args.output).resolve()
    if out.parent != M52.resolve() or out.exists():
        raise ValueError('Output must be a new direct build/m52 child')

    base = M52 / 'room-travel-driver-12'
    manifest = json.loads((base / 'prepared.json').read_text(encoding='utf-8-sig'))
    for name in ('ProductionDeclarations.swc', 'timing/EffectsHarness.swf'):
        if sha(base / name) != manifest['files'][name]:
            raise ValueError('Frozen external dependency changed: ' + name)
    stub = M52 / 'coop-bundle-04/build/GameCombatStubs.swc'
    sources = {path: sha(path) for path in [Path(__file__), HERE / 'README.md', *sorted((HERE / 'tests').glob('*.as'))]}
    dependencies = {base / 'prepared.json': sha(base / 'prepared.json'), stub: sha(stub),
                    base / 'ProductionDeclarations.swc': sha(base / 'ProductionDeclarations.swc'),
                    base / 'timing/EffectsHarness.swf': sha(base / 'timing/EffectsHarness.swf')}
    references = {GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/GameData.as': None,
                  GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/loc/LandAct.as': None,
                  GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/World.as': None,
                  GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/inter/Ctr.as': None,
                  GAME / 'game-reference/decompiled/1.02/src102/scripts/fe/unit/UnitPlayer.as': None,
                  GAME / 'Rooms/rooms_raiders.xml': None}
    references = {path: sha(path) for path in references}
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from run_security_terminals import installation
    before = installation()
    out.mkdir()
    (out / 'tests').mkdir()
    for path in sorted((HERE / 'tests').glob('*.as')):
        shutil.copyfile(path, out / 'tests' / path.name)
    (out / 'tests/ColdTravelBuildConfig.as').write_text(
        'package { public final class ColdTravelBuildConfig {\n'
        ' public static const REQUIRE_BRIDGE:Boolean=' + str(args.require_bridge).lower() + ';\n'
        ' public static const BRIDGE_MODE:String=' + json.dumps(bridge_mode) + ';\n'
        '} }\n', encoding='utf-8')
    shutil.copyfile(HERE / 'README.md', out / 'README.md')
    shutil.copyfile(Path(__file__), out / 'prepare-recipe.py')
    shutil.copyfile(base / 'ProductionDeclarations.swc', out / 'ProductionDeclarations.swc')
    shutil.copyfile(stub, out / 'GameCombatStubs.swc')
    (out / 'timing').mkdir()
    shutil.copyfile(base / 'timing/EffectsHarness.swf', out / 'timing/EffectsHarness.swf')
    frozen = {p: sha(p) for p in out.rglob('*') if p.is_file()}
    save(out / 'inputs.json', dict(
        recipe_sha256=sha(__file__),
        driver_config=driver_config,
        sources={str(p.relative_to(ROOT)): h for p, h in sources.items()},
        dependencies={str(p.relative_to(ROOT)): h for p, h in dependencies.items()},
        map_references={str(p.relative_to(GAME)): h for p, h in references.items()},
        installation=before,
        map=dict(id='raiders', file='rooms_raiders', rnd=False, entrance=[0, 1]),
        fixture_operations=['beginMission(raiders)', 'gotoLand(rbl)', 'gotoLand(raiders)'],
        manual_production_prepare=False))
    frozen[out / 'inputs.json'] = sha(out / 'inputs.json')

    def unchanged():
        current_sources = {Path(__file__), HERE / 'README.md', *sorted((HERE / 'tests').glob('*.as'))}
        if current_sources != set(sources):
            raise ValueError('External test source set changed while preparing')
        for path, digest in {**sources, **dependencies, **references, **frozen}.items():
            if sha(path) != digest:
                raise ValueError('Input changed while preparing: ' + str(path))
        if installation() != before:
            raise ValueError('Installation changed while preparing the external driver')

    compiled = False
    try:
        if args.compile:
            sys.path.insert(0, str(ROOT / 'tools/host_authority'))
            from common import JAVA, SDK
            sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
            from test_registry import Registration
            for tool in (JAVA, SDK / 'lib/mxmlc.jar'):
                if not tool.is_file():
                    raise FileNotFoundError(tool)
            cmd = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
                   '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
                   '-source-path=' + str(out / 'tests'),
                   '-external-library-path+=' + str(out / 'ProductionDeclarations.swc'),
                   '-external-library-path+=' + str(out / 'GameCombatStubs.swc'),
                   '-output=' + str(out / 'timing/EffectsDriver.swf'), str(out / 'tests/ColdFixedTravelTestDoc.as')]
            with Registration(owner='RConnect / 固定图原生旅行外部驱动', resource='game',
                              purpose='Compile external cold fixed-map driver; no AIR', run_dir=out,
                              evidence=out / 'compile.log', wait=args.registry_wait) as record:
                unchanged()
                with (out / 'compile.log').open('x', encoding='utf-8') as log:
                    process = None
                    try:
                        record.before_launch('ColdFixedTravelTestDoc AIR compiler')
                        unchanged()
                        process = subprocess.Popen(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                                   env=dict(os.environ, AIR_HOME=str(SDK)))
                        record.child(process.pid)
                        code = process.wait()
                        if code:
                            raise subprocess.CalledProcessError(code, cmd)
                    finally:
                        if process is not None:
                            if process.poll() is None:
                                process.terminate()
                            try:
                                process.wait(timeout=10)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait()
                        record.child_stopped()
                unchanged()
                compiled = (out / 'timing/EffectsDriver.swf').is_file()
                if not compiled:
                    raise RuntimeError('Compiler did not create EffectsDriver.swf')
                record.outcome = 'passed'
                record.note = 'External driver compiled; native travel/runtime/performance not tested'
        unchanged()
        save(out / 'prepared.json', dict(kind='cold-fixed-native-travel-driver', compiled=compiled,
            external=True, diagnostic_only=False, runtime_tested=False, performance_qualified=False,
            driver_config=driver_config,
            recipe_sha256=sha(__file__), input_manifest_sha256=sha(out / 'inputs.json'),
            source_set_unchanged=True, installation_unchanged=True, scenarios=['timing'],
            files={p.relative_to(out).as_posix(): sha(p) for p in out.rglob('*') if p.is_file()}))
    except BaseException as error:
        save(out / 'failed.json', dict(compiled=compiled, passed=False, error=repr(error),
                                      installation_unchanged=installation() == before))
        raise
    print(out, flush=True)


if __name__ == '__main__':
    main()
