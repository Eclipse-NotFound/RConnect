"""Read the frozen native profile; never treat instrumented FPS as a gate."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def analyze(out):
    native = json.loads((out / 'result.json').read_text(encoding='utf-8-sig'))
    run = ROOT / 'build/cooperation' / native['run']
    report = dict(run=native['run'], diagnostic_only=True,
                  performance_qualified=False, release_qualified=False,
                  installed_unchanged=native['installation_unchanged'],
                  exclusive=native['exclusive_air_confirmed'],
                  result_sha256=sha(out / 'result.json'), roles={})
    for role in ('host', 'join'):
        log = run / (role + '.log')
        lines = log.read_text(encoding='utf-8-sig', errors='strict').splitlines()
        rows = [json.loads(s[len('PROJECTILE PROFILE '):])
                for s in lines if s.startswith('PROJECTILE PROFILE ')]
        assert len(rows) == 1 and rows[0]['role'] == role
        frames = rows[0]['frames']
        sampled = [f for f in frames if f['samples'] > 0]
        inclusive, leaf, stacks, allocations = Counter(), Counter(), Counter(), Counter()
        phases = {}
        for f in sampled:
            assert sum(f['stacks'].values()) == f['cpu']
            p = phases.setdefault(str(f['phase']), dict(windows=0, cpu=0,
                                  elapsed_ms=0, enter_ms=0, after_enter_ms=0))
            p['windows'] += 1
            p['cpu'] += f['cpu']
            p['elapsed_ms'] += f['end'] - f['at']
            p['enter_ms'] += f['after'] - f['at']
            p['after_enter_ms'] += f['end'] - f['after']
            for stack, count in f['stacks'].items():
                names = [x.split('@', 1)[0] for x in stack.split(' <- ') if x]
                for name in set(names):
                    inclusive[name] += count
                if names:
                    leaf[names[0]] += count
                stacks[stack] += count
            for kind, a in f['allocations'].items():
                allocations[kind] += a['count']
        cpu = sum(f['cpu'] for f in sampled)
        report['roles'][role] = dict(log_sha256=sha(log), recorded_frames=len(frames),
            sampled_windows=len(sampled), cpu_samples=cpu, phases=phases,
            inclusive_top=inclusive.most_common(45), leaf_top=leaf.most_common(35),
            stacks_top=stacks.most_common(25), allocation_count_top=allocations.most_common(12),
            valid_cpu_sample=cpu > 0,
            scope='ENTER_FRAME through final RENDER only; inclusive rows overlap; no allocation stacks; sampling overhead excluded from qualification')
    return report


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('run_output', type=Path)
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    folder = (ROOT / a.run_output).resolve()
    assert folder.parent == ROOT / 'build/m52'
    r = analyze(folder)
    if a.output:
        dest = (ROOT / a.output).resolve()
        assert dest.is_relative_to(ROOT) and not dest.exists()
        dest.write_text(json.dumps(r, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in r.items() if k != 'roles'}, ensure_ascii=False))
    for role, data in r['roles'].items():
        print(json.dumps(dict(role=role, windows=data['sampled_windows'], cpu=data['cpu_samples'],
                             phases=data['phases'], inclusive=data['inclusive_top'][:15],
                             leaf=data['leaf_top'][:12]), ensure_ascii=False))
