"""Install only the tested F14A mod, with a unique backup and hash-guarded rollback."""
from pathlib import Path
import argparse, json, os, re, shutil, uuid
from build import RC, GAME, inventory, sha, save

OLD = '2c49dfd05d524085ea43fb8ffa537d1a9359febd52fb13d6a19faae6e2563621'
NEW = 'f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb'
parser = argparse.ArgumentParser()
parser.add_argument('--player-run', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[0-9a-f]{10}', args.player_run)
folder = RC / 'build/m52/a-stutter-repair-02'
candidate = folder / 'RConnectMod.swf'
target = RC / 'release/RConnectMod.swf'
meta = json.loads((folder / 'compile.json').read_text('utf8'))
audit = json.loads((folder / 'class-audit-recheck.json').read_text('utf8'))
assert meta['compiled'] and sha(candidate) == meta['candidate_sha256'] == NEW
assert inventory(folder / 'src') == meta['source']
assert audit['passed'] and audit['candidate_sha256'] == NEW and audit['classes'] == 81
assert sha(target) == OLD, 'Installed mod changed concurrently'
evidence = {}
for run in ['9655519e55', args.player_run]:
    root = RC / 'build/cooperation' / run
    result = json.loads((root / 'result.json').read_text('utf8'))
    inputs = json.loads((root / 'input.json').read_text('utf8'))
    assert result['passed'] and result['installation_unchanged'] and inputs['candidate_sha256'] == NEW
    evidence[run] = {'result_sha256': sha(root / 'result.json'), 'input_sha256': sha(root / 'input.json')}
    for role in ['host', 'join']:
        data = json.loads((root / 'logs' / role / 'stutter-result.json').read_text('utf8'))
        assert data['completed'] and not data['error'] and data['audioVolume'] == 0
        if run == '9655519e55':
            if role == 'host': assert len(data['blasts']) == 7 and data['invisibleBirths'] == 56
            else:
                final = [p for p in data['wire'] if p['stream'] == 'units' and p['age'] > 25000]
                assert final and all(p['nullFlights'] == 0 for p in final)
        else:
            phases = {p['name']: p for p in data['phases']}
            motion = {}
            # Qualify actual movement during BOTH sustained-fire windows.
            # The earlier driver02 'input' window overlapped native resurrection;
            # retain that failure, and do not use it as movement/FPS evidence.
            for name in ['both-lmg', 'both-plamg']:
                assert len(phases[name]['births']) >= 50
                assert any(not c['native'] for r in phases[name]['rows'] for c in r['clips'])
                xs = [r['local']['x'] for r in phases[name]['rows']]
                ys = [r['local']['y'] for r in phases[name]['rows']]
                assert max(xs) - min(xs) > 30 and max(ys) - min(ys) > 30
                assert all(r['local'].get('anim') != 'res' and r['local'].get('work') != 'res'
                           for r in phases[name]['rows'])
                motion[name] = dict(x_range=max(xs)-min(xs), y_range=max(ys)-min(ys),
                                    native_shots=len(phases[name]['births']))
            evidence[run][role] = dict(movement_during_fire=motion,
                samples_sha256=sha(root / 'logs' / role / 'stutter-result.json'),
                excludes_early_input_window=True)
out = RC / 'build/m52' / ('a-stutter-deploy-' + uuid.uuid4().hex[:8])
out.mkdir()
backup = out / 'RConnectMod.before.swf'
shutil.copy2(target, backup)
assert sha(backup) == OLD
untouched = [GAME / 'pfe.swf', GAME / 'application.xml', RC / 'release/config.txt']
before = {str(p): sha(p) for p in untouched}
receipt = dict(status='prepared', previous_sha256=OLD, candidate_sha256=NEW,
               source_directory=str(folder / 'src'), backup=str(backup), evidence=evidence,
               untouched_before=before, version='0.2.24-animfix2',
               scope='Ended invisible record cleanup and full-history reuse; no general FPS or complete stutter claim')
save(out / 'deployment.json', receipt)
pending = target.parent / ('.RConnectMod-' + out.name + '.pending')
assert not pending.exists()
try:
    shutil.copy2(candidate, pending)
    assert sha(pending) == NEW and sha(target) == OLD
    os.replace(pending, target)
    assert sha(target) == NEW
    receipt['untouched_after'] = {str(p): sha(p) for p in untouched}
    assert receipt['untouched_after'] == before
    receipt['status'] = 'verified'
except BaseException as error:
    receipt['error'] = repr(error)
    receipt['status'] = 'failed'
    rollback_pending = target.parent / ('.RConnectMod-' + out.name + '.rollback')
    try:
        if target.exists() and sha(target) == NEW:
            assert not rollback_pending.exists()
            shutil.copy2(backup, rollback_pending)
            assert sha(rollback_pending) == OLD and sha(target) == NEW
            os.replace(rollback_pending, target)
            receipt['rollback_verified'] = sha(target) == OLD
    except BaseException as rollback_error:
        receipt['rollback_error'] = repr(rollback_error)
    raise
finally:
    for temporary in [pending, target.parent / ('.RConnectMod-' + out.name + '.rollback')]:
        try:
            if temporary.exists(): temporary.unlink()
        except OSError as cleanup_error:
            receipt.setdefault('cleanup_errors', []).append(repr(cleanup_error))
    receipt['installed_sha256'] = sha(target)
    save(out / 'deployment.json', receipt)
print(json.dumps({'directory': str(out), 'status': receipt['status'], 'installed_sha256': receipt['installed_sha256']}))
