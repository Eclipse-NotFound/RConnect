"""Summarize preserved peer-projectile logs, including controller faults."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('run', type=Path)
    args = ap.parse_args()
    run = (ROOT/args.run).resolve()
    assert run.is_relative_to(ROOT/'build/cooperation')
    result = dict(run=str(run), roles={})
    for role in ('host', 'join'):
        path = run/(role+'.log')
        text = path.read_text('utf-8-sig', errors='replace')
        rows = text.splitlines()
        failures = [s for s in rows if 'COOP FAIL' in s or 'RConnectProjectileGrip: failed' in s
                    or 'game error dialog' in s or 'uncaught' in s.lower()]
        samples = [json.loads(s.split('PROJECTILE GRIP RESULT ', 1)[1])
                   for s in rows if 'PROJECTILE GRIP RESULT ' in s]
        result['roles'][role] = dict(log_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            passes=sum('COOP PASS' in s for s in rows), failures=failures,
            complete='COOP EFFECTS DONE projectile-grip '+role in text, samples=samples)
    result['passed'] = all(r['complete'] and r['samples'] and not r['failures']
                           for r in result['roles'].values())
    (run/'peer-projectile-summary.json').write_text(json.dumps(result, indent=2), 'utf-8')
    print(json.dumps(dict(run=run.name, passed=result['passed'], roles={role:dict(
        passes=r['passes'], failures=len(r['failures']), samples=len(r['samples']), complete=r['complete'])
        for role, r in result['roles'].items()}), indent=2))


if __name__ == '__main__':
    main()
