"""Keep real final runs only when their complete runtime/driver inputs are unchanged."""
import argparse,json,shutil,subprocess
from pathlib import Path
from validation_baseline import ROOT,sha,read,verify_protected,verify_runtime_inputs
from run_final_regressions import JAVA,required_entries

CONTROLLERS={'tools/validation/carry_m50_checks.py','tools/validation/audit_m50.py',
    'tools/validation/reuse_m50_candidate.py','tools/validation/prepare_m50.py','tools/validation/build_m50.py'}
def fixture(n):
    p=Path(n)
    return p.suffix=='.as' and (p.parent==Path('tests') or n.startswith('tests/fe/'))
def profile(n):return n.startswith('build/m50/') and '/profiles/' in n
ap=argparse.ArgumentParser();ap.add_argument('--from-snapshot',type=Path,required=True);ap.add_argument('--snapshot',type=Path,required=True)
ap.add_argument('--rerun',nargs='*',default=[],help='Require fresh runs for these groups; never copy their earlier green results')
a=ap.parse_args();old,out=a.from_snapshot.resolve(),a.snapshot.resolve()
for d in (old,out):assert d.parent==ROOT/'build/m50' and d.name.startswith('final')
assert old!=out
before,m=read(old/'source-input.json'),read(out/'source-input.json')
ov,nv=read(old/'verified-test-input.json'),read(out/'verified-test-input.json')
assert before['version']==m['version']=='0.2.22-dev' and before['source']==m['source']
assert before['candidate_sha256']==m['candidate_sha256']==sha(old/'RConnectMod.swf')==sha(out/'RConnectMod.swf')
assert before['stub_sha256']==m['stub_sha256']==sha(ROOT/'build/GameCombatStubs.swc')==sha(out/'GameCombatStubs.swc')
assert before['baseline_path']==m['baseline_path'] and before['baseline_inputs_sha256']==m['baseline_inputs_sha256'], 'Do not carry checks across installation baselines'
baseline=verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(old/n)==sha(out/n)==h,n
for n,h in ov.items():assert sha(old/'verified-files'/n)==h,n
for n,h in nv.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
changed={n for n in set(ov)|set(nv) if not profile(n) and ov.get(n)!=nv.get(n)}
assert all(fixture(n) or n in CONTROLLERS for n in changed),changed
changed_classes={Path(n).relative_to('tests').with_suffix('').as_posix().replace('/','.') for n in changed if fixture(n)}
production={Path(n).relative_to('src').with_suffix('').as_posix().replace('/','.') for n in m['source'] if n.endswith('.as')}
for role in ('host','join'):
    assert before['profiles'][role]['sha256']==m['profiles'][role]['sha256']
    assert sha(ROOT/before['profiles'][role]['path'])==sha(ROOT/m['profiles'][role]['path'])==m['profiles'][role]['sha256']
assert not(out/'carried-checks.json').exists()
requested_reruns=set(a.rerun)
assert requested_reruns.issubset(set(required_entries(m))),requested_reruns
records=[]
for entry in required_entries(m):
    p=old/(entry+'-result.json')
    if not p.exists() or read(p)['exit']!=0 or entry in changed_classes or entry in requested_reruns:continue
    result=read(p);driver=old/(entry+'-driver')
    listing=subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar','-dumpAS3',str(driver/'EffectsDriver.swf')],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True).stdout
    classes={line.split()[0] for line in listing.splitlines() if line.strip()}
    if classes.intersection(changed_classes):continue
    assert entry in classes and not classes.intersection(production)
    assert not {'fe.World','fe.unit.Unit','fe.unit.UnitPlayer','fe.weapon.Weapon','fe.weapon.Bullet'}.intersection(classes)
    folder=ROOT/'build/cooperation'/result['run'];r,inp=read(folder/'run.json'),read(folder/'input.json')
    verify_runtime_inputs(baseline,r)
    assert sha(folder/'input.json')==r['input_manifest_sha256'] and r['inputs']==inp['inputs']
    assert r['configuration_files']==inp['configuration_files'] and r['inputs']['host']==r['inputs']['join']
    assert r['sha256']==m['candidate_sha256']==sha(folder/'candidate.swf')
    assert read(driver/'driver-input.json')==dict(candidate_sha256=m['candidate_sha256'],entry=entry)
    for role in ('host','join'):
        s=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
        assert 'COOP EFFECTS DONE' in s and 'COOP PASS' in s and 'COOP FAIL' not in s and 'Error #1009' not in s
        assert r['inputs'][role]['production']==m['candidate_sha256']
        assert r['inputs'][role]['driver']==sha(driver/'EffectsDriver.swf') and r['inputs'][role]['harness']==sha(driver/'EffectsHarness.swf')
        for n,h in r['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    target=out/(entry+'-driver');assert not target.exists() and not(out/(entry+'-result.json')).exists()
    shutil.copytree(driver,target)
    for suffix in ('result.json','runner.log','build.log'):shutil.copy2(old/(entry+'-'+suffix),out/(entry+'-'+suffix))
    if entry=='MirrorMaskRestoreTestDoc':
        assert result['runner_exit']==0 and result['white_blocks']==[]
        mask=read(old/'mask-scene-check.json');assert len(mask)==14 and all(x['white_block'] is None for x in mask)
        shutil.copy2(old/'mask-scene-check.json',out/'mask-scene-check.json')
    listed=out/(entry+'-retained-classes.txt');listed.write_text(listing,encoding='utf-8')
    records.append(dict(entry=entry,run=result['run'],origin=old.relative_to(ROOT).as_posix(),
        unchanged_test_sha256=nv['tests/'+entry+'.as'],driver_classes_sha256=sha(listed),
        result_sha256=sha(out/(entry+'-result.json')),input_sha256=sha(folder/'input.json')))
assert records
verify_protected(m)
receipt=dict(kind='retained exact-byte checks, not new runs',entries=records,changed_input=sorted(changed),rerun_requested=sorted(requested_reruns),
    old_source_manifest_sha256=sha(old/'source-input.json'),new_source_manifest_sha256=sha(out/'source-input.json'),
    old_verification_manifest_sha256=sha(old/'verified-test-input.json'),new_verification_manifest_sha256=sha(out/'verified-test-input.json'),
    controller_sha256=sha(Path(__file__)))
(out/'carried-checks.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(retained=[r['entry'] for r in records],candidate_sha256=m['candidate_sha256']),ensure_ascii=False))
