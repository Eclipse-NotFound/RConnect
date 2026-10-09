"""Restart isolated normal-loading instances; roll back any smoke validation failure."""
import argparse,datetime,hashlib,json,os,re,shutil,subprocess,sys,uuid
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT.parents[1]
from validation_baseline import verify_protected,verify_runtime_inputs
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
ap=argparse.ArgumentParser();ap.add_argument('--snapshot',type=Path);args=ap.parse_args()
if args.snapshot:
    OUT=args.snapshot.resolve();assert OUT.parent in (ROOT/'build/m46',ROOT/'build/m47',ROOT/'build/m48',ROOT/'build/m49',ROOT/'build/m50') and OUT.name.startswith('final')
    receipt=OUT/'deployment.json'
else:receipt=ROOT/'build/m46/deployment.json'
d=read(receipt);OUT=ROOT/d['snapshot'];target=ROOT/'release/RConnectMod.swf'
assert d['status']=='deployed-awaiting-smoke' and sha(target)==d['sha256']
record={'run':None,'exit':None};runner_output=''
try:
    manifest=read(OUT/'source-input.json')
    baseline=verify_protected(manifest,own_release=d['sha256'])
    command=[sys.executable,'-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(target),'--smoke','--all-mods',
        '--responsive','--seconds','150','--expected-version',d['version']]
    if manifest.get('visible_windows') is True:command.append('--visible-windows')
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    runner_output=result.stdout+'\n'+result.stderr
    (OUT/'normal-smoke-runner.log').write_text(runner_output,encoding='utf-8')
    found=re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$',result.stdout,re.M)
    record={'run':found.group(1) if found else None,'exit':result.returncode}
    assert result.returncode==0 and record['run'],record
    folder=ROOT/'build/cooperation'/record['run'];r=read(folder/'run.json');inp=read(folder/'input.json')
    assert r['sha256']==d['sha256']==sha(folder/'candidate.swf') and r['inputs']==inp['inputs']
    assert r['inputs']['host']==r['inputs']['join'] and sha(folder/'input.json')==r['input_manifest_sha256']
    assert r['configuration_files']==inp['configuration_files']
    if manifest.get('visible_windows') is True:
        assert r['visible_windows'] is True and inp['visible_windows'] is True
        assert r['descriptors']==inp['descriptors']
        for role in ('host','join'):
            descriptor=folder/'descriptors'/(role+'.xml')
            assert sha(descriptor)==r['descriptors'][role]
            assert ET.parse(descriptor).findtext('.//{*}visible')=='true'
    verify_runtime_inputs(baseline,r)
    record.update(pids=r['pids'],inputs=r['inputs'],configuration_files=r['configuration_files'],log_sha256={})
    for role in ('host','join'):
        assert 'production' not in r['inputs'][role]
        assert r['inputs'][role]['modules']['mods\\Rconnect\\release\\RConnectMod.swf']==d['sha256']
        for name,digest in r['configuration_files'][role].items():assert sha(folder/'configuration'/role/name)==digest,name
        p=folder/(role+'.log');s=p.read_text(encoding='utf-8-sig')
        assert ('v'+d['version']+' initialized') in s and 'tick 200' in s
        for bad in ('COOP FAIL','game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed','RConnectGrip: failed','RConnectPeerGrip: failed','Error #1009'):
            assert bad not in s,(role,bad)
        if role=='join':assert 'welcome id=' in s and 'unitsync matched' in s
        record['log_sha256'][role]=sha(p)
    milestone={'0.2.18-dev':'m46','0.2.19-dev':'m47','0.2.20-dev':'m48','0.2.21-dev':'m49','0.2.22-dev':'m50'}[d['version']]
    evidence=read(ROOT/('knowledge/experiments/'+milestone+'-validation-evidence.json'))
    for name,digest in evidence['protected']['hashes'].items():assert sha(GAME/name)==digest,name
    assert sha(target)==d['sha256']
    verify_protected(read(OUT/'source-input.json'),own_release=d['sha256'])
except BaseException as error:
    backup=ROOT/d['backup'];assert sha(backup)==d['previous_sha256']
    temp=target.with_name('RConnectMod.'+uuid.uuid4().hex+'.tmp');shutil.copy2(backup,temp);os.replace(temp,target)
    assert sha(target)==d['previous_sha256']
    d.update(status='rolled-back-after-smoke-failed',smoke=record,error=str(error),at=datetime.datetime.now().astimezone().isoformat())
    receipt.write_text(json.dumps(d,indent=2),encoding='utf-8')
    (OUT/'normal-smoke-result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps(d),flush=True);print(runner_output[-5000:],flush=True);raise
d.update(status='deployed-smoke-passed',smoke=record)
receipt.write_text(json.dumps(d,indent=2),encoding='utf-8')
(OUT/'normal-smoke-result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({'status':d['status'],'run':record['run'],'pids':record['pids'],'sha256':d['sha256']}),flush=True)
