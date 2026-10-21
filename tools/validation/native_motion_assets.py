"""Single native game instance: real asset replay, never a TCP/FPS qualification."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, JAVA, SDK, save, read, sha, inventory
from run_security_terminals import installation


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('mode',choices=['build','run'])
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--candidate',type=Path)
    ap.add_argument('--driver',type=Path)
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==M52 and not out.exists()
    if args.mode=='build':build(out)
    else:run((ROOT/args.candidate).resolve(),(ROOT/args.driver).resolve(),out)


def build(out):
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 原生弹体资源驱动',purpose='外部驱动编译，不运行游戏',
                      run_dir=out,evidence=out/'prepared.json',wait=300) as record:
        out.mkdir();src=out/'tests';src.mkdir()
        for name in ['NativeProjectileReplayTestDoc','ProjectileCadenceRegression']:
            shutil.copyfile(ROOT/'tests'/(name+'.as'),src/(name+'.as'))
        base=M52/'coop-bundle-drivers-04';bm=read(base/'prepared.json')
        for name,digest in bm['files'].items():assert sha(base/name)==digest,name
        shutil.copyfile(base/'EffectsHarness.swf',out/'EffectsHarness.swf')
        declarations=base/'ProductionDeclarations.swc';stub=M52/'coop-bundle-04/build/GameCombatStubs.swc'
        command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
                 '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
                 '-source-path='+str(src),'-external-library-path+='+str(declarations),
                 '-external-library-path+='+str(stub),'-output='+str(out/'EffectsDriver.swf'),
                 str(src/'NativeProjectileReplayTestDoc.as')]
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            code=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK))).returncode
        save(out/'prepared.json',dict(compile_exit=code,files=inventory(out),
             declarations_sha256=sha(declarations),stubs_sha256=sha(stub),script_sha256=sha(__file__)))
        if code:
            print((out/'compile.log').read_text(encoding='utf-8',errors='replace')[-5000:]);raise SystemExit(code)
        record.outcome='passed';record.note='仅外部驱动编译成功'
        print(out)


def run(candidate,driver,out):
    assert candidate.parent==driver.parent==M52
    cm=read(candidate/'prepared.json');dm=read(driver/'prepared.json')
    for n,h in {**cm['source'],**cm['inputs']}.items():assert sha(candidate/n)==h,n
    for n,h in dm['files'].items():assert sha(driver/n)==h,n
    digest=sha(candidate/'RConnectMod.swf');assert digest==cm['candidate_sha256']
    out.mkdir();binding=out/'driver';binding.mkdir()
    for name in ['EffectsDriver.swf','EffectsHarness.swf']:shutil.copyfile(driver/name,binding/name)
    save(binding/'driver-input.json',dict(candidate_sha256=digest,entry='NativeProjectileReplayTestDoc'))
    before=installation();runner=ROOT/'tools/run_coop_regression.py'
    save(out/'intent.json',dict(installation=before,candidate_sha256=digest,driver_sha256=sha(binding/'EffectsDriver.swf'),
                              runner_sha256=sha(runner),wrapper_sha256=sha(__file__),solo=True,performance_qualified=False))
    command=[sys.executable,'-B','-X','utf8',str(runner),'--candidate',str(candidate/'RConnectMod.swf'),
             '--expected-version',cm['version'],'--effects','--effects-driver',str(binding),'--all-mods','--solo',
             '--private-desktop','--defer-visible','--land','rbl','--seconds','180','--require-exclusive-air','--registry-wait','300']
    with (out/'runner.log').open('w',encoding='utf-8') as log:
        code=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT).returncode
    text=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
    found=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',text,re.M)
    result=dict(exit=code,run=found[1] if found else None,installation_unchanged=before==installation(),
                tcp_test=False,performance_qualified=False,passed=False)
    if found:
        folder=ROOT/'build/cooperation'/found[1];run=read(folder/'run.json');inp=run['inputs']['host']
        assert inp['production']==digest and inp['game']==before['pfe.swf'] and inp['driver']==sha(binding/'EffectsDriver.swf')
        log=(folder/'host.log').read_text(encoding='utf-8-sig',errors='replace')
        result.update(checks=len(re.findall('^COOP PASS ',log,re.M)),errors=[s for s in log.splitlines() if 'COOP FAIL' in s],
                      done='COOP EFFECTS DONE native-projectile-replay' in log,log_sha256=sha(folder/'host.log'))
        result['passed']=code==0 and result['installation_unchanged'] and result['done'] and result['checks']==14 and not result['errors']
    save(out/'result.json',result);print(json.dumps(result,ensure_ascii=False),flush=True)
    if not result['passed']:raise SystemExit(1)


if __name__=='__main__':main()
