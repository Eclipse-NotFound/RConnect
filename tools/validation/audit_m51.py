"""Audit exact final-23 game/driver bytes and all independent runtime checks.

Probe results are diagnostic only. This gate never deploys or closes a game.
"""
import argparse, datetime, json, re, subprocess
from pathlib import Path
import xml.etree.ElementTree as ET
from validation_baseline import ROOT, GAME, M51_SHA, sha, read, verify_protected, verify_runtime_inputs
from run_final_regressions import JAVA, required_entries

ap=argparse.ArgumentParser();ap.add_argument('snapshot');a=ap.parse_args()
out=(ROOT/a.snapshot).resolve()
assert out.parent==ROOT/'build/m51' and out.name.startswith('final-')
m=read(out/'source-input.json');v=read(out/'verified-test-input.json')
assert m['version']=='0.2.23-dev' and m['build_exit']==0
baseline=verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
for n,h in v.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
assert sha(out/'RConnectMod.swf')==m['candidate_sha256']
assert sha(out/'GameCombatStubs.swc')==sha(out/'build/GameCombatStubs.swc')==m['stub_sha256']
assert sha(out/'classes.txt')==m['class_list_sha256']
production={Path(n).relative_to('src').with_suffix('').as_posix().replace('/','.') for n in m['source'] if n.endswith('.as')}
actual={line.split()[0] for line in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if line.strip()}
assert actual==production and len(actual)==m['classes']
FFDEC='D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'

