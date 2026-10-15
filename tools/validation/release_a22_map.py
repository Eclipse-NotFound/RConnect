"""Audit and install only the A22 expedition-seed pair; rollback failed smoke.

Uses current-installation inputs, exact production-byte drivers and the ordinary
loader for smoke. Does not close user games or write any user save/configuration.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path,value): Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def require(ok,message):
    if not ok: raise RuntimeError(message)

def verify_install(frozen,overrides=None):
    overrides=overrides or {}
    for name,digest in frozen['files'].items():
        require(sha(GAME/name)==overrides.get(name.lower(),digest),'Installation changed: '+name)

def audit(out,bundle):
    m=read(out/'prepared.json');frozen=read(bundle/'inputs.json')
    require(m['kind']=='isolated-a22-map-only','Only the independent map-only candidate is eligible')
    require(set(m['changes'])=={'src/RConnectMod.as','src/rconnect/core/MapGeneration.as','src/rconnect/core/RoomSync.as','src/rconnect/game/GameBridge.as'},'Unexpected production changes')
    for name,digest in {**m['source'],**m['inputs']}.items():require(sha(out/name)==digest,name)
    for name,digest in frozen['files'].items():require(sha(bundle/'game'/name)==digest,name)
    require(sha(out/'RConnectMod.swf')==m['candidate_sha256'],'Module mismatch')
    require(sha(out/'native/pfe.swf')==m['candidate_game_sha256'],'Native mismatch')
    require(sha(out/'original/pfe.swf')==m['original_game_sha256'],'Original mismatch')
    require(m['loader_unchanged'] and m['non_code_tags_unchanged'],'Native preservation missing')
    require((out/'native/before/scripts/MainFE.as').read_bytes()==(out/'native/after/scripts/MainFE.as').read_bytes(),'Loader changed')
    version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(out/'src/RConnectMod.as').read_text()).group(1)
    runs={};legacy_warnings={};compatibility_failures={};picker_rows={};picker_failures={}
    cases=[('solo-control-01','SoloMapGenerationTestDoc',True,True),
           ('solo-candidate-01','SoloMapGenerationTestDoc',False,True),
           ('network-map-01','NativeMapGenerationTestDoc',False,False),
           ('picker-map-01','MapGenerationTestDoc',False,False),
           ('picker-control-01','MapGenerationTestDoc',True,False)]
    expected_passes={'solo-control-01':{'host':14},'solo-candidate-01':{'host':16},
                     'network-map-01':{'host':22,'join':7},'picker-map-01':{'host':10,'join':3},
                     'picker-control-01':{'host':10,'join':3}}
    for label,entry,control,solo in cases:
        path=out/(label+'-result.json');r=read(path)
        require(r['entry']==entry and r['control']==control and r['solo']==solo,label+' mode mismatch')
        require(r['inputs']['prepared']==sha(out/'prepared.json') and r['inputs']['runtime']==sha(bundle/'inputs.json'),label+' provenance mismatch')
        require(r['runtime_matches_installation'] and not r['installation_changes'],label+' installation guard')
        require(r['inputs']['runner']==sha(ROOT/'tools/run_coop_regression.py'),label+' runner changed')
        require(r['inputs']['script']==sha(ROOT/'tools/validation/run_a22_map_refresh.py'),label+' orchestrator changed')
        folder=ROOT/'build/cooperation'/r['run'];actual=read(folder/'run.json')
        require(sha(folder/'run.json')==r['run_sha256'],label+' receipt changed')
        require(sha(folder/'input.json')==actual['input_manifest_sha256'],label+' input manifest changed')
        require(actual['solo']==solo and len(actual['pids'])==(1 if solo else 2),label+' process count')
        roles=('host',) if solo else ('host','join')
        for role in roles:
            log=folder/(role+'.log');text=log.read_text(encoding='utf-8-sig')
            require(sha(log)==r[role]['log_sha256'],label+' log changed')
            require('v'+('0.2.22-dev' if control else version)+' initialized' in text,label+' version absent')
            require(r[role]['done'] and r[role]['passed']==expected_passes[label][role],label+' incomplete')
            bad=[s for s in text.splitlines() if s.startswith('COOP FAIL ')]
            if entry=='MapGenerationTestDoc':
                # This separate generator's original red assertions stay red.
                # It bypasses Land's rnd constructor entirely. The user has
                # confirmed ordinary Pip expeditions as the requested scope.
                expected_bad=['COOP FAIL map-generation joining map geometry equals host\'s newly generated map round='+str(i) for i in range(3)] if role=='host' else []
                require(bad==expected_bad and r['exit']==1,'Changed RandomRooms failure boundary')
                picker_failures[label+'/'+role]=bad
                if role=='host':picker_rows[label]=[json.loads(s[len('MAP GENERATION '):]) for s in text.splitlines() if s.startswith('MAP GENERATION ')]
            elif control:
                require(len(bad)==2 and all('new expedition changes layout' in s for s in bad),'Control did not reproduce only the two fresh-layout failures')
            else:require(not bad and r['exit']==0,label+' failed')
            for marker in ('game error dialog','RConnectRoom: ERROR','handoff timed out','Error #1009'):
                require(marker not in text,label+' '+marker)
            warnings=[s for s in text.splitlines() if "obj spawn '" in s and 'failed:' in s]
            if warnings:
                control_run=read(out/'picker-control-01-result.json')['run']
                old_logs=[ROOT/'build/cooperation'/run/'join.log' for run in ('3998a6ac20',control_run)]
                old_text='\n'.join(p.read_text(encoding='utf-8-sig') for p in old_logs)
                require(all(s in old_text for s in warnings),'Previously unrecorded object-spawn warning')
                legacy_warnings[label+'/'+role]=dict(lines=sorted(set(warnings)),
                    original_controls={p.parent.name:sha(p) for p in old_logs})
            expected_native=m['original_game_sha256' if control else 'candidate_game_sha256']
            require(actual['inputs'][role]['game']==expected_native,label+' native input')
            require(actual['inputs'][role]['production']==m['control_sha256' if control else 'candidate_sha256'],label+' production input')
            require(actual['inputs'][role]['driver']==r['inputs']['driver']['EffectsDriver.swf'],label+' driver input')
            require(actual['inputs'][role]['harness']==r['inputs']['driver']['EffectsHarness.swf'],label+' harness input')
            for name,digest in actual['inputs'][role]['modules'].items():
                name=name.replace('\\','/')
                if not name.lower().startswith('mods/rconnect/'):
                    require(digest==frozen['files'][name],label+' third-party input '+name)
            if solo:
                cfg=read(folder/'configuration'/role/'mods/Rconnect/release/config.txt')
                require(cfg['autoRole']=='' and 'welcome id=' not in text and 'mode=hosting' not in text,label+' must remain offline')
        record={'result_sha256':sha(path),'run':r['run'],'counts':{role:{k:r[role][k] for k in ('passed','failed')} for role in roles}}
        if entry=='MapGenerationTestDoc':compatibility_failures[label]=record
        else:runs[label]=record
    before=picker_rows['picker-control-01'];after=picker_rows['picker-map-01']
    require(len(before)==len(after)==3,'Incomplete explicit-seed comparison')
    require(before[0]['seed']==after[0]['seed'] and before[0]['signature']==after[0]['signature'],
            'Fixed-seed host geometry changed outside the native generator')
    require(picker_failures['picker-control-01/host']==picker_failures['picker-map-01/host'],'Different failure set')
    return dict(version=version,prepared_sha256=sha(out/'prepared.json'),runtime_sha256=sha(bundle/'inputs.json'),
                candidate_sha256=m['candidate_sha256'],candidate_game_sha256=m['candidate_game_sha256'],runs=runs,
                legacy_warnings=legacy_warnings,compatibility_failures=compatibility_failures,
                scope='User-confirmed ordinary Pip expeditions only. 45 positive core assertions. RandomRooms remains 13 PASS / 3 FAIL in both installed control and candidate; not counted as a pass. Existing A22 Trap spawn warnings also remain unresolved.')

def replace(source,target,digest):
    temporary=target.with_name(target.name+'.'+uuid.uuid4().hex+'.tmp')
    try:
        shutil.copy2(source,temporary);require(sha(temporary)==digest,'Staging mismatch')
        os.replace(temporary,target);require(sha(target)==digest,'Replacement mismatch')
    finally:
        if temporary.exists():temporary.unlink()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['audit','deploy'])
    ap.add_argument('--candidate',required=True);ap.add_argument('--bundle',required=True);args=ap.parse_args()
    out=(ROOT/args.candidate).resolve();bundle=(ROOT/args.bundle).resolve()
    require(out.parent==bundle.parent==ROOT/'build/m52','Unexpected scope')
    proof=audit(out,bundle);frozen=read(bundle/'inputs.json');m=read(out/'prepared.json')
    verify_install(frozen)
    if args.mode=='audit':
        require(not (out/'release-audit.json').exists(),'Audit already exists')
        save(out/'release-audit.json',proof);print(json.dumps(proof,ensure_ascii=False));return
    require(read(out/'release-audit.json')==proof,'Audit changed')
    receipt=out/'deployment.json';require(not receipt.exists(),'Deployment already exists')
    stamp=datetime.datetime.now().astimezone().isoformat()
    backup=ROOT/'build/backup'/('a22-map-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False)
    targets=[(GAME/'pfe.swf',out/'native/pfe.swf',m['original_game_sha256'],m['candidate_game_sha256']),
             (ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf',m['control_sha256'],m['candidate_sha256'])]
    saved={}
    for target,source,old,new in targets:
        require(sha(target)==old and sha(source)==new,'Target changed')
        p=backup/(target.stem+'.before.swf');shutil.copy2(target,p);require(sha(p)==old,'Backup mismatch');saved[str(target)]=str(p)
    d=dict(status='deploying',at=stamp,version=proof['version'],proof=proof,backup=saved,
           authorization='用户既有修复及候选部署授权；本次只修复单人/联机探索种子，保留其他安装改动。',
           script_sha256=sha(__file__))
    save(receipt,d)
    overrides={str(t.relative_to(GAME)).replace('\\','/').lower():new for t,_,_,new in targets}
    changed=[]
    try:
        for target,source,old,new in targets:replace(source,target,new);changed.append((target,old,new))
        verify_install(frozen,overrides)
        d['status']='deployed-awaiting-smoke';save(receipt,d)
        command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
                 '--candidate',str(ROOT/'release/RConnectMod.swf'),'--smoke','--all-mods','--visible-windows',
                 '--seconds','180','--expected-version',proof['version']]
        with (out/'installed-smoke.log').open('w',encoding='utf-8') as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        log=(out/'installed-smoke.log').read_text(encoding='utf-8');match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',log,re.M)
        require(result.returncode==0 and match is not None,'Ordinary-loader smoke failed')
        folder=ROOT/'build/cooperation'/match[1];r=read(folder/'run.json')
        require(r['sha256']==m['candidate_sha256'] and not r['solo'],'Smoke binary/mode')
        for role in ('host','join'):
            inp=r['inputs'][role];require(inp['game']==m['candidate_game_sha256'] and 'production' not in inp,'Smoke must use ordinary loader')
            for name,digest in inp['modules'].items():
                name=name.replace('\\','/')
                require(digest==overrides.get(name.lower(),frozen['files'].get(name)),'Smoke module '+name)
            text=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
            require('v'+proof['version']+' initialized' in text and 'tick 200' in text,'Smoke heartbeat')
        verify_install(frozen,overrides)
        d.update(status='deployed-smoke-passed',smoke_run=match[1],smoke_run_sha256=sha(folder/'run.json'))
    except BaseException as error:
        d.update(status='smoke-failed',error=str(error))
        for target,old,new in reversed(changed):
            require(sha(target)==new,'External change prevents safe rollback: '+str(target))
            replace(Path(saved[str(target)]),target,old)
        d['status']='rolled-back';save(receipt,d);raise
    save(receipt,d);print(json.dumps(d,ensure_ascii=False))

if __name__=='__main__':main()
