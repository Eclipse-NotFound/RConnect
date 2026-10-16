"""Serial A motion / telekinesis compatibility qualification; no retries."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ('terrain', 'TerrainComparisonTestDoc', 'rbl', 240, False),
    ('throw', 'A22ThrowCollisionTestDoc', 'rbl', 480, True),
    ('saved-grip', 'A22SavedGripStressTestDoc', 'rbl', 360, True),
    ('timeline', 'A22EnemyTimelineTestDoc', 'random_mane', 240, False),
    ('late-pause', 'A22LatePausePacketTestDoc', 'random_mane', 300, False),
    ('pause-timing', 'A22PauseTimingTestDoc', 'random_mane', 300, False),
    ('pause-repaint', 'A22PauseRepaintTestDoc', 'random_mane', 300, False),
    ('targets', 'TargetLifecycleTestDoc', 'random_mane', 300, False),
    ('continuity', 'PresentationContinuityTestDoc', 'random_mane', 300, False),
    ('animation', 'A22AnimationTestDoc', 'rbl', 240, False),
    ('behavior', 'A22BehaviorTestDoc', 'rbl', 240, False),
    ('room', 'A22RoomTestDoc', 'random_mane', 600, False),
    ('respawn', 'RespawnRoomTestDoc', 'random_mane', 600, False),
    ('pause', 'CoopPauseTestDoc', 'random_mane', 420, False),
    ('density', 'ProjectileLoadTestDoc', 'random_mane', 420, False),
    ('vision-api', 'VisionApiTestDoc', 'random_mane', 240, False),
    ('hud', 'HudTestDoc', 'random_mane', 300, False),
    ('navigation', 'TeammateNavigationTestDoc', 'random_mane', 480, False),
    ('codec', 'PacketCodecTestDoc', 'random_mane', 240, False),
    ('weapon-batch', 'WeaponBatchTestDoc', 'random_mane', 240, False),
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--fa', help='Optional validated FA override; default uses the frozen installed version')
    parser.add_argument('--rv', help='Optional validated RV wall comparison candidate')
    parser.add_argument('--wb', help='Optional validated WallBlend comparison candidate')
    parser.add_argument('--cases')
    parser.add_argument('--prefix', required=True)
    args = parser.parse_args()
    selected = set(args.cases.split(',')) if args.cases else {r[0] for r in CASES}
    assert selected <= {r[0] for r in CASES}
    manifest = json.loads((ROOT/args.candidate/'prepared.json').read_text(encoding='utf-8'))
    for name, entry, land, seconds, copied_save in CASES:
        if name not in selected:
            continue
        command = [sys.executable, '-B', '-X', 'utf8', str(ROOT/'tools/validation/run_a22_map_refresh.py'),
                   'candidate', '--candidate', args.candidate, '--bundle', args.bundle,
                   '--entry', entry, '--label', args.prefix+'-'+name, '--land', land,
                   '--seconds', str(seconds), '--expected-version', manifest['version']]
        if args.fa:
            command += ['--fa-candidate', args.fa]
        if args.rv:
            command += ['--vision-candidate', args.rv]
        if args.wb:
            command += ['--wallblend-candidate', args.wb]
        if copied_save:
            saved = ROOT/'build/m52/littlepip-save-replay-01'
            command += ['--host-save-template', str(saved/'host/PFEgame0.sol'),
                        '--join-save-template', str(saved/'join/PFEgame0.sol'), '--connect-after-load']
        print('START '+name, flush=True)
        result = subprocess.run(command, cwd=ROOT)
        if result.returncode:
            raise SystemExit(result.returncode)
        path = ROOT/args.candidate/(args.prefix+'-'+name+'-result.json')
        receipt = json.loads(path.read_text(encoding='utf-8'))
        assert receipt['exit'] == 0 and not receipt['installation_changes']
        assert all(receipt[r]['done'] and receipt[r]['passed'] > 0 and receipt[r]['failed'] == 0
                   for r in ('host', 'join'))
        print('FINISHED '+name, flush=True)

if __name__ == '__main__':
    main()
