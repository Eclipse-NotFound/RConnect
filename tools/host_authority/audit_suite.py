"""Require all agreed B regression categories, then audit their exact frozen bytes.

This verifies evidence, not a release or a claim that every possible weapon,
internet connection, player input method or performance condition was tested.
"""
import argparse
import subprocess
import sys
from pathlib import Path
from common import ROOT, inside_build, read, save, sha

REQUIRED = set('native-gun time-exit-replay time-exit-record time-control time-special time-journey motion '
    'body-effects enemies angles pause-cycles friendly friendly-melee friendly-magic mines party cooperation terrain '
    'travel ownership split-rooms msw msw-sweep msw-lifecycle menus dialogue movement personal grabs enemy-grabs '
    'throw vectors guns melee magic explosives areas sound music hud pause-holders lifecycle teleport vision'.split())


def main():
    ap = argparse.ArgumentParser()
    for name in ('candidate', 'native', 'tdfc', 'rv', 'msw', 'sandy', 'logic', 'suite', 'output'):
        ap.add_argument('--'+name, required=True)
    ap.add_argument('--extra-run', action='append', default=[])
    ap.add_argument('--default', action='append', default=[], dest='defaults')
    args = ap.parse_args()
    suite, out = [inside_build(ROOT/p) for p in (args.suite, args.output)]
    collection = read(suite/'suite.json')
    rows = collection['results']
    if not collection.get('complete') or not collection.get('all_passed'):
        raise ValueError('The full suite did not complete successfully')
    if len(rows) != len(REQUIRED) or {r['scenario'] for r in rows} != REQUIRED:
        raise ValueError('Missing, duplicate or unexpected agreed regression category')
    for row in rows:
        path = suite/row['scenario']
        if row['runner_exit'] != 0 or not row['complete'] or not row['safe_cleanup'] or sha(path/'run.json') != row['run_receipt_sha256']:
            raise ValueError('Suite row differs from its successful receipt: '+row['scenario'])
    if out.exists():
        raise FileExistsError('Preserve each audit in a new directory')
    out.mkdir(parents=True)
    command = [sys.executable, '-B', '-X', 'utf8', str(Path(__file__).with_name('audit_checkpoint.py')),
               '--scope', 'dual-room', '--output', str((out/'frozen-inputs').relative_to(ROOT))]
    for name in ('candidate', 'native', 'tdfc', 'rv', 'msw', 'sandy', 'logic'):
        command.extend(['--'+name, getattr(args, name)])
    for row in rows:
        command.extend(['--run', str((suite/row['scenario']).relative_to(ROOT))])
    for run in args.extra_run:
        command.extend(['--run', str(inside_build(ROOT/run).relative_to(ROOT))])
    for default in args.defaults:
        command.extend(['--default', str(inside_build(ROOT/default).relative_to(ROOT))])
    with (out/'audit.log').open('x', encoding='utf-8') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    audited = read(out/'frozen-inputs/audit.json')
    summary = dict(experimental_only=True, agreed_regression_categories_complete=True, release_gate_complete=False,
        categories=len(rows), suite_receipt_sha256=sha(suite/'suite.json'), frozen_audit_sha256=sha(out/'frozen-inputs/audit.json'),
        script_sha256=sha(__file__), candidate_sha256=audited['candidate_sha256'], source_id=audited['source_id'],
        core_passed=sum(r['roles'][role]['passed'] for r in rows for role in ('host', 'join')),
        core_failed=0, extra_runs=len(args.extra_run), defaults=len(args.defaults),
        limitations=['No human mouse or IME validation', 'No public internet, reconnect, third player or other game version',
                     'Performance is reported separately; passing functional assertions does not mean a fluid dense scene',
                     'The 51 legacy mapping retains specific untested combinations'])
    save(out/'suite-audit.json', summary)
    print(summary, flush=True)


if __name__ == '__main__':
    main()
