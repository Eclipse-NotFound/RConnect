import json, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
PROFILE = os.path.join(BASE, '..', '..', 'build', 'ab', 'b-smooth-profile-03')

for d in ['01-A', '02-B', '03-A', '04-B']:
    for role in ['host', 'join']:
        p = os.path.join(PROFILE, d, role, 'ABBench.log')
        if not os.path.exists(p):
            continue
        for line in open(p, encoding='utf-8', errors='replace'):
            line = line.strip()
            if not line.startswith('{'):
                continue
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get('kind') != 'result':
                continue
            data = o.get('data') or {}
            t = data.get('timings')
            if not t:
                continue
            print('###', d, role, 'enemies', data.get('expectedEnemies'),
                  'phase', data.get('phase'), 'frames', data.get('frames'),
                  'elapsed', data.get('elapsed'))
            for k, v in sorted(t.items(), key=lambda kv: -kv[1].get('meanMs', 0)):
                print(f"  {k:30s} n={v['n']:6d} mean={v['meanMs']:8.3f} p50={v['p50Ms']:4d} p95={v['p95Ms']:4d} max={v['maxMs']:4d}")
            print()
