"""B body-only update. Exact evidence, four backed-up targets, no process/save writes."""
from pathlib import Path
import argparse, importlib.util, json, shutil, sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module

d = load('smooth_transaction_utilities', ROOT / 'experimental/b-field8-validation/transaction.py')
q = load('smooth_final_performance', HERE / 'qualify-final.py')
P = d.PLAYABLE
BASE = 'c953c0684ca716b2641c88f13e514275d5f2cc8e3387d9ade50d7ab8bd1fc5a0'
BASE_MANUAL = '18ece1be58d84452c884663ea6ab9b5fff89bd45762b950560027deb8636c070'
NATIVE = '3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83'
NAMES = (d.RC, 'README.txt', 'manual-input.json', 'playable-validation.json')
REQUIRED = {'ui', 'textmotion', 'rockets'}

def test_record(item, build, pins, ids):
    path = d.path(item['result']); prep_path = d.path(item['preparation'])
    r = d.read(path); prep = d.read(prep_path); folder = path.parent
    d.require(r.get('passed') and r.get('complete') and r.get('runtime_unchanged') and r.get('private_desktop') and not r.get('error'), 'Unqualified functional run')
    d.require(r['candidate_sha256'] == build['candidate_sha256'], 'Different tested candidate')
    d.require(r['preparation_sha256'] == d.sha(prep_path), 'Preparation changed')
    d.require(prep['environment_sha256'] == 'd1f953f68e58650df6c1d7900994d7edd584441e10b0136c3d62e1ceda3fe475', 'Different default dependency environment')
    files = d.canonical(r['runtime_files'])
    d.require(files['pfe.swf'] == NATIVE and files['mods/rconnect/release/rconnectmod.swf'] == build['candidate_sha256'], 'Wrong tested binary tuple')
    for name, digest in d.canonical(prep['files']).items():
        if name not in d.RUNTIME_MUTABLE: d.require(files.get(name) == digest, 'Test dependency differs: ' + name)
    source = d.path(prep['compiler_command'][-1])
    d.require(d.pinned(source, pins) == prep['driver'], 'Driver source changed')
    d.verify(source.parent, prep['helpers'], pins)
    d.require(d.pinned(folder / 'runner.py', pins) == r['runner_sha256'], 'Executed runner changed')
    d.require(r['seed_hashes'] == {k: v['sha256'] for k, v in prep['seeds'].items()}, 'Copied seeds differ')
    counts = {}
    d.require(set(r['roles']) == {'host', 'join'}, 'Both players required')
    for role, entry in r['roles'].items():
        d.require(entry['done'] and entry['passed'] > 0 and entry['failed'] == 0 and not entry['fatal'], 'Functional role failed')
        d.require(entry['appid'].startswith('pfe-modsettings-rconnect-b-startup-' + role + '-') and entry['appid'] not in ids, 'Test identity reused')
        ids.add(entry['appid']); d.verify(folder, entry['logs'], pins)
        rows = d.events(folder / (role + '.BStartupDriver.log'))
        game = d.events(folder / (role + '.RConnect-B.log'))
        d.require(not any(v['kind'] in ('FAIL', 'FATAL', 'ERROR') for v in rows + game), 'Retained logs contain failure')
        d.require(d.one(rows, 'installed') == dict(scenario=r['scenario'], role=role, source=build['source_id'], version=build['version']), 'Loaded source differs')
        d.require(d.one(rows, 'DONE') == dict(passed=entry['passed'], failed=0) and sum(v['kind'] == 'PASS' for v in rows) == entry['passed'], 'Assertion tally differs')
        counts[role] = entry['passed']
    d.pinned(path, pins); d.pinned(prep_path, pins)
    return dict(scenario=r['scenario'], result=d.rel(path), preparation=d.rel(prep_path), checks=counts)

def check(args):
    manifest = d.package()
    d.require(d.sha(P / 'manual-input.json') == BASE_MANUAL and manifest['candidate_sha256'] == BASE, 'Installed B changed')
    d.require(d.sha(P / 'game/pfe.swf') == NATIVE, 'Installed native changed')
    pins = {}; build = d.build_info(args.candidate, pins)
    d.require(build['version'] == 'B3-0.1-smooth1', 'Wrong candidate version')
    archive = HERE / 'source-04/source-manifest.json'; source = d.read(archive)
    d.require(source['source_id'] == build['source_id'] and source['build_manifest_sha256'] == build['manifest_sha256'], 'Archive differs from tested build')
    d.verify(archive.parent, source['overlay'], pins); d.pinned(archive, pins)
    performance_path = d.path(args.performance); performance = d.read(performance_path)
    d.require(performance == q.evaluate(performance['series']) and performance['qualified'], 'Performance cannot be reproduced')
    d.require(performance['candidate_sha256'] == build['candidate_sha256'], 'Wrong performance candidate')
    d.pinned(performance_path, pins); d.pinned(Path(q.__file__), pins)
    spec_path = d.path(args.tests); spec = d.read(spec_path); ids = set()
    records = [test_record(item, build, pins, ids) for item in spec]
    d.require(REQUIRED <= {v['scenario'] for v in records}, 'Missing changed-feature scenarios')
    d.pinned(spec_path, pins); notes = d.path(args.notes); d.pinned(notes, pins)
    d.require(build['version'] in notes.read_text(encoding='utf-8'), 'Notes must identify the candidate')
    d.pinned(Path(__file__), pins); d.pinned(Path(d.__file__), pins)
    preserved = {d.rel(P / 'game' / name): digest for name, digest in manifest['files'].items()
                 if name.lower() != 'mods/rconnect/release/rconnectmod.swf'}
    for item in manifest['launchers']:
        for key in ('descriptor', 'launcher'): preserved[d.rel(P / item[key])] = item[key + '_sha256']
    return dict(build=build, manifest=manifest, tests=records, evidence=pins, preserved=preserved,
                performance=dict(path=d.rel(performance_path), sha256=d.sha(performance_path)),
                before={name: d.sha(P / name) for name in NAMES}, notes=d.rel(notes))

