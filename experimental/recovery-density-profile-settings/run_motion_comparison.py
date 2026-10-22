"""Run one exact-byte motion comparison on owned hidden AIR desktops.

Use --reference for later runs: installation, assets, driver and runtime modules
must match. A successful diagnostic is not a full release qualification.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/validation'))
from prepare_motion_transport import ROOT, sha
from run_security_terminals import installation, test_port

GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
CASES = {'fast-motion': ('rbl', 240), 'continuity': ('random_mane', 300),
         'density': ('random_mane', 420), 'pause-timing': ('random_mane', 300),
         'animation': ('rbl', 240), 'native-jump': ('rbl', 300), 'fast-held': ('rbl', 360)}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def summary(values):
    ordered = sorted(values)
    if not ordered:
        return None
    return dict(count=len(ordered), mean=sum(ordered)/len(ordered),
                p50=ordered[len(ordered)//2], p95=ordered[min(len(ordered)-1, int(len(ordered)*.95))],
                maximum=ordered[-1], over50=sum(v>50 for v in ordered), over100=sum(v>100 for v in ordered))


def signature(run):
    # Ports, unique AppIDs and the RConnect production binary intentionally differ.
    return {role: {key: inp[key] for key in ('game', 'assets', 'modules', 'driver', 'harness')}
            for role, inp in run['inputs'].items()}


def exclusive_air_evidence(inputs, timeline, expected_digest):
    if inputs.get('require_exclusive_air') is not True or inputs.get('air_inventory_sha256') != expected_digest:
        return False
    if timeline.get('stopped_for_overlap') is not False:
        return False
    rows = timeline.get('rows', [])
    monitored = [row['foreign_air'] for row in rows if isinstance(row, dict) and 'foreign_air' in row]
    return bool(monitored) and all(isinstance(foreign, list) and not foreign for foreign in monitored)


def vision_signature_matches(run, run_input, expected):
    return run.get('vision_config_templates') == expected and run_input.get('vision_config_templates') == expected


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('candidate', 'drivers', 'output'):
        ap.add_argument('--'+name, type=Path, required=True)
    ap.add_argument('--case', choices=CASES, required=True)
    ap.add_argument('--reference', type=Path)
    ap.add_argument('--host-vision-config-template', type=Path, required=True)
    ap.add_argument('--join-vision-config-template', type=Path, required=True)
    ap.add_argument('--registry-wait', type=int, default=300)
    args = ap.parse_args()
    candidate, drivers, out = [(ROOT / p).resolve() for p in (args.candidate, args.drivers, args.output)]
    assert candidate.parent == drivers.parent == out.parent == M52 and not out.exists()
    vision_sources = {role: (ROOT / getattr(args, role+'_vision_config_template')).resolve()
                      for role in ('host', 'join')}
    vision_hashes = {role: sha(path) for role, path in vision_sources.items()}
    cm, dm = read(candidate/'prepared.json'), read(drivers/'prepared.json')
    if cm['kind'] == 'isolated-recovery':
        from audit_room_entry_candidate import audit
        audit(candidate)
    else:
        for name, digest in {**cm['source'], **cm['inputs']}.items():
            assert sha(candidate/name) == digest, name
    for name, digest in dm['files'].items():
        assert sha(drivers/name) == digest, name
    binary = candidate/'RConnectMod.swf'
    digest = sha(binary)
    assert digest == cm['candidate_sha256'] and cm['compiled']
    before = installation()
    runner = ROOT/'tools/run_coop_regression.py'
    helper = ROOT/'tools/validation/air_test_inventory.py'
    runner_digest, helper_digest = sha(runner), sha(helper)
    reference = (ROOT / args.reference).resolve() if args.reference else None
    if reference:
        assert reference.parent == M52
        previous = read(reference/'intent.json')
        assert previous['installation'] == before, 'Installation changed between controls'
        assert previous.get('vision_config_templates') == vision_hashes, 'RV templates differ from reference'
        assert previous.get('wrapper_sha256') == sha(Path(__file__)), 'Profile wrapper differs from reference'
        assert previous.get('require_exclusive_air') is True, 'Start a new baseline with overlap detection enabled'
        assert previous['runner_sha256']==runner_digest and previous['air_inventory_sha256']==helper_digest, \
            'Runner or overlap detector changed between controls'
    out.mkdir()
    vision_folder = out/'vision-config'
    vision_folder.mkdir()
    vision_copies = {}
    for role, source in vision_sources.items():
        target = vision_folder/(role+'.txt')
        shutil.copyfile(source, target)
        assert sha(source) == sha(target) == vision_hashes[role]
        vision_copies[role] = target
    binding = out/'driver'
    binding.mkdir()
    for name in ('EffectsDriver.swf', 'EffectsHarness.swf'):
        shutil.copyfile(drivers/args.case/name, binding/name)
    # Same external binary can observe old/new private implementations. The
    # old public declarations are used by both; no production code is embedded.
    save(binding/'driver-input.json', dict(candidate_sha256=digest,
         identical_driver=sha(binding/'EffectsDriver.swf'), source_binding=sha(drivers/args.case/'driver-input.json')))
    evidence = out/'runner-source'
    evidence.mkdir()
    for source in (runner, helper):
        shutil.copyfile(source, evidence/source.name)
    assert sha(evidence/runner.name)==runner_digest and sha(evidence/helper.name)==helper_digest
    intent = dict(candidate=str(candidate), candidate_sha256=digest, version=cm['version'],
                  driver_manifest=sha(drivers/'prepared.json'), case=args.case, installation=before,
                  reference=str(reference) if reference else None, runner_sha256=runner_digest,
                  require_exclusive_air=True, air_inventory_sha256=helper_digest,
                  wrapper_sha256=sha(Path(__file__)),
                  vision_config_templates=vision_hashes,
                  vision_template_sources={role: str(path) for role, path in vision_sources.items()})
    save(out/'intent.json', intent)
    # Read-only launcher inventory. The existing paired runner preserves the
    # entire selected manifest, with isolated storage and all native assets.
    inventory = subprocess.run([str(GAME/'mods/ModLoader/RemainsModLauncher.exe'),
        '--root', str(GAME), '--list', '--json', '--no-ui'], capture_output=True,
        encoding='utf-8-sig', errors='replace', timeout=60, check=True)
    save(out/'installation-inventory.json', json.loads(inventory.stdout))
    land, seconds = CASES[args.case]
    command = [sys.executable, '-B', '-X', 'utf8', str(runner), '--candidate', str(binary),
        '--effects', '--effects-driver', str(binding), '--all-mods', '--land', land,
        '--seconds', str(seconds), '--expected-version', cm['version'], '--port', str(test_port()),
        '--private-desktop', '--defer-visible', '--wait-host-world', '--require-exclusive-air',
        '--registry-wait', str(args.registry_wait),
        '--host-vision-config-template', str(vision_copies['host']),
        '--join-vision-config-template', str(vision_copies['join'])]
    with (out/'runner.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    raw = (out/'runner.log').read_text(encoding='utf-8', errors='replace')
    found = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$', raw, re.M)
    result = dict(exit_code=process.returncode, run=found[1] if found else None,
        installation_unchanged=before == installation(), runner_unchanged=intent['runner_sha256']==sha(runner),
        air_inventory_unchanged=helper_digest==sha(helper), exclusive_air_confirmed=False,
        invalid_reason='foreign AIR before start' if 'Other AIR processes exist; timing run not started' in raw else None,
        passed=False, performance_qualified=False, full_release_qualified=False,
        vision_config_templates=vision_hashes, vision_templates_confirmed=False,
        vision_templates_unchanged=all(sha(vision_sources[r]) == sha(vision_copies[r]) == vision_hashes[r]
                                      for r in ('host', 'join')))
    if not found and 'commit headroom; no AIR instance started' in raw:
        result['invalid_reason'] = 'insufficient commit headroom before start'
    if found:
        folder = ROOT/'build/cooperation'/found[1]
        run = read(folder/'run.json')
        result['runtime_signature'] = signature(run)
        result['same_runtime_as_reference'] = reference is None or signature(run)==read(reference/'result.json')['runtime_signature']
        result['roles'] = {}
        for role in ('host', 'join'):
            inp = run['inputs'][role]
            assert inp['game'] == before['pfe.swf'] and inp['production'] == digest
            assert inp['driver'] == sha(binding/'EffectsDriver.swf')
            log = folder/(role+'.log')
            text = log.read_text(encoding='utf-8-sig', errors='replace') if log.exists() else ''
            stdout = folder/(role+'.stdout.log')
            combined = text+'\n'+(stdout.read_text(encoding='utf-8', errors='replace') if stdout.exists() else '')
            errors = [line for line in combined.splitlines() if 'COOP FAIL' in line or re.search(
                r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b', line, re.I)]
            traces = [json.loads(line.split('FAST MOTION TRACE '+role+' ', 1)[1])
                      for line in text.splitlines() if 'FAST MOTION TRACE '+role+' ' in line]
            metrics = [line for line in text.splitlines() if line.startswith(('COOP METRIC ', 'COOP PROBE host-window ',
                       'COOP PROBE host-final ', 'FAST MOTION METRIC '))]
            result['roles'][role] = dict(checks=len(re.findall(r'^COOP PASS ', text, re.M)), errors=errors,
                done='COOP EFFECTS DONE' in text, version='v'+cm['version']+' initialized' in text,
                frame_intervals=summary([r['dt'] for trace in traces for r in trace]), metrics=metrics,
                log_sha256=sha(log) if log.exists() else None)
        result['memory'] = read(folder/'memory-timeline.json')
        run_input = read(folder/'input.json')
        result['vision_templates_confirmed'] = vision_signature_matches(run, run_input, vision_hashes)
        result['exclusive_air_confirmed'] = exclusive_air_evidence(run_input, result['memory'], helper_digest)
        if not result['exclusive_air_confirmed']:
            result['invalid_reason'] = 'overlap detected or complete overlap evidence absent'
        result['passed'] = process.returncode==0 and result['installation_unchanged'] and result['runner_unchanged'] \
            and result['air_inventory_unchanged'] and result['exclusive_air_confirmed'] \
            and result['vision_templates_unchanged'] and result['vision_templates_confirmed'] \
            and result['same_runtime_as_reference'] and all(r['done'] and r['version'] and r['checks']>0 and not r['errors']
                                                          for r in result['roles'].values())
    save(out/'result.json', result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('runtime_signature','memory')}, ensure_ascii=False), flush=True)
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
