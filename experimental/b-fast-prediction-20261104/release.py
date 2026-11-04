"""B-only deployment of the exact tested fast1 body.

Target: build/ab/b3-playable-190 (the B player package reached by the B
launchers). The A body in release/, the game SWFs, configuration, saves and any
running process are never touched. The candidate is copied byte-for-byte; the
manual and validation manifests are rebound to the new body; a full before/after
receipt with rollback instructions is written.

Run only after the functional gate referenced in tests[] has passed on these
exact bytes.
"""
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PLAYABLE = ROOT / 'build/ab/b3-playable-190'
GAME = PLAYABLE / 'game'
RC_REL = 'mods/RConnect/release/RConnectMod.swf'
RC = GAME / RC_REL
MANUAL = PLAYABLE / 'manual-input.json'
VALIDATION = PLAYABLE / 'playable-validation.json'
BEFORE = HERE / 'before'
CANDIDATE = ROOT / 'build/ab/b-fast1-03'
VERSION = 'B3-0.1-fast1'

BEFORE_RC = '3b58198e6e11ef32cf12f6499b75d7a4497788cb668680aa637057b30311644c'
BEFORE_MANUAL = 'b5bb40e9cdcd267591c8c5a431835fec67433971d1fe84cd8d098943e2fa1de0'
BEFORE_VALIDATION = '824b379e36a8a9c4c0bc3c5856a55ac052402b5e8e7b0bccfc6f2cd6c53647da'

A_WITNESS = ROOT / 'release/RConnectMod.swf'
A_WITNESS_SHA = '8ab94c8b11e642d55df11dd94490259bcbf47619eeb52a63f6e181aefee94ea8'

TESTS = []          # filled from the accepted result receipts below
PERFORMANCE = []    # must stay empty unless a comparable ABAB pair was accepted

