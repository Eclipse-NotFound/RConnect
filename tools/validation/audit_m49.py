"""Audit final 21 bytes, installed 20 native negatives, and all 20 groups."""
import argparse, datetime, json, re, subprocess
from pathlib import Path
from validation_baseline import ROOT, GAME, M49_SHA, sha, read, verify_protected
from run_final_regressions import required_entries, JAVA

FFDEC='D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
ap=argparse.ArgumentParser();ap.add_argument('--snapshot',required=True,type=Path)
out=ap.parse_args().snapshot.resolve()
assert out.parent==ROOT/'build/m49' and out.name.startswith('final')
m=read(out/'source-input.json');assert m['version']=='0.2.21-dev'
baseline=verify_protected(m);v=read(out/'verified-test-input.json')
assert sha(out/'RConnectMod.swf')==m['candidate_sha256'] and m['build_exit']==0
for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
for n,h in v.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
assert sha(out/'GameCombatStubs.swc')==sha(ROOT/'build/GameCombatStubs.swc')==m['stub_sha256']
production={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
assert production==actual and len(actual)==m['classes'] and sha(out/'classes.txt')==m['class_list_sha256']

def logs(run):
    return {r:(ROOT/'build/cooperation'/run/(r+'.log')).read_text(encoding='utf-8-sig') for r in ('host','join')}

def counts(run):
    return {r:dict(pass_count=len(re.findall('^COOP PASS ',s,re.M)),fail=len(re.findall('^COOP FAIL ',s,re.M)),
                   done='COOP EFFECTS DONE' in s,log_sha256=sha(ROOT/'build/cooperation'/run/(r+'.log')))
            for r,s in logs(run).items()}

def metrics(run,prefix):
    return [json.loads(line[len(prefix):]) for s in logs(run).values() for line in s.splitlines() if line.startswith(prefix)]

def actual_driver_classes(driver,report=None):
    result=subprocess.run([JAVA,'-jar',FFDEC,'-dumpAS3',str(driver/'EffectsDriver.swf')],
                          capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
    report=driver/'classes' if report is None else report
    report.with_suffix('.txt').write_text(result.stdout,encoding='utf-8')
    report.with_suffix('.log').write_text(result.stderr,encoding='utf-8')
    dc={line.split()[0] for line in result.stdout.splitlines() if line.strip()}
    assert not dc.intersection(production),dc.intersection(production)
    assert not {'fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(dc)
    return dc

runs=[];pids=[]
for entry in required_entries(m):
    result=read(out/(entry+'-result.json'));assert result['exit']==0 and result['run'],entry
    run=result['run'];folder=ROOT/'build/cooperation'/run
    data=read(folder/'run.json');inp=read(folder/'input.json')
    assert sha(folder/'candidate.swf')==data['sha256']==m['candidate_sha256']
    assert sha(folder/'input.json')==data['input_manifest_sha256']
    assert data['inputs']==inp['inputs'] and data['inputs']['host']==data['inputs']['join']
    assert data['configuration_files']==inp['configuration_files']
    driver=out/(entry+'-driver');di=read(driver/'driver-input.json')
    assert di['entry']==entry and di['candidate_sha256']==m['candidate_sha256']
    dc=actual_driver_classes(driver);assert entry in dc
    roles=counts(run)
    for role,c in roles.items():
        assert c['pass_count']>0 and c['fail']==0 and c['done'],(entry,role,c)
        assert data['inputs'][role]['production']==m['candidate_sha256']
        assert data['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf')
        assert data['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
        s=logs(run)[role];assert 'v0.2.21-dev initialized' in s
        for bad in ('game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed','RConnectGrip: failed','RConnectPeerGrip: failed','Error #1009'):
            assert bad not in s,(entry,role,bad)
        if entry in ('FastHeldTestDoc','TelekinesisMotionTestDoc'):
            assert data['save_templates'][role]['source_sha256']==m['profiles'][role]['sha256']
    pids+=data['pids']
    runs.append(dict(entry=entry,run=run,exit=0,roles=roles,pass_count=sum(c['pass_count'] for c in roles.values()),fail=0,
                     result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json'),
                     driver_sha256=sha(driver/'EffectsDriver.swf'),harness_sha256=sha(driver/'EffectsHarness.swf'),
                     driver_classes=sorted(dc),run_manifest_sha256=sha(folder/'run.json')))

# Installed 20 negatives retain the exact production bytes and native drivers.
controls=[]
for snapshot,run,entry,failures in [
    ('red-target-06','9beba4f621','TargetLifecycleTestDoc',3),
    ('red-native-death-08','950b33f377','RespawnRoomTestDoc',6)]:
    old=ROOT/'build/m49'/snapshot;folder=ROOT/'build/cooperation'/run
    om=read(old/'source-input.json');data=read(folder/'run.json');inp=read(folder/'input.json')
    assert om['version']=='0.2.20-dev' and sha(old/'RConnectMod.swf')==sha(folder/'candidate.swf')==data['sha256']==om['candidate_sha256']==M49_SHA
    assert data['inputs']==inp['inputs'] and data['inputs']['host']==data['inputs']['join']
    assert sha(folder/'input.json')==data['input_manifest_sha256'] and data['configuration_files']==inp['configuration_files']
    for n,h in om['source'].items():assert sha(old/n)==h,n
    ov=read(old/'verified-test-input.json')
    for n,h in ov.items():assert sha(old/'verified-files'/n)==h,n
    assert ov['tests/'+entry+'.as']==v['tests/'+entry+'.as'], 'Regression differs from actual installed negative'
    driver=old/(entry+'-driver');assert entry in actual_driver_classes(driver,out/(snapshot+'-classes'))
    roles=counts(run);assert all(c['done'] for c in roles.values()) and sum(c['fail'] for c in roles.values())==failures
    for role in ('host','join'):
        assert data['inputs'][role]['production']==M49_SHA
        assert data['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf')
        assert data['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    controls.append(dict(snapshot=snapshot,run=run,entry=entry,roles=roles,
        source_manifest_sha256=sha(old/'source-input.json'),run_manifest_sha256=sha(folder/'run.json')))

def run_for(entry):return next(r['run'] for r in runs if r['entry']==entry)

old_raster=metrics('9beba4f621','TARGET RASTER ');raster=metrics(run_for('TargetLifecycleTestDoc'),'TARGET RASTER ')
assert len(old_raster)==len(raster)==1
assert abs(old_raster[0]['bitmapX']-old_raster[0]['expectedX'])>20
assert all(x['count']>=16 and x['referenceCount']>=16 and abs(x['bitmapX']-x['expectedX'])<=1 for x in raster)
old_dead=metrics('950b33f377','RESPAWN INSPECT ');dead=metrics(run_for('RespawnRoomTestDoc'),'RESPAWN INSPECT ')
assert any(u['visible'] and not u['inUnits'] for row in old_dead for u in row['seen'])
assert len(dead)==7 and all(not u['visible'] and u['sost']>=3 and u['hp']<=0 for row in dead for u in row['seen'])
assert 'authority pairs with original joining native objects' in logs(run_for('RespawnRoomTestDoc'))['join']
grip=metrics(run_for('PeerGripTestDoc'),'PEER GRIP SAMPLE ')
assert len(grip)==24
for n in range(12):
    pair=[x for x in grip if x['round']==n];assert len(pair)==2 and {x['caster'] for x in pair}=={True,False}
    if n%6:assert all(x['held']>=3 and x['rise']>20 for x in pair)
    else:assert all(x['held']==0 and x['rise']<=1 for x in pair)
pause=metrics(run_for('PeerGripTestDoc'),'PEER GRIP PAUSE ')
assert {x['round'] for x in pause}=={5,11}
for n in (5,11):
    owner=[x for x in pause if x['round']==n and not x['caster']]
    remote=[x for x in pause if x['round']==n and x['caster'] and x['endpoint'] is not None and x['elapsed']>500]
    assert owner and remote and max(x['y'] for x in owner)-min(x['y'] for x in owner)<=1
    assert all(abs(x['y']-x['endpoint'])<=1 for x in remote)

continuity=run_for('PresentationContinuityTestDoc')
cadence=metrics(continuity,'CONTINUITY CADENCE ');drops=metrics(continuity,'CONTINUITY DROP ');stops=metrics(continuity,'CONTINUITY PAUSE ')
assert len(cadence)==2 and all(x['maxVelocityEdge']<=.01 and x['bounded'] and x['edges']>=50 for x in cadence)
assert len(drops)==2 and all(x['longestStillMs']<=85 and x['sourceSpan']>20 and x['span']>20 and x['airFrames']>=8 for x in drops)
assert len(stops)==1 and abs(stops[0]['pausedX']-stops[0]['endpoint'])<=1 and stops[0]['resumeJump']<=4
fast=metrics(run_for('FastHeldTestDoc'),'FAST HELD METRIC ')
assert len(fast)==4 and all(0<=x['lagMs']<=160 and x['samples']>=12 for x in fast)
angle=metrics(run_for('WeaponAngleTestDoc'),'WEAPON ANGLE METRIC ')
assert len(angle)==14 and all(x['wrong']==0 and x['samples']>=12 and x['flashes']>0 and x['sourceFlashes']>0 for x in angle)
png=read(out/'mask-scene-check.json');assert len(png)==14 and all(x['white_block'] is None for x in png)
hud_folder=ROOT/'build/cooperation'/run_for('HudTestDoc');hud={p.name:sha(p) for p in hud_folder.glob('*-hud-*.png')}
assert len(hud)==24
raster_folder=ROOT/'build/cooperation'/run_for('TargetLifecycleTestDoc');raster_png=raster_folder/'join-target-sats.png'
assert raster_png.is_file()
protected={n:h for n,h in baseline['protected'].items() if n.lower()!='mods/rconnect/release/rconnectmod.swf'}
for n,h in protected.items():assert sha(GAME/n)==h,n
check=subprocess.run(['powershell.exe','-NoProfile','-Command',
    '$r=@(Get-Process -Id '+','.join(map(str,pids))+' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id); ConvertTo-Json -InputObject $r -Compress'],
    capture_output=True,text=True,encoding='utf-8',check=True)
assert json.loads(check.stdout)==[],check.stdout
e=dict(at=datetime.datetime.now().astimezone().isoformat(),required_entries=required_entries(m),
       candidate=dict(version=m['version'],sha256=m['candidate_sha256'],size=m['size'],classes=m['classes'],
                      snapshot=out.relative_to(ROOT).as_posix(),source_manifest_sha256=sha(out/'source-input.json'),
                      verification_manifest_sha256=sha(out/'verified-test-input.json')),
       runs=runs,pass_count=sum(r['pass_count'] for r in runs),fail=0,pids=pids,pids_exited=True,
       protected=dict(count=len(protected),hashes=protected),controls=controls,
       target_raster=dict(before=old_raster,after=raster,png_sha256=sha(raster_png)),death_rows=dead,peer_grip=grip,
       pause_samples=pause,fast_metrics=fast,angle_metrics=angle,mask_png=png,hud_png=hud,
       continuity=dict(cadence=cadence,drop=[{k:v for k,v in x.items() if k not in ('source','display')} for x in drops],pause=stops))
if (out/'carried-checks.json').exists():e['carried_checks']=read(out/'carried-checks.json')
p=ROOT/'knowledge/experiments/m49-validation-evidence.json';assert not p.exists()
p.write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='all-frozen-checks-pass',groups=len(runs),passed=e['pass_count'],fail=0,protected=len(protected),pids=pids)))
