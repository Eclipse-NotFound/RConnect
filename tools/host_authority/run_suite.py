"""Run explicit isolated B scenarios serially, retaining every failed attempt.

This is a regression collection, never a release gate. Each child verifies the
frozen tuple, owns its AIR processes and independently checks installed files.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path
from common import ROOT, inside_build, read, save, sha


def main():
    ap = argparse.ArgumentParser()
    for name in ('baseline', 'candidate', 'native', 'tdfc', 'rv', 'msw', 'output'):
        ap.add_argument('--' + name, required=True)
    ap.add_argument('--scenarios', nargs='+', required=True)
    ap.add_argument('--sandy', help='Optional independently attached Sandevistan build')
    ap.add_argument('--seconds', type=int, default=600)
    ap.add_argument('--archive', action='store_true')
    args = ap.parse_args()
    out = inside_build(ROOT / args.output)
    if out.exists():
        raise FileExistsError('Every suite attempt requires a fresh directory')
    if len(args.scenarios) != len(set(args.scenarios)):
        raise ValueError('List each scenario once per suite')
    if any(not s.replace('-', '').isalnum() for s in args.scenarios):
        raise ValueError('Invalid scenario name')
    out.mkdir(parents=True)
    Path(out / 'run_suite.py').write_bytes(Path(__file__).read_bytes())
    runner = Path(__file__).with_name('run_probe.py')
    base = [sys.executable, '-B', '-X', 'utf8', str(runner)]
    for name in ('baseline', 'candidate', 'native', 'tdfc', 'rv', 'msw'):
        base.extend(['--' + name, getattr(args, name)])
    if args.sandy:
        base.extend(['--sandy', args.sandy])
    report = {'experimental_only': True, 'kind': 'serial-regression-collection',
              'runner_sha256': sha(runner), 'arguments': vars(args),
              'results': [], 'complete': False}
    save(out / 'suite.json', report)
    for scenario in args.scenarios:
        if sha(runner) != report['runner_sha256']:
            raise RuntimeError('Runner changed during the suite')
        target = out / scenario
        command = base + ['--scenario', scenario, '--seconds', str(args.seconds),
                          '--output', str(target.relative_to(ROOT))]
        print(json.dumps({'begin': scenario, 'output': str(target)}), flush=True)
        started = time.monotonic()
        with (out / (scenario + '.runner.log')).open('x', encoding='utf-8') as log:
            child = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        receipt = read(target / 'run.json')
        safe = (receipt.get('owned_processes_exited') is True
                and receipt.get('installation_unchanged') is True
                and all(r.get('runtime_unchanged') is True for r in receipt['roles'].values()))
        result = {'scenario': scenario, 'elapsed_seconds': round(time.monotonic() - started, 1),
                  'runner_exit': child.returncode, 'complete': receipt.get('complete'),
                  'run_receipt_sha256': sha(target / 'run.json'),
                  'roles': {role: {k: r.get(k) for k in ('passed', 'failed', 'done', 'fatal')}
                            for role, r in receipt['roles'].items()}, 'safe_cleanup': safe}
        report['results'].append(result)
        save(out / 'suite.json', report)
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if not safe:
            raise RuntimeError('Stop collection: child cleanup or file verification unconfirmed')
        if args.archive:
            subprocess.run([sys.executable, '-B', '-X', 'utf8',
                            str(Path(__file__).with_name('archive_evidence.py')),
                            '--runs', str(target.relative_to(ROOT))], cwd=ROOT, check=True)
    report['complete'] = True
    report['all_passed'] = all(r['runner_exit'] == 0 for r in report['results'])
    save(out / 'suite.json', report)
    raise SystemExit(0 if report['all_passed'] else 1)


if __name__ == '__main__':
    main()
