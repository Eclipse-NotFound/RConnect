"""Release the qualified A22 follow-up and its optional MSW target contract.

Preserves the installed native game, configuration, and every other module.
Runs ordinary-loader smoke after replacing only the two audited module files.
"""
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
from run_a22_release_checks import CASES

OVERRIDES = {
    'src/fe/unit/RConnectAnimationAccess.as', 'src/rconnect/core/EnemyGrip.as',
    'src/rconnect/core/RoomSync.as', 'src/rconnect/core/Session.as',
    'src/rconnect/game/EnergyImpactVisuals.as', 'src/rconnect/game/GameBridge.as',
    'src/rconnect/game/PeerHitUnit.as', 'src/rconnect/game/ProjectileVisuals.as',
    'src/rconnect/game/RemoteMotion.as', 'src/rconnect/game/WallImpactVisuals.as',
}

def audit(out, bundle, msw, prefix, hidden_pack):
    m, runtime, mm = read(out/'prepared.json'), read(bundle/'inputs.json'), read(msw/'prepared.json')
    require(m['kind'] == 'isolated-a22-followup' and m['native_unchanged'], 'Wrong candidate type')
    base = Path(m['installed_baseline'])
    if not base.is_absolute():
        base = ROOT/base
    bm = read(base/'prepared.json')
    require(sha(base/'deployment.json') == m['installed_deployment_sha256'], 'Installed baseline changed')
    require(read(base/'deployment.json')['status'] == 'deployed-smoke-passed', 'Baseline not installed')
    require(m['control_sha256'] == bm['candidate_sha256'], 'Wrong control')
    require(m['original_game_sha256'] == m['candidate_game_sha256'] == bm['candidate_game_sha256'], 'Native game changed')
    require(set(m['source']) == set(bm['source']), 'Unexpected source set')
    differences = {n for n, h in m['source'].items() if bm['source'][n] != h}
    require(differences == OVERRIDES | {'src/RConnectMod.as'}, 'Unexpected A changes')
    for n, h in {**m['source'], **m['inputs']}.items():
        require(sha(out/n) == h, 'A input changed: '+n)
    for n in OVERRIDES:
        require(sha(ROOT/'experimental/a22-fixes'/n) == m['source'][n], 'A override changed: '+n)
    require(sha(out/'RConnectMod.swf') == m['candidate_sha256'], 'A binary changed')
    require(sha(out/'control.swf') == m['control_sha256'], 'A control changed')
    require(sha(out/'native/pfe.swf') == m['candidate_game_sha256'], 'Native copy changed')
    for n, h in runtime['files'].items():
        require(sha(bundle/'game'/n) == h, 'Runtime changed: '+n)
    version = re.search(r'VERSION:String\s*=\s*"([^"]+)"', (out/'src/RConnectMod.as').read_text()).group(1)
    require(version != m['control_version'], 'Version must change')
    require(set(mm['overrides']) == {'MSWSmartWeapons.as', 'MoreSkillsWeaponsMod.as'}, 'Unexpected MSW changes')
    require(mm['contract'] == 'rconnectSmartTargetAllowed-v1', 'Wrong MSW contract')
    for n, h in mm['source'].items():
        require(sha(msw/n) == h, 'MSW input changed: '+n)
    require(sha(msw/'MoreSkillsWeaponsMod.swf') == mm['candidate_sha256'], 'MSW binary changed')
    require(sha(ROOT/'experimental/a22-fixes/msw-src/MSWSmartWeapons.as') == mm['source']['src/MSWSmartWeapons.as'], 'MSW override changed')
    installed_msw = ROOT.parent/'MoreSkills&Weapons/build/out/flashbang'
    require(sha(installed_msw/'installation.json') == mm['installed_receipt_sha256'], 'MSW installation record changed')
    require(sha(installed_msw/'source-manifest.json') == mm['installed_source_manifest'], 'MSW baseline record changed')
    for n, h in mm['baseline'].items():
        require(sha(installed_msw/'final-source'/n) == h, 'MSW baseline changed: '+n)
        if n.removeprefix('src/') not in mm['overrides']:
            require(mm['source'][n] == h, 'Unexpected MSW production change: '+n)
    old_entry = (installed_msw/'final-source/src/MoreSkillsWeaponsMod.as').read_text(encoding='utf-8-sig')
    new_entry = (msw/'src/MoreSkillsWeaponsMod.as').read_text(encoding='utf-8-sig')
    require(new_entry == old_entry.replace('"1.16.0-flashbang"', '"'+mm['version']+'"'), 'MSW version entry changed behavior')
    hm = read(hidden_pack/'prepared.json')
    require(hm['kind']=='isolated-a22-testpack' and hm['parent_prepared_sha256']==sha(out/'prepared.json'), 'Hidden testpack parent')
    require(hm['source']==m['source'] and hm['candidate_sha256']==m['candidate_sha256'], 'Hidden testpack changed production')
    require(sha(hidden_pack/'RConnectMod.swf')==m['candidate_sha256'] and sha(hidden_pack/'native/pfe.swf')==m['candidate_game_sha256'], 'Hidden testpack binary')
    for n,h in {**hm['source'],**hm['inputs']}.items():require(sha(hidden_pack/n)==h,'Hidden testpack input '+n)
    # Preserve the original failed run. The installed control reproduced the
    # cancellation while its native battle gate was still active; testpack 04
    # waits for that gate, without changing gameplay or dropping assertions.
    failed = read(out/(prefix+'-hidden-result.json'))
    require(failed['exit']==1 and failed['join']['failed']==1 and not failed['installation_changes'], 'Missing original failure')
    control_pack=ROOT/'build/m52/a22-testpack-15-03'
    negative_path=control_pack/'hidden-timing-control-01-result.json'
    negative=read(negative_path)
    require(negative['control'] and negative['exit']==1 and negative['join']['failed']==1, 'Missing native-gate control')
    require(not negative['installation_changes'] and negative['inputs']['runtime']==sha(bundle/'inputs.json'), 'Control runtime')
    neg_folder=ROOT/'build/cooperation'/negative['run'];neg_run=read(neg_folder/'run.json')
    require(sha(neg_folder/'run.json')==negative['run_sha256'] and neg_run['inputs']['join']['production']==m['control_sha256'], 'Control binary/receipt')
    neg_log=neg_folder/'join.log';require(sha(neg_log)==negative['join']['log_sha256'], 'Control trace changed')
    lines=neg_log.read_text(encoding='utf-8-sig').splitlines()
    traces=[row for line in lines if line.startswith('HIDDEN TEST action-trace ')
            for row in json.loads(line[len('HIDDEN TEST action-trace '):])]
    completion=[row for before,row in zip(traces,traces[1:])
                if before['selected'] and before['remaining']==0 and not row['selected'] and not row['key'] and not row['ready']]
    require(completion and all(row['exitBlocked']==2 and row['battle']>0 for row in completion), 'Native battle rejection not observed')
    excluded=dict(original_run=failed['run'],original_result_sha256=sha(out/(prefix+'-hidden-result.json')),
                  control_run=negative['run'],control_result_sha256=sha(negative_path),native_completion=completion,
                  reason='Door completed during native battle prohibition. Test now waits for native permission; old failures remain red.')
    runs, warnings = {}, {}
    for name, entry, land, seconds in CASES:
        label = prefix+'-'+name
        evidence=hidden_pack if name=='hidden' else out
        if name=='hidden':entry='A22HiddenTimingTestDoc'
        path = evidence/(label+'-result.json')
        r = read(path)
        require(r['entry'] == entry and not r['control'] and not r['solo'], label+' mode')
        require(r['exit'] == 0 and r['runtime_matches_installation'] and not r['installation_changes'], label+' result')
        for key, value in [('prepared',sha(evidence/'prepared.json')), ('runtime',sha(bundle/'inputs.json')),
                           ('runner',sha(ROOT/'tools/run_coop_regression.py')),
                           ('script',sha(ROOT/'tools/validation/run_a22_map_refresh.py')),
                           ('msw',mm['candidate_sha256'])]:
            require(r['inputs'][key] == value, label+' provenance '+key)
        folder = ROOT/'build/cooperation'/r['run']
        actual = read(folder/'run.json')
        require(sha(folder/'run.json') == r['run_sha256'], label+' receipt changed')
        require(sha(folder/'input.json') == actual['input_manifest_sha256'], label+' inputs changed')
        require(not actual['solo'] and len(actual['pids']) == 2, label+' processes')
        for role in ('host','join'):
            log = folder/(role+'.log')
            text = log.read_text(encoding='utf-8-sig')
            require(sha(log) == r[role]['log_sha256'], label+' log changed')
            require('v'+version+' initialized' in text, label+' wrong version')
            require(r[role]['done'] and r[role]['passed'] > 0 and r[role]['failed'] == 0, label+' incomplete')
            if name=='hidden':
                require(r[role]['passed']==(121 if role=='host' else 157), 'Twelve hidden-room round trips incomplete')
            for marker in ('COOP FAIL ', 'game error dialog', 'RConnectRoom: ERROR', 'handoff timed out',
                           'RConnectPause: failed', 'RConnectGrip: failed', 'Error #1009'):
                require(marker not in text, label+' '+marker)
            found = [s for s in text.splitlines() if "obj spawn '" in s and 'failed:' in s]
            if found:
                # Established pre-existing warnings, never reclassified as fixes.
                controls = [ROOT/'build/cooperation'/n/'join.log' for n in ('e6f23851c9','3998a6ac20')]
                old_text = '\n'.join(p.read_text(encoding='utf-8-sig') for p in controls)
                require(all(s in old_text for s in found), label+' new spawn warning')
                warnings[label+'/'+role] = dict(lines=sorted(set(found)), controls={p.parent.name:sha(p) for p in controls})
            inp = actual['inputs'][role]
            require(inp['game'] == m['candidate_game_sha256'] and inp['production'] == m['candidate_sha256'], label+' binary input')
            require(inp['driver'] == r['inputs']['driver']['EffectsDriver.swf'] and inp['harness'] == r['inputs']['driver']['EffectsHarness.swf'], label+' driver input')
            for n, h in inp['modules'].items():
                n = n.replace('\\','/')
                if n.lower().startswith('mods/rconnect/'):
                    continue
                expected = mm['candidate_sha256'] if n.lower() == 'mods/moreskills&weapons/release/moreskillsweaponsmod.swf' else runtime['files'][n]
                require(h == expected, label+' third-party input '+n)
            for save_input in r['inputs']['saves'].values():
                require(sha(save_input['path']) == save_input['sha256'], label+' save template changed')
        runs[name] = dict(run=r['run'], result_sha256=sha(path), counts={role:{k:r[role][k] for k in ('passed','failed')} for role in ('host','join')})
    verify_install(runtime)
    require(sha(ROOT/'release/RConnectMod.swf') == m['control_sha256'], 'Installed A changed')
    require(sha(ROOT.parent/'MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf') == mm['original_sha256'], 'Installed MSW changed')
    return dict(version=version, msw_version=mm['version'], prefix=prefix, prepared_sha256=sha(out/'prepared.json'),
                msw_prepared_sha256=sha(msw/'prepared.json'), runtime_sha256=sha(bundle/'inputs.json'),
                candidate_sha256=m['candidate_sha256'], msw_sha256=mm['candidate_sha256'],
                native_sha256=m['candidate_game_sha256'], runs=runs, legacy_warnings=warnings,
                hidden_testpack=str(hidden_pack.relative_to(ROOT)),hidden_testpack_sha256=sha(hidden_pack/'prepared.json'),
                excluded_test_precondition_failure=excluded,
                limits='Room redraw stalls remain. Complete failure to throw was not reproduced; this fixes confirmed delayed-coordinate direction. Existing RandomRooms explicit-seed compatibility failures remain. B is unchanged.')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('mode',choices=['audit','deploy'])
    ap.add_argument('--candidate',required=True);ap.add_argument('--bundle',required=True);ap.add_argument('--msw',required=True)
    ap.add_argument('--prefix',default='release')
    ap.add_argument('--hidden-testpack',required=True)
    args=ap.parse_args()
    out,bundle,msw,hidden=[(ROOT/n).resolve() for n in (args.candidate,args.bundle,args.msw,args.hidden_testpack)]
    require(all(p.parent==ROOT/'build/m52' for p in (out,bundle,msw,hidden)), 'Unexpected paths')
    require(re.fullmatch(r'[A-Za-z0-9_-]+', args.prefix), 'Invalid result prefix')
    proof=audit(out,bundle,msw,args.prefix,hidden)
    if args.mode=='audit':
        require(not (out/'release-audit.json').exists(),'Audit exists')
        save(out/'release-audit.json',proof);print(json.dumps(proof,ensure_ascii=False));return
    require(read(out/'release-audit.json')==proof,'Audit changed')
    receipt=out/'deployment.json';require(not receipt.exists(),'Deployment exists')
    runtime=read(bundle/'inputs.json');m=read(out/'prepared.json');mm=read(msw/'prepared.json')
    backup=ROOT/'build/backup'/('a22-fixes-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False)
    targets=[(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf',m['control_sha256'],m['candidate_sha256']),
             (ROOT.parent/'MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf',msw/'MoreSkillsWeaponsMod.swf',mm['original_sha256'],mm['candidate_sha256'])]
    saved={}
    for target,source,old,new in targets:
        require(sha(target)==old and sha(source)==new,'Target changed')
        p=backup/(target.stem+'.before.swf');shutil.copy2(target,p);require(sha(p)==old,'Backup mismatch');saved[str(target)]=str(p)
    d=dict(status='deploying',at=datetime.datetime.now().astimezone().isoformat(),proof=proof,backup=saved,
           authorization='用户要求部署之前未部署的修正；包括 A 版友伤开启时 MSW 智能武器锁定队友的必要接口。',script_sha256=sha(__file__))
    save(receipt,d)
    overrides={t.relative_to(GAME).as_posix().lower():new for t,_,_,new in targets}
    changed=[]
    try:
        for target,source,old,new in targets:
            replace(source,target,new);changed.append((target,old,new))
        verify_install(runtime,overrides)
        d['status']='deployed-awaiting-smoke';save(receipt,d)
        command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
                 '--candidate',str(ROOT/'release/RConnectMod.swf'),'--smoke','--all-mods','--visible-windows',
                 '--seconds','180','--expected-version',proof['version']]
        with (out/'installed-smoke.log').open('w',encoding='utf-8') as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        text=(out/'installed-smoke.log').read_text(encoding='utf-8')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',text,re.M)
        require(result.returncode==0 and match is not None,'Ordinary-loader smoke failed')
        folder=ROOT/'build/cooperation'/match[1];r=read(folder/'run.json')
        require(r['sha256']==m['candidate_sha256'] and not r['solo'],'Smoke binary/mode')
        for role in ('host','join'):
            inp=r['inputs'][role]
            require(inp['game']==m['candidate_game_sha256'] and 'production' not in inp,'Smoke must use ordinary loader')
            for n,h in inp['modules'].items():
                n=n.replace('\\','/')
                require(h==overrides.get(n.lower(),runtime['files'].get(n)),'Smoke module '+n)
            log=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
            require('v'+proof['version']+' initialized' in log and 'tick 200' in log,'Smoke heartbeat')
        verify_install(runtime,overrides)
        d.update(status='deployed-smoke-passed',smoke_run=match[1],smoke_run_sha256=sha(folder/'run.json'))
    except BaseException as error:
        d.update(status='smoke-failed',error=str(error));save(receipt,d)
        for target,old,new in reversed(changed):
            require(sha(target)==new,'External change prevents safe rollback: '+str(target))
            replace(Path(saved[str(target)]),target,old)
        d['status']='rolled-back';save(receipt,d);raise
    save(receipt,d);print(json.dumps(d,ensure_ascii=False))

if __name__=='__main__':main()
