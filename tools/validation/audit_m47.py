"""Audit actual frozen production bytes, native red controls and all 16 groups."""
import argparse,datetime,json,re,subprocess
from pathlib import Path
from validation_baseline import ROOT,GAME,sha,read,verify_protected
from run_final_regressions import required_entries,JAVA

ap=argparse.ArgumentParser();ap.add_argument('--snapshot',required=True,type=Path)
out=ap.parse_args().snapshot.resolve();assert out.parent==ROOT/'build/m47' and out.name.startswith('final')
m=read(out/'source-input.json');assert m['version']=='0.2.19-dev'
baseline=verify_protected(m);v=read(out/'verified-test-input.json');candidate=out/'RConnectMod.swf'
assert sha(candidate)==m['candidate_sha256']
for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
for n,h in v.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
assert sha(out/'GameCombatStubs.swc')==sha(ROOT/'build/GameCombatStubs.swc')==m['stub_sha256']
production={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
actual={line.split()[0] for line in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if line.strip()}
assert production==actual and len(actual)==m['classes'] and sha(out/'classes.txt')==m['class_list_sha256']

def log_counts(folder):
    roles={}
    for role in ('host','join'):
        p=folder/(role+'.log');s=p.read_text(encoding='utf-8-sig')
        roles[role]=dict(pass_count=len(re.findall('^COOP PASS ',s,re.M)),fail=len(re.findall('^COOP FAIL ',s,re.M)),
                         done='COOP EFFECTS DONE' in s,log_sha256=sha(p))
    return roles

runs=[];pids=[]
for entry in required_entries(m):
    result=read(out/(entry+'-result.json'));assert result['exit']==0 and result['run'],entry
    folder=ROOT/'build/cooperation'/result['run'];data=read(folder/'run.json');inp=read(folder/'input.json')
    assert sha(folder/'candidate.swf')==data['sha256']==m['candidate_sha256']
    assert sha(folder/'input.json')==data['input_manifest_sha256']
    assert data['inputs']==inp['inputs'] and data['inputs']['host']==data['inputs']['join']
    assert data['configuration_files']==inp['configuration_files']
    driver=out/(entry+'-driver');di=read(driver/'driver-input.json')
    assert di['entry']==entry and di['candidate_sha256']==m['candidate_sha256']
    classes=driver/'classes.txt'
    with classes.open('w',encoding='utf-8') as f:
        subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar','-dumpAS3',str(driver/'EffectsDriver.swf')],stdout=f,check=True)
    dc={line.split()[0] for line in classes.read_text(encoding='utf-8-sig').splitlines() if line.strip()}
    assert entry in dc and not dc.intersection(production),(entry,dc.intersection(production))
    assert not {'fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(dc)
    roles=log_counts(folder)
    for role,c in roles.items():
        assert c['pass_count']>0 and c['fail']==0 and c['done'],(entry,role,c)
        assert data['inputs'][role]['production']==m['candidate_sha256']
        assert data['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf')
        assert data['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
        s=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
        assert 'v0.2.19-dev initialized' in s
        for bad in ('game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed','RConnectGrip: failed','Error #1009'):
            assert bad not in s,(entry,role,bad)
    pids+=data['pids']
    runs.append(dict(entry=entry,run=result['run'],exit=0,roles=roles,
                     pass_count=sum(r['pass_count'] for r in roles.values()),fail=0,
                     result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json'),
                     driver_sha256=sha(driver/'EffectsDriver.swf'),harness_sha256=sha(driver/'EffectsHarness.swf'),
                     driver_classes=sorted(dc),run_manifest_sha256=sha(folder/'run.json')))

def metric(run,prefix):
    result=[]
    for role in ('host','join'):
        s=(ROOT/'build/cooperation'/run/(role+'.log')).read_text(encoding='utf-8-sig')
        result += [json.loads(line[len(prefix):]) for line in s.splitlines() if line.startswith(prefix)]
    return result

fast=next(r for r in runs if r['entry']=='FastHeldTestDoc')
new=metric(fast['run'],'FAST HELD METRIC ');old=metric('8cf53db5a2','FAST HELD METRIC ')
assert len(new)==len(old)==4
for a in new:
    b=next(b for b in old if b['round']==a['round'])
    assert 0<=a['lagMs']<=160 and b['lagMs']>=250 and b['lagMs']-a['lagMs']>=150 and a['samples']>=12,(a['round'],a['lagMs'],b['lagMs'])
old_fast_roles=log_counts(ROOT/'build/cooperation/8cf53db5a2')
assert all(r['done'] for r in old_fast_roles.values()) and sum(r['fail'] for r in old_fast_roles.values())==4
old_angle=metric('d8de7e1749','WEAPON ANGLE METRIC ')
new_angle=metric(next(r['run'] for r in runs if r['entry']=='WeaponAngleTestDoc'),'WEAPON ANGLE METRIC ')
assert len(old_angle)==len(new_angle)==14
assert sum(a['wrong']>0 for a in old_angle)==12 and all(a['sourceFlashes']>0 for a in old_angle)
assert all(a['wrong']==0 and a['samples']>=12 and a['flashes']>0 and a['sourceFlashes']>0 for a in new_angle)
png=read(out/'mask-scene-check.json');assert len(png)==14 and all(x['white_block'] is None for x in png)
protected={n:h for n,h in baseline['protected'].items() if n.lower()!='mods/rconnect/release/rconnectmod.swf'}
for n,h in protected.items():assert sha(GAME/n)==h,n
e=dict(at=datetime.datetime.now().astimezone().isoformat(),required_entries=required_entries(m),
       candidate=dict(version=m['version'],sha256=m['candidate_sha256'],size=m['size'],classes=m['classes'],
                      snapshot=out.relative_to(ROOT).as_posix(),source_manifest_sha256=sha(out/'source-input.json'),
                      verification_manifest_sha256=sha(out/'verified-test-input.json')),
       runs=runs,pass_count=sum(r['pass_count'] for r in runs),fail=0,pids=pids,
       protected=dict(count=len(protected),hashes=protected),
       fast_comparison=dict(old_run='8cf53db5a2',new_run=fast['run'],old=old,new=new),
       angle_comparison=dict(old_run='d8de7e1749',old=old_angle,new=new_angle),mask_png=png)
if (out/'carried-checks.json').exists():e['carried_checks']=read(out/'carried-checks.json')
p=ROOT/'knowledge/experiments/m47-validation-evidence.json';assert not p.exists()
p.write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='all-frozen-checks-pass',groups=len(runs),passed=e['pass_count'],fail=0,protected=len(protected),pids=pids)))
