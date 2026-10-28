"""Narrow field8 loading repair, using the established five-file rollback engine.

Require real empty-room/map-travel and terminal-policy tests of these exact bytes.
No performance claim: scheduling, presentation and protocol are unchanged.
Installed UI smoke uses the existing finalizer; no player process is controlled.
"""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


d = load('loadfix_transaction', ROOT / 'experimental/b-field8-validation/transaction.py')
q = load('loadfix_source_verifier', ROOT / 'experimental/b-field-sustained-bench/qualify.py')
BASE = ROOT / 'build/ab/b190-field8-check03-build'
BASE_HASH = 'd1a83ed5e38da1b80786b32e39e1375794586614420e1731ee5cbc9380813ed5'
MANUAL = 'ab7a72c103a5bfdc97f526bbac87f07b2239263fb1a9af64424b17a474571c5c'
REQUIRED = {'loading', 'security'}


def assignments(values):
    result = {}
    for value in values:
        name, sep, path = value.partition('=')
        d.require(sep and name in REQUIRED and name not in result, 'Expected loading/security=PATH exactly once')
        result[name] = path
    d.require(set(result) == REQUIRED, 'Both loading and security evidence required')
    return result


def preflight(args):
    pins, ids = {}, set()
    manifest = d.package()
    baseline = d.build_info(BASE, pins)
    d.require(baseline['candidate_sha256'] == BASE_HASH and baseline['version'] == 'B3-0.1-field8', 'Wrong baseline')
    d.require(d.sha(d.PLAYABLE / 'manual-input.json') == MANUAL and manifest['candidate_sha256'] == BASE_HASH and
              manifest['source_id'] == baseline['source_id'] and d.sha(d.PLAYABLE / d.RC) == BASE_HASH and
              d.sha(d.PLAYABLE / 'game/pfe.swf') == d.NEW_NATIVE, 'Installed B changed concurrently')
    candidate_path = d.path(args.candidate)
    candidate = d.build_info(candidate_path, pins)
    d.require(candidate['version'] == 'B3-0.1-field8-loadfix1', 'Expected explicit loading repair version')
    identity, source_pins = q.build_identity(d.rel(candidate_path), 'build/ab/native-hooks-021/pfe.swf', d.NEW_NATIVE)
    for name, expected in source_pins.items():
        d.require(d.pinned(d.path(name), pins) == expected, 'Candidate source changed')
    old_sources = d.read(BASE / 'build-input.json')['sources']
    new_sources = d.read(candidate_path / 'build-input.json')['sources']
    d.require(set(old_sources) == set(new_sources), 'Loading repair cannot change source inventory')
    changed = {name for name in old_sources if old_sources[name] != new_sources[name]}
    d.require(changed == {'src/RConnectMod.as', 'src/authority/SecurityTerminals.as', 'src/authority/BuildInfo.as'},
              'Unexpected implementation outside the loading fix')
    for folder, info in ((BASE, baseline), (candidate_path, candidate)):
        stamp = (folder / 'src/authority/BuildInfo.as').read_bytes().replace(info['source_id'].encode(), b'__SOURCE_HASH__')
        if folder == BASE:
            old_stamp = stamp
        else:
            d.require(stamp == old_stamp, 'Loading repair changed protocol/native requirements')
    tests, preparations = assignments(args.test), assignments(args.preparation)
    records = [d.test_evidence(tests[name], preparations[name], name, candidate, manifest, MANUAL, pins,
                              used_appids=ids) for name in sorted(REQUIRED)]
    notes = d.path(args.notes)
    d.require(notes.read_text(encoding='utf-8').strip(), 'Empty release notes')
    d.pinned(notes, pins)
    d.pinned(Path(__file__), pins)
    d.pinned(Path(q.__file__), pins)
    return dict(schema=d.SCHEMA, checked_utc=d.utc(), candidate=candidate, baseline=baseline,
                native=d.native_proof(pins), tests=records,
                performance=dict(status='not-rerun-no-performance-claim', workload='Not rerun: narrow initialization correction; field8 timing limitations remain'),
                notes=d.rel(notes), evidence=pins, before={name: d.sha(d.PLAYABLE / name) for name in d.NAMES},
                manifest=manifest, appids=sorted(ids), script_sha256=d.sha(d.__file__))


d.preflight = preflight


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    for command in ('check', 'install'):
        p = sub.add_parser(command)
        for name in ('candidate', 'notes'):
            p.add_argument('--' + name, required=True)
        for name in ('test', 'preparation'):
            p.add_argument('--' + name, action='append', required=True)
        if command == 'install':
            p.add_argument('--transaction', required=True)
    p = sub.add_parser('finalize')
    for name in ('transaction', 'smoke', 'smoke-preparation'):
        p.add_argument('--' + name, required=True)
    p = sub.add_parser('rollback')
    p.add_argument('--transaction', required=True)
    args = parser.parse_args()
    if args.action == 'check':
        gate = preflight(args)
        result = dict(status='ready_for_install', candidate=gate['candidate'], tests=gate['tests'])
    elif args.action == 'install':
        result = d.install(args)
    elif args.action == 'finalize':
        result = d.finalize(args)
    else:
        out = d.transaction_path(args.transaction)
        with d.package_lock():
            receipt = d.load_transaction(out)
            d.rollback(out, receipt)
        result = dict(status=receipt['status'])
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