def audit_run(snapshot,entry,digest,version):
    result=read(snapshot/(entry+'-result.json'));run=result['run'];folder=ROOT/'build/cooperation'/run
    assert 'vision_override' not in result,'Final evidence must use the installed integration baseline'
    driver=snapshot/'build'/(entry+'-driver')
    data=read(folder/'run.json');inp=read(folder/'input.json')
    assert result['sha256']==digest==data['sha256']==sha(folder/'candidate.swf')
    assert sha(folder/'input.json')==data['input_manifest_sha256']
    assert data['inputs']==inp['inputs'] and data['inputs']['host']==data['inputs']['join']
    assert data['configuration_files']==inp['configuration_files']
    assert data['visible_windows'] and inp['visible_windows'] and data['descriptors']==inp['descriptors']
    verify_runtime_inputs(baseline,data)
    assert read(driver/'driver-input.json')==dict(candidate_sha256=digest,entry=entry)
    listing=subprocess.run([JAVA,'-jar',FFDEC,'-dumpAS3',str(driver/'EffectsDriver.swf')],
        capture_output=True,text=True,encoding='utf-8',errors='replace',check=True).stdout
    classes={line.split()[0] for line in listing.splitlines() if line.strip()}
    assert entry in classes and not classes.intersection(production)
    assert not {'fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(classes)
    (out/(entry+'-'+('control' if version.endswith('22-dev') else 'final')+'-classes.txt')).write_text(listing,encoding='utf-8')
    roles={}
    for role in ('host','join'):
        assert data['inputs'][role]['production']==digest
        assert data['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf')
        assert data['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
        descriptor=folder/'descriptors'/(role+'.xml')
        assert sha(descriptor)==data['descriptors'][role]
        xml=ET.parse(descriptor);assert xml.findtext('.//{*}visible')=='true' and xml.findtext('.//{*}content')=='pfe.swf'
        p=folder/(role+'.log');s=p.read_text(encoding='utf-8-sig')
        assert 'v'+version+' initialized' in s and 'COOP EFFECTS DONE' in s
        for bad in ('game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed',
                    'RConnectPeerGrip: failed','Error #1009','uncaught'):
            assert bad not in s,(entry,role,bad)
        roles[role]=dict(passed=len(re.findall('^COOP PASS ',s,re.M)),failed=len(re.findall('^COOP FAIL ',s,re.M)),
            done=True,log_sha256=sha(p))
    return dict(entry=entry,run=run,exit=result['exit'],roles=roles,fail=sum(c['failed'] for c in roles.values()),
        pass_count=sum(c['passed'] for c in roles.values()),driver_sha256=sha(driver/'EffectsDriver.swf'),
        harness_sha256=sha(driver/'EffectsHarness.swf'),input_sha256=sha(folder/'input.json'),
        result_sha256=sha(snapshot/(entry+'-result.json')),driver_classes=sorted(classes),
        manifest_sha256=sha(folder/'run.json'),pids=data['pids'],png={p.name:sha(p) for p in folder.glob('*.png')})

runs=[]
for entry in required_entries(m):
    r=audit_run(out,entry,m['candidate_sha256'],m['version'])
    assert r['exit']==0 and r['fail']==0 and all(c['passed']>0 for c in r['roles'].values()),r
    data=read(ROOT/'build/cooperation'/r['run']/'run.json')
    if entry in ('FastHeldTestDoc','TelekinesisMotionTestDoc'):
        for role in ('host','join'):assert data['save_templates'][role]['source_sha256']==m['profiles'][role]['sha256']
    runs.append(r);print(json.dumps(dict(entry=entry,passed=r['pass_count'])),flush=True)

# Independent old-build failures for body alpha, ordinary impacts and door debris.
# The exploratory acid runs also contain fixture failures and are not gate controls.
controls=[]
for name,entry in [('red-vision-cache-02','BodyEffectsTestDoc'),('red-vision-cache-02','BallisticVisualTestDoc'),('red-vision-cache-02','DoorVisualTestDoc')]:
    old=ROOT/'build/m51'/name;om=read(old/'source-input.json')
    assert sha(old/'RConnectMod.swf')==M51_SHA
    for n,h in {**om['source'],**om['verification']}.items():assert sha(old/n)==h,n
    r=audit_run(old,entry,M51_SHA,'0.2.22-dev');assert r['exit']==1 and r['fail']>0
    # A timeout or unrelated regression is not an old-build negative control.
    # These are the observed immutable runs, classified by the actual defect.
    expected={'BodyEffectsTestDoc':(56,56),'BallisticVisualTestDoc':(14,14),'DoorVisualTestDoc':(0,15)}[entry]
    for role,count in zip(('host','join'),expected):
        log=(ROOT/'build/cooperation'/r['run']/(role+'.log')).read_text(encoding='utf-8-sig')
        failures=re.findall(r'^COOP FAIL .*$',log,re.M)
        assert len(failures)==count,(entry,role,failures)
        if entry=='BodyEffectsTestDoc':
            assert all('peer matches authoritative body' in line and 'first=native root alpha' in line for line in failures)
        elif entry=='BallisticVisualTestDoc':
            allowed=('between native frames projectile moves continuously','remote impact renders native particle artwork',
                'particles originate at the native hit target','one native randomized spark burst')
            assert all(any(label in line for label in allowed) for line in failures)
            assert all(any(label in line for line in failures) for label in allowed[:3])
        elif failures:
            assert all('open/close emits no wall destruction' in line or 'native door collision follows open state' in line for line in failures)
            assert any('id=door1a' in line for line in failures) and any('id=door1b' in line for line in failures)
    r['scope']='Exact installed 22 under the same deployed RV cache and current test inputs'
    controls.append(r)

query="$ErrorActionPreference='Stop'; $rcRows=@(Get-CimInstance Win32_Process -Filter \"Name='adl64.exe'\" | Select-Object ProcessId,CommandLine); ConvertTo-Json -InputObject $rcRows -Compress"
result=subprocess.run(['powershell.exe','-NoProfile','-Command',query],capture_output=True,text=True,encoding='utf-8',check=True)
observed=json.loads(result.stdout);assert isinstance(observed,list)
owned={str((ROOT/'build/cooperation'/r['run']/role/'coop.xml').resolve()).lower() for r in runs+controls for role in ('host','join')}
for row in observed:
    command=row['CommandLine'];assert command is not None
    assert not any(p in command.replace('/','\\').lower() for p in owned),row
protected={n:h for n,h in baseline['protected'].items() if n.lower()!='mods/rconnect/release/rconnectmod.swf'}
for n,h in protected.items():assert sha(GAME/n)==h,n
e=dict(at=datetime.datetime.now().astimezone().isoformat(),required_entries=required_entries(m),
    candidate=dict(version=m['version'],sha256=m['candidate_sha256'],size=m['size'],classes=m['classes'],
        snapshot=out.relative_to(ROOT).as_posix(),source_manifest_sha256=sha(out/'source-input.json'),
        verification_manifest_sha256=sha(out/'verified-test-input.json')),
    runs=runs,controls=controls,pass_count=sum(r['pass_count'] for r in runs),fail=0,
    pids_exited=True,process_observation=dict(owned_alive=0,descriptors=len(owned),others=len(observed)),
    protected=dict(count=len(protected),hashes=protected))
path=ROOT/'knowledge/experiments/m51-validation-evidence.json';assert not path.exists()
path.write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='all-frozen-checks-pass',groups=len(runs),passed=e['pass_count'],protected=len(protected))))
