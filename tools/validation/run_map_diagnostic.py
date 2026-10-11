"""Run a frozen map candidate against a physical diagnostic runtime snapshot.

The compile baseline is retained unchanged. Runtime differences are explicit,
and this runner never produces final release evidence or mutates installation.
"""
import argparse
import ast
import copy
import json
import os
import re
import shutil
import subprocess
import sys
from validation_baseline import ROOT, read, sha, read_baseline, verify_runtime_inputs
from freeze_map_runtime import verify_bundle, changes_from
from run_final_regressions import JAVA


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('snapshot')
    ap.add_argument('entry')
    ap.add_argument('--runtime', required=True)
    ap.add_argument('--game-candidate')
    args = ap.parse_args()
    out = (ROOT/args.snapshot).resolve()
    assert out.parent == ROOT/'build/m51' and out.name.startswith(('red-', 'probe-'))
    m = read(out/'source-input.json')
    baseline = read_baseline(m)  # Compile provenance, not a claim about installed files.
    for name, digest in {**m['source'], **m['verification']}.items():
        assert sha(out/name) == digest, name
    assert sha(out/'RConnectMod.swf') == m['candidate_sha256']
    bundle = (ROOT/args.runtime).resolve()
    pinned = verify_bundle(bundle)
    runtime = copy.deepcopy(pinned['runtime'])
    before = changes_from(runtime)
    assert not any(n in before for n in ('pfe.swf', 'mods/RConnect/release/RConnectMod.swf')), before
    game_args = []
    game_record = None
    if args.game_candidate:
        assert out.name.startswith('probe-')
        patch = (ROOT/args.game_candidate).resolve()
        assert patch.parent.parent == ROOT/'build/m51' and patch.parent.name.startswith('map-seed-game-') and patch.name == 'pfe.swf'
        v = read(patch.parent/'game-input.json')
        assert v['diagnostic_only'] and sha(patch) == v['candidate_sha256']
        assert v['original_sha256'] == runtime['protected']['pfe.swf'] == baseline['protected']['pfe.swf']
        for name, digest in v['sources'].items():
            assert sha(patch.parent/name) == digest, name
        assert sha(ROOT/v['script']) == v['script_sha256']
        runtime['protected']['pfe.swf'] = runtime['runtime_assets']['pfe.swf'] = sha(patch)
        game_args = ['--game-candidate', str(patch)]
        game_record = dict(path=str(patch), sha256=sha(patch), inputs_sha256=sha(patch.parent/'game-input.json'))
    label = args.entry+'-pinned'
    result_path = out/(label+'-result.json')
    log_path = out/(label+'-runner.log')
    driver = out/'build'/(label+'-driver')
    assert not any(p.exists() for p in (result_path, log_path, driver)), 'Never overwrite previous evidence'
    planner = ast.parse((out/'tools/validation/run_final_regressions.py').read_text(encoding='utf-8-sig'))
    checks = next(ast.literal_eval(node.value) for node in planner.body if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == 'CHECKS' for target in node.targets))
    assert args.entry in checks
    seconds, land, profile = checks[args.entry]
    assert not profile, 'This diagnostic runner uses new isolated characters'
    for name in ('tools/run_coop_regression.py', 'tools/RConnect.Process.ps1', 'tools/keep_test_responsive.ps1', 'tools/validation/native_runtime_assets.py'):
        assert sha(ROOT/name) == m['verification'][name], name
    with (out/(label+'-build.log')).open('w', encoding='utf-8') as log:
        subprocess.run([sys.executable, '-X', 'utf8', str(out/'tools/build_effects_driver.py'), '--candidate', str(out/'RConnectMod.swf'),
            '--source-root', str(out/'src'), '--java', JAVA, '--output', str(driver), '--entry', args.entry],
            cwd=out, stdout=log, stderr=subprocess.STDOUT, check=True)
    command = [sys.executable, '-X', 'utf8', str(ROOT/'tools/run_coop_regression.py'), '--candidate', str(out/'RConnectMod.swf'),
        '--game-root', str(bundle/'game'), '--effects-driver', str(driver), '--effects', '--all-mods', '--responsive', '--visible-windows',
        '--seconds', str(seconds), '--expected-version', m['version']]+game_args
    if land:
        command += ['--land', land]
    orchestration = {name: sha(ROOT/name) for name in ('tools/validation/run_map_diagnostic.py', 'tools/validation/freeze_map_runtime.py', 'tools/validation/validation_baseline.py')}
    print('RUN '+args.entry+' with pinned runtime '+bundle.name, flush=True)
    with log_path.open('w', encoding='utf-8') as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    text = log_path.read_text(encoding='utf-8', errors='replace')
    found = re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$', text, re.M)
    record = dict(diagnostic_only=True, entry=args.entry, run=found.group(1) if found else None, exit=result.returncode,
        sha256=m['candidate_sha256'], source_inputs_sha256=sha(out/'source-input.json'),
        pinned_runtime=str(bundle), runtime_inputs_sha256=sha(bundle/'runtime-input.json'),
        game_override=game_record, orchestrator=orchestration, installation_changes_before=before)
    if record['run']:
        folder = ROOT/'build/cooperation'/record['run']
        run = read(folder/'run.json')
        verify_runtime_inputs(runtime, run)
        for role in ('host', 'join'):
            assert run['inputs'][role]['production'] == m['candidate_sha256']
            content = (folder/(role+'.log')).read_text(encoding='utf-8-sig')
            record[role] = dict(passed=len(re.findall('^COOP PASS ', content, re.M)), failed=len(re.findall('^COOP FAIL ', content, re.M)), done='COOP EFFECTS DONE' in content)
            storage = __import__('pathlib').Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-coop-'+role+'-'+record['run'])/'Local Store'
            for picture in storage.glob('*.png'):
                shutil.copy2(picture, folder/(role+'-'+picture.name))
    verify_bundle(bundle)
    record['installation_changes_after'] = changes_from(pinned['runtime'])
    assert not any(n in record['installation_changes_after'] for n in ('pfe.swf', 'mods/RConnect/release/RConnectMod.swf'))
    result_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(record, ensure_ascii=False))
    if result.returncode:
        print('\n'.join(line for line in text.splitlines() if 'FAIL ' in line or 'ERROR' in line)[-6000:])
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
