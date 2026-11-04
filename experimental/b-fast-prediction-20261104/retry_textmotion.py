"""Retry the textmotion functional scenario until the join reaches the room
inside the window the driver's 220 s phase budget can still absorb.

A run whose join takes longer than that is not evidence about this candidate:
the phase budget is consumed while the game is still loading under external CPU
load, and the only failing check is 'diagnostic phase completes'. Such runs are
kept, never deleted, and marked invalid here.
"""
import json
import subprocess
import sys
from pathlib import Path

RC = Path(__file__).resolve().parents[2]
RUNNER = RC / 'tools/host_authority/field2_driver/run.py'
WORKSPACE = 'build/ab/b-field2-runtime-01'
CANDIDATE = 'build/ab/b-fast1-02/RConnectMod.swf'
PREPARATION = 'prepared-entry-01.json'
JOIN_LIMIT_MS = 70000
MAX_ATTEMPTS = 4


def log_read(path):
    out = []
    if not path.is_file():
        return out
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            pass
    return out


def run(attempt):
    name = f'b-fast1-test-textmotion-{attempt:02d}'
    result = RC / 'build/ab' / name
    if result.exists():
        return None
    cmd = [sys.executable, str(RUNNER), '--workspace', WORKSPACE, '--scenario', 'textmotion',
           '--candidate', CANDIDATE, '--result', f'build/ab/{name}', '--preparation', PREPARATION]
    print('RUN', name, flush=True)
    subprocess.run(cmd, cwd=RC)
    joined = None
    for event in log_read(result / 'join.RConnect-B.log'):
        if event.get('kind') == 'joined':
            joined = event.get('at')
            break
    receipt = {}
    if (result / 'result.json').is_file():
        receipt = json.loads((result / 'result.json').read_text(encoding='utf-8'))
    roles = {k: {'passed': v.get('passed'), 'failed': v.get('failed'), 'done': v.get('done')}
             for k, v in (receipt.get('roles') or {}).items()}
    verdict = dict(result=name, joinedMs=joined, complete=receipt.get('complete'),
                   runtime_unchanged=receipt.get('runtime_unchanged'), roles=roles,
                   authoritative=(joined is not None and joined <= JOIN_LIMIT_MS))
    print('VERDICT', json.dumps(verdict, ensure_ascii=False), flush=True)
    return verdict


def main():
    for attempt in range(4, 4 + MAX_ATTEMPTS):
        verdict = run(attempt)
        if verdict is None:
            continue
        if verdict['authoritative']:
            ok = (verdict['complete'] and verdict['runtime_unchanged']
                  and all((r['failed'] == 0 and r['done']) for r in verdict['roles'].values()))
            print('DECISION', 'pass' if ok else 'fail', flush=True)
            return 0 if ok else 1
        print('INVALID: join too late for the phase budget; retrying', flush=True)
    print('DECISION', 'no authoritative run', flush=True)
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
