import json, os, statistics as st

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'ab')
runs = [
    ('profile-03/04-B', 'b-smooth-profile-03/04-B'),
    ('clean-05/04-B', 'b-smooth-clean-05/04-B'),
    ('clean-05/02-B', 'b-smooth-clean-05/02-B'),
    ('clean-05/01-A', 'b-smooth-clean-05/01-A'),
]
for label, rel in runs:
    for role in ['host', 'join']:
        p = os.path.join(BASE, rel, role, 'ABBench.log')
        if not os.path.exists(p):
            continue
        print('##', label, role)
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
            d = o.get('data') or {}
            iv = d.get('intervals') or []
            if not iv:
                continue
            iv = sorted(iv)
            n = len(iv)
            def pct(q):
                return iv[min(n - 1, int(n * q))]
            over = {t: sum(1 for x in iv if x >= t) for t in (34, 50, 67, 100, 150, 200)}
            print(f"  phase={d.get('phase')} enemies={d.get('expectedEnemies')} n={n} "
                  f"mean={sum(iv)/n:.2f} p50={pct(.5)} p90={pct(.9)} p95={pct(.95)} p99={pct(.99)} max={iv[-1]}")
            print('   >=34/50/67/100/150/200ms:', over)
