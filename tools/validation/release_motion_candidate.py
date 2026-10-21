"""Audit the exact motion2 candidate; installation needs its density-limit decision.

Never changes the host or other mods. Failed density runs remain failed; this
can only install an explicitly accepted limited candidate, not certify FPS.
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

from check_coop_bundle import ROOT, M52, read, save, sha
from run_security_terminals import installation, test_port
from release_coop_bundle import replace, check_log
from runtime_memory import snapshot
from air_test_inventory import air_processes

CANDIDATE = M52/'motion-continuity-02'
EXPECTED = '6e03c9a719bcd23c029ee61bef6a8dc334abd44d28e6e4885578b00b00f98cef'
OLD = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
HOST = '5432a3b9b6820a94ae15ac0a97b13c4edc534d3dc6dbed12063e0fe47677b71d'
CORE = ['motion2-candidate-jump-02', 'motion2-candidate-held-01',
        'motion2-candidate-continuity-02', 'motion2-candidate-fast-03',
        'motion2-candidate-continuity-03', 'motion2-candidate-fast-04']
DENSITY = ['motion2-baseline-density-01', 'motion2-candidate-density-01']


def audit():
    manifest = read(CANDIDATE/'prepared.json')
    assert manifest['compiled'] and manifest['compile_exit'] == 0
    assert sha(CANDIDATE/'RConnectMod.swf') == manifest['candidate_sha256'] == EXPECTED
    assert manifest['base_sha256'] == OLD and manifest['version'] == '0.2.24-motion2'
    for name, digest in {**manifest['source'], **manifest['inputs']}.items():
        assert sha(CANDIDATE/name) == digest, name
    base = read(M52/'coop-bundle-04/prepared.json')
    changed = {name for name, digest in manifest['source'].items() if base['source'].get(name) != digest}
    assert changed == {'src/RConnectMod.as', 'src/rconnect/game/RemoteMotion.as',
                       'src/rconnect/game/ProjectileVisuals.as'}
    current = installation()
    assert current['pfe.swf'] == HOST and current['mods/Rconnect/release/RConnectMod.swf'] == OLD
    evidence = {}
    for name in CORE + DENSITY:
        folder = M52/name
        intent, result = read(folder/'intent.json'), read(folder/'result.json')
        assert all(result[k] for k in ('installation_unchanged', 'runner_unchanged',
            'air_inventory_unchanged', 'exclusive_air_confirmed', 'same_runtime_as_reference'))
        assert not result['memory']['stopped_for_pressure']
        expected_binary = OLD if name == DENSITY[0] else EXPECTED
        assert intent['candidate_sha256'] == expected_binary
        # Earlier evidence is explicitly retained on its recorded host. Only
        # the host may have changed; current-host core checks below are required.
        assert {k:v for k,v in intent['installation'].items() if k != 'pfe.swf'} == {
            k:v for k,v in current.items() if k != 'pfe.swf'}
        run = ROOT/'build/cooperation'/result['run']
        actual = read(run/'run.json')
        assert sha(run/'input.json') == actual['input_manifest_sha256']
        for role in ('host','join'):
            r = result['roles'][role]
            assert sha(run/(role+'.log')) == r['log_sha256']
            assert r['done'] and r['version'] and r['checks'] > 0
            assert actual['inputs'][role]['production'] == expected_binary
            assert actual['inputs'][role]['game'] == intent['installation']['pfe.swf']
            if name in CORE:
                assert not r['errors']
                check_log(run, role, manifest['version'])
        if name in CORE:
            assert result['passed'] and result['exit_code'] == 0
        else:
            # Preserve the seven exact legacy density failures, never turn
            # their failed result or exit status green.
            assert not result['passed'] and result['exit_code'] == 1
            assert result['roles']['host']['errors'] == []
            assert result['roles']['join']['errors'] == [
                'COOP FAIL network-state 80 enemies keep stage frames progressing'] * 7
        if name in CORE[-2:]:
            assert intent['installation'] == current
        evidence[name] = dict(result_sha256=sha(folder/'result.json'), run=result['run'],
            host_sha256=intent['installation']['pfe.swf'], passed=result['passed'],
            checks={role:result['roles'][role]['checks'] for role in ('host','join')})
    for name, count in [('motion2-clock-candidate-01',37), ('motion2-clock-legacy-01',18),
                        ('motion2-projectile-candidate-01',15)]:
        p=M52/name/'result.json';r=read(p)
        assert r['fail']==0 and r['pass']==count
        inputs=read(p.parent/'inputs.json')
        assert inputs['files']['rconnect/game/RemoteMotion.as']==manifest['source']['src/rconnect/game/RemoteMotion.as']
        if name=='motion2-projectile-candidate-01':
            assert inputs['files']['rconnect/game/ProjectileVisuals.as']==manifest['source']['src/rconnect/game/ProjectileVisuals.as']
        evidence[name]=dict(result_sha256=sha(p), input_sha256=sha(p.parent/'inputs.json'),
                            checks=count, game_loaded=False)
    asset=M52/'motion2-native-assets-candidate-01'
    asset_intent,asset_result=read(asset/'intent.json'),read(asset/'result.json')
    assert asset_intent['candidate_sha256']==EXPECTED
    assert asset_result['passed'] and asset_result['checks']==14 and not asset_result['tcp_test']
    evidence[asset.name]=dict(result_sha256=sha(asset/'result.json'),checks=14,tcp_test=False,
                             host_sha256=asset_intent['installation']['pfe.swf'])
    latest_old=read(M52/'motion2-baseline-fast-06/result.json')
    latest_new=read(M52/'motion2-candidate-fast-04/result.json')
    timing={role:dict(old=latest_old['roles'][role]['frame_intervals'],
                      candidate=latest_new['roles'][role]['frame_intervals']) for role in ('host','join')}
    return dict(version=manifest['version'], candidate_sha256=EXPECTED,
        candidate_manifest_sha256=sha(CANDIDATE/'prepared.json'), baseline=current,
        evidence=evidence, changed=sorted(changed), current_host_fast_timing=timing,
        qualification='limited motion candidate; density FPS gate still FAILS',
        full_performance_qualified=False, density_gate_passed=False,
        authorization_required='Explicit user acceptance of the retained density limitation',
        recipe_sha256=sha(__file__))


def deploy(out, proof, accepted):
    assert accepted, 'User density-limit decision required; audit alone never permits installation'
    assert not (out/'deployment.json').exists()
    assert snapshot()['free_commit_bytes'] >= 6*1024**3 and not air_processes()
    assert installation() == proof['baseline']
    target=ROOT/'release/RConnectMod.swf'
    backup=ROOT/'build/backup'/('motion2-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False)
    saved=backup/'RConnectMod.before.swf';shutil.copy2(target,saved)
    assert sha(saved)==sha(target)==OLD
    receipt=out/'deployment.json'
    record=dict(status='prepared',target=str(target),before=OLD,after=EXPECTED,
        backup=str(saved),proof_sha256=sha(out/'audit.json'),
        known_limit_accepted=True,full_performance_qualified=False)
    save(receipt,record)
    changed=False
    try:
        assert installation()==proof['baseline']
        replace(CANDIDATE/'RConnectMod.swf',target,EXPECTED);changed=True
        expected=proof['baseline'].copy();expected['mods/Rconnect/release/RConnectMod.swf']=EXPECTED
        assert installation()==expected
        record['status']='installed-awaiting-smoke';save(receipt,record)
        cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
             '--candidate',str(target),'--smoke','--all-mods','--land','random_mane',
             '--seconds','180','--expected-version',proof['version'],'--port',str(test_port()),
             '--private-desktop','--defer-visible','--wait-host-world',
             '--require-exclusive-air','--registry-wait','600']
        with (out/'installed-smoke.log').open('w',encoding='utf-8') as log:
            code=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT).returncode
        raw=(out/'installed-smoke.log').read_text(encoding='utf-8',errors='replace')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',raw,re.M)
        assert code==0 and match, 'Installed-loader smoke failed'
        run=ROOT/'build/cooperation'/match[1];actual=read(run/'run.json')
        assert actual['sha256']==EXPECTED and not actual['solo']
        timeline=read(run/'memory-timeline.json')
        assert not timeline['stopped_for_pressure'] and not timeline['stopped_for_overlap']
        for role in ('host','join'):
            inp=actual['inputs'][role]
            assert inp['game']==HOST and 'driver' not in inp and 'production' not in inp
            for name,digest in inp['modules'].items():
                assert digest==expected[name.replace('\\','/')], name
            check_log(run,role,proof['version'],True)
        assert installation()==expected
        record.update(status='deployed-smoke-passed',smoke_run=match[1],
                      smoke_run_sha256=sha(run/'run.json'))
    except BaseException as error:
        record.update(status='failed',error=repr(error));save(receipt,record)
        if changed:
            assert sha(target)==EXPECTED,'Concurrent change prevents automatic rollback'
            replace(saved,target,OLD)
        record['status']='rolled-back' if changed else 'not-installed';save(receipt,record)
        raise
    save(receipt,record)
    print(json.dumps(record,ensure_ascii=False),flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--deploy',action='store_true')
    ap.add_argument('--accept-known-density-limit',action='store_true')
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==M52
    proof=audit()
    if not out.exists():out.mkdir();save(out/'audit.json',proof)
    else:assert read(out/'audit.json')==proof
    if args.deploy:deploy(out,proof,args.accept_known_density_limit)
    else:print(json.dumps(dict(output=str(out),qualification=proof['qualification'],
             ready_for_user_decision=True,installed=False),ensure_ascii=False),flush=True)


if __name__=='__main__':main()
