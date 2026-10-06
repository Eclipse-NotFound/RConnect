"""UI-only release based on the verified installed M45 source, never pending M46 core."""
import argparse,datetime,hashlib,json,os,re,shutil,subprocess,sys,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT.parents[1]
JAVA='C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
SDK=Path('D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk')
FFDEC=Path('D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar')
BASE=ROOT/'build/m45/final';BASE_SHA='59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790'
env=dict(os.environ,PYTHONUTF8='1',JAVA_TOOL_OPTIONS='-Dfile.encoding=UTF-8',AIR_HOME=str(SDK))
CHECKS={'HudTestDoc':(180,'rbl'),'CoopPauseTestDoc':(300,'random_mane'),
        'TeammateNavigationTestDoc':(240,'random_mane'),'RoomCooperationTestDoc':(300,'random_mane')}
BAD=('COOP FAIL','game error dialog','RConnectRoom: ERROR','handoff timed out','RConnectPause: failed',
     'RConnectGrip: failed','RConnectNavigation: failed','Error #1009')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
def command(cmd,log):
    p=subprocess.run(list(map(str,cmd)),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log.write_bytes(p.stdout);print(p.stdout.decode('utf-8',errors='replace')[-6000:],flush=True)
    save(log.with_suffix('.result.json'),{'exit':p.returncode,'cmd':list(map(str,cmd))})
    if p.returncode:raise SystemExit(p.returncode)
def close(out,after_deploy=False):
    d=json.loads((out/'input.json').read_text(encoding='utf-8'))
    for n,h in d['source'].items():assert sha(out/n)==h,n
    for n,h in d['verification'].items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
    for n,h in d['ui_working_source'].items():assert sha(ROOT/n)==h,n
    for n,h in d['protected'].items():
        if after_deploy and n.lower()=='mods/rconnect/release/rconnectmod.swf':
            h=json.loads((out/'build-proof.json').read_text())['candidate_sha256']
        assert sha(GAME/n)==h,n
    return d
def audit_run(out,entry,record,smoke=False):
    proof=json.loads((out/'build-proof.json').read_text());digest=proof['candidate_sha256']
    run=Path(record['run']);r=json.loads((run/'run.json').read_text(encoding='utf-8-sig'))
    frozen=json.loads((run/'input.json').read_text(encoding='utf-8-sig'))
    assert record['exit']==0 and r['sha256']==frozen['candidate_sha256']==sha(run/'candidate.swf')==digest
    assert sha(run/'input.json')==r['input_manifest_sha256']
    assert r['inputs']==frozen['inputs'] and r['configuration_files']==frozen['configuration_files']
    assert r['inputs']['host']==r['inputs']['join']
    if not smoke:
        driver=out/(entry+'-driver')
        assert json.loads((driver/'driver-input.json').read_text())=={'candidate_sha256':digest,'entry':entry}
        assert r['inputs']['host']['production']==digest
        assert r['inputs']['host']['driver']==sha(driver/'EffectsDriver.swf')
        assert r['inputs']['host']['harness']==sha(driver/'EffectsHarness.swf')
    roles={};images={}
    for role in ('host','join'):
        inp=r['inputs'][role]
        if smoke:
            assert 'production' not in inp and 'driver' not in inp
            assert inp['modules']['mods\\Rconnect\\release\\RConnectMod.swf']==digest
        for name,h in r['configuration_files'][role].items():assert sha(run/'configuration'/role/name)==h,name
        path=run/(role+'.log');s=path.read_text(encoding='utf-8-sig')
        assert 'v0.2.17-dev initialized' in s and 'tick 200' in s,(role,'load/heartbeat')
        for bad in BAD:assert bad not in s,(role,bad)
        if not smoke:assert s.count('COOP EFFECTS DONE')==1,(role,'DONE')
        if role=='join':assert 'welcome id=' in s and 'unitsync matched' in s
        roles[role]={'pass':len(re.findall(r'^COOP PASS ',s,re.M)),'fail':0,'log_sha256':sha(path)}
        images[role]={p.name:sha(p) for p in run.glob(role+'-hud-*.png')}
        if entry=='HudTestDoc':
            assert len(images[role])>=11,(role,'missing UI pictures')
            assert 'new production HUD restores saved bottom anchor and expansion' in s
            assert 'real co-op pause notice survives F10 hiding' in s
            assert 'title drag follows event coordinates and persists free position' in s
    return {'entry':entry,'run':run.name,'exit':0,'pids':r['pids'],'inputs':r['inputs'],
            'input_manifest_sha256':sha(run/'input.json'),'configuration_files':r['configuration_files'],
            'roles':roles,'images':images,'pass':sum(v['pass'] for v in roles.values())}
ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['prepare','build','test','verify','audit','deploy','smoke'])
ap.add_argument('--snapshot',required=True);ap.add_argument('--entry',choices=list(CHECKS),default='HudTestDoc');ap.add_argument('--seconds',type=int)
a=ap.parse_args();out=(ROOT/a.snapshot).resolve();assert out.parent==ROOT/'build/ui-20261006'
if a.mode=='prepare':
    assert sha(ROOT/'release/RConnectMod.swf')==sha(BASE/'RConnectMod.swf')==BASE_SHA
    out.mkdir(parents=True,exist_ok=False)
    base=json.loads((BASE/'source-input.json').read_text(encoding='utf-8'))
    source={};unchanged=[]
    for n,h in base['source'].items():
        p=BASE/n;assert sha(p)==h,n
        dest=out/n;dest.parent.mkdir(parents=True,exist_ok=True);data=p.read_bytes()
        if n=='src/RConnectMod.as':
            assert data.count(b'0.2.16-dev')==1;data=data.replace(b'0.2.16-dev',b'0.2.17-dev')
        elif n=='src/rconnect/ui/NetHud.as':data=(ROOT/n).read_bytes()
        else:unchanged.append(n)
        dest.write_bytes(data);source[n]=sha(dest)
    n='src/rconnect/ui/HudLayout.as';p=out/n;p.write_bytes((ROOT/n).read_bytes());source[n]=sha(p)
    paths=list((ROOT/'tests').rglob('*.as'))+list((ROOT/'tools/stubs').rglob('*.as'))
    paths += [ROOT/'tools'/n for n in ['build_effects_driver.py','run_coop_regression.py','RConnect.Process.ps1','keep_test_responsive.ps1']]
    paths += [Path(__file__).resolve()]
    verification={}
    for p in paths:
        n=p.relative_to(ROOT).as_posix();q=out/'verified-files'/n;q.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,q);verification[n]=sha(q)
    protected=json.loads((ROOT/'build/m46/integration-baseline/inputs.json').read_text(encoding='utf-8'))['protected']
    ui={n:sha(ROOT/n) for n in ['src/rconnect/ui/NetHud.as','src/rconnect/ui/HudLayout.as']}
    save(out/'input.json',{'version':'0.2.17-dev','base_sha256':BASE_SHA,'source':source,'verification':verification,
        'ui_working_source':ui,'protected':protected,'unchanged_M45_sources':unchanged,
        'changes':['NetHud','new HudLayout','version only'],'required_entries':list(CHECKS),'pending_M46_core_included':False})
    close(out);print('Prepared UI-only freeze',len(source),len(verification),flush=True)
