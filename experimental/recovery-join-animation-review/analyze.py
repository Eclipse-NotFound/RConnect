"""Read frozen inputs; write only this review's compact evidence file. No runtime."""
from pathlib import Path
import collections
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def profile(run):
    path = ROOT / 'build/cooperation' / run / 'join.log'
    objects = [json.loads(line[line.index('{'):])
               for line in path.read_text(encoding='utf-8-sig').splitlines()
               if '"stacks"' in line]
    stacks = collections.Counter()
    phases = {}

    def visit(value):
        if isinstance(value, dict):
            if isinstance(value.get('stacks'), dict):
                stacks.update(value['stacks'])
                phases.setdefault(value['phase'], collections.Counter()).update(value['stacks'])
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    for value in objects:
        visit(value)
    filters = ['tickFrozenAnims', 'UnitPresentation/tick', 'UnitPresentation/play',
               'UnitPresentation/apply', 'UnitPresentation/animateBody',
               'RemoteMotion/sample', 'MirrorMasks', 'MirrorHitUnit/syncMotion',
               'RConnectAnimationAccess', 'RealisticVisionMod/applyMask',
               'RealisticVisionMod/hideEnemies']
    return dict(run=run, log_sha256=sha(path), cpu_samples=sum(stacks.values()),
                counts_are_inclusive_not_call_counts=True,
                paths={key:dict(samples=sum(n for s, n in stacks.items() if key in s),
                               phases={p:sum(n for s, n in rows.items() if key in s)
                                       for p, rows in phases.items()}) for key in filters},
                play_via_tick=sum(n for s, n in stacks.items()
                                  if 'UnitPresentation/play' in s and 'UnitPresentation/tick' in s),
                play_via_apply=sum(n for s, n in stacks.items()
                                   if 'UnitPresentation/play' in s and 'UnitPresentation/apply' in s),
                recursive_tick_samples=sum(n for s, n in stacks.items() if s.count('tickFrozenAnims') > 1),
                play_stacks=sorted([(s, n) for s, n in stacks.items() if 'UnitPresentation/play' in s],
                                   key=lambda row:-row[1])[:8])


def main():
    paths = ['rconnect/game/GameBridge.as', 'rconnect/game/UnitPresentation.as',
             'rconnect/game/MirrorMasks.as', 'rconnect/game/MirrorHitUnit.as',
             'rconnect/game/RemoteMotion.as', 'rconnect/game/WeaponDisplay.as',
             'fe/unit/RConnectAnimationAccess.as']
    sources = {}
    for name in paths:
        a = ROOT / 'build/m52/recovery-13/src' / name
        b = ROOT / 'build/m52/recovery-14/src' / name
        sources[name] = dict(sha256=sha(b), same_in_13=a.read_bytes() == b.read_bytes())
        assert sources[name]['same_in_13']
    rv = ROOT.parent / 'RealisticVision/build/regression-recovery-output/production-singlepass'
    manifest = json.loads((rv / 'manifest.json').read_text(encoding='utf-8'))
    assert all(sha(rv / 'src' / p) == h for p, h in manifest['sources'].items())
    assert sha(rv / 'RealisticVisionMod.swf') == manifest['swf']
    for run in ['3b8269a9a7', 'a6a7e27789']:
        assert manifest['swf'] in (ROOT / 'build/cooperation' / run / 'run.json').read_text(encoding='utf-8')
    output = dict(read_only_review=True, diagnostic_only=True, performance_qualified=False,
                  profiles=[profile('3b8269a9a7'), profile('a6a7e27789')],
                  exact_sources=sources,
                  rv_frozen_source=str(rv / 'src'), rv_swf_sha256=manifest['swf'],
                  rv_manifest_sha256=sha(rv / 'manifest.json'), rv_sources_verified=True,
                  native_weapon_reference=dict(
                      path='game-reference/decompiled/1.02/src102/scripts/fe/weapon/Weapon.as',
                      sha256=sha(ROOT.parents[1] / 'game-reference/decompiled/1.02/src102/scripts/fe/weapon/Weapon.as'),
                      is_current_installed_method_byte_audit=False))
    (HERE / 'evidence.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(profiles=[p['run'] for p in output['profiles']],
                          source_pairs=len(sources), rv_sources_verified=True)))


if __name__ == '__main__':
    main()
