"""Copy explicit real-class components only. No compiler, AIR or runtime writes."""
from pathlib import Path
import argparse
import hashlib
import json

HERE = Path(__file__).resolve().parent
PORT = HERE.parent
ROOT = PORT.parents[1]
CURRENT = ROOT / 'build/m52/recovery-room-production-05/src'
READY = ROOT / 'experimental/recovery-room-ready-once/component'
EARLY = ROOT / 'experimental/recovery-early-travel/components'
EXIT = ROOT / 'experimental/recovery-early-exit-authorization'
WALL = ROOT / 'experimental/recovery-wall-working-set/components'
MANIFEST = HERE / 'inputs.json'
EXCLUDED = ('NativeTravelPlan', 'FirstRasterGate', 'SeedRasterEntry')
OVERLAY = ('rconnect/core/RoomSync.as', 'rconnect/core/EarlyTravelGate.as')
FIXTURES = (
    'RConnectMod.as', 'modlocales/connect/RCLocale.as',
    'rconnect/core/Session.as', 'rconnect/core/MapGeneration.as',
    'rconnect/core/Log.as', 'rconnect/core/TravelGuard.as',
    'rconnect/core/TravelPlacement.as', 'rconnect/game/GameBridge.as',
    'rconnect/net/TcpLink.as',
)
CURRENT_CLASSES = ('rconnect/net/RoomCodec.as', 'rconnect/net/Protocol.as',
                   'rconnect/ui/RoomEntryView.as')
ENTRIES = {
    'crossing': READY / 'RoomCrossingChecks.as',
    'room': EARLY / 'room/EarlyTravelRoomChecks.as',
    'guard': EXIT / 'tests/EarlyExitAuthorizationChecks.as',
    'gate': EARLY / 'gate/EarlyTravelGateChecks.as',
}
ADDED_ENTRIES = {'room': 'EarlyTravelPortChecks.as', 'wall': 'WallFirstRasterChecks.as'}
GROUPS = ('crossing', 'room', 'guard', 'gate', 'wall')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def selection():
    files = {}
    for group in ('crossing', 'room', 'guard'):
        for name in FIXTURES:
            files[f'{group}/{name}'] = READY / name
        for name in CURRENT_CLASSES:
            files[f'{group}/{name}'] = CURRENT / name
        for name in OVERLAY:
            files[f'{group}/{name}'] = PORT / 'src' / name
    files['guard/rconnect/core/TravelGuard.as'] = CURRENT / 'rconnect/core/TravelGuard.as'
    files['guard/fe/inter/RConnectTravelAccess.as'] = EXIT / 'components/guard-fixed/fe/inter/RConnectTravelAccess.as'
    files['gate/rconnect/core/EarlyTravelGate.as'] = PORT / 'src/rconnect/core/EarlyTravelGate.as'
    for group, source in ENTRIES.items():
        files[f'{group}/{source.name}'] = source
    for group, name in ADDED_ENTRIES.items():
        files[f'{group}/{name}'] = HERE / 'tests' / name
    files['room/DecliningTravelGameBridge.as'] = HERE / 'tests/DecliningTravelGameBridge.as'
    files['wall/rconnect/game/WallImpactVisuals.as'] = PORT / 'src/rconnect/game/WallImpactVisuals.as'
    files['wall/rconnect/net/RoomCodec.as'] = CURRENT / 'rconnect/net/RoomCodec.as'
    for name in ('rconnect/game/GameBridge.as', 'rconnect/core/Log.as', 'fe/weapon/Bullet.as'):
        files[f'wall/{name}'] = WALL / name
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Read-only verification of prepared files and their exact inputs')
    args = parser.parse_args()
    sources = selection()
    # Validate every class in the parent's manifest before copying any source.
    port_meta = read_json(PORT / 'manifest.json')
    for name, wanted in port_meta['sources'].items():
        assert digest((PORT / 'src' / name).read_bytes()) == wanted, ('parent source changed', name)
    frozen = {str(p): p.read_bytes() for p in set(sources.values())}
    outputs = {name: digest(frozen[str(source)]) for name, source in sources.items()}
    assert all(not any(token in name for token in EXCLUDED) for name in outputs)
    actual = {p.relative_to(HERE).as_posix(): digest(p.read_bytes())
              for group in GROUPS for p in (HERE / group).rglob('*.as')}
    meta = {
        'kind': 'first-raster-current-real-class-components',
        'compiled': False, 'air_started': False, 'native_runtime': False,
        'performance_qualified': False,
        'generator_sha256': digest(Path(__file__).read_bytes()),
        'port_manifest_sha256': digest((PORT / 'manifest.json').read_bytes()),
        'inputs': {p: digest(data) for p, data in sorted(frozen.items())},
        'outputs': outputs,
        'entries': {group: source.name for group, source in ENTRIES.items()},
        'unchanged_test_entries': True,
        'added_entries': ADDED_ENTRIES,
        'expected_complete_assertions': {'RoomCrossingChecks': 92, 'EarlyTravelRoomChecks': 36,
                                        'EarlyExitAuthorizationChecks': 79, 'EarlyTravelGateChecks': 20,
                                        'EarlyTravelPortChecks': 12, 'WallFirstRasterChecks': 12},
        'excluded_classes': list(EXCLUDED),
        'not_exercised_real_classes': ['MapGeneration', 'Session', 'GameBridge'],
    }
    if args.check:
        assert read_json(MANIFEST) == meta, 'Prepared metadata/input changed; refresh explicitly'
        assert actual == outputs, 'Missing, modified or unexpected component source'
    else:
        if MANIFEST.exists():
            assert actual == read_json(MANIFEST)['outputs'], 'Existing component edits must not be overwritten'
        else:
            assert not actual, 'Unregistered component source already exists'
        assert all(Path(p).read_bytes() == data for p, data in frozen.items()), 'Input changed while preparing'
        for name, source in sources.items():
            dest = HERE / name
            assert HERE in dest.resolve().parents, 'Output escaped components directory'
            dest.parent.mkdir(parents=True, exist_ok=True)
            # Leave unrelated groups, including any currently running wall
            # fixture, untouched when their accurate bytes already match.
            if not dest.exists() or dest.read_bytes() != frozen[str(source)]:
                dest.write_bytes(frozen[str(source)])
        MANIFEST.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'checked_only': args.check, 'source_files': len(outputs),
                      'groups': list(GROUPS), 'compiled': False, 'air_started': False}))


if __name__ == '__main__':
    main()
