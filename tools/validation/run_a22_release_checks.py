"""Serial, exact-combination A22 checks; stop at the first failed run."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ('throw', 'A22ThrowTimingTestDoc', 'rbl', 240),
    ('saved-grip', 'A22SavedGripStressTestDoc', 'rbl', 360),
    ('cadence', 'A22CadenceTestDoc', 'rbl', 180),
    ('impact-life', 'A22ImpactLifetimeTestDoc', 'rbl', 180),
    ('plasma', 'A22PlasmaTestDoc', 'rbl', 360),
    ('energy', 'A22EnergyRegressionTestDoc', 'rbl', 360),
    ('wall', 'A22WallTestDoc', 'rbl', 360),
    ('animation', 'A22AnimationTestDoc', 'rbl', 240),
    ('behavior', 'A22BehaviorTestDoc', 'rbl', 240),
    ('room', 'A22RoomTestDoc', 'random_mane', 600),
    ('hidden', 'HiddenRoomFollowTestDoc', 'random_mane', 600),
    ('respawn', 'RespawnRoomTestDoc', 'random_mane', 600),
    ('smart', 'A22SmartPeerTestDoc', 'rbl', 240),
    ('map', 'NativeMapGenerationTestDoc', 'rbl', 600),
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--candidate', required=True)
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--msw', required=True)
    ap.add_argument('--version', required=True)
    ap.add_argument('--cases', help='Comma-separated subset; no automatic retries')
    ap.add_argument('--prefix', default='release')
    args = ap.parse_args()
    selected = set(args.cases.split(',')) if args.cases else {r[0] for r in CASES}
    assert selected <= {r[0] for r in CASES}
    for name, entry, land, seconds in CASES:
        if name not in selected:
            continue
        cmd = [sys.executable, '-B', '-X', 'utf8', str(ROOT/'tools/validation/run_a22_map_refresh.py'),
               'candidate', '--candidate', args.candidate, '--bundle', args.bundle,
               '--entry', entry, '--label', args.prefix+'-'+name, '--land', land,
               '--seconds', str(seconds), '--expected-version', args.version,
               '--msw-candidate', args.msw]
        if name == 'saved-grip':
            saved = ROOT/'build/m52/littlepip-save-replay-01'
            cmd += ['--host-save-template', str(saved/'host/PFEgame0.sol'),
                    '--join-save-template', str(saved/'join/PFEgame0.sol'), '--connect-after-load']
        print('START '+name, flush=True)
        result = subprocess.run(cmd, cwd=ROOT)
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
