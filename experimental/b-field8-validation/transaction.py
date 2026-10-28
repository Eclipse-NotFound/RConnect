"""Reviewable B-only deployment transaction. Never launches or stops a game.

check is read-only. install changes exactly five files in b3-playable-190 after
all exact-byte gates pass. finalize requires a fresh isolated ui run sourced
from the installed bytes. Any failed finalize rolls back our known writes.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import uuid

ROOT = next(p for p in Path(__file__).resolve().parents
            if p.name.lower() == 'rconnect' and (p / 'AGENT_SCOPE.md').is_file() and (p / 'build/ab').is_dir())
PLAYABLE = ROOT / 'build/ab/b3-playable-190'
BASE = ROOT / 'build/ab/b190-field9-build'
NATIVE = ROOT / 'build/ab/native-hooks-021'
QUALIFIER = ROOT / 'experimental/b-field-perf-qualification/qualify.py'
PERFORMANCE_FAMILIES = {
    'b-field-ab007-qualification-2': (QUALIFIER, 'AB007 native 90-round magazine'),
    'b-field-sustained-qualification-1': (ROOT / 'experimental/b-field-sustained-bench/qualify.py', 'Sustained LMG 1000-round test magazine'),
}
PERFORMANCE_GATES = dict(seconds_per_phase=60, samples_per_phase_min=45, enemies=[8, 80],
                         maximum_mean_ratio=1.05, maximum_p95_ratio=1.05,
                         maximum_repeat_ratio=1.2, required_firing_windows=6, window_span_min_ms=8000)
BASE_SWF = 'fbaaea1b9f9da4514d0cbedff43403ed53fc694198ddd0e917980c7d922a1acd'
BASE_NATIVE = '1028a49a4af4d8e1b4bd215a44d38a742723438e24056e2336ea875d82efdba9'
NEW_NATIVE = 'eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063'
NATIVE_RECEIPT = '40dc8060b9987aa049c81f11d1b9944b6a1500f7ee48a49059158a5744b049bd'
FROZEN_NATIVE_INPUT = 'experimental/b-field-security/evidence/native021-source-manifest.json'
FROZEN_NATIVE_HASH = '2fe6068a7f1f8a6eb5f1b7136e91ca59fa54fb32306887599987b6a128eeeaa5'
CORE = ('ui', 'darkteleport', 'controls', 'security', 'terrainlive', 'rockets', 'enemies', 'textmotion')
RC = 'game/mods/RConnect/release/RConnectMod.swf'
NAMES = ('game/pfe.swf', RC, 'README.txt', 'manual-input.json', 'playable-validation.json')
RUNTIME_MUTABLE = {'pfe.swf', 'mods/rconnect/release/rconnectmod.swf',
                   'mods/rconnect/release/config.txt', 'startup-test.json'}
SCHEMA = 'b-field-deployment-1'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def utc():
    return datetime.now(timezone.utc).isoformat()


def path(value):
    p = Path(value)
    p = (p if p.is_absolute() else ROOT / p).resolve()
    require(p.is_relative_to(ROOT), 'Path outside RConnect: ' + str(p))
    return p


def rel(value):
    return path(value).relative_to(ROOT).as_posix()


def member(root, name):
    key = name.replace('\\', '/')
    pure = PurePosixPath(key)
    require(not pure.is_absolute() and '..' not in pure.parts and ':' not in key,
            'Unsafe manifest member: ' + name)
    p = (root / key).resolve()
    require(p.is_relative_to(root.resolve()), 'Manifest escapes its directory: ' + name)
    return p


def canonical(values):
    out = {}
    require(isinstance(values, dict) and values, 'Missing file inventory')
    for name, value in values.items():
        member(ROOT, name)
        key = name.replace('\\', '/').lower()
        # Historical preparation receipts contain an identical config entry
        # under both Rconnect and RConnect. Only identical aliases are valid.
        require(key not in out or out[key] == value, 'Conflicting case aliases: ' + name)
        require(isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value), 'Invalid file digest')
        out[key] = value
    return out


def verify(root, values, pins=None):
    canonical(values)
    for name, value in values.items():
        p = member(root, name)
        require(sha(p) == value, 'File changed: ' + str(p))
        if pins is not None:
            pins[rel(p)] = value


def pinned(p, pins):
    p = path(p)
    pins[rel(p)] = sha(p)
    return pins[rel(p)]


def build_info(directory, pins):
    directory = path(directory)
    info = read(directory / 'build-input.json')
    verify(directory, info['sources'], pins)
    pinned(directory / 'build-input.json', pins)
    require(pinned(directory / 'RConnectMod.swf', pins) == info['candidate_sha256'], 'Candidate SWF differs from build receipt')
    source = (directory / 'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    version = re.search(r'const\s+VERSION:String\s*=\s*"([^"]+)"', source)
    require(version is not None, 'Missing source version')
    build_source = (directory / 'src/authority/BuildInfo.as').read_text(encoding='utf-8-sig')
    require('"' + info['source_id'] + '"' in build_source, 'BuildInfo source differs from receipt')
    require(info['native_capability'] == 'b3-v12', 'Unexpected native capability')
    return dict(path=rel(directory), source_id=info['source_id'], version=version.group(1),
                candidate_sha256=info['candidate_sha256'], manifest_sha256=sha(directory / 'build-input.json'))


def package():
    info = read(PLAYABLE / 'manual-input.json')
    verify(PLAYABLE / 'game', info['files'])
    require(read(PLAYABLE / 'game/mods/RConnect/release/config.txt') == info['config'], 'Player configuration changed')
    require(sha(PLAYABLE / 'README.txt') == info['readme_sha256'], 'Player README changed')
    require(len(info['launchers']) == 2, 'Unexpected B launchers')
    for item in info['launchers']:
        for name in ('descriptor', 'launcher'):
            require(sha(member(PLAYABLE, item[name])) == item[name + '_sha256'], 'B launcher or descriptor changed')
    return info


def native_proof(pins):
    require(pinned(NATIVE / 'build.json', pins) == NATIVE_RECEIPT, 'Frozen native021 build receipt changed')
    info = read(NATIVE / 'build.json')
    require(info['base_sha256'] == BASE_NATIVE and info['candidate_sha256'] == NEW_NATIVE, 'Unexpected native lineage')
    require(all(info[k] is True for k in ('compiled', 'build_checks_passed', 'installation_unchanged', 'inputs_unchanged')), 'Native retention build not qualified')
    require(pinned(NATIVE / 'pfe.swf', pins) == NEW_NATIVE, 'Native021 bytes changed')
    require(pinned(ROOT / FROZEN_NATIVE_INPUT, pins) == FROZEN_NATIVE_HASH, 'Frozen native input manifest changed')
    # Large temporary XML and donor SWFs need not be kept forever: these exact
    # byte-identity proof reports and the compiled output are explicitly pinned
    # by the reviewed, immutable build receipt. No rebuild or Java is executed.
    keep = {k: v for k, v in info['artifacts'].items() if k in
            ('method-audit.json', 'retain.json', 'splice.json', 'prepared.json')
            or k.startswith('import/') or k.startswith('verified/')}
    verify(NATIVE, keep, pins)
    for filename, key in [('method-audit.json', 'method_audit'), ('retain.json', 'retain'), ('splice.json', 'splice')]:
        require(read(NATIVE / filename) == info[key], 'Native proof differs from frozen receipt: ' + filename)
    for name, entry in read(ROOT / FROZEN_NATIVE_INPUT)['native'].items():
        target = ROOT / 'experimental/b-field-security/native-source' / name
        require(pinned(target, pins) == entry['overlay'], 'Native source changed: ' + name)
    return dict(path=rel(NATIVE / 'build.json'), sha256=NATIVE_RECEIPT,
                base_sha256=BASE_NATIVE, candidate_sha256=NEW_NATIVE,
                frozen_input=dict(path=FROZEN_NATIVE_INPUT, sha256=FROZEN_NATIVE_HASH))


def events(p):
    rows = []
    for line in Path(p).read_text(encoding='utf-8-sig').splitlines():
        if line.strip():
            value = json.loads(line)
            require(isinstance(value, dict) and 'kind' in value, 'Malformed JSON event: ' + str(p))
            rows.append(value)
    return rows


def one(rows, kind):
    selected = [r['data'] for r in rows if r['kind'] == kind]
    require(len(selected) == 1, 'Expected one ' + kind + ' record')
    return selected[0]


def windows_json_hash(value):
    # common.save writes text with Windows LF translation, without a final LF.
    return digest(json.dumps(value, ensure_ascii=False, indent=2).replace('\n', '\r\n').encode('utf-8'))


def test_evidence(result_path, preparation_path, scenario, build, manifest, manifest_hash, pins,
                  installed=False, used_appids=None):
    result_path, preparation_path = path(result_path), path(preparation_path)
    r, prepared = read(result_path), read(preparation_path)
    pinned(result_path, pins)
    require(pinned(preparation_path, pins) == r['preparation_sha256'], 'Test preparation changed')
    require(r['scenario'] == scenario and r['candidate_sha256'] == build['candidate_sha256'], 'Test ran another scenario/candidate')
    require(all(r.get(k) is True for k in ('passed', 'complete', 'runtime_unchanged', 'private_desktop')),
            'Test incomplete, failed, non-isolated or runtime changed')
    require(not r.get('error') and r.get('runtime_changes') == [], 'Test error/runtime mutation')
    expected_candidate = PLAYABLE / RC if installed else ROOT / build['path'] / 'RConnectMod.swf'
    expected_native = PLAYABLE / 'game/pfe.swf' if installed else NATIVE / 'pfe.swf'
    require(path(r['candidate_path']) == expected_candidate.resolve() and path(r['native_source']) == expected_native.resolve(),
            'Test source paths do not identify the exact candidate/native source')
    require(pinned(result_path.parent / 'runner.py', pins) == r['runner_sha256'], 'Frozen test runner changed')
    require(prepared['manual_manifest'] == manifest_hash, 'Preparation belongs to another playable package')
    require(canonical(prepared['original_files']) == canonical(manifest['files']), 'Preparation original tuple differs')
    source = path(prepared['compiler_command'][-1])
    require(pinned(source, pins) == prepared['driver'], 'Frozen driver source changed')
    verify(source.parent, prepared['helpers'], pins)
    driver_key = 'mods/bstartupdriver/release/bstartupdrivermod.swf'
    expected = canonical(prepared['files'])
    require(pinned(source.parent / 'BStartupDriverMod.swf', pins) == expected[driver_key], 'Frozen driver SWF changed')
    runtime = canonical(r['runtime_files'])
    require(set(runtime) == set(expected) | {'startup-test.json'}, 'Test runtime inventory shape differs')
    for name, value in expected.items():
        if name not in RUNTIME_MUTABLE:
            require(runtime[name] == value, 'Test runtime dependency changed: ' + name)
    require(runtime['pfe.swf'] == NEW_NATIVE and runtime['mods/rconnect/release/rconnectmod.swf'] == build['candidate_sha256'],
            'Test used another binary tuple')
    require(set(r['roles']) == {'host', 'join'}, 'Both roles required')
    require(r['seed_hashes'] == {role: v['sha256'] for role, v in prepared['seeds'].items()}, 'Test seed identity differs')
    for role, seed in prepared['seeds'].items():
        require(pinned(preparation_path.parent / (role + '-save0.sol'), pins) == seed['sha256'], 'Frozen test save changed')
    ids, count, host_events = [], 0, None
    for role, value in r['roles'].items():
        appid = value['appid']
        require(re.fullmatch('pfe-modsettings-rconnect-b-startup-' + role + '-[0-9a-f]{32}', appid) is not None,
                'Test does not have a fresh isolated role identity')
        require(appid not in ids and (used_appids is None or appid not in used_appids), 'AIR test identity reused')
        require(value['done'] is True and value['failed'] == 0 and value['fatal'] == [] and value['passed'] > 0,
                'Failed or empty role: ' + role)
        verify(result_path.parent, value['logs'], pins)
        rows = events(result_path.parent / (role + '.BStartupDriver.log'))
        rc_rows = events(result_path.parent / (role + '.RConnect-B.log'))
        require(not any(x['kind'] in ('FAIL', 'FATAL', 'ERROR', 'DRIVER_IO_FAILED') for x in rows + rc_rows), 'Fatal/error evidence present')
        identity = one(rows, 'installed')
        require(identity == dict(scenario=scenario, role=role, source=build['source_id'], version=build['version']), 'Actual loaded driver identity differs')
        boot = one(rc_rows, 'boot')
        require(boot['source'] == build['source_id'] and boot['version'] == build['version'] and
                boot['session'] == manifest['config']['session'] and boot['role'] == '', 'Actual loaded product identity differs')
        require(sum(x['kind'] == 'PASS' for x in rows) == value['passed'], 'Assertion count differs')
        require(one(rows, 'DONE') == dict(passed=value['passed'], failed=0) and rows[-1]['kind'] == 'DONE', 'Final evidence not completely flushed')
        descriptor = ('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
            f'<id>{appid}</id><versionNumber>1.0</versionNumber><filename>B Startup Test</filename>'
            '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>')
        require(digest(descriptor.encode('utf-8')) == value['descriptor_sha256'], 'Test descriptor differs from isolated template')
        if role == 'host':
            host_events = rc_rows
        ids.append(appid)
        count += value['passed']
    port = one(host_events, 'listening')['port']
    config = dict(manifest['config'], role='', autoGame=False, probe=False, port=port)
    require(runtime['mods/rconnect/release/config.txt'] == windows_json_hash(config), 'Test configuration differs beyond allocated port')
    startup = dict(scenario=scenario, port=port, timeout=960 if scenario in ('enemies','teleport','rockets','terrain') else 300,
                   evidenceDirectory=str(result_path.parent), clockTrace=scenario == 'rockets')
    require(runtime['startup-test.json'] == windows_json_hash(startup), 'Scenario startup input differs')
    if used_appids is not None:
        used_appids.update(ids)
    return dict(path=rel(result_path), sha256=sha(result_path), preparation=rel(preparation_path),
                preparation_sha256=sha(preparation_path), scenario=scenario, checks=count, appids=ids)


def performance_family(schema):
    require(schema in PERFORMANCE_FAMILIES, 'Unknown performance evidence family')
    return PERFORMANCE_FAMILIES[schema]


def performance(report_path, build, pins):
    report_path = path(report_path)
    result = read(report_path)
    qualifier, workload = performance_family(result.get('schema'))
    require(result.get('gates') == PERFORMANCE_GATES, 'Performance thresholds changed')
    require(all(result.get(k) is True for k in ('valid_inputs', 'qualified', 'no_material_regression')), 'Performance qualification not passed')
    require(result['candidate_sha256'] == build['candidate_sha256'] and result['source'] == build['source_id'], 'Performance belongs to another candidate')
    require(result['combinations']['candidate']['native_sha256'] == NEW_NATIVE and
            result['combinations']['baseline']['candidate_sha256'] == BASE_SWF and
            result['combinations']['baseline']['native_sha256'] == BASE_NATIVE, 'Performance binary comparison differs')
    require(pinned(qualifier, pins) == result['qualifier_sha256'], 'Read-only qualifier changed')
    plan_path = path(result['plan']['path'])
    require(pinned(plan_path, pins) == result['plan']['sha256'], 'Frozen performance plan changed')
    spec = importlib.util.spec_from_file_location('b_field_readonly_qualification', qualifier)
    module = importlib.util.module_from_spec(spec)
    previous_bytecode = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous_bytecode
    groups = {g: [path(x['path']) for x in result['inputs'] if x['group'] == g] for g in ('baseline', 'candidate')}
    require(len(groups['baseline']) == len(groups['candidate']) == 2, 'Four performance runs required')
    require(module.evaluate(plan_path, groups['baseline'], groups['candidate']) == result, 'Performance cannot be reproduced from archived evidence')
    for name, value in read(plan_path)['artifacts'].items():
        require(pinned(path(name), pins) == value, 'Frozen performance input changed')
    for run in result['inputs']:
        verify(path(run['path']), run['hashes'], pins)
    return dict(path=rel(report_path), sha256=pinned(report_path, pins), qualifier_sha256=result['qualifier_sha256'],
                schema=result['schema'], workload=workload, plan=result['plan'])


def assignments(values):
    out = {}
    for item in values:
        name, sep, value = item.partition('=')
        require(sep and name in CORE and name not in out, 'Use each required scenario exactly once: NAME=PATH')
        out[name] = value
    require(set(out) == set(CORE), 'All eight core scenarios are required: ' + ', '.join(CORE))
    return out


def preflight(args):
    pins, ids = {}, set()
    manifest = package()
    base = build_info(BASE, pins)
    require(base['candidate_sha256'] == BASE_SWF and base['version'] == 'B3-0.1-field3', 'Unexpected field9 baseline')
    require(manifest['source_id'] == base['source_id'] and manifest['candidate_sha256'] == BASE_SWF and
            sha(PLAYABLE / RC) == BASE_SWF and sha(PLAYABLE / 'game/pfe.swf') == BASE_NATIVE, 'Installed B is no longer field9/native019')
    require(base['version'] in (PLAYABLE / 'README.txt').read_text(encoding='utf-8-sig'), 'Installed version label differs')
    candidate_path = path(args.candidate)
    match = re.fullmatch(r'b190-field(\d+)-build', candidate_path.name)
    require(candidate_path.parent == ROOT / 'build/ab' and match is not None and int(match.group(1)) >= 20,
            'This transaction accepts only explicitly selected field20-or-later frozen builds')
    candidate = build_info(candidate_path, pins)
    require(candidate['candidate_sha256'] != BASE_SWF and candidate['version'] != base['version'], 'Candidate/version did not advance')
    native = native_proof(pins)
    tests, preparations = assignments(args.test), assignments(args.preparation)
    manifest_hash = sha(PLAYABLE / 'manual-input.json')
    records = [test_evidence(tests[s], preparations[s], s, candidate, manifest, manifest_hash, pins, used_appids=ids) for s in CORE]
    perf = performance(args.performance, candidate, pins)
    notes = path(args.notes)
    require(notes.read_text(encoding='utf-8-sig').strip(), 'Empty reviewed release notes')
    pinned(notes, pins)
    return dict(schema=SCHEMA, checked_utc=utc(), candidate=candidate, baseline=base, native=native,
                tests=records, performance=perf, notes=rel(notes), evidence=pins,
                before={name: sha(PLAYABLE / name) for name in NAMES},
                manifest=manifest, appids=sorted(ids), script_sha256=sha(__file__))


def atomic_write(target, data, expected=None):
    target = Path(target)
    if expected is not None:
        require(sha(target) == expected, 'Concurrent edit: ' + str(target))
    temp = target.with_name(target.name + '.b-field-' + uuid.uuid4().hex + '.tmp')
    try:
        with temp.open('xb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        require(sha(temp) == digest(data), 'Temporary write differs')
        if expected is not None:
            require(sha(target) == expected, 'Concurrent edit before replacement: ' + str(target))
        os.replace(temp, target)
        require(sha(target) == digest(data), 'Replacement readback differs')
    finally:
        if temp.exists():
            temp.unlink()  # Only the uniquely named file created by this call.


@contextmanager
def package_lock():
    lock = PLAYABLE / '.b-field-deployment.lock'
    token = uuid.uuid4().hex
    with lock.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(dict(token=token, pid=os.getpid(), created=utc())))
    try:
        yield
    finally:
        if lock.exists() and read(lock).get('token') == token:
            lock.unlink()


def receipt_save(out, value):
    atomic_write(out / 'deployment.json', encode(value))


def transaction_path(value, new=False):
    out = path(value)
    require(out.parent == ROOT / 'build/ab' and out.name.startswith('b-field-deploy-'), 'Transaction must be a new build/ab/b-field-deploy-* directory')
    require(out != PLAYABLE, 'Transaction cannot be installed package')
    if new:
        require(not out.exists(), 'Transaction already exists')
    return out


def rollback(out, receipt):
    # Check every target before reverting anything. A changed file that is not
    # one of our recorded states belongs to somebody else; never overwrite it.
    try:
        observed = {}
        for name in NAMES:
            require(sha(out / 'before' / name) == receipt['before'][name], 'Rollback backup changed: ' + name)
            known = {receipt['before'][name], *receipt.get('allowed_after', {}).get(name, [])}
            observed[name] = sha(PLAYABLE / name)
            require(observed[name] in known, 'Concurrent edit blocks rollback: ' + name)
        for name in reversed(NAMES):
            atomic_write(PLAYABLE / name, (out / 'before' / name).read_bytes(), observed[name])
        package()
        receipt.update(status='rolled_back', finished_utc=utc())
        receipt_save(out, receipt)
    except Exception as error:
        receipt.update(status='rollback_blocked', rollback_error=str(error))
        receipt_save(out, receipt)
        raise


def preserved(manifest):
    values = {rel(PLAYABLE / 'game' / name): value for name, value in manifest['files'].items()
              if name.lower() not in ('pfe.swf', 'mods/rconnect/release/rconnectmod.swf')}
    for item in manifest['launchers']:
        for kind in ('descriptor', 'launcher'):
            values[rel(PLAYABLE / item[kind])] = item[kind + '_sha256']
    return values


def root_game_snapshot():
    # Read-only witnesses. These paths are deliberately outside the write set.
    game = ROOT.parent.parent
    names = ('pfe.swf', 'DLC/pfe.swf', 'DLC/pfeUI.swf', 'application.xml',
             'mods/RConnect/release/RConnectMod.swf', 'mods/RConnect/release/config.txt')
    return {name: sha(game / name) for name in names}


def check_root_game(values):
    require(root_game_snapshot() == values, 'Root/A files changed during B deployment; inspect concurrent work')


def install(args):
    out = transaction_path(args.transaction, new=True)
    with package_lock():
        gate = preflight(args)
        out.mkdir()
        shutil.copy2(__file__, out / 'deploy-executed.py')
        for name in NAMES:
            destination = out / 'before' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PLAYABLE / name, destination)
            require(sha(destination) == gate['before'][name], 'Backup changed during copy')
        candidate, old = gate['candidate'], gate['manifest']
        readme = (PLAYABLE / 'README.txt').read_text(encoding='utf-8-sig')
        readme = readme.replace(gate['baseline']['version'], candidate['version']).replace(gate['baseline']['source_id'], candidate['source_id'])
        readme = readme.replace('更新候选前请退出两个旧 B 窗口，再启动新目录。', '更新后，已有窗口仍使用旧版；请保存并重新打开原启动器以加载新版。')
        readme += '\n' + path(gate['notes']).read_text(encoding='utf-8-sig').strip() + '\n'
        updated = json.loads(json.dumps(old))
        updated.update(source_id=candidate['source_id'], candidate_sha256=candidate['candidate_sha256'],
                       candidate_manifest_sha256=candidate['manifest_sha256'], native_manifest_sha256=NATIVE_RECEIPT,
                       native_files={'pfe.swf': NEW_NATIVE}, readme_sha256=digest(readme.encode('utf-8')),
                       local_field_gate_complete=False, parent_manifest=dict(path=rel(out / 'before/manual-input.json'), sha256=gate['before']['manual-input.json']))
        for name in updated['files']:
            if name.lower() == 'pfe.swf': updated['files'][name] = NEW_NATIVE
            if name.lower() == 'mods/rconnect/release/rconnectmod.swf': updated['files'][name] = candidate['candidate_sha256']
        validation = dict(experimental_only=True, candidate_ready_for_manual_testing=False, formal_release_gate_complete=False,
                          local_field_gate_complete=False, source_id=candidate['source_id'], candidate_sha256=candidate['candidate_sha256'],
                          native=gate['native'], field_tests=gate['tests'], performance=gate['performance'],
                          historical_validation=dict(path=rel(out / 'before/playable-validation.json'), sha256=gate['before']['playable-validation.json']),
                          limitations=['Recorded scenarios: ' + ', '.join(t['scenario'] for t in gate['tests']) + '; visualfield is a diagnostic with a separately recorded review. Performance workload: ' + gate['performance']['workload'] + '.',
                                       'Existing windows keep their already-loaded version until the player saves and restarts.'])
        contents = {'game/pfe.swf': (NATIVE / 'pfe.swf').read_bytes(), RC: (ROOT / candidate['path'] / 'RConnectMod.swf').read_bytes(),
                    'README.txt': readme.encode('utf-8'), 'manual-input.json': encode(updated)}
        validation['manual_manifest_sha256'] = digest(contents['manual-input.json'])
        contents['playable-validation.json'] = encode(validation)
        receipt = {k: v for k, v in gate.items() if k != 'manifest'}
        receipt.update(status='prepared', created_utc=utc(), preserved=preserved(old),
                       allowed_after={name: [digest(contents[name])] for name in NAMES}, after={}, target=rel(PLAYABLE),
                       root_game=root_game_snapshot())
        # Write-ahead record knows every possible target hash before any replace,
        # including a crash between replacement and saving the completion mark.
        receipt_save(out, receipt)
        try:
            verify(ROOT, receipt['evidence'])
            verify(ROOT, receipt['preserved'])
            for name in NAMES:
                atomic_write(PLAYABLE / name, contents[name], receipt['before'][name])
                receipt['after'][name] = digest(contents[name])
                receipt_save(out, receipt)
            package()
            verify(ROOT, receipt['preserved'])
            check_root_game(receipt['root_game'])
            receipt.update(status='installed_pending_smoke', installed_utc=utc())
            receipt_save(out, receipt)
        except Exception as error:
            receipt['failure'] = str(error)
            rollback(out, receipt)
            raise
    return dict(status=receipt['status'], receipt=rel(out / 'deployment.json'), restart_required=True)


def load_transaction(out):
    receipt = read(out / 'deployment.json')
    require(receipt.get('schema') == SCHEMA and receipt.get('target') == rel(PLAYABLE), 'Wrong transaction identity')
    require(sha(out / 'deploy-executed.py') == receipt['script_sha256'] == sha(__file__), 'Use the original transaction script for recovery')
    require(set(receipt['before']) == set(NAMES) and set(receipt['allowed_after']) == set(NAMES), 'Transaction scope changed')
    return receipt


def finalize(args):
    out = transaction_path(args.transaction)
    with package_lock():
        receipt = load_transaction(out)
        require(receipt['status'] == 'installed_pending_smoke', 'Not awaiting installed-byte smoke')
        try:
            verify(PLAYABLE, receipt['after'])
            verify(ROOT, receipt['preserved'])
            check_root_game(receipt['root_game'])
            # The performance plan pins the previous manual manifest. That one
            # authorized replacement is checked against its backup; all other
            # archived evidence must still be exact. Do not run games again.
            for name, value in receipt['evidence'].items():
                p = path(name)
                if p == PLAYABLE / 'manual-input.json': p = out / 'before/manual-input.json'
                require(sha(p) == value, 'Qualified evidence changed after install: ' + name)
            old = read(out / 'before/manual-input.json')
            smoke_pins, ids = {}, set(receipt['appids'])
            result_path = path(args.smoke)
            require(result_path.stat().st_mtime >= datetime.fromisoformat(receipt['installed_utc']).timestamp(), 'Smoke predates installation')
            # Reusing the frozen old preparation is legitimate: run.py replaces
            # native/RC/config from the actual newly installed paths at launch.
            smoke = test_evidence(result_path, args.smoke_preparation, 'ui', receipt['candidate'], old,
                                  receipt['before']['manual-input.json'], smoke_pins, installed=True, used_appids=ids)
            manifest = package()
            manifest['local_field_gate_complete'] = True
            validation = read(PLAYABLE / 'playable-validation.json')
            contents = {'manual-input.json': encode(manifest)}
            validation.update(candidate_ready_for_manual_testing=True, local_field_gate_complete=True, deployment_smoke=smoke,
                              manual_manifest_sha256=digest(contents['manual-input.json']), rollback=rel(out / 'deployment.json'))
            contents['playable-validation.json'] = encode(validation)
            for name, data in contents.items():
                receipt['allowed_after'][name].append(digest(data))
            receipt.update(status='finalizing', smoke=smoke, smoke_evidence=smoke_pins)
            receipt_save(out, receipt)
            for name, data in contents.items():
                atomic_write(PLAYABLE / name, data, receipt['after'][name])
                receipt['after'][name] = digest(data)
                receipt_save(out, receipt)
            package()
            verify(ROOT, receipt['preserved'])
            check_root_game(receipt['root_game'])
            receipt.update(status='verified', finished_utc=utc())
            receipt_save(out, receipt)
        except Exception as error:
            receipt['failure'] = str(error)
            rollback(out, receipt)
            raise
    return dict(status=receipt['status'], receipt=rel(out / 'deployment.json'), restart_required=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    for command in ('check', 'install'):
        p = sub.add_parser(command)
        p.add_argument('--candidate', required=True, help='Exact frozen build directory; no automatic candidate fallback')
        p.add_argument('--test', action='append', required=True, help='SCENARIO=result.json, exactly eight entries')
        p.add_argument('--preparation', action='append', required=True, help='SCENARIO=prepared-vNN.json')
        p.add_argument('--performance', required=True)
        p.add_argument('--notes', required=True, help='Reviewed UTF-8 release note file')
        if command == 'install': p.add_argument('--transaction', required=True)
    p = sub.add_parser('finalize')
    p.add_argument('--transaction', required=True)
    p.add_argument('--smoke', required=True)
    p.add_argument('--smoke-preparation', required=True)
    p = sub.add_parser('rollback')
    p.add_argument('--transaction', required=True)
    args = parser.parse_args()
    if args.action == 'check':
        value = preflight(args)
        output = dict(status='ready_for_install', candidate=value['candidate'], tests=value['tests'], performance=value['performance'])
    elif args.action == 'install': output = install(args)
    elif args.action == 'finalize': output = finalize(args)
    else:
        out = transaction_path(args.transaction)
        with package_lock():
            value = load_transaction(out)
            rollback(out, value)
        output = dict(status=value['status'], receipt=rel(out / 'deployment.json'))
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
