"""Current unchanged restoration driver on the retained old production byte."""
import hashlib,json,re,subprocess,sys
from pathlib import Path
from validation_baseline import verify_protected
ROOT=Path(__file__).resolve().parents[2]
OUT=(ROOT/sys.argv[1]).resolve()
assert OUT.parent==ROOT/'build/m46' and OUT.name.startswith('final')
OLD=ROOT/'build/m46/final-13'
JAVA='C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
m=read(OUT/'source-input.json');old=read(OLD/'source-input.json');v=read(OUT/'verified-test-input.json')
def verify():
    assert sha(OUT/'RConnectMod.swf')==m['candidate_sha256']
    assert sha(OLD/'RConnectMod.swf')==old['candidate_sha256']
    for n,h in m['source'].items():assert sha(ROOT/n)==sha(OUT/n)==h,n
    for n,h in old['source'].items():assert sha(OLD/n)==h,n
    for n,h in v.items():assert sha(ROOT/n)==sha(OUT/'verified-files'/n)==h,n
    verify_protected(m)
verify()
entry='MirrorMaskRestoreTestDoc';driver=OUT/'old-restore-driver'
assert not driver.exists()
cmd=[sys.executable,str(ROOT/'tools/build_effects_driver.py'),'--candidate',str(OLD/'RConnectMod.swf'),
    '--source-root',str(OLD/'src'),'--java',JAVA,'--output',str(driver),'--entry',entry]
with (OUT/'old-restore-build.log').open('w',encoding='utf-8') as log:
    subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
verify()
print('RUN expected-red old production restoration control',flush=True)
result=subprocess.run([sys.executable,str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(OLD/'RConnectMod.swf'),
    '--effects-driver',str(driver),'--effects','--all-mods','--responsive','--land','random_mane',
    '--seconds','180','--expected-version',old['version']],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
(OUT/'old-restore-runner.log').write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
found=re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$',result.stdout,re.M)
record={'run':found.group(1) if found else None,'exit':result.returncode,'candidate_sha256':old['candidate_sha256'],
    'compiled_candidate_origin':old['compiled_candidate_origin'],'old_source_manifest_sha256':sha(OLD/'source-input.json'),
    'current_verification_manifest_sha256':sha(OUT/'verified-test-input.json'),
    'driver_test_sha256':sha(ROOT/'tests'/ (entry+'.as')),'driver_sha256':sha(driver/'EffectsDriver.swf'),
    'harness_sha256':sha(driver/'EffectsHarness.swf'),'production_declarations_sha256':sha(driver/'ProductionDeclarations.swc'),
    'compile_stub_sha256':sha(ROOT/'build/GameCombatStubs.swc'),
    'compile_stub_origin':'Current '+OUT.relative_to(ROOT).as_posix()+'/GameCombatStubs.swc with frozen AS3 declarations; production old stub retained separately in final-13',
    'original_test_assertions':'unchanged','native_empty_masks_observed':False,'roles':{},'controller_sha256':sha(Path(__file__))}
(OUT/'old-restore-control.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
assert result.returncode!=0 and record['run'],record
folder=ROOT/'build/cooperation'/record['run'];data=read(folder/'run.json');inp=read(folder/'input.json')
assert data['sha256']==old['candidate_sha256']==sha(folder/'candidate.swf')
assert data['inputs']==inp['inputs'] and data['configuration_files']==inp['configuration_files']
assert sha(folder/'input.json')==data['input_manifest_sha256']
assert data['inputs']['host']==data['inputs']['join']
for role in ('host','join'):
    p=folder/(role+'.log');log=p.read_text(encoding='utf-8-sig',errors='replace')
    assert 'COOP EFFECTS DONE' in log,role
    for bad in ('game error dialog','Error #1009'):assert bad not in log,(role,bad)
    assert 'COOP FAIL mask-restore vis restores a live clip' in log,role
    assert 'COOP FAIL mask-restore hpbar restores a live clip' in log,role
    empty=[]
    for line in log.splitlines():
        if not line.startswith('MASK RESTORE AFTER '):continue
        row=json.loads(line.split('MASK RESTORE AFTER ',1)[1])
        if row['vis'] is None and row['hpbar'] is None:empty.append(row)
    assert empty,(role,'actual empty native field masks not recorded')
    for n,h in data['configuration_files'][role].items():assert sha(folder/'configuration'/role/n)==h,n
    record['roles'][role]={'pass':len(re.findall(r'^COOP PASS ',log,re.M)),'fail':len(re.findall(r'^COOP FAIL ',log,re.M)),
        'done':True,'empty_mask_records':empty,'log_sha256':sha(p)}
record.update(native_empty_masks_observed=True,pids=data['pids'],input_manifest_sha256=data['input_manifest_sha256'])
verify()
(OUT/'old-restore-control.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({'status':'expected-red control verified','run':record['run'],'roles':{r:{k:v for k,v in x.items() if k in ('pass','fail')} for r,x in record['roles'].items()}}),flush=True)
