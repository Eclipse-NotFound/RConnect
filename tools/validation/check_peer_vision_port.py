"""Build and run exact isolated Q-sight production bytes with a separate driver."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from release_a22_map import ROOT,GAME,sha,read,save,require

JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'

def build(out):
    manifest=read(out/'source.json')
    for name,h in {**manifest['source'],**manifest['inputs']}.items():require(sha(out/name)==h,name)
    require(not (out/'compiled.json').exists(),'Already built')
    tests=out/'tests';tests.mkdir()
    for p in (ROOT/'experimental/peer-vision-port/tests').rglob('*.as'):
        target=tests/p.relative_to(ROOT/'experimental/peer-vision-port/tests')
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    shutil.copytree(ROOT/'tests/harness',tests/'harness')
    cmd=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),
         '--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
    driver=out/'driver';driver.mkdir()
    compiler=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
              '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
    env=dict(os.environ,AIR_HOME=str(SDK))
    declarations=compiler.copy();declarations[3]=str(SDK/'lib/compc.jar')
    extern=driver/'ProductionDeclarations.swc';stub=out/'build/GameCombatStubs.swc'
    classes=['.'.join(p.relative_to(out/'src').with_suffix('').parts) for p in sorted((out/'src').rglob('*.as'))]
    calls=[declarations+['-source-path='+str(out/'src'),'-external-library-path+='+str(stub),
        '-include-classes='+','.join(classes),'-output='+str(extern)],
        compiler+['-source-path='+str(tests),'-external-library-path+='+str(extern),
            '-external-library-path+='+str(stub),'-output='+str(driver/'EffectsDriver.swf'),str(tests/'PeerPortTestDoc.as')],
        compiler+['-source-path='+str(tests/'harness'),'-output='+str(driver/'EffectsHarness.swf'),str(tests/'harness/RConnectDoc.as')]]
    with (out/'driver-compile.log').open('w',encoding='utf-8') as log:
        for command in calls:subprocess.run(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    save(driver/'driver-input.json',dict(candidate_sha256=sha(out/'RConnectMod.swf'),entry='PeerPortTestDoc'))
    files={p.relative_to(out).as_posix():sha(p) for folder in ('src','tools','tests','driver','build') for p in (out/folder).rglob('*') if p.is_file()}
    files['RConnectMod.swf']=sha(out/'RConnectMod.swf')
    save(out/'compiled.json',dict(source_sha256=sha(out/'source.json'),files=files,version=manifest['version'],script_sha256=sha(Path(__file__))))
    print('Compiled '+str(out)+' '+files['RConnectMod.swf'],flush=True)

def run(out):
    require(not (out/'result.json').exists(),'Run result already exists')
    manifest=read(out/'compiled.json')
    for n,h in manifest['files'].items():require(sha(out/n)==h,'Frozen build changed: '+n)
    names=read(ROOT/'build/m52/a22-map-runtime-19/inputs.json')['files']
    before={n:sha(GAME/n) for n in names}
    save(out/'runtime-before.json',before)
    cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
         '--candidate',str(out/'RConnectMod.swf'),'--effects','--effects-driver',str(out/'driver'),
         '--all-mods','--visible-windows','--defer-visible','--land','random_mane',
         '--seconds','350','--expected-version',manifest['version']]
    with (out/'run.log').open('w',encoding='utf-8') as log:
        completed=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    text=(out/'run.log').read_text(encoding='utf-8');match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',text,re.M)
    changed={n:sha(GAME/n) for n,h in before.items() if sha(GAME/n)!=h}
    result=dict(exit=completed.returncode,run=match[1] if match else None,installation_changes=changed,
        compiled_sha256=sha(out/'compiled.json'),runner_sha256=sha(ROOT/'tools/run_coop_regression.py'))
    if match:
        folder=ROOT/'build/cooperation'/match[1]
        result['run_sha256']=sha(folder/'run.json')
        for role in ('host','join'):
            path=folder/(role+'.log');raw=path.read_text(encoding='utf-8-sig') if path.exists() else ''
            native=(folder/(role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
            result[role]=dict(passed=raw.count('COOP PASS '),failed=raw.count('COOP FAIL '),
                done='COOP EFFECTS DONE peer-port' in raw,log_sha256=sha(path) if path.exists() else None,
                exceptions=re.findall(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught|out of memory)\b',native,re.I),
                production_errors=[s for s in raw.splitlines() if 'peer-vision Q failed:' in s])
    save(out/'result.json',result);print(json.dumps(result,ensure_ascii=False),flush=True)
    require(completed.returncode==0 and not changed and all(result[r]['done'] and not result[r]['failed']
        and not result[r]['exceptions'] and not result[r]['production_errors'] for r in ('host','join')),'Native Q tests failed')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['build','run']);ap.add_argument('candidate');a=ap.parse_args()
    folder=(ROOT/a.candidate).resolve();require(folder.parent==ROOT/'build/m52','Wrong build location')
    (build if a.mode=='build' else run)(folder)
