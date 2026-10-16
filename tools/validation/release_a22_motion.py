"""Audit the A22 motion candidate; install only RConnect with rollback on smoke failure."""
import argparse
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from release_a22_map import ROOT, GAME, sha, read, save, require, verify_install, replace
from run_a22_motion_checks import CASES
from prepare_a22_motion_keybinds import UI_FILES, UI_SHA, UI_VERSION, verify_ui, verify_ui_deployment, optimize_hud_refresh

CHANGED = {'src/RConnectMod.as', 'src/fe/unit/RConnectAnimationAccess.as',
           'src/rconnect/core/Session.as', 'src/rconnect/game/GameBridge.as',
           'src/rconnect/game/RemoteMotion.as', 'src/rconnect/game/UnitPresentation.as',
           'src/rconnect/game/WallImpactVisuals.as', 'src/rconnect/game/SatsTargetVisuals.as'}


def audit(out, bundle, evidence):
    m, runtime = read(out/'prepared.json'), read(bundle/'inputs.json')
    base = ROOT/m['installed_baseline']
    bm = read(base/'prepared.json')
    changed = set(CHANGED)
    if 'src/rconnect/game/ExplorationSync.as' in m['overrides']:
        changed.add('src/rconnect/game/ExplorationSync.as')
    # Reviewed A37/A39 pose-field and channel-comparison optimizations.
    for name in ('src/rconnect/game/PlayerBodyEffects.as', 'src/rconnect/game/TerrainSync.as'):
        if name in m['overrides'] and m['source'][name] != bm['source'].get(name):
            changed.add(name)
    codec = {'src/rconnect/net/TcpLink.as', 'src/rconnect/net/BinaryMessageCodec.as'}
    if codec & m['overrides'].keys():
        require(codec <= m['overrides'].keys(), 'Incomplete negotiated codec override')
        changed.update(codec)
    require(m['kind'] in ('isolated-a22-followup', 'isolated-a22-testpack') and m['native_unchanged'], 'Not a native-preserving candidate')
    if m['kind'] == 'isolated-a22-testpack':
        parent = ROOT/m['parent_candidate']
        parent_receipt = read(parent/'prepared.json')
        require(sha(parent/'prepared.json') == m['parent_prepared_sha256'], 'Testpack parent changed')
        require(m['production_recompiled'] is False and m['source'] == parent_receipt['source']
                and m['candidate_sha256'] == m['same_production_sha256'] == parent_receipt['candidate_sha256'],
                'Testpack changed production')
    require(sha(base/'deployment.json') == m['installed_deployment_sha256'], 'Baseline receipt changed')
    require(read(base/'deployment.json')['status'] == 'deployed-smoke-passed', 'Baseline not deployed')
    merged = m.get('keybind_merge')
    if merged:
        require(m['control_sha256'] == UI_SHA and m['control_version'] == UI_VERSION, 'Wrong shortcut control')
        ui = ROOT/'build/keybind-output'
        require(verify_ui(base,ui) == merged['ui_source'], 'Shortcut source changed')
        require(sha(ROOT/'tools/validation/build_keybinds.py') == merged['recipe_sha256'], 'Shortcut recipe changed')
        require(sha(out/'evidence/keybind-candidate.json') == merged['ui_candidate_sha256'], 'Shortcut receipt changed')
        require(read(out/'evidence/keybind-candidate.json')['sha256'] == UI_SHA, 'Shortcut receipt binary')
        require(sha(out/'evidence/keybind-deployment.json') == merged['deployment_sha256'], 'Shortcut deployment changed')
        verify_ui_deployment(out/'evidence/keybind-deployment.json',bm['candidate_sha256'])
        previous = ROOT/merged['motion_base']
        pm = read(previous/'prepared.json')
        require(sha(previous/'prepared.json') == merged['motion_prepared_sha256'], 'Motion source receipt changed')
        require(m['base_prepared_sha256'] == merged['motion_prepared_sha256'], 'Motion lineage differs')
        for n,h in pm['source'].items():
            require(sha(previous/n) == h, 'Motion source changed: '+n)
            if n not in UI_FILES and n != 'src/RConnectMod.as':
                require(m['source'][n] == h, 'Merge changed motion behavior: '+n)
        for n in UI_FILES:
            if n == 'src/rconnect/ui/NetHud.as' and merged.get('hud_performance'):
                expected_hud = optimize_hud_refresh((ui/n).read_text(encoding='utf-8-sig'))
                require((out/n).read_text(encoding='utf-8-sig') == expected_hud, 'HUD changed beyond exact performance transform')
            else:
                require(m['source'][n] == merged['ui_source'][n], 'Merge changed shortcuts: '+n)
    else:
        require(m['control_sha256'] == bm['candidate_sha256'], 'Wrong installed control')
    require(m['original_game_sha256'] == m['candidate_game_sha256'] == runtime['files']['pfe.swf'], 'Native game changed')
    added = {'src/rconnect/game/SatsTargetVisuals.as'} | ({'src/rconnect/ui/NetKeybinds.as'} if merged else set())
    if codec <= m['overrides'].keys():
        added.add('src/rconnect/net/BinaryMessageCodec.as')
    require(set(m['source']) == set(bm['source']) | added, 'Unexpected source inventory')
    differences = {n for n, h in m['source'].items() if bm['source'].get(n) != h}
    require(differences == changed | (UI_FILES if merged else set()), 'Unexpected production changes: '+str(differences))
    for n, h in {**m['source'], **m['inputs']}.items():
        require(sha(out/n) == h, 'Frozen input changed: '+n)
    for n in m['overrides']:
        require(sha(ROOT/'experimental/a22-fixes'/n) == m['source'][n], 'Current override differs: '+n)
    for n, field in [('RConnectMod.swf','candidate_sha256'), ('control.swf','control_sha256'), ('native/pfe.swf','candidate_game_sha256')]:
        require(sha(out/n) == m[field], 'Frozen binary differs: '+n)
    before = (base/'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    after = (out/'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    require(after == before.replace('"'+bm['version']+'"', '"'+m['version']+'"'), 'Entry must change only version')
    for n, h in runtime['files'].items():
        require(sha(bundle/'game'/n) == h, 'Frozen runtime changed: '+n)
    selections = read(evidence)
    require(set(selections) == {c[0] for c in CASES}, 'Incomplete required scenarios')
    runs, warnings = {}, {}
    old_logs = [ROOT/'build/cooperation'/n/'join.log' for n in ('e6f23851c9','3998a6ac20')]
    known_warnings = '\n'.join(p.read_text(encoding='utf-8-sig') for p in old_logs)
    for name, entry, land, seconds, copied_save in CASES:
        path = (ROOT/selections[name]).resolve()
        require(path.parent.parent == ROOT/'build/m52' and path.name.endswith('-result.json'), 'Invalid evidence path')
        pack = path.parent
        pm, result = read(pack/'prepared.json'), read(path)
        require(pm['source'] == m['source'] and pm['candidate_sha256'] == m['candidate_sha256'], name+' changed production')
        for n, h in {**pm['source'], **pm['inputs']}.items():
            require(sha(pack/n) == h, name+' frozen input '+n)
        require(result['entry'] == entry and not result['control'] and not result['solo'], name+' mode')
        require(result['exit'] == 0 and result['runtime_matches_installation'] and not result['installation_changes'], name+' result')
        expected = dict(prepared=sha(pack/'prepared.json'), runtime=sha(bundle/'inputs.json'),
                        runner=sha(ROOT/'tools/run_coop_regression.py'), script=sha(ROOT/'tools/validation/run_a22_map_refresh.py'),
                        msw=None, fa=None)
        for n, h in expected.items():
            require(result['inputs'][n] == h, name+' provenance '+n)
        folder = ROOT/'build/cooperation'/result['run']
        actual = read(folder/'run.json')
        require(sha(folder/'run.json') == result['run_sha256'], name+' runtime receipt changed')
        require(sha(folder/'input.json') == actual['input_manifest_sha256'], name+' input manifest changed')
        require(not actual['solo'] and len(actual['pids']) == 2, name+' process count')
        require(len(result['inputs']['saves']) == (2 if copied_save else 0), name+' copied-save coverage')
        for saved in result['inputs']['saves'].values():
            require(sha(saved['path']) == saved['sha256'], name+' original replay template changed')
        for role in ('host','join'):
            log = folder/(role+'.log')
            text = log.read_text(encoding='utf-8-sig')
            require(sha(log) == result[role]['log_sha256'], name+' log changed')
            require('v'+m['version']+' initialized' in text, name+' incorrect version')
            require(result[role]['done'] and result[role]['passed'] > 0 and result[role]['failed'] == 0, name+' incomplete')
            for marker in ('COOP FAIL ', 'game error dialog', 'RConnectRoom: ERROR', 'handoff timed out',
                           'RConnectPause: failed', 'RConnectGrip: failed', 'Error #1009', 'RConnectWall: bitmap copy failed'):
                require(marker not in text, name+' '+marker)
            stdout = folder/(role+'.stdout.log')
            stdout_text = stdout.read_text(encoding='utf-8', errors='replace')
            require('out of memory' not in stdout_text.lower(), name+' AIR memory failure')
            require(re.search(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught)\b',
                              stdout_text, re.I) is None, name+' AIR/native exception')
            found = [line for line in text.splitlines() if "obj spawn '" in line and 'failed:' in line]
            require(all(line in known_warnings for line in found), name+' new object-spawn warning')
            if found:
                warnings[name+'/'+role] = sorted(set(found))
            inp = actual['inputs'][role]
            require(inp['game'] == m['candidate_game_sha256'] and inp['production'] == m['candidate_sha256'], name+' loaded binary')
            for binary, field in [('EffectsDriver.swf','driver'), ('EffectsHarness.swf','harness')]:
                require(inp[field] == result['inputs']['driver'][binary], name+' external driver')
            for n, h in inp['modules'].items():
                n = n.replace('\\','/')
                if not n.lower().startswith('mods/rconnect/'):
                    require(h == runtime['files'][n], name+' third-party input '+n)
        runs[name] = dict(path=path.relative_to(ROOT).as_posix(), result_sha256=sha(path), run=result['run'],
                          counts={role:result[role]['passed'] for role in ('host','join')})
    verify_install(runtime)
    require(sha(ROOT/'release/RConnectMod.swf') == m['control_sha256'], 'Installed RConnect changed')
    return dict(version=m['version'], candidate_sha256=m['candidate_sha256'], native_sha256=m['candidate_game_sha256'],
                prepared_sha256=sha(out/'prepared.json'), runtime_sha256=sha(bundle/'inputs.json'),
                evidence_sha256=sha(evidence), runs=runs, legacy_warnings=warnings, preserved_shortcuts=bool(merged),
                boundaries='A motion/SATS and scoped HUD, exploration, packet-codec, weapon-capture optimizations. Native, B, other mods and user configurations remain unchanged. Earlier failed attempts remain recorded.')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('mode', choices=['audit','deploy'])
    ap.add_argument('--candidate', required=True)
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--evidence', required=True)
    args = ap.parse_args()
    out, bundle, evidence = [(ROOT/n).resolve() for n in (args.candidate,args.bundle,args.evidence)]
    require(out.parent == bundle.parent == ROOT/'build/m52' and evidence.parent == out, 'Invalid paths')
    proof = audit(out,bundle,evidence)
    if args.mode == 'audit':
        require(not (out/'release-audit.json').exists(), 'Audit already exists')
        save(out/'release-audit.json', proof)
        print(json.dumps(proof,ensure_ascii=False))
        return
    require(read(out/'release-audit.json') == proof, 'Audit changed')
    receipt = out/'deployment.json'
    require(not receipt.exists(), 'Deployment already exists')
    m, runtime = read(out/'prepared.json'), read(bundle/'inputs.json')
    target, source = ROOT/'release/RConnectMod.swf', out/'RConnectMod.swf'
    backup = ROOT/'build/backup'/('a22-motion-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False)
    old = backup/'RConnectMod.before.swf'
    shutil.copy2(target,old)
    require(sha(old) == m['control_sha256'], 'Backup mismatch')
    d = dict(status='deploying', at=datetime.datetime.now().astimezone().isoformat(), proof=proof,
             backup={str(target):str(old)}, script_sha256=sha(__file__))
    save(receipt,d)
    overrides = {target.relative_to(GAME).as_posix().lower():m['candidate_sha256']}
    replaced = False
    try:
        verify_install(runtime)
        replace(source,target,m['candidate_sha256']);replaced=True
        verify_install(runtime,overrides)
        d['status']='deployed-awaiting-smoke';save(receipt,d)
        command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
                 '--candidate',str(target),'--smoke','--all-mods','--visible-windows',
                 '--seconds','180','--expected-version',m['version']]
        with (out/'installed-smoke.log').open('w',encoding='utf-8') as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        output=(out/'installed-smoke.log').read_text(encoding='utf-8')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',output,re.M)
        require(result.returncode==0 and match is not None,'Ordinary-loader smoke failed')
        folder=ROOT/'build/cooperation'/match[1];run=read(folder/'run.json')
        require(run['sha256']==m['candidate_sha256'] and not run['solo'],'Smoke binary/mode')
        for role in ('host','join'):
            inp=run['inputs'][role]
            require(inp['game']==m['candidate_game_sha256'] and 'production' not in inp,'Smoke must use ordinary loader')
            for n,h in inp['modules'].items():
                n=n.replace('\\','/')
                require(h==overrides.get(n.lower(),runtime['files'].get(n)),'Smoke module '+n)
            log=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
            require('v'+m['version']+' initialized' in log and 'tick 200' in log,'Smoke heartbeat')
            stdout=(folder/(role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
            require(re.search(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught|out of memory)\b',
                              stdout,re.I) is None,'Smoke AIR/native exception')
        verify_install(runtime,overrides)
        d.update(status='deployed-smoke-passed',smoke_run=match[1],smoke_run_sha256=sha(folder/'run.json'))
    except BaseException as error:
        d.update(status='smoke-failed',error=str(error));save(receipt,d)
        if replaced:
            require(sha(target)==m['candidate_sha256'],'External change prevents safe rollback')
            replace(old,target,m['control_sha256'])
        d['status']='rolled-back';save(receipt,d)
        raise
    save(receipt,d)
    print(json.dumps(d,ensure_ascii=False))


if __name__=='__main__':
    main()
