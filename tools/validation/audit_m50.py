"""Audit final 22 inputs, isolated runtime evidence, and the installed-21 red.

Diagnostic probes are never deployment evidence. Every required group must
have run the exact final production SWF with a separate native-game driver.
"""
import argparse, datetime, json, re, subprocess
from pathlib import Path
import xml.etree.ElementTree as ET
from validation_baseline import ROOT, GAME, M50_SHA, sha, read, verify_protected, verify_runtime_inputs
from run_final_regressions import required_entries, JAVA

FFDEC='D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
ap=argparse.ArgumentParser();ap.add_argument('--snapshot',required=True,type=Path)
out=ap.parse_args().snapshot.resolve()
assert out.parent==ROOT/'build/m50' and out.name.startswith('final')
m=read(out/'source-input.json');v=read(out/'verified-test-input.json')
assert m['version']=='0.2.22-dev' and m['build_exit']==0
baseline=verify_protected(m)
assert sha(out/'RConnectMod.swf')==m['candidate_sha256']
for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
for n,h in v.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
assert sha(out/'GameCombatStubs.swc')==sha(ROOT/'build/GameCombatStubs.swc')==m['stub_sha256']
production={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
assert actual==production and len(actual)==m['classes'] and sha(out/'classes.txt')==m['class_list_sha256']

def logs(run):
    return {role:(ROOT/'build/cooperation'/run/(role+'.log')).read_text(encoding='utf-8-sig') for role in ('host','join')}

def counts(run):
    return {role:dict(pass_count=len(re.findall('^COOP PASS ',s,re.M)),fail=len(re.findall('^COOP FAIL ',s,re.M)),
                     done='COOP EFFECTS DONE' in s,log_sha256=sha(ROOT/'build/cooperation'/run/(role+'.log')))
            for role,s in logs(run).items()}

def classes(driver,report):
    result=subprocess.run([JAVA,'-jar',FFDEC,'-dumpAS3',str(driver/'EffectsDriver.swf')],
        capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
    report.write_text(result.stdout,encoding='utf-8')
    dc={s.split()[0] for s in result.stdout.splitlines() if s.strip()}
    assert not dc.intersection(production),dc.intersection(production)
    assert not {'fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(dc)
    return sorted(dc)

def inputs(run,driver,digest):
    folder=ROOT/'build/cooperation'/run;data=read(folder/'run.json');inp=read(folder/'input.json')
    assert sha(folder/'candidate.swf')==data['sha256']==digest
    assert sha(folder/'input.json')==data['input_manifest_sha256']
    assert data['inputs']==inp['inputs'] and data['inputs']['host']==data['inputs']['join']
    assert data['configuration_files']==inp['configuration_files']
    if m.get('visible_windows') is True:
        assert data['visible_windows'] is True and inp['visible_windows'] is True
        assert data['descriptors']==inp['descriptors']
        for role in ('host','join'):
            descriptor=folder/'descriptors'/(role+'.xml')
            assert sha(descriptor)==data['descriptors'][role]
            xml=ET.parse(descriptor)
            assert xml.findtext('.//{*}visible')=='true'
            assert xml.findtext('.//{*}content')=='pfe.swf'
    verify_runtime_inputs(baseline,data)
    for role in ('host','join'):
        assert data['inputs'][role]['production']==digest
        assert data['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf')
        assert data['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    return data

runs=[];pids=[];metrics={}
for entry in required_entries(m):
    result=read(out/(entry+'-result.json'));assert result['entry']==entry and result['exit']==0 and result['run'],entry
    run=result['run'];folder=ROOT/'build/cooperation'/run;driver=out/(entry+'-driver')
    data=inputs(run,driver,m['candidate_sha256']);di=read(driver/'driver-input.json')
    assert di['entry']==entry and di['candidate_sha256']==m['candidate_sha256']
    dc=classes(driver,out/(entry+'-audited-classes.txt'));assert entry in dc
    roles=counts(run)
    for role,c in roles.items():
        assert c['pass_count']>0 and c['fail']==0 and c['done'],(entry,role,c)
        s=logs(run)[role];assert 'v0.2.22-dev initialized' in s
        for bad in ('game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed',
                    'RConnectGrip: failed','RConnectPeerGrip: failed','Error #1009','uncaught'):
            assert bad not in s,(entry,role,bad)
        for line in s.splitlines():
            if ' METRIC {' in line:
                prefix,payload=line.split(' {',1)
                row=json.loads('{'+payload)
                # Keep concise summaries; the full independent source/remote
                # point arrays remain in the hash-bound original logs.
                metrics.setdefault(entry,[]).append(dict(role=role,kind=prefix,
                    values={k:value for k,value in row.items() if not isinstance(value,(list,dict))}))
        if entry in ('FastHeldTestDoc','TelekinesisMotionTestDoc'):
            assert data['save_templates'][role]['source_sha256']==m['profiles'][role]['sha256']
    pids+=data['pids']
    runs.append(dict(entry=entry,run=run,exit=0,roles=roles,fail=0,pass_count=sum(c['pass_count'] for c in roles.values()),
        result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json'),
        driver_sha256=sha(driver/'EffectsDriver.swf'),harness_sha256=sha(driver/'EffectsHarness.swf'),
        driver_classes=dc,run_manifest_sha256=sha(folder/'run.json'),png={p.name:sha(p) for p in folder.glob('*.png')}))

# This red is the original seven-angle native test, before the later positive
# potion cases. It proves only the original fake-wing/muzzle symptoms, not
# every new M50 feature or every later fixture change.
old=ROOT/'build/m50/red-peer-01';control=read(out/'installed-control-result.json');run=control['run'];entry='PeerVisualTestDoc'
assert control['expected_negative'] is True and control['exit']==1
om=read(old/'source-input.json');driver=old/(entry+'-driver')
assert om['version']=='0.2.21-dev' and sha(old/'RConnectMod.swf')==M50_SHA
for n,h in om['source'].items():assert sha(old/n)==h,n
ov=read(old/'verified-test-input.json')
for n,h in ov.items():assert sha(old/'verified-files'/n)==h,n
inputs(run,driver,M50_SHA);roles=counts(run)
assert all(c['done'] for c in roles.values()) and sum(c['fail'] for c in roles.values())==28
assert entry in classes(driver,out/'installed-21-peer-classes.txt')
controls=[dict(entry=entry,run=run,roles=roles,production_sha256=M50_SHA,
    scope='Original seven-angle wings and projectile geometry only',source_manifest_sha256=sha(old/'source-input.json'))]

mask=read(out/'mask-scene-check.json');assert len(mask)==14 and all(x['white_block'] is None for x in mask)
def group(name):return next(x for x in runs if x['entry']==name)
assert len(group('HudTestDoc')['png'])>=24
assert 'join-target-sats.png' in group('TargetLifecycleTestDoc')['png']
protected={n:h for n,h in baseline['protected'].items() if n.lower()!='mods/rconnect/release/rconnectmod.swf'}
for n,h in protected.items():assert sha(GAME/n)==h,n
# A sandbox Get-Process list can be scoped to the sandbox itself. Query the
# actual host through approved execution; CIM failure must fail the audit,
# never become an empty process list. Also distinguish recycled PIDs.
query="$ErrorActionPreference='Stop'; $rcRows=@(Get-CimInstance Win32_Process -Filter \"Name='adl64.exe'\" | Select-Object ProcessId,CreationDate,CommandLine); ConvertTo-Json -InputObject $rcRows -Compress"
check=subprocess.run(['powershell.exe','-NoProfile','-Command',query],
    capture_output=True,text=True,encoding='utf-8',check=True)
observed=json.loads(check.stdout);assert isinstance(observed,list),observed
expected_descriptors={'"'+str((ROOT/'build/cooperation'/row['run']/role/'coop.xml').resolve()).replace('/','\\').lower()+'"'
    for row in runs for role in ('host','join')}
alive=[];reused=[]
for process in observed:
    if int(process['ProcessId']) not in pids:continue
    command=process['CommandLine'];assert command is not None,('Cannot identify tested PID',process['ProcessId'])
    normalized=command.replace('/','\\').lower()
    if any(path in normalized for path in expected_descriptors):alive.append(process)
    else:reused.append(int(process['ProcessId']))
assert not alive,alive
process_observation=dict(query='host Win32_Process; errors are fatal',tested_descriptors=len(expected_descriptors),
    owned_alive=0,recycled_pid_ids=sorted(reused))

e=dict(at=datetime.datetime.now().astimezone().isoformat(),required_entries=required_entries(m),
    candidate=dict(version=m['version'],sha256=m['candidate_sha256'],size=m['size'],classes=m['classes'],
        snapshot=out.relative_to(ROOT).as_posix(),source_manifest_sha256=sha(out/'source-input.json'),
        verification_manifest_sha256=sha(out/'verified-test-input.json')),
    runs=runs,pass_count=sum(r['pass_count'] for r in runs),fail=0,pids=pids,pids_exited=True,process_observation=process_observation,
    protected=dict(count=len(protected),hashes=protected),controls=controls,metrics=metrics,mask_png=mask)
if (out/'carried-checks.json').exists():e['carried_checks']=read(out/'carried-checks.json')
p=ROOT/'knowledge/experiments/m50-validation-evidence.json';assert not p.exists()
p.write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='all-frozen-checks-pass',groups=len(runs),passed=e['pass_count'],fail=0,protected=len(protected))))
