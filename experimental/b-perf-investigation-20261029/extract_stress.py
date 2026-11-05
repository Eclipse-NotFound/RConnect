import json, os, sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'ab')
PROFILE = os.path.join(BASE, 'b-smooth-profile-03')

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
            data = o.get('data') or {}
            kind = o.get('kind')
            if kind == 'stress-measurements':
                samples = data.get('memory', [])
                print('###', d, role, 'stress', 'elapsed', data.get('elapsedMs'),
                      'frames', data.get('screenFrames'), 'steps', data.get('hostSteps'))
                for s in samples:
                    print(f"   ms={s.get('ms'):5d} q={s.get('queued')} delay={s.get('playbackDelay')} "
                          f"underflows={s.get('underflows')} effects={s.get('effects')} "
                          f"projectiles={s.get('projectiles')} heap={s.get('heapBytes')}")
            elif kind == 'stress-payload':
                print('###', d, role, 'payload chars', data.get('sceneCharacters'),
                      'firstUnit', data.get('firstUnitCharacters'))
                for e in (data.get('effects') or [])[:6]:
                    print('   effect', e.get('clip'), e.get('name'), 'chars', e.get('characters'))
                print()