elif a.mode=='build':
    close(out);assert not (out/'RConnectMod.swf').exists()
    compiler=[JAVA,'-Xmx384m','-jar',SDK/'lib/compc.jar','+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38']
    declarations=out/'verified-files/tools/stubs'
    names=[p.relative_to(declarations).with_suffix('').as_posix().replace('/','.') for p in declarations.rglob('*.as')]
    command(compiler+['-source-path='+str(declarations),'-include-classes='+','.join(names),'-output='+str(out/'GameCombatStubs.swc')],out/'stubs-build.log')
    compiler[3]=SDK/'lib/mxmlc.jar'
    command(compiler+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),'-debug=false','-optimize=true',
        '-output='+str(out/'RConnectMod.swf'),out/'src/RConnectDoc.as'],out/'build.log')
    command([JAVA,'-jar',FFDEC,'-dumpAS3',out/'RConnectMod.swf'],out/'classes.txt')
    actual={line.split()[0] for line in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if line.strip() and not line.startswith('Picked up')}
    expected={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
    assert actual==expected,(actual-expected,expected-actual)
    # fe.*.RConnect*Access are intentional package bridges already in M45.
    # Reject native declaration classes, rather than rejecting their namespace.
    assert not actual.intersection(names),(actual.intersection(names))
    assert not any(n.endswith('TestDoc') for n in actual)
    close(out);save(out/'build-proof.json',{'candidate_sha256':sha(out/'RConnectMod.swf'),'size':(out/'RConnectMod.swf').stat().st_size,
        'classes':len(actual),'source_count':len(expected),'stub_sha256':sha(out/'GameCombatStubs.swc'),'exit':0})
elif a.mode=='test':
    close(out);proof=json.loads((out/'build-proof.json').read_text());assert sha(out/'RConnectMod.swf')==proof['candidate_sha256']
    target=out/(a.entry+'-driver');assert not target.exists()
    shutil.copy2(out/'GameCombatStubs.swc',ROOT/'build/GameCombatStubs.swc')
    command([sys.executable,ROOT/'tools/build_effects_driver.py','--candidate',out/'RConnectMod.swf','--java',JAVA,
        '--source-root',out/'src','--output',target,'--entry',a.entry],out/(a.entry+'-build.log'))
    seconds,land=CHECKS[a.entry]
    cmd=[sys.executable,ROOT/'tools/run_coop_regression.py','--candidate',out/'RConnectMod.swf','--effects-driver',target,
         '--effects','--all-mods','--responsive','--land',land,'--seconds',str(a.seconds or seconds),'--expected-version','0.2.17-dev']
    log=out/(a.entry+'-runner.log');p=subprocess.run(list(map(str,cmd)),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log.write_bytes(p.stdout);content=p.stdout.decode('utf-8',errors='replace');print(content[-14000:],flush=True)
    match=re.search(r'^OUTPUT (.+)$',content,re.M);assert match,content
    run=Path(match.group(1).strip());roles={}
    for role in ['host','join']:
        s=(run/(role+'.log')).read_text(encoding='utf-8',errors='replace')
        storage=Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-coop-'+role+'-'+run.name)/'Local Store'
        for picture in storage.glob('hud-*.png'):shutil.copy2(picture,run/(role+'-'+picture.name))
        roles[role]={'pass':len(re.findall('COOP PASS ',s)),'fail':len(re.findall('COOP FAIL ',s)),
            'done':len(re.findall('COOP EFFECTS DONE',s)),'log_sha256':sha(run/(role+'.log'))}
    save(out/(a.entry+'-result.json'),{'exit':p.returncode,'run':str(run),'roles':roles,'candidate_sha256':proof['candidate_sha256']})
    close(out);raise SystemExit(p.returncode)
elif a.mode=='audit':
    d=close(out);proof=json.loads((out/'build-proof.json').read_text());assert proof['exit']==0
    assert sha(out/'RConnectMod.swf')==proof['candidate_sha256']
    assert sha(ROOT/'build/GameCombatStubs.swc')==sha(out/'GameCombatStubs.swc')==proof['stub_sha256']
    runs=[audit_run(out,entry,json.loads((out/(entry+'-result.json')).read_text())) for entry in d['required_entries']]
    protected={n:h for n,h in d['protected'].items() if n.lower()!='mods/rconnect/release/rconnectmod.swf'}
    evidence={'date':'2026-10-06','version':d['version'],'candidate':proof,'snapshot':out.relative_to(ROOT).as_posix(),
        'input_sha256':sha(out/'input.json'),'required_entries':d['required_entries'],'runs':runs,'fail':0,
        'pass':sum(r['pass'] for r in runs),'protected':protected,'base':BASE_SHA,
        'scope':'M45 core unchanged; compact HUD, tabs, local preferences, event handling and co-op UI integration.',
        'limits':['Synthetic input events; real Chinese IME and hardware mouse were not automated.',
                  'Pending M46 core fixes are excluded; all retained M46 red runs remain red.']}
    save(out/'audit.json',evidence);print('UI audit PASS',evidence['pass'],len(protected),flush=True)
elif a.mode=='deploy':
    d=close(out);e=json.loads((out/'audit.json').read_text());proof=json.loads((out/'build-proof.json').read_text())
    assert e['input_sha256']==sha(out/'input.json') and e['candidate']==proof and e['fail']==0
    assert e['required_entries']==list(CHECKS) and len(e['runs'])==len(CHECKS)
    assert all(audit_run(out,r['entry'],{'run':str(ROOT/'build/cooperation'/r['run']),'exit':0})==r for r in e['runs'])
    assert sha(out/'RConnectMod.swf')==proof['candidate_sha256']
    receipt=out/'deployment.json';assert not receipt.exists()
    target=ROOT/'release/RConnectMod.swf';assert sha(target)==BASE_SHA
    stamp=datetime.datetime.now().astimezone();backup=ROOT/'build/backup'/('ui-release-'+stamp.strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6])
    backup.mkdir(parents=True,exist_ok=False);saved=backup/'RConnectMod.before.swf';shutil.copy2(target,saved);assert sha(saved)==BASE_SHA
    record={'status':'deployed-awaiting-smoke','at':stamp.isoformat(),'version':d['version'],'sha256':proof['candidate_sha256'],
        'size':proof['size'],'previous_sha256':BASE_SHA,'backup':saved.relative_to(ROOT).as_posix(),
        'snapshot':out.relative_to(ROOT).as_posix(),'authorization':'用户已授权开始实装及本会话统一候选部署；仅本模组release。',
        'deployment_script_sha256':sha(Path(__file__))}
    save(receipt,record);temp=target.with_name('RConnectMod.'+uuid.uuid4().hex+'.tmp')
    try:
        shutil.copy2(out/'RConnectMod.swf',temp);assert sha(temp)==record['sha256'];os.replace(temp,target)
    finally:
        if temp.exists():temp.unlink()
    close(out,after_deploy=True);print(json.dumps(record,ensure_ascii=False),flush=True)
elif a.mode=='smoke':
    receipt=out/'deployment.json';d=json.loads(receipt.read_text());target=ROOT/'release/RConnectMod.swf'
    assert d['status']=='deployed-awaiting-smoke' and sha(target)==d['sha256'];record={'run':None,'exit':None}
    try:
        close(out,after_deploy=True)
        cmd=[sys.executable,ROOT/'tools/run_coop_regression.py','--candidate',target,'--smoke','--all-mods','--responsive',
            '--seconds','150','--expected-version','0.2.17-dev']
        p=subprocess.run(list(map(str,cmd)),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (out/'normal-smoke-runner.log').write_bytes(p.stdout);s=p.stdout.decode('utf-8',errors='replace')
        print(s[-10000:],flush=True);match=re.search(r'^OUTPUT (.+)$',s,re.M);assert match,s
        record={'run':match.group(1).strip(),'exit':p.returncode}
        result=audit_run(out,'normal-smoke',record,smoke=True);close(out,after_deploy=True)
    except BaseException as error:
        backup=ROOT/d['backup'];assert sha(backup)==BASE_SHA
        temp=target.with_name('RConnectMod.'+uuid.uuid4().hex+'.tmp');shutil.copy2(backup,temp);os.replace(temp,target)
        assert sha(target)==BASE_SHA;d.update(status='rolled-back-after-smoke-failed',smoke=record,error=str(error))
        save(receipt,d);save(out/'normal-smoke-result.json',record);raise
    d.update(status='deployed-smoke-passed',smoke=result);save(receipt,d);save(out/'normal-smoke-result.json',result)
    print('Normal UI smoke PASS',result['run'],result['pids'],flush=True)
else:
    d=close(out);print('Closed source/test/UI/57 protected inputs',len(d['source']),len(d['verification']),len(d['protected']))
