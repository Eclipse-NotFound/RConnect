"""Exact field5 -> explicit field8 deployment; reuse five-file atomic rollback engine.

No game is launched or closed here. --test/--preparation contain the reviewed
scenario subset. ui, textmotion and the new base visual diagnostic are required;
other established core scenarios can be supplied according to changed scope.
The visual diagnostic is evidence of observation, not a visual-equivalence gate.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


d = load('field8_transaction', HERE / 'transaction.py')
q = load('field8_qualification_wrapper', HERE / 'qualify.py').q
BASE = ROOT / 'build/ab/b190-scalar04-build'
BASE_HASH = 'f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07'
MANUAL_HASH = '4a85197620badfa03ec4eeac7769ed6106114178ee0d30678e01b8e71543cbf9'
KNOWN = set(d.CORE) | {'visualfield'}
REQUIRED = {'ui', 'textmotion', 'visualfield'}


def assignments(values):
    out = {}
    for value in values:
        name, sep, path = value.partition('=')
        d.require(sep and name in KNOWN and name not in out, 'Use each selected scenario once: NAME=PATH')
        out[name] = path
    d.require(REQUIRED <= set(out), 'Required changed-behavior scenarios: ui, textmotion, visualfield')
    return out


def performance(report_path, build, pins):
    report_path = d.path(report_path)
    result = d.read(report_path)
    d.require(result.get('schema') == q.REPORT_SCHEMA and result.get('gates') == d.PERFORMANCE_GATES, 'Different performance workload or gates')
    d.require(all(result.get(k) is True for k in ('valid_inputs', 'qualified', 'no_material_regression')), 'Performance qualification failed')
    d.require(result['candidate_sha256'] == build['candidate_sha256'] and result['source'] == build['source_id'], 'Performance belongs to another candidate')
    d.require(result['combinations']['baseline']['candidate_sha256'] == BASE_HASH and
              result['combinations']['baseline']['native_sha256'] == d.NEW_NATIVE and
              result['combinations']['candidate']['native_sha256'] == d.NEW_NATIVE, 'Wrong baseline/candidate native tuple')
    d.require(d.pinned(Path(q.__file__), pins) == result['qualifier_sha256'], 'Qualification evaluator changed')
    plan = d.path(result['plan']['path'])
    d.require(d.pinned(plan, pins) == result['plan']['sha256'], 'Frozen performance plan changed')
    groups = {name: [d.path(v['path']) for v in result['inputs'] if v['group'] == name] for name in ('baseline', 'candidate')}
    d.require(q.evaluate(plan, groups['baseline'], groups['candidate']) == result, 'Qualification cannot be reproduced from original logs')
    for name, digest in d.read(plan)['artifacts'].items():
        d.require(d.pinned(d.path(name), pins) == digest, 'Frozen performance artifact changed')
    for run in result['inputs']:
        d.verify(d.path(run['path']), run['hashes'], pins)
    return dict(path=d.rel(report_path), sha256=d.pinned(report_path, pins), qualifier_sha256=result['qualifier_sha256'],
                schema=result['schema'], workload='Sustained LMG 1000-round magazine; exact field5/native021 baseline', plan=result['plan'])


def preflight(args):
    pins, ids = {}, set()
    manifest = d.package()
    baseline = d.build_info(BASE, pins)
    d.require(baseline['candidate_sha256'] == BASE_HASH and baseline['version'] == 'B3-0.1-field5', 'Baseline is not exact field5')
    d.require(d.sha(d.PLAYABLE / 'manual-input.json') == MANUAL_HASH and manifest['candidate_sha256'] == BASE_HASH and
              manifest['source_id'] == baseline['source_id'] and d.sha(d.PLAYABLE / RC) == BASE_HASH and
              d.sha(d.PLAYABLE / 'game/pfe.swf') == d.NEW_NATIVE, 'Installed field5 package changed')
    candidate_path = d.path(args.candidate)
    d.require(candidate_path.parent == ROOT / 'build/ab' and candidate_path != BASE, 'Explicit separate frozen build required')
    candidate = d.build_info(candidate_path, pins)
    d.require(candidate['version'] == 'B3-0.1-field8' and candidate['candidate_sha256'] != BASE_HASH, 'Expected final field8 candidate')
    stamp = (candidate_path / 'src/authority/BuildInfo.as').read_text(encoding='utf-8-sig')
    d.require(re.search(r'const\s+REVISION:int\s*=\s*5\s*;', stamp) is not None, 'field8 must retain revision 5 isolation')
    # Also validate complete source inventory and reconstructed SOURCE rather
    # than merely trusting the hash written inside a build manifest.
    identity, source_pins = q.build_identity(d.rel(candidate_path), 'build/ab/native-hooks-021/pfe.swf', d.NEW_NATIVE)
    for name, digest in source_pins.items():
        d.require(d.pinned(d.path(name), pins) == digest, 'Candidate source changed')
    native = d.native_proof(pins)
    tests, preparations = assignments(args.test), assignments(args.preparation)
    d.require(set(tests) == set(preparations), 'Each selected scenario needs exactly its own preparation')
    records = [d.test_evidence(tests[s], preparations[s], s, candidate, manifest, MANUAL_HASH, pins, used_appids=ids) for s in sorted(tests)]
    # Required visual diagnosis must be read and accepted explicitly. The
    # runner's PASS only proves sampling; colour/pixel differences remain data.
    visual = d.path(args.visual_review)
    review = d.read(visual)
    d.require(review.get('candidate_sha256') == candidate['candidate_sha256'] and review.get('source_id') == candidate['source_id'], 'Visual review belongs to another build')
    d.require(review.get('result_sha256') == d.sha(d.path(tests['visualfield'])) and review.get('accepted') is True,
              'Visual diagnostic needs an explicit exact-result review')
    d.require(isinstance(review.get('findings'), list) and len(review['findings']) > 0 and isinstance(review.get('limitations'), list), 'Visual review must preserve findings and limits')
    evidence = review.get('evidence')
    d.require(isinstance(evidence, dict) and 'visualfield-join-final.json' in evidence and
              'visualfield-host-rows.json' in evidence, 'Visual review must pin the original paired trees and host samples')
    d.verify(d.path(tests['visualfield']).parent, evidence, pins)
    d.pinned(visual, pins)
    perf = performance(args.performance, candidate, pins)
    notes = d.path(args.notes)
    d.require(notes.read_text(encoding='utf-8-sig').strip(), 'Empty reviewed release notes')
    d.pinned(notes, pins)
    d.pinned(Path(__file__), pins)
    return dict(schema=d.SCHEMA, checked_utc=d.utc(), candidate=candidate, baseline=baseline, native=native,
                tests=records, visual_review=dict(path=d.rel(visual), sha256=d.sha(visual)), performance=perf,
                notes=d.rel(notes), evidence=pins, before={name: d.sha(d.PLAYABLE / name) for name in d.NAMES},
                manifest=manifest, appids=sorted(ids), script_sha256=d.sha(d.__file__))


RC = d.RC
d.preflight = preflight


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    for command in ('check', 'install'):
        p = sub.add_parser(command)
        for name in ('candidate', 'performance', 'notes', 'visual-review'):
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
        result = dict(status='ready_for_install', candidate=gate['candidate'], tests=gate['tests'], visual_review=gate['visual_review'], performance=gate['performance'])
    elif args.action == 'install':
        result = d.install(args)
    elif args.action == 'finalize':
        result = d.finalize(args)
    else:
        out = d.transaction_path(args.transaction)
        with d.package_lock():
            receipt = d.load_transaction(out)
            d.rollback(out, receipt)
        result = dict(status=receipt['status'], receipt=d.rel(out / 'deployment.json'))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
