"""Retain all exact runs across audit-only corrections; never relabel them new."""
import argparse,json,shutil,subprocess
from pathlib import Path
from validation_baseline import ROOT,sha,read,verify_protected
from run_final_regressions import JAVA,required_entries

CONTROLLERS={'tools/validation/carry_m48_checks.py','tools/validation/audit_m48.py'}
ap=argparse.ArgumentParser();ap.add_argument('--from-snapshot',type=Path,required=True);ap.add_argument('--snapshot',type=Path,required=True)
a=ap.parse_args();old,out=a.from_snapshot.resolve(),a.snapshot.resolve()
for d in (old,out):assert d.parent==ROOT/'build/m48' and d.name.startswith('final')
assert old!=out
before,m=read(old/'source-input.json'),read(out/'source-input.json')
ov,nv=read(old/'verified-test-input.json'),read(out/'verified-test-input.json')
assert before['version']==m['version']=='0.2.20-dev' and before['source']==m['source']
assert required_entries(before)==required_entries(m) and before['build_exit']==0
assert before['candidate_sha256']==sha(old/'RConnectMod.swf')
assert before['stub_sha256']==sha(ROOT/'build/GameCombatStubs.swc')==sha(old/'GameCombatStubs.swc')
verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(old/n)==sha(out/n)==h,n
old_profiles={x['path'] for x in before['profiles'].values()}
new_profiles={x['path'] for x in m['profiles'].values()}
changed=[]
for n,h in ov.items():
    assert sha(old/'verified-files'/n)==h,n
    if n in old_profiles:continue
    assert n in nv and sha(ROOT/n)==sha(out/'verified-files'/n)==nv[n],n
    if nv[n]!=h:changed.append(n)
for n,h in nv.items():
    assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
    if n not in ov and n not in new_profiles:changed.append(n)
assert changed and set(changed)<=CONTROLLERS,changed
for role in ('host','join'):
    assert before['profiles'][role]['sha256']==m['profiles'][role]['sha256']
    assert sha(ROOT/before['profiles'][role]['path'])==sha(ROOT/m['profiles'][role]['path'])==m['profiles'][role]['sha256']
for name in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):
    assert not (out/name).exists();shutil.copy2(old/name,out/name)
for key in ('candidate_sha256','size','classes','stub_sha256','class_list_sha256','build_exit'):m[key]=before[key]
(out/'source-input.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'candidate-reuse.json').write_text(json.dumps(dict(origin=old.relative_to(ROOT).as_posix(),
    kind='same actual production build; audit-only correction',sha256=m['candidate_sha256'],
    origin_source_manifest_sha256=sha(old/'source-input.json')),indent=2),encoding='utf-8')
records=[]
for entry in required_entries(m):
    result=read(old/(entry+'-result.json'))
    assert result['entry']==entry and result['exit']==0 and result['run']
    folder=ROOT/'build/cooperation'/result['run'];r,inp=read(folder/'run.json'),read(folder/'input.json')
    assert sha(folder/'input.json')==r['input_manifest_sha256'] and r['inputs']==inp['inputs']
    assert r['configuration_files']==inp['configuration_files'] and r['inputs']['host']==r['inputs']['join']
    assert r['sha256']==m['candidate_sha256']==sha(folder/'candidate.swf')
    driver=old/(entry+'-driver');di=read(driver/'driver-input.json')
    assert di==dict(candidate_sha256=m['candidate_sha256'],entry=entry)
    target=out/(entry+'-driver');assert not target.exists() and not(out/(entry+'-result.json')).exists()
    listing=subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar','-dumpAS3',str(driver/'EffectsDriver.swf')],
        capture_output=True,text=True,encoding='utf-8',errors='replace',check=True).stdout
    classes={line.split()[0] for line in listing.splitlines() if line.strip()}
    assert entry in classes
    assert not {'RConnectMod','fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(classes)
    for role in ('host','join'):
        s=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
        assert 'COOP EFFECTS DONE' in s and 'COOP FAIL' not in s and 'Error #1009' not in s
        assert r['inputs'][role]['production']==m['candidate_sha256']
        assert r['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf') and r['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in r['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    shutil.copytree(driver,target)
    for suffix in ('result.json','runner.log','build.log'):shutil.copy2(old/(entry+'-'+suffix),out/(entry+'-'+suffix))
    listed=out/(entry+'-retained-classes.txt');listed.write_text(listing,encoding='utf-8')
    records.append(dict(entry=entry,run=result['run'],origin=old.relative_to(ROOT).as_posix(),
        unchanged_test_sha256=nv['tests/'+entry+'.as'],driver_classes_sha256=sha(listed),
        result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json')))
assert not (out/'mask-scene-check.json').exists()
shutil.copy2(old/'mask-scene-check.json',out/'mask-scene-check.json')
verify_protected(m)
receipt=dict(kind='retained exact-byte checks, not new runs',entries=records,changed_input=changed,
    old_source_manifest_sha256=sha(old/'source-input.json'),new_source_manifest_sha256=sha(out/'source-input.json'),
    old_verification_manifest_sha256=sha(old/'verified-test-input.json'),new_verification_manifest_sha256=sha(out/'verified-test-input.json'),
    controller_sha256=sha(Path(__file__)))
(out/'carried-checks.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(retained=len(records),candidate_sha256=m['candidate_sha256'],changed_input=changed)))
