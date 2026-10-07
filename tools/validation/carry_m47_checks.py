"""Retain identical driver runs after independent native fixture corrections."""
import argparse,json,shutil,subprocess
from pathlib import Path
from validation_baseline import ROOT,sha,read,verify_protected
from run_final_regressions import JAVA

FIXTURES={'tests/EnemyGrabTestDoc.as','tests/ProjectileNetworkTestDoc.as','tests/MirrorMaskRestoreTestDoc.as'}
CONTROLLERS={'tools/validation/carry_m47_checks.py','tools/validation/audit_m47.py'}
ap=argparse.ArgumentParser();ap.add_argument('--from-snapshot',type=Path,required=True);ap.add_argument('--snapshot',type=Path,required=True)
a=ap.parse_args();old,out=a.from_snapshot.resolve(),a.snapshot.resolve()
for d in (old,out):assert d.parent==ROOT/'build/m47' and d.name.startswith('final')
assert old!=out
before,m=read(old/'source-input.json'),read(out/'source-input.json')
ov,nv=read(old/'verified-test-input.json'),read(out/'verified-test-input.json')
assert before['version']==m['version']=='0.2.19-dev' and before['source']==m['source']
assert before['candidate_sha256']==m['candidate_sha256']==sha(old/'RConnectMod.swf')==sha(out/'RConnectMod.swf')
assert before['stub_sha256']==m['stub_sha256']==sha(ROOT/'build/GameCombatStubs.swc')==sha(out/'GameCombatStubs.swc')
verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(old/n)==sha(out/n)==h,n
changed=[]
for n,h in ov.items():
    assert sha(old/'verified-files'/n)==h,n
    if n.startswith('build/m47/') and '/profiles/' in n:continue
    assert n in nv and sha(ROOT/n)==sha(out/'verified-files'/n)==nv[n],n
    if nv[n]!=h:changed.append(n)
for n,h in nv.items():
    assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
    if n not in ov and not(n.startswith('build/m47/') and '/profiles/' in n):changed.append(n)
assert set(changed)<=FIXTURES|CONTROLLERS and set(changed)&FIXTURES,changed
changed_classes={Path(n).stem for n in changed if n in FIXTURES}
entries=[]
for entry in m['required_entries']:
    p=old/(entry+'-result.json')
    if p.exists() and read(p)['exit']==0 and entry not in changed_classes:entries.append(entry)
assert entries
for role in ('host','join'):
    assert before['profiles'][role]['sha256']==m['profiles'][role]['sha256']
    assert sha(ROOT/before['profiles'][role]['path'])==sha(ROOT/m['profiles'][role]['path'])==m['profiles'][role]['sha256']
assert not(out/'carried-checks.json').exists()
records=[]
for entry in entries:
    result=read(old/(entry+'-result.json'));assert result==dict(entry=entry,run=result['run'],exit=0)
    folder=ROOT/'build/cooperation'/result['run'];r,inp=read(folder/'run.json'),read(folder/'input.json')
    assert sha(folder/'input.json')==r['input_manifest_sha256'] and r['inputs']==inp['inputs']
    assert r['configuration_files']==inp['configuration_files'] and r['inputs']['host']==r['inputs']['join']
    assert r['sha256']==m['candidate_sha256']==sha(folder/'candidate.swf')
    driver=old/(entry+'-driver');di=read(driver/'driver-input.json')
    assert di==dict(candidate_sha256=m['candidate_sha256'],entry=entry)
    target=out/(entry+'-driver');assert not target.exists() and not(out/(entry+'-result.json')).exists()
    listing=subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar','-dumpAS3',str(driver/'EffectsDriver.swf')],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True).stdout
    classes={line.split()[0] for line in listing.splitlines() if line.strip()}
    assert entry in classes and not classes.intersection(changed_classes)
    assert not {'RConnectMod','fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(classes)
    for role in ('host','join'):
        s=(folder/(role+'.log')).read_text(encoding='utf-8-sig');assert 'COOP EFFECTS DONE' in s and 'COOP FAIL' not in s and 'Error #1009' not in s
        assert r['inputs'][role]['production']==m['candidate_sha256']
        assert r['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf') and r['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in r['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    shutil.copytree(driver,target)
    for suffix in ('result.json','runner.log','build.log'):shutil.copy2(old/(entry+'-'+suffix),out/(entry+'-'+suffix))
    listed=out/(entry+'-retained-classes.txt');listed.write_text(listing,encoding='utf-8')
    records.append(dict(entry=entry,run=result['run'],origin=old.relative_to(ROOT).as_posix(),
        unchanged_test_sha256=nv['tests/'+entry+'.as'],driver_classes_sha256=sha(listed),
        result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json')))
verify_protected(m)
receipt=dict(kind='retained exact-byte checks, not new runs',entries=records,changed_input=changed,
    old_source_manifest_sha256=sha(old/'source-input.json'),new_source_manifest_sha256=sha(out/'source-input.json'),
    old_verification_manifest_sha256=sha(old/'verified-test-input.json'),new_verification_manifest_sha256=sha(out/'verified-test-input.json'),
    controller_sha256=sha(Path(__file__)))
(out/'carried-checks.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(retained=entries,candidate_sha256=m['candidate_sha256']),ensure_ascii=False))
