"""Audit frozen 20 bytes, the installed 19 negative control, and all 17 groups."""
import argparse, datetime, json, re, subprocess
from pathlib import Path
from validation_baseline import ROOT, GAME, M48_SHA, sha, read, verify_protected
from run_final_regressions import required_entries, JAVA

FFDEC='D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
ap=argparse.ArgumentParser();ap.add_argument('--snapshot',required=True,type=Path)
out=ap.parse_args().snapshot.resolve()
assert out.parent==ROOT/'build/m48' and out.name.startswith('final')
m=read(out/'source-input.json');assert m['version']=='0.2.20-dev'
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
        s=logs(run)[role];assert 'v0.2.20-dev initialized' in s
        for bad in ('game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed','RConnectGrip: failed','Error #1009'):
            assert bad not in s,(entry,role,bad)
        if entry in ('FastHeldTestDoc','TelekinesisMotionTestDoc'):
            assert data['save_templates'][role]['source_sha256']==m['profiles'][role]['sha256']
    pids+=data['pids']
    runs.append(dict(entry=entry,run=run,exit=0,roles=roles,pass_count=sum(c['pass_count'] for c in roles.values()),fail=0,
                     result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json'),
                     driver_sha256=sha(driver/'EffectsDriver.swf'),harness_sha256=sha(driver/'EffectsHarness.swf'),
                     driver_classes=sorted(dc),run_manifest_sha256=sha(folder/'run.json')))

# The old failing run exercised the same actual 1.02 game/production-domain boundary.
old_run='bd9ceaf401';old_folder=ROOT/'build/cooperation'/old_run
old_snapshot=ROOT/'build/m48/red-continuity-04';om=read(old_snapshot/'source-input.json')
od=read(old_folder/'run.json');oi=read(old_folder/'input.json');oc=counts(old_run)
assert om['version']=='0.2.19-dev' and om['candidate_sha256']==M48_SHA
assert sha(old_snapshot/'RConnectMod.swf')==sha(old_folder/'candidate.swf')==od['sha256']==M48_SHA
assert sha(old_folder/'input.json')==od['input_manifest_sha256'] and od['inputs']==oi['inputs']
assert od['inputs']['host']==od['inputs']['join'] and all(c['done'] for c in oc.values())
assert sum(c['fail'] for c in oc.values())==7
old_driver=old_snapshot/'PresentationContinuityTestDoc-driver'
assert od['inputs']['host']['driver']==sha(old_driver/'EffectsDriver.swf')
assert od['inputs']['host']['harness']==sha(old_driver/'EffectsHarness.swf')
assert 'PresentationContinuityTestDoc' in actual_driver_classes(old_driver,out/'control-driver-classes')
for role in ('host','join'):
    for n,h in od['configuration_files'][role].items():assert sha(old_folder/'configuration'/role/n)==h,n
for n,h in om['source'].items():assert sha(old_snapshot/n)==h,n
for n,h in read(old_snapshot/'verified-test-input.json').items():assert sha(old_snapshot/'verified-files'/n)==h,n

continuity=next(r for r in runs if r['entry']=='PresentationContinuityTestDoc')['run']
comparison={}
for name,prefix in [('cadence','CONTINUITY CADENCE '),('drop','CONTINUITY DROP '),('pause','CONTINUITY PAUSE ')]:
    before=metrics(old_run,prefix);after=metrics(continuity,prefix)
    assert len(before)==len(after)==(1 if name=='pause' else 2)
    if name=='cadence':
        assert all(x['maxVelocityEdge']>.01 and x['bounded'] for x in before)
        assert all(x['maxVelocityEdge']<=.01 and x['bounded'] and x['edges']>=50 for x in after)
    elif name=='drop':
        assert all(x['longestStillMs']>85 and x['sourceSpan']>20 for x in before)
        assert all(x['longestStillMs']<=85 and x['sourceSpan']>20 and x['span']>20 and x['airFrames']>=8 for x in after)
    else:
        # initialGap is sampled when the endpoint message arrives, before the
        # last in-flight world frame. The native assertion uses pausedX at 1.2s.
        assert abs(before[0]['pausedX']-before[0]['endpoint'])>20 and before[0]['resumeJump']>20
        assert abs(after[0]['pausedX']-after[0]['endpoint'])<=1 and after[0]['resumeJump']<=4
    # Original full per-frame traces stay in the fingerprinted logs.
    comparison[name]=dict(old=[{k:v for k,v in x.items() if k not in ('source','display','trace')} for x in before],
                          new=[{k:v for k,v in x.items() if k not in ('source','display','trace')} for x in after])

fast=metrics(next(r['run'] for r in runs if r['entry']=='FastHeldTestDoc'),'FAST HELD METRIC ')
assert len(fast)==4 and all(0<=x['lagMs']<=160 and x['samples']>=12 for x in fast)
angle=metrics(next(r['run'] for r in runs if r['entry']=='WeaponAngleTestDoc'),'WEAPON ANGLE METRIC ')
assert len(angle)==14 and all(x['wrong']==0 and x['samples']>=12 and x['flashes']>0 and x['sourceFlashes']>0 for x in angle)
png=read(out/'mask-scene-check.json');assert len(png)==14 and all(x['white_block'] is None for x in png)
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
       protected=dict(count=len(protected),hashes=protected),
       continuity_comparison=dict(old_run=old_run,new_run=continuity,old_roles=oc,metrics=comparison,
           old_source_manifest_sha256=sha(old_snapshot/'source-input.json'),old_run_manifest_sha256=sha(old_folder/'run.json')),
       fast_metrics=fast,angle_metrics=angle,mask_png=png)
if (out/'carried-checks.json').exists():e['carried_checks']=read(out/'carried-checks.json')
p=ROOT/'knowledge/experiments/m48-validation-evidence.json';assert not p.exists()
p.write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='all-frozen-checks-pass',groups=len(runs),passed=e['pass_count'],fail=0,protected=len(protected),pids=pids)))
