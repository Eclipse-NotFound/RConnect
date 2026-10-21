"""Freeze external recovery drivers against exact candidate bytes; never run AIR.

Reuses the existing external declarations/harness layout and game registry.
No production compiler is invoked and no file outside the new output is written.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK, sha, read, save

BASE = ROOT / 'build/m52/coop-bundle-04/RConnectMod.swf'
BASE_SHA = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
ENTRIES = {
    'PeerGripTestDoc': (16, 420, '双向原生 Q、最终舞台光晕像素、释放/抛掷/reset/换房清理'),
    'PeerThrowDamageTestDoc': (20, 420, '双向原生 Q/E 与碰墙伤害开关、释放和共享暂停'),
    'WallBallisticTestDoc': (14, 420, '普通枪、NPC 慢弹、连射、到期和肉体命中'),
    'WallEnergyTestDoc': (15, 420, '能量、天角兽闪电、喷火和速射命中'),
    'WallMagicTestDoc': (14, 420, '七种原生魔法武器双向击墙'),
    'RecoveryWallMaterialsTestDoc': (14, 420, '材质 1—7 双向真碰撞及不应出现火星的负例'),
    'ExplosiveVisualTestDoc': (14, 420, '普通爆炸物、入水、飞行中换枪和真实爆炸像素'),
    'SpecialWeaponTestDoc': (12, 420, '酸性/等离子/EMP/冰冻/毒气/燃烧投掷物及地面附效'),
    'MagicExplosionTestDoc': (4, 240, '独立快捷魔法槽的火球与 eclipse 爆炸'),
    'HeavyProjectileTestDoc': (8, 300, '火箭/重弹/榴弹原生轨迹、朝向、寿命及近墙'),
    'NativeFlightContinuityTestDoc': (8, 360, '真实枪弹与移动闪电逐弹源轨迹、TCP及最终RENDER停顿和尾段'),
}
COMPONENTS = {
    'aura': ('PlayerAuraChecks', 59, ('TelekinesisVisuals', 'PlayerBodyEffects')),
    'impact': ('ImpactQueueChecks', 41, ('ImpactEventQueue', 'BallisticImpactVisuals', 'EnergyImpactVisuals', 'ProjectileFrameStream')),
}


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}


def verify_files(root, values):
    for name, digest in values.items():
        p = (root / name).resolve()
        assert p.is_relative_to(root.resolve()) and p.is_file() and sha(p) == digest, name


def freeze(source, out, components_only=False, entry_names=None):
    assert not out.exists(), 'Use a new output folder; existing evidence is never replaced'
    binary = source.parent / 'RConnectMod.swf'
    stub = source.parent / 'build/GameCombatStubs.swc'
    assert (source / 'RConnectMod.as').is_file() and binary.is_file() and stub.is_file(), \
        'First compile the final production candidate; this script never compiles it'
    assert sha(BASE) == BASE_SHA, 'The fixed 574D negative-control binary changed'
    out.mkdir()
    originals = {}

    def copy(p, relative):
        dest = out / relative
        assert dest.resolve().is_relative_to(out)
        dest.parent.mkdir(parents=True, exist_ok=True)
        originals[str(p.resolve())] = sha(p)
        shutil.copyfile(p, dest)
        assert sha(dest) == originals[str(p.resolve())]

    for p in sorted(source.rglob('*.as')):
        copy(p, Path('production') / p.relative_to(source))
    copy(stub, Path('inputs/GameCombatStubs.swc'))
    # Only the needed external test closure, not the entire historical test tree.
    for origin in [ROOT / 'experimental/recovery-aura/tests',
                   ROOT / 'experimental/recovery-wall-impact/tests', HERE / 'tests', HERE / 'continuity-extra',
                   ROOT / 'experimental/recovery-aura-followup/tests']:
        for p in sorted(origin.rglob('*.as')):
            copy(p, Path('tests') / p.relative_to(origin))
    copy(HERE / 'continuity-extra/analyze.py', Path('analysis/native_flight.py'))
    for name in ['MagicExplosionTestDoc.as', 'SpecialWeaponTestDoc.as', 'fe/unit/EnemyGrabProbe.as']:
        copy(ROOT / 'tests' / name, Path('tests') / name)
    for p in sorted((ROOT / 'tests/harness').rglob('*.as')):
        copy(p, Path('harness') / p.relative_to(ROOT / 'tests/harness'))
    for kind, (entry, count, production) in COMPONENTS.items():
        origin = ROOT / ('experimental/recovery-aura-followup/component' if kind == 'aura'
                         else 'experimental/recovery-wall-impact/components')
        for p in sorted(origin.rglob('*.as')):
            copy(p, Path('components') / kind / 'src' / p.relative_to(origin))
        for name in production:
            relative = Path('rconnect/game') / (name + '.as')
            copy(source / relative, Path('components') / kind / 'src' / relative)
        appid = 'rconnect-recovery-' + kind + '-' + uuid.uuid4().hex
        (out / 'components' / kind / 'application.xml').write_text(
            '<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid +
            '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>'
            '<content>Checks.swf</content><visible>false</visible><width>120</width><height>120</height>'
            '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
    originals[str(binary)] = sha(binary)
    originals[str(BASE)] = BASE_SHA
    candidate_manifest = source.parent / 'prepared.json'
    if candidate_manifest.is_file():
        copy(candidate_manifest, Path('inputs/candidate-prepared.json'))
    tool_inputs = [Path(__file__).resolve(), ROOT / 'tools/host_authority/common.py',
                   ROOT.parent / 'ModLoader/tools/test_registry.py', JAVA,
                   SDK / 'lib/mxmlc.jar', SDK / 'lib/compc.jar',
                   SDK / 'frameworks/air-config.xml', SDK / 'frameworks/libs/air/airglobal.swc']
    for p in tool_inputs:
        assert p.is_file(), 'Missing build tool: ' + str(p)
        originals[str(p.resolve())] = sha(p)
    manifest = dict(kind='recovery-external-drivers', source_root=str(source),
                    candidate_sha256=sha(binary), control_sha256=BASE_SHA,
                    recipe_sha256=sha(__file__), inputs=inventory(out), originals=originals,
                    entries={k: dict(scenarios=v[0], seconds=v[1], purpose=v[2], land='random_mane',
                                     functional_only=True, performance_qualified=False)
                             for k, v in ({} if components_only else ENTRIES).items()
                             if entry_names is None or k in entry_names},
                    components={k: dict(entry=v[0], expected_checks=v[1], game_loaded=False)
                                for k, v in COMPONENTS.items()},
                    compiled=False, air_started=False, native_qualified=False)
    save(out / 'prepared.json', manifest)
    return manifest


def verify(out, source, runtime=False):
    manifest = read(out / 'prepared.json')
    assert manifest['kind'] == 'recovery-external-drivers' and manifest['source_root'] == str(source)
    if not runtime:
        assert manifest['recipe_sha256'] == sha(__file__), 'Freeze again after a recipe change'
    verify_files(out, manifest['inputs'])
    if manifest.get('compiled'):
        verify_files(out, manifest['files'])
    # The frozen test tree is authoritative during both build and execution.
    # A later template edit must not abort an already queued build: every copied
    # byte is already recorded above and is the byte the compiler will consume.
    # Production sources and binaries remain pinned to their original locations.
    for name, digest in manifest['originals'].items():
        original = Path(name)
        if original.is_relative_to(source) or original in (source.parent / 'RConnectMod.swf', BASE):
            assert sha(original) == digest, 'An original input changed: ' + name
    return manifest


def build(source, out, registry_wait):
    manifest = verify(out, source)
    assert not manifest['compiled'] and not (out / 'compile.log').exists(), \
        'Never rebuild over completed or failed evidence; freeze a new output'
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 恢复整合版外部测试驱动', purpose='只编译外部原生与组件驱动，不运行 AIR',
                      resource='game', run_dir=out, evidence=out / 'compile.log', wait=registry_wait) as record:
        # Inputs may change while this build waits for the shared test lock.
        verify(out, source)
        compiler = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
                    '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true']
        declarations = compiler.copy()
        declarations[3] = str(SDK / 'lib/compc.jar')
        stub = out / 'inputs/GameCombatStubs.swc'
        extern = out / 'ProductionDeclarations.swc'
        harness = out / 'EffectsHarness.swf'
        env = dict(os.environ, AIR_HOME=str(SDK))
        commands = []
        with (out / 'compile.log').open('w', encoding='utf-8') as log:
            def call(command):
                commands.append(command)
                save(out / 'commands.json', commands)
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, env=env)

            classes = ['.'.join(p.relative_to(out / 'production').with_suffix('').parts)
                       for p in sorted((out / 'production').rglob('*.as'))]
            call(declarations + ['-source-path=' + str(out / 'production'), '-external-library-path+=' + str(stub),
                                 '-include-classes=' + ','.join(classes), '-output=' + str(extern)])
            call(compiler + ['-source-path=' + str(out / 'harness'), '-output=' + str(harness),
                             str(out / 'harness/RConnectDoc.as')])
            for entry, spec in manifest['entries'].items():
                dest = out / 'drivers' / entry
                dest.mkdir(parents=True)
                call(compiler + ['-source-path=' + str(out / 'tests'), '-external-library-path+=' + str(extern),
                                 '-external-library-path+=' + str(stub), '-output=' + str(dest / 'EffectsDriver.swf'),
                                 str(out / 'tests' / (entry + '.as'))])
                shutil.copyfile(harness, dest / 'EffectsHarness.swf')
                binding = dict(candidate_sha256=manifest['candidate_sha256'], entry=entry,
                               driver_sha256=sha(dest / 'EffectsDriver.swf'), source_recipe_sha256=sha(__file__),
                               purpose=spec['purpose'], functional_only=True)
                save(dest / 'driver-input.json', binding)
                control = out / 'controls' / entry
                shutil.copytree(dest, control)
                binding['candidate_sha256'] = BASE_SHA
                binding['negative_control'] = True
                save(control / 'driver-input.json', binding)
                print('BUILT ' + entry, flush=True)
            for kind, spec in manifest['components'].items():
                folder = out / 'components' / kind
                call(compiler + ['-source-path=' + str(folder / 'src'), '-output=' + str(folder / 'Checks.swf'),
                                 str(folder / 'src' / (spec['entry'] + '.as'))])
        verify(out, source)
        manifest['compiled'] = True
        manifest['files'] = inventory(out)
        manifest['files'].pop('prepared.json', None)
        save(out / 'prepared.json', manifest)
        record.outcome = 'passed'
        record.note = '外部驱动编译通过；没有启动 AIR，无原生、组件或性能通过结论'
    return manifest


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--components-only', action='store_true', help='Compile no native drivers')
    ap.add_argument('--entries', nargs='+', choices=tuple(ENTRIES), help='Freeze only these native entries')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    source = (ROOT / args.source).resolve()
    out = (ROOT / args.output).resolve()
    assert source.is_relative_to(ROOT) and source.name == 'src'
    assert out.parent == (ROOT / 'build/m52').resolve() and not source.is_relative_to(out)
    if out.exists():
        assert args.build, 'Existing output is immutable except its first pending build'
        manifest = verify(out, source)
    else:
        manifest = freeze(source, out, args.components_only, args.entries)
    if args.build:
        manifest = build(source, out, args.registry_wait)
    print(json.dumps(dict(output=str(out), compiled=manifest['compiled'], native_drivers=len(manifest['entries']),
                          components=len(manifest['components']), candidate_sha256=manifest['candidate_sha256'],
                          air_started=False), ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