FUNCTIONAL_EVIDENCE = [
    # (scenario, result path relative to mods/RConnect)
    ('textmotion', 'build/ab/b-fast1-test-textmotion-08/result.json'),
]


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    tmp = Path(str(path) + '.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(tmp, path)


def witness():
    game_root = ROOT.parents[1]
    out = {}
    for rel in ('pfe.swf', 'DLC/pfe.swf', 'DLC/pfeUI.swf', 'application.xml'):
        p = game_root / rel
        out[rel] = sha(p) if p.is_file() else None
    out['mods/RConnect/release/RConnectMod.swf'] = sha(A_WITNESS)
    return out


def accepted_results():
    """Only receipts whose byte identity and pass state match this candidate."""
    build = read(CANDIDATE / 'build-input.json')
    candidate = sha(CANDIDATE / 'RConnectMod.swf')
    out = []
    result_root = ROOT / 'build/ab'
    for scenario, path in FUNCTIONAL_EVIDENCE:
        if path is None:
            continue
        receipt = read(ROOT / path)
        if receipt.get('candidate_sha256') != candidate:
            raise SystemExit('Evidence for ' + scenario + ' is not this candidate')
        if not receipt.get('passed') or not receipt.get('complete') or not receipt.get('runtime_unchanged'):
            raise SystemExit('Evidence for ' + scenario + ' did not pass: ' + path)
        roles = {k: v.get('failed') for k, v in (receipt.get('roles') or {}).items()}
        if any(v != 0 for v in roles.values()):
            raise SystemExit('Evidence for ' + scenario + ' has failures: ' + path)
        out.append({'scenario': scenario, 'path': path,
                    'sha256': sha(ROOT / path),
                    'checks': {k: v.get('passed') for k, v in (receipt.get('roles') or {}).items()}})
    out.sort(key=lambda r: str(r['path']))
    return out, build


def main():
    if (HERE / 'deployment.json').exists():
        raise SystemExit('Transaction already completed')
    if not (CANDIDATE / 'RConnectMod.swf').is_file():
        raise SystemExit('Candidate missing')
    build = read(CANDIDATE / 'build-input.json')
    candidate_sha = sha(CANDIDATE / 'RConnectMod.swf')
    if candidate_sha != build['candidate_sha256']:
        raise SystemExit('Candidate SWF differs from its build input')
    if sha(RC) != BEFORE_RC:
        raise SystemExit('B body changed since inspection: ' + sha(RC))
    if sha(MANUAL) != BEFORE_MANUAL:
        raise SystemExit('manual-input changed since inspection: ' + sha(MANUAL))
    if sha(VALIDATION) != BEFORE_VALIDATION:
        raise SystemExit('validation changed since inspection: ' + sha(VALIDATION))
    if sha(A_WITNESS) != A_WITNESS_SHA:
        raise SystemExit('A witness differs')

    tests, build = accepted_results()
    if not tests:
        raise SystemExit('No accepted functional evidence bound to this candidate')

    before_witness = witness()
    # A previous attempt may have stopped after writing the backups but before
    # touching the package. Reuse them only when they are the expected baseline.
    if BEFORE.exists():
        expected = {'RConnectMod.swf': BEFORE_RC, 'manual-input.json': BEFORE_MANUAL,
                    'playable-validation.json': BEFORE_VALIDATION}
        have = {p.name: sha(p) for p in BEFORE.iterdir() if p.is_file()}
        if have != expected:
            raise SystemExit('Existing before/ is not the expected baseline: ' + str(have))
    else:
        BEFORE.mkdir(parents=True, exist_ok=False)
        for src, name in ((RC, 'RConnectMod.swf'), (MANUAL, 'manual-input.json'),
                          (VALIDATION, 'playable-validation.json')):
            shutil.copy2(src, BEFORE / name)
    if (sha(BEFORE / 'RConnectMod.swf') != BEFORE_RC or sha(BEFORE / 'manual-input.json') != BEFORE_MANUAL
            or sha(BEFORE / 'playable-validation.json') != BEFORE_VALIDATION):
        raise SystemExit('Backup mismatch')

    manual = read(MANUAL)
    manual['source_id'] = build['source_id']
    manual['candidate_sha256'] = candidate_sha
    manual['candidate_manifest_sha256'] = sha(CANDIDATE / 'build-input.json')
    manual['parent_manifest'] = {'path': (BEFORE / 'manual-input.json').relative_to(ROOT).as_posix(),
                                 'sha256': BEFORE_MANUAL}
    manual['script_sha256'] = sha(__file__)
    manual['files'][RC_REL] = candidate_sha
    manual['environment_body_override'] = {'path': 'game/' + RC_REL, 'sha256': candidate_sha}

    validation = read(VALIDATION)
    validation['candidate_sha256'] = candidate_sha
    validation['source_id'] = build['source_id']
    validation['field_tests'] = [{'scenario': t['scenario'], 'path': t['path'], 'sha256': t['sha256'],
                                  'checks': t['checks']} for t in tests]
    validation['limitations'] = [
        'Existing windows must be restarted.',
        'Stage intervals are not input-to-display latency; dense combat may still stutter.',
        'Playback-clock and receive-burst shaping are validated by the published contract checks and one functional scenario only.',
        'No comparable ABAB performance pair was accepted for this body in this environment.',
    ]

    tmp_swf = RC.with_name(RC.name + '.fast1.tmp')
    tmp_manual = MANUAL.with_name(MANUAL.name + '.fast1.tmp')
    tmp_validation = VALIDATION.with_name(VALIDATION.name + '.fast1.tmp')
    try:
        shutil.copy2(CANDIDATE / 'RConnectMod.swf', tmp_swf)
        if sha(tmp_swf) != candidate_sha:
            raise SystemExit('Copied candidate mismatch')
        save(tmp_manual, manual)
        validation['manual_manifest_sha256'] = sha(tmp_manual)
        save(tmp_validation, validation)
        os.replace(tmp_swf, RC)
        os.replace(tmp_manual, MANUAL)
        os.replace(tmp_validation, VALIDATION)
        if sha(RC) != candidate_sha:
            raise SystemExit('Installed body readback mismatch')
        installed = read(MANUAL)
        if installed['candidate_sha256'] != candidate_sha or installed['files'][RC_REL] != candidate_sha:
            raise SystemExit('Installed manual mismatch')
        if read(VALIDATION)['manual_manifest_sha256'] != sha(MANUAL):
            raise SystemExit('Installed validation/manual mismatch')
        after_witness = witness()
        if after_witness != before_witness:
            raise SystemExit('Root/A witness changed')
        receipt = {
            'schema': 'b-fast1-deployment-1',
            'status': 'verified',
            'installed': True,
            'experimental_only': True,
            'build': {'path': CANDIDATE.relative_to(ROOT).as_posix(), 'version': VERSION,
                      'candidate_sha256': candidate_sha, 'source_id': build['source_id'],
                      'manifest_sha256': sha(CANDIDATE / 'build-input.json')},
            'before': {'game/' + RC_REL: BEFORE_RC, 'manual-input.json': BEFORE_MANUAL,
                       'playable-validation.json': BEFORE_VALIDATION,
                       'backup': BEFORE.relative_to(ROOT).as_posix()},
            'after': {'game/' + RC_REL: sha(RC), 'manual-input.json': sha(MANUAL),
                      'playable-validation.json': sha(VALIDATION)},
            'parent_manifest': manual['parent_manifest'],
            'witnesses': {'before': before_witness, 'after': after_witness},
            'tests': tests,
            'performance': PERFORMANCE,
            'known_limits': [
                'Version string is B3-0.1-fast1; both sides must run this exact body because the greeting pins the source hash.',
                'Changes are playback shaping (smooth post-stall catch-up, backlog cap at 4+), a wider bounded prediction lead inside the unchanged 150 ms hold window, and two dead-cost removals.',
                'The 150 ms prediction hold boundary is a published contract; it was not changed.',
                'Host capture of full-room tiles and per-unit native fields is unchanged: dense host frame time is still dominated by capture/publish.',
                'No end-to-end input-to-display latency fixture exists yet; no ABAB performance pair was accepted here.',
            ],
            'rollback': 'restore before/RConnectMod.swf, before/manual-input.json and before/playable-validation.json, verify hashes',
        }
        save(HERE / 'deployment.json', receipt)
        print(json.dumps({'status': 'verified', 'candidate': candidate_sha, 'manual': sha(MANUAL),
                          'validation': sha(VALIDATION)}, ensure_ascii=False))
    finally:
        for p in (tmp_swf, tmp_manual, tmp_validation):
            if p.exists():
                try:
                    p.unlink()
                except OSError:
                    pass


if __name__ == '__main__':
    main()