def folder(value, new=False):
    out = d.path(value)
    d.require(out.parent == ROOT / 'build/ab' and out.name.startswith('b-smooth-deploy-'), 'Explicit B transaction directory required')
    if new: d.require(not out.exists(), 'Keep previous transaction')
    return out

def persist(out, receipt): d.atomic_write(out / 'deployment.json', d.encode(receipt))

def rollback(out, receipt):
    d.require(receipt['target'] == d.rel(P) and set(receipt['before']) == set(NAMES), 'Unexpected rollback scope')
    for name in NAMES:
        d.require(d.sha(out / 'before' / name) == receipt['before'][name], 'Backup changed')
        d.require(d.sha(P / name) in {receipt['before'][name], receipt['after'][name]}, 'Concurrent edit blocks rollback')
    for name in reversed(NAMES):
        d.atomic_write(P / name, (out / 'before' / name).read_bytes(), d.sha(P / name))
    d.package(); receipt.update(status='rolled_back', finished=d.utc()); persist(out, receipt)

def install(args):
    out = folder(args.transaction, True)
    with d.package_lock():
        gate = check(args); out.mkdir(); build = gate['build']; old = gate['manifest']
        for name in NAMES:
            target = out / 'before' / name; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(P / name, target); d.require(d.sha(target) == gate['before'][name], 'Backup differs')
        readme = d.path(gate['notes']).read_text(encoding='utf-8').strip() + '\n'
        manifest = json.loads(json.dumps(old))
        manifest.update(source_id=build['source_id'], candidate_sha256=build['candidate_sha256'], candidate_manifest_sha256=build['manifest_sha256'],
                        readme_sha256=d.digest(readme.encode('utf-8')), local_field_gate_complete=True,
                        parent_manifest=dict(path=d.rel(out / 'before/manual-input.json'), sha256=gate['before']['manual-input.json']))
        for name in manifest['files']:
            if name.lower() == 'mods/rconnect/release/rconnectmod.swf': manifest['files'][name] = build['candidate_sha256']
        # The recorded environment remains the inherited dependency bundle;
        # the explicit body override describes this one newer tested module.
        manifest['environment_body_override'] = dict(path=d.RC, sha256=build['candidate_sha256'])
        contents = {d.RC: (ROOT / build['path'] / 'RConnectMod.swf').read_bytes(), 'README.txt': readme.encode('utf-8'), 'manual-input.json': d.encode(manifest)}
        validation = dict(experimental_only=True, candidate_ready_for_manual_testing=True, formal_release_gate_complete=False,
            local_field_gate_complete=True, source_id=build['source_id'], candidate_sha256=build['candidate_sha256'],
            field_tests=gate['tests'], performance=gate['performance'], manual_manifest_sha256=d.digest(contents['manual-input.json']),
            historical_validation=dict(path=d.rel(out / 'before/playable-validation.json'), sha256=gate['before']['playable-validation.json']),
            rollback=d.rel(out / 'deployment.json'),
            verification_scope='Same tested module bytes and unchanged native/dependency/config/launcher files. Readback verification; no additional installed-instance run.',
            limitations=['Stage timing does not measure input-to-display delay. Dense combat may still stutter.', 'Existing windows retain old code until saved and restarted.'])
        contents['playable-validation.json'] = d.encode(validation)
        receipt = {k: v for k, v in gate.items() if k != 'manifest'}
        receipt.update(schema='b-smooth-body-transaction-1', target=d.rel(P), status='prepared', created=d.utc(),
            after={name: d.digest(data) for name, data in contents.items()}, root_witness=d.root_game_snapshot())
        shutil.copy2(__file__, out / 'release-executed.py'); persist(out, receipt)
        try:
            d.verify(ROOT, gate['evidence']); d.verify(ROOT, gate['preserved'])
            for name in NAMES: d.atomic_write(P / name, contents[name], gate['before'][name])
            d.package(); d.verify(P, receipt['after']); d.verify(ROOT, gate['preserved']); d.check_root_game(receipt['root_witness'])
            receipt.update(status='verified', finished=d.utc()); persist(out, receipt)
        except Exception as error:
            receipt['failure'] = str(error); persist(out, receipt); rollback(out, receipt); raise
    return dict(status='verified', transaction=d.rel(out), candidate_sha256=build['candidate_sha256'], restart_required=True)

def main():
    ap = argparse.ArgumentParser(description=__doc__); sub = ap.add_subparsers(dest='action', required=True)
    for action in ('check', 'install'):
        parser = sub.add_parser(action)
        for name in ('candidate', 'performance', 'tests', 'notes'): parser.add_argument('--' + name, required=True)
        if action == 'install': parser.add_argument('--transaction', required=True)
    parser = sub.add_parser('rollback'); parser.add_argument('--transaction', required=True)
    args = ap.parse_args()
    if args.action == 'check':
        r = check(args); value = dict(status='ready_not_installed', build=r['build'], tests=r['tests'])
    elif args.action == 'install': value = install(args)
    else:
        out = folder(args.transaction); receipt = d.read(out / 'deployment.json')
        d.require(d.sha(__file__) == d.sha(out / 'release-executed.py'), 'Use original transaction script')
        with d.package_lock(): rollback(out, receipt)
        value = dict(status=receipt['status'])
    print(json.dumps(value, ensure_ascii=False))

if __name__ == '__main__': main()
