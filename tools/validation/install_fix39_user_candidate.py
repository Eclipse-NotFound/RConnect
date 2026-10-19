"""Install the exact user-requested fix39 candidate; not a full release gate.

The October 19 user requested installation before the remaining dense-scene
work. Preserve its failures, current other modules, and rollback failed smoke.
"""
import argparse
import datetime
import re
import shutil
import subprocess
import sys
from pathlib import Path
from release_a22_map import ROOT, GAME, read, save, sha, require, replace, verify_install


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--attempt',default='01')
    args=parser.parse_args()
    require(re.fullmatch(r'[0-9]{2}',args.attempt) is not None,'Invalid attempt label')
    candidate = ROOT/'build/m52/a22-fixes-39'
    digest = 'a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60'
    previous = 'b2ed7f3a9b1d176dffb2b912d69da8084982906ff71d6fba8367bd36514e84f8'
    prepared = 'ccb9401c418c75a9d014c52187abbcca84eabf0a32b44a198056f7fc7f26fbab'
    require(sha(candidate/'prepared.json') == prepared, 'Frozen receipt changed')
    meta = read(candidate/'prepared.json')
    require(sha(candidate/'RConnectMod.swf') == digest, 'Frozen candidate changed')
    for name, fingerprint in {**meta['source'], **meta['inputs']}.items():
        require(sha(candidate/name) == fingerprint, 'Frozen input changed: '+name)
    evidence = {}
    passes = 0
    for path in candidate.glob('*-result.json'):
        result = read(path)
        require(result['inputs']['prepared'] == prepared, 'Evidence source changed')
        run = ROOT/'build/cooperation'/result['run']
        require(sha(run/'run.json') == result['run_sha256'], 'Evidence run changed')
        for role in ('host', 'join'):
            require(sha(run/(role+'.log')) == result[role]['log_sha256'], 'Evidence log changed')
        if result['exit'] == 0:
            require(all(result[r]['done'] and result[r]['failed'] == 0 for r in ('host','join')), 'Incomplete success')
            passes += sum(result[r]['passed'] for r in ('host','join'))
        evidence[path.name] = dict(sha256=sha(path), run=result['run'], exit=result['exit'])
    require(passes == 739 and len(evidence) == 10, 'Unexpected frozen evidence')
    target = ROOT/'release/RConnectMod.swf'
    require(sha(target) == previous, 'Installation no longer fix15')
    names = read(ROOT/'build/m52/a22-map-runtime-19/inputs.json')['files']
    current = {'files': {n:sha(GAME/n) for n in names}}
    require(current['files']['pfe.swf'] == '2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea', 'Native baseline changed')
    output = ROOT/('build/m52/fix39-user-install-20261019-'+args.attempt)
    output.mkdir(exist_ok=False)
    save(output/'installation-before.json', current)
    backup = output/'RConnectMod.before.swf'
    shutil.copy2(target, backup)
    require(sha(backup) == previous, 'Backup mismatch')
    receipt = dict(status='prepared', full_release_qualified=False,
        authorization='2026-10-19 user: 先部署新版; primary chat explicitly handed off this exact candidate installation.',
        at=datetime.datetime.now().astimezone().isoformat(), version=meta['version'],
        candidate_sha256=digest, previous_sha256=previous, backup=str(backup),
        source_prepared_sha256=prepared, positive_assertions_on_older_dependency_combination=passes,
        evidence=evidence, known_failures=['Dense scenes below 80 frames/8 s; earlier P95 above 200 ms',
            'Earlier loot first-pause 86 ms above 85 ms; full 20-suite final combination remains incomplete'],
        script_sha256=sha(__file__))
    save(output/'deployment.json', receipt)
    overrides={target.relative_to(GAME).as_posix().lower():digest}
    replaced=False
    try:
        verify_install(current)
        replace(candidate/'RConnectMod.swf', target, digest); replaced=True
        verify_install(current, overrides)
        receipt['status']='installed-awaiting-ordinary-loader-smoke';save(output/'deployment.json',receipt)
        print('Installed exact fix39; starting ordinary-loader smoke', flush=True)
        command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
                 '--candidate',str(target),'--smoke','--all-mods','--visible-windows',
                 '--seconds','180','--expected-version',meta['version']]
        with (output/'smoke.log').open('w',encoding='utf-8') as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        text=(output/'smoke.log').read_text(encoding='utf-8')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',text,re.M)
        require(result.returncode==0 and match is not None, 'Ordinary-loader smoke failed')
        folder=ROOT/'build/cooperation'/match[1];run=read(folder/'run.json')
        require(run['sha256']==digest and not run['solo'],'Smoke mode/binary')
        for role in ('host','join'):
            inp=run['inputs'][role]
            require('production' not in inp and inp['game']==current['files']['pfe.swf'],'Smoke native/loader')
            for name,value in inp['modules'].items():
                name=name.replace('\\','/')
                require(value==overrides.get(name.lower(),current['files'].get(name)),'Smoke module changed: '+name)
            log=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
            require('v'+meta['version']+' initialized' in log and 'tick 200' in log,'Smoke version/heartbeat')
            stdout=(folder/(role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
            require(re.search(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught|out of memory)\b',stdout,re.I) is None,'Native exception')
        verify_install(current, overrides)
        receipt.update(status='installed-user-candidate-smoke-passed',smoke_run=match[1],smoke_run_sha256=sha(folder/'run.json'))
    except BaseException as error:
        receipt.update(status='failed',error=str(error));save(output/'deployment.json',receipt)
        if replaced:
            require(sha(target)==digest,'External replacement prevents rollback')
            replace(backup,target,previous)
        receipt['status']='rolled-back';save(output/'deployment.json',receipt)
        raise
    save(output/'deployment.json',receipt)
    print(receipt['status']+' '+str(output),flush=True)


if __name__=='__main__':main()
