"""Isolated diagnostic snapshot while independent features are still being authored.

Never deploy from this directory. Production, tests and compilation stubs are
copied before compiling, and the real runner records the actual runtime inputs.
"""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
from validation_baseline import ROOT,M50_BASELINE,sha,read,verify_protected
from run_final_regressions import JAVA,CHECKS

ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['build','control','run']);ap.add_argument('name')
ap.add_argument('--entry',default='PeerVisualTestDoc')
ap.add_argument('--land');ap.add_argument('--seconds',type=int);a=ap.parse_args()
out=ROOT/'build/m50'/a.name
assert out.parent==ROOT/'build/m50' and out.name.startswith('probe-')
if a.mode in ('build','control'):
    assert not out.exists();out.mkdir(parents=True)
    for directory in ('src','tests','tools/stubs'):
        origin=ROOT/'build/m49/final-lifecycle-16' if a.mode=='control' and directory=='src' else ROOT
        shutil.copytree(origin/directory,out/directory)
    for name in ('build_mod.py','build_effects_driver.py'):shutil.copy2(ROOT/'tools'/name,out/'tools'/name)
    if a.mode=='control':
        (out/'build').mkdir()
        # External native declarations only; these bytes are never linked into
        # the control driver or the actual installed production SWF.
        shutil.copy2(ROOT/'build/m50/probe-peer-02/build/GameCombatStubs.swc',out/'build/GameCombatStubs.swc')
        shutil.copy2(ROOT/M50_BASELINE/'RConnectMod.swf',out/'RConnectMod.swf')
    files={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file()}
    m=dict(version='0.2.21-dev' if a.mode=='control' else '0.2.22-dev',baseline_path=M50_BASELINE,baseline_inputs_sha256=sha(ROOT/M50_BASELINE/'inputs.json'),files=files)
    verify_protected(m);(out/'inputs.json').write_text(json.dumps(m,indent=2),encoding='utf-8')
    if a.mode=='control':
        assert sha(out/'RConnectMod.swf')==read(ROOT/M50_BASELINE/'inputs.json')['release_sha256']
        print(json.dumps(dict(snapshot=str(out),kind='exact-installed-21-control',sha256=sha(out/'RConnectMod.swf'))));raise SystemExit(0)
    with (out/'build.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([sys.executable,'-X','utf8',str(out/'tools/build_mod.py'),'--java',JAVA,'--output',str(out/'RConnectMod.swf')],cwd=out,stdout=log,stderr=subprocess.STDOUT)
    print(json.dumps(dict(snapshot=str(out),exit=result.returncode)))
    if result.returncode:print((out/'build.log').read_bytes().decode('gb18030',errors='replace')[-6000:]);raise SystemExit(result.returncode)
else:
    m=read(out/'inputs.json');verify_protected(m)
    for n,h in m['files'].items():assert sha(out/n)==h,n
    driver=out/'build'/(a.entry+'-driver');assert not driver.exists()
    with (out/(a.entry+'-build.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run([sys.executable,'-X','utf8',str(out/'tools/build_effects_driver.py'),'--candidate',str(out/'RConnectMod.swf'),
            '--source-root',str(out/'src'),'--java',JAVA,'--output',str(driver),'--entry',a.entry],cwd=out,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:print((out/(a.entry+'-build.log')).read_bytes().decode('gb18030',errors='replace')[-6000:]);raise SystemExit(result.returncode)
    seconds,land,_=CHECKS.get(a.entry,(240,'rbl',False))
    if a.seconds is not None:seconds=a.seconds
    if a.land is not None:land=a.land
    travel=['--land',land] if land else []
    result=subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(out/'RConnectMod.swf'),
        '--effects-driver',str(driver),'--effects','--all-mods','--responsive','--seconds',str(seconds),'--expected-version',m['version']]+travel,
        cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (out/(a.entry+'-runner.log')).write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
    found=re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$',result.stdout,re.M)
    record=dict(entry=a.entry,run=found.group(1) if found else None,exit=result.returncode,candidate_sha256=sha(out/'RConnectMod.swf'),land=land,seconds=seconds)
    (out/(a.entry+'-result.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
    for n,h in m['files'].items():assert sha(out/n)==h,n
    verify_protected(m);print(json.dumps(record))
    if result.returncode:print(result.stdout[-6500:]+result.stderr[-1000:]);raise SystemExit(result.returncode)
