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


def collection_rows(directory):
    collection = read(directory/'suite.json')
    if not collection.get('complete'):
        raise ValueError('The suite is still running: '+str(directory))
    rows = collection['results']
    names = [r['scenario'] for r in rows]
    if len(set(names)) != len(names) or not set(names) <= REQUIRED:
        raise ValueError('Duplicate or unexpected regression category')
    checked = {}
    for row in rows:
        path = inside_build(directory/row['scenario'])
        receipt = read(path/'run.json')
        if sha(path/'run.json') != row['run_receipt_sha256']:
            raise ValueError('Suite receipt changed: '+row['scenario'])
        roles = {role:{key:r.get(key) for key in ('passed', 'failed', 'done', 'fatal')}
                 for role,r in receipt['roles'].items()}
        safe = (receipt.get('owned_processes_exited') is True
                and receipt.get('installation_unchanged') is True
                and all(r.get('runtime_unchanged') is True for r in receipt['roles'].values()))
        if row['complete'] != receipt.get('complete') or row['roles'] != roles or row['safe_cleanup'] != safe:
            raise ValueError('Suite summary differs from its receipt: '+row['scenario'])
        if set(roles) != {'host', 'join'} or any(r['config'].get('scenario') != row['scenario']
                                               for r in receipt['roles'].values()):
            raise ValueError('Run did not exercise its declared category')
        if not safe:
            raise ValueError('Unconfirmed input protection or cleanup: '+row['scenario'])
        success = (row['runner_exit'] == 0 and row['complete']
                   and all(r['done'] and not r['failed'] and not r['fatal'] for r in roles.values()))
        checked[row['scenario']] = dict(path=path, row=row, receipt=receipt, success=success)
    return checked


def select_runs(suite, rerun_suites):
    selected = collection_rows(suite)
    if set(selected) != REQUIRED:
        raise ValueError('Missing agreed regression category')
    retained = []
    for directory in rerun_suites:
        for name, new in collection_rows(directory).items():
            old = selected[name]
            if old['success'] or not new['success']:
                raise ValueError('A rerun must complete a previously failed category: '+name)
            for key in ('baseline_manifest_sha256', 'build_manifest_sha256', 'native_manifest_sha256',
                        'tdfc_manifest_sha256', 'rv_manifest_sha256', 'msw_manifest_sha256',
                        'sandy_manifest_sha256', 'script_sha256'):
                if not old['receipt'].get(key) or old['receipt'][key] != new['receipt'].get(key):
                    raise ValueError('Rerun changed frozen inputs or the driver: '+name+'/'+key)
            for role in ('host', 'join'):
                # Fresh connection identity is expected; gameplay options must match.
                def gameplay(record):
                    return {k:v for k,v in record['roles'][role]['config'].items()
                            if k not in ('session', 'port', 'hostIp')}
                if gameplay(old['receipt']) != gameplay(new['receipt']):
                    raise ValueError('Rerun changed gameplay options: '+name+'/'+role)
            retained.append(dict(scenario=name, original_path=str(old['path'].relative_to(ROOT)),
                original_row=old['row'], replacement_path=str(new['path'].relative_to(ROOT)),
                replacement_receipt_sha256=new['row']['run_receipt_sha256']))
            selected[name] = new
    if not all(r['success'] for r in selected.values()):
        raise ValueError('Regression categories still lack a successful complete run')
    return list(selected.values()), retained


def main():
    ap = argparse.ArgumentParser()
    for name in ('candidate', 'native', 'tdfc', 'rv', 'msw', 'sandy', 'logic', 'suite', 'output'):
        ap.add_argument('--'+name, required=True)
    ap.add_argument('--extra-run', action='append', default=[])
    ap.add_argument('--rerun-suite', action='append', default=[],
                    help='Explicit successful same-input reruns; original failures remain recorded')
    ap.add_argument('--default', action='append', default=[], dest='defaults')
    args = ap.parse_args()
    suite, out = [inside_build(ROOT/p) for p in (args.suite, args.output)]
    reruns = [inside_build(ROOT/p) for p in args.rerun_suite]
    selected, retained = select_runs(suite, reruns)
    rows = [r['row'] for r in selected]
    if out.exists():
        raise FileExistsError('Preserve each audit in a new directory')
    out.mkdir(parents=True)
    command = [sys.executable, '-B', '-X', 'utf8', str(Path(__file__).with_name('audit_checkpoint.py')),
               '--scope', 'dual-room', '--output', str((out/'frozen-inputs').relative_to(ROOT))]
    for name in ('candidate', 'native', 'tdfc', 'rv', 'msw', 'sandy', 'logic'):
        command.extend(['--'+name, getattr(args, name)])
    for entry in selected:
        command.extend(['--run', str(entry['path'].relative_to(ROOT))])
    for run in args.extra_run:
        command.extend(['--run', str(inside_build(ROOT/run).relative_to(ROOT))])
    for default in args.defaults:
        command.extend(['--default', str(inside_build(ROOT/default).relative_to(ROOT))])
    with (out/'audit.log').open('x', encoding='utf-8') as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    audited = read(out/'frozen-inputs/audit.json')
    summary = dict(experimental_only=True, agreed_regression_categories_complete=True, release_gate_complete=False,
        categories=len(rows), suite_receipt_sha256=sha(suite/'suite.json'), frozen_audit_sha256=sha(out/'frozen-inputs/audit.json'),
        selected_runs=[dict(scenario=r['row']['scenario'], path=str(r['path'].relative_to(ROOT)),
                            receipt_sha256=r['row']['run_receipt_sha256']) for r in selected],
        retained_attempts=retained,
        rerun_suites=[dict(path=str(p.relative_to(ROOT)), receipt_sha256=sha(p/'suite.json')) for p in reruns],
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
