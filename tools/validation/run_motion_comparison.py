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

from prepare_motion_transport import ROOT, sha
from run_security_terminals import installation, test_port

GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
CASES = {'fast-motion': ('rbl', 240), 'continuity': ('random_mane', 300),
         'density': ('random_mane', 420), 'pause-timing': ('random_mane', 300),
         'animation': ('rbl', 240)}


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


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('candidate', 'drivers', 'output'):
        ap.add_argument('--'+name, type=Path, required=True)
    ap.add_argument('--case', choices=CASES, required=True)
    ap.add_argument('--reference', type=Path)
    args = ap.parse_args()
    candidate, drivers, out = [(ROOT / p).resolve() for p in (args.candidate, args.drivers, args.output)]
    assert candidate.parent == drivers.parent == out.parent == M52 and not out.exists()
    cm, dm = read(candidate/'prepared.json'), read(drivers/'prepared.json')
    for name, digest in {**cm['source'], **cm['inputs']}.items():
        assert sha(candidate/name) == digest, name
    for name, digest in dm['files'].items():
        assert sha(drivers/name) == digest, name
    binary = candidate/'RConnectMod.swf'
    digest = sha(binary)
    assert digest == cm['candidate_sha256'] and cm['compiled']
    before = installation()
    reference = (ROOT / args.reference).resolve() if args.reference else None
    if reference:
        assert reference.parent == M52
        assert read(reference/'intent.json')['installation'] == before, 'Installation changed between controls'
    out.mkdir()
    binding = out/'driver'
    binding.mkdir()
    for name in ('EffectsDriver.swf', 'EffectsHarness.swf'):
        shutil.copyfile(drivers/args.case/name, binding/name)
    # Same external binary can observe old/new private implementations. The
    # old public declarations are used by both; no production code is embedded.
    save(binding/'driver-input.json', dict(candidate_sha256=digest,
         identical_driver=sha(binding/'EffectsDriver.swf'), source_binding=sha(drivers/args.case/'driver-input.json')))
    runner = ROOT/'tools/run_coop_regression.py'
    intent = dict(candidate=str(candidate), candidate_sha256=digest, version=cm['version'],
                  driver_manifest=sha(drivers/'prepared.json'), case=args.case, installation=before,
                  reference=str(reference) if reference else None, runner_sha256=sha(runner),
                  wrapper_sha256=sha(Path(__file__)))
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
        '--private-desktop', '--defer-visible', '--wait-host-world']
    with (out/'runner.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    raw = (out/'runner.log').read_text(encoding='utf-8', errors='replace')
    found = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$', raw, re.M)
    result = dict(exit_code=process.returncode, run=found[1] if found else None,
        installation_unchanged=before == installation(), runner_unchanged=intent['runner_sha256']==sha(runner),
        passed=False, performance_qualified=False, full_release_qualified=False)
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
        result['passed'] = process.returncode==0 and result['installation_unchanged'] and result['runner_unchanged'] \
            and result['same_runtime_as_reference'] and all(r['done'] and r['version'] and r['checks']>0 and not r['errors']
                                                          for r in result['roles'].values())
    save(out/'result.json', result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('runtime_signature','memory')}, ensure_ascii=False), flush=True)
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
