"""Audit and install the exact combined A/native pair; rollback on failed smoke."""
import argparse
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid
from check_coop_bundle import CASES, M52, ROOT, read, save, sha, verify
from run_security_terminals import installation, test_port
from runtime_memory import snapshot

GAME=ROOT.parents[1]
ERRORS=re.compile(r'\b(?:Error\s*#\d+|ArgumentError|TypeError|ReferenceError|RangeError|VerifyError|SecurityError|uncaught|out of memory)\b',re.I)

def check_log(folder, role, version, smoke=False):
    text=(folder/(role+'.log')).read_text(encoding='utf-8-sig',errors='replace')
    native=(folder/(role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
    assert 'v'+version+' initialized' in text
    assert ('tick 200' if smoke else 'COOP EFFECTS DONE') in text
    assert not ERRORS.search(native+'\n'+text)
    assert not any('COOP FAIL' in s or ('obj spawn' in s and 'failed' in s)
        or ('RConnect' in s and (' failed:' in s or ' ERROR' in s)) for s in text.splitlines())
    if not smoke:assert 'COOP PASS ' in text
    if role=='join':assert 'welcome id=' in text and 'unitsync matched' in text

def audit(candidate, evidence):
    m=verify(candidate);assert m['compiled'] and sha(candidate/'RConnectMod.swf')==m['sha256']
    selections=read(evidence);assert isinstance(selections,dict)
    expected={r[0]:r[1] for r in CASES};required=set(expected)|{'smoke'};found={};baseline=None
    native=M52/'security-native-02';patch=read(native/'prepared.json')
    assert sha(native/'prepared.json')=='cf029626d99e948b096ea108177d794f78ada338260ce9c00c9f9d7912259cf9'
    assert sha(native/'pfe.swf')==patch['candidate_sha256'] and patch['loader_unchanged'] and patch['non_code_tags_unchanged']
    assert set(selections)==required
    for selected_name,relative in selections.items():
        out=(ROOT/relative).resolve();assert out.parent==M52
        intent=read(out/'intent.json');rows=[r for r in read(out/'result.json') if r['name']==selected_name]
        assert len(rows)==1
        assert intent['candidate_sha256']==m['sha256'] and intent['native']==patch
        drivers=None
        if intent['driver_manifest'] is not None:
            drivers=(ROOT/intent.get('drivers','build/m52/coop-bundle-drivers-01')).resolve();assert drivers.parent==M52
            driver_manifest=read(drivers/'prepared.json')
            assert driver_manifest['candidate_sha256']==m['sha256'] and driver_manifest['source_manifest']==sha(candidate/'prepared.json')
            assert intent['driver_manifest']==sha(drivers/'prepared.json')
            for n,h in driver_manifest['files'].items():assert sha(drivers/n)==h,n
        # WB remains outside this release until separately qualified; never
        # silently substitute a different tested composition at installation.
        assert intent['wb'] is None
        if baseline is None:baseline=intent['installation']
        assert intent['installation']==baseline
        for row in rows:
            name=row['name'];assert name in required and name not in found
            assert row['passed'] and row['exit_code']==0 and not row['installation_changes']
            folder=ROOT/'build/cooperation'/row['run'];actual=read(folder/'run.json')
            assert sha(folder/'run.json')==row['run_sha256'] and actual['sha256']==m['sha256']
            assert not actual['solo'] and len(actual['pids'])==2
            assert sha(folder/'input.json')==actual['input_manifest_sha256']
            assert not read(folder/'memory-timeline.json')['stopped_for_pressure']
            for role in ('host','join'):
                inputs=actual['inputs'][role];assert inputs['game']==patch['candidate_sha256']
                assert sha(folder/(role+'.log'))==row[role]['log_sha256']
                check_log(folder,role,m['version'],name=='smoke')
                if name=='smoke':assert 'production' not in inputs and 'driver' not in inputs
                else:
                    assert inputs['production']==m['sha256']
                    assert read(drivers/name/'driver-input.json')['entry']==expected[name]
                    assert inputs['driver']==sha(drivers/name/'EffectsDriver.swf')
                    assert inputs['harness']==sha(drivers/name/'EffectsHarness.swf')
                for n,h in inputs['assets'].items():
                    assert h==(patch['candidate_sha256'] if n=='pfe.swf' else sha(GAME/n)),n
                for n,h in inputs['modules'].items():
                    if n.replace('\\','/').lower()=='mods/rconnect/release/rconnectmod.swf':
                        assert h==(m['sha256'] if name=='smoke' else inputs['harness'])
                    else:assert h==baseline[n.replace('\\','/')],n
            found[name]=dict(result=relative,result_sha256=sha(out/'result.json'),run=row['run'],
                counts={r:row[r]['checks'] for r in ('host','join')})
    assert set(found)==required,sorted(required-set(found))
    assert installation()==baseline
    assert baseline['pfe.swf']==patch['original_sha256']
    assert baseline['mods/Rconnect/release/RConnectMod.swf']==m['base_sha256']
    return dict(version=m['version'],candidate_sha256=m['sha256'],native_sha256=patch['candidate_sha256'],
        prepared_sha256=sha(candidate/'prepared.json'),evidence_sha256=sha(evidence),baseline=baseline,runs=found)

def replace(source, target, digest):
    assert sha(source)==digest
    temp=target.with_name(target.name+'.coop-'+uuid.uuid4().hex+'.tmp')
    try:
        shutil.copyfile(source,temp);assert sha(temp)==digest
        temp.replace(target);assert sha(target)==digest
    finally:
        if temp.exists():temp.unlink()

def deploy(candidate, proof):
    assert read(candidate/'release-audit.json')==proof
    assert snapshot()['free_commit_bytes']>=6*1024**3
    receipt=candidate/'deployment.json';assert not receipt.exists()
    assert installation()==proof['baseline']
    backup=ROOT/'build/backup'/('coop-bundle-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False)
    targets=[(GAME/'pfe.swf',M52/'security-native-02/pfe.swf',proof['native_sha256']),
        (ROOT/'release/RConnectMod.swf',candidate/'RConnectMod.swf',proof['candidate_sha256'])]
    items=[]
    for target,source,digest in targets:
        old=backup/(target.stem+'.before.swf');shutil.copyfile(target,old)
        old_hash=sha(target);assert sha(old)==old_hash
        items.append(dict(target=str(target),source=str(source),before=old_hash,after=digest,backup=str(old)))
    d=dict(status='prepared',files=items,proof=proof,script_sha256=sha(__file__))
    save(receipt,d);changed=[]
    try:
        assert installation()==proof['baseline']
        for item in items:
            target=Path(item['target']);assert sha(target)==item['before']
            replace(Path(item['source']),target,item['after']);changed.append(item)
        d['status']='installed-awaiting-smoke';save(receipt,d)
        expected=proof['baseline'].copy();expected['pfe.swf']=proof['native_sha256']
        expected['mods/Rconnect/release/RConnectMod.swf']=proof['candidate_sha256']
        assert installation()==expected
        command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
            '--candidate',str(ROOT/'release/RConnectMod.swf'),'--smoke','--all-mods','--land','random_mane',
            '--seconds','180','--expected-version',proof['version'],'--port',str(test_port())]
        with (candidate/'installed-smoke.log').open('w',encoding='utf-8') as log:
            result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        text=(candidate/'installed-smoke.log').read_text(encoding='utf-8',errors='replace')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',text,re.M)
        assert result.returncode==0 and match
        folder=ROOT/'build/cooperation'/match[1];actual=read(folder/'run.json')
        assert actual['sha256']==proof['candidate_sha256'] and not actual['solo']
        for role in ('host','join'):
            inp=actual['inputs'][role];assert inp['game']==proof['native_sha256'] and 'driver' not in inp and 'production' not in inp
            for n,h in inp['modules'].items():assert h==expected[n.replace('\\','/')],n
            check_log(folder,role,proof['version'],True)
        assert installation()==expected
        d.update(status='deployed-smoke-passed',smoke_run=match[1],smoke_run_sha256=sha(folder/'run.json'))
    except BaseException as error:
        d.update(status='failed',error=repr(error));save(receipt,d)
        for item in reversed(changed):
            target=Path(item['target']);assert sha(target)==item['after'],'Third-party change prevents rollback: '+str(target)
            replace(Path(item['backup']),target,item['before'])
        d['status']='rolled-back';save(receipt,d);raise
    save(receipt,d);print(json.dumps(d,ensure_ascii=False))

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('mode',choices=['audit','deploy'])
    ap.add_argument('--candidate',type=Path,required=True);ap.add_argument('--evidence',type=Path,required=True)
    a=ap.parse_args();candidate=(ROOT/a.candidate).resolve();evidence=(ROOT/a.evidence).resolve()
    assert candidate.parent==M52 and evidence.parent==candidate
    proof=audit(candidate,evidence)
    if a.mode=='audit':
        assert not (candidate/'release-audit.json').exists();save(candidate/'release-audit.json',proof);print(json.dumps(proof,ensure_ascii=False))
    else:deploy(candidate,proof)

if __name__=='__main__':main()
