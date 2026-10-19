"""Frozen combined A validation. External drivers never replace production code."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_security_terminals import ROOT, sha
from run_security_terminals import installation, test_port
from run_a22_motion_checks import CASES as MOTION
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK

CASES = [
    ('security','SecurityTerminalTestDoc','random_mane',360,False),
    ('peer-port','PeerPortTestDoc','random_mane',350,False),
    ('projectile-grip','PeerProjectileGripTestDoc','random_mane',240,False),
    ('entry-room','A22RoomEntryTestDoc','random_mane',600,False),
    ('entry-map','A22MapEntryTestDoc','rbl',600,False),
] + MOTION
M52=ROOT/'build/m52'

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def inventory(folder): return {p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file()}

def verify(candidate):
    m=read(candidate/'prepared.json')
    assert m['kind']=='isolated-coop-bundle' and not m['conflicts']
    for n,h in {**m['source'],**m['inputs']}.items(): assert sha(candidate/n)==h,n
    return m

def build(candidate, out):
    m=verify(candidate)
    assert not out.exists() and (candidate/'RConnectMod.swf').is_file()
    # Called only after the standalone production compiler has succeeded.
    m.update(compiled=True,sha256=sha(candidate/'RConnectMod.swf'),candidate_sha256=sha(candidate/'RConnectMod.swf'))
    save(candidate/'prepared.json',m)
    out.mkdir();tests=out/'tests'
    base=M52/'a22-room-entry-testpack-05'
    old=read(base/'prepared.json')
    for n,h in old['inputs'].items(): assert sha(base/n)==h,n
    shutil.copytree(base/'tests',tests)
    frozen={str(base.relative_to(ROOT)):sha(base/'prepared.json')}
    for source in [M52/'security-driver-17/tests',M52/'peer-vision-port-07/tests',M52/'peer-projectile-test-05/tests']:
        # Exact test bytes used by the feature owners, with dependencies retained.
        frozen[str(source.relative_to(ROOT))]=inventory(source)
        shutil.copytree(source,tests,dirs_exist_ok=True)
    stub=candidate/'build/GameCombatStubs.swc'
    compiler=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
        '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
    declarations=compiler.copy();declarations[3]=str(SDK/'lib/compc.jar')
    external=out/'ProductionDeclarations.swc'
    env=dict(os.environ,AIR_HOME=str(SDK))
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        def call(cmd): subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=env,check=True)
        classes=['.'.join(p.relative_to(candidate/'src').with_suffix('').parts) for p in sorted((candidate/'src').rglob('*.as'))]
        call(declarations+['-source-path='+str(candidate/'src'),'-external-library-path+='+str(stub),
            '-include-classes='+','.join(classes),'-output='+str(external)])
        extras={}
        for key,cls in [('throw','fe.unit.UnitRaider'),('pause','fe.Pt')]:
            p=out/(key+'-declarations.swc');extras[key]=p
            call(declarations+['-source-path='+str(tests/(key+'-extern')),'-external-library-path+='+str(stub),
                '-include-classes='+cls,'-output='+str(p)])
        harness=out/'EffectsHarness.swf'
        call(compiler+['-source-path='+str(tests/'harness'),'-output='+str(harness),str(tests/'harness/RConnectDoc.as')])
        for name,entry,_,_,_ in CASES:
            driver=out/name;driver.mkdir()
            extra=[]
            if name in ('throw','saved-grip'): extra=['-external-library-path+='+str(extras['throw'])]
            if name=='pause': extra=['-external-library-path+='+str(extras['pause'])]
            call(compiler+extra+['-source-path='+str(tests),'-external-library-path+='+str(external),
                '-external-library-path+='+str(stub),'-output='+str(driver/'EffectsDriver.swf'),str(tests/(entry+'.as'))])
            shutil.copyfile(harness,driver/'EffectsHarness.swf')
            save(driver/'driver-input.json',dict(candidate_sha256=m['sha256'],entry=entry))
            print('BUILT '+name,flush=True)
    save(out/'prepared.json',dict(candidate_sha256=m['sha256'],source_manifest=sha(candidate/'prepared.json'),
        recipe_sha256=sha(__file__),origins=frozen,files=inventory(out)))

def run(candidate, out, drivers, selected, wb, smoke):
    m=verify(candidate);assert m['compiled'] and sha(candidate/'RConnectMod.swf')==m['sha256']
    native=M52/'security-native-02';patch=read(native/'prepared.json')
    assert sha(native/'pfe.swf')==patch['candidate_sha256']
    assert patch['loader_unchanged'] and patch['non_code_tags_unchanged']
    before=installation();assert before['pfe.swf']==patch['original_sha256']
    if wb:
        assert sha(wb/'WallBlendMod.swf')=='2714473057682534f54574fe34669a7179b2b2ff3958fe7ca4485a42db1e04a8'
        assert before['mods/WallBlend/release/WallBlendMod.swf']=='df9aa07265e2538e115a5f048d272b85fc1c34d00ec4bc81585cd40d96648f76'
    if not smoke:
        d=read(drivers/'prepared.json');assert d['candidate_sha256']==m['sha256']
        for n,h in d['files'].items(): assert sha(drivers/n)==h,n
    assert not out.exists();out.mkdir()
    rows=[('smoke',None,'random_mane',120,False)] if smoke else [r for r in CASES if r[0] in selected]
    assert len(rows)==(1 if smoke else len(selected))
    save(out/'intent.json',dict(candidate_sha256=m['sha256'],native=patch,installation=before,wb=str(wb) if wb else None,
        cases=rows,drivers=drivers.relative_to(ROOT).as_posix() if drivers else None,driver_manifest=sha(drivers/'prepared.json') if not smoke else None,runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),wrapper_sha256=sha(__file__)))
    results=[]
    for name,entry,land,seconds,copied in rows:
        cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
            '--candidate',str(candidate/'RConnectMod.swf'),'--game-candidate',str(native/'pfe.swf'),
            '--all-mods','--land',land,'--seconds',str(seconds),'--expected-version',m['version'],'--port',str(test_port())]
        cmd+=['--smoke'] if smoke else ['--effects','--effects-driver',str(drivers/name),'--visible-windows','--defer-visible']
        if wb:cmd+=['--wallblend-candidate',str(wb/'WallBlendMod.swf')]
        if copied:
            copied_root=M52/'littlepip-save-replay-01'
            cmd+=['--host-save-template',str(copied_root/'host/PFEgame0.sol'),'--join-save-template',str(copied_root/'join/PFEgame0.sol'),'--connect-after-load']
        print('START '+name,flush=True)
        with (out/(name+'.log')).open('w',encoding='utf-8') as log: process=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        output=(out/(name+'.log')).read_text(encoding='utf-8',errors='replace')
        match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',output,re.M)
        after=installation();changes={n:dict(before=before.get(n),after=after.get(n)) for n in set(before)|set(after) if before.get(n)!=after.get(n)}
        row=dict(name=name,exit_code=process.returncode,run=match[1] if match else None,installation_changes=changes,passed=False)
        if match:
            folder=ROOT/'build/cooperation'/match[1];info=read(folder/'run.json')
            row['run_sha256']=sha(folder/'run.json')
            for role in ('host','join'):
                inputs=info['inputs'][role];assert inputs['game']==patch['candidate_sha256']
                if not smoke:assert inputs['production']==m['sha256'] and inputs['driver']==sha(drivers/name/'EffectsDriver.swf')
                else:assert info['sha256']==m['sha256'] and 'driver' not in inputs
                path=folder/(role+'.log');raw=path.read_text(encoding='utf-8-sig',errors='replace') if path.exists() else ''
                stdout=folder/(role+'.stdout.log');native_text=stdout.read_text(encoding='utf-8',errors='replace') if stdout.exists() else ''
                errors=[s for s in (raw+'\n'+native_text).splitlines() if 'COOP FAIL' in s or ('obj spawn' in s and 'failed' in s)
                    or re.search(r'\b(?:Error\s*#\d+|ArgumentError|TypeError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',s,re.I)
                    or ('RConnect' in s and (' failed:' in s or ' ERROR' in s))]
                row[role]=dict(checks=len(re.findall(r'^COOP PASS ',raw,re.M)),errors=errors,
                    done=('tick 200' in raw if smoke else 'COOP EFFECTS DONE' in raw),
                    version='v'+m['version']+' initialized' in raw,log_sha256=sha(path) if path.exists() else None)
            row['passed']=process.returncode==0 and not changes and all(row[r]['done'] and row[r]['version'] and not row[r]['errors'] and (smoke or row[r]['checks']>0) for r in ('host','join'))
        results.append(row);save(out/'result.json',results);print(json.dumps(row,ensure_ascii=False),flush=True)
        if not row['passed']:raise SystemExit(1)

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('mode',choices=['build','run','smoke'])
    ap.add_argument('--candidate',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--drivers',type=Path);ap.add_argument('--cases');ap.add_argument('--wb',type=Path)
    a=ap.parse_args();candidate=(ROOT/a.candidate).resolve();out=(ROOT/a.output).resolve()
    assert candidate.parent==M52 and out.parent==M52
    if a.mode=='build':build(candidate,out)
    else:run(candidate,out,(ROOT/a.drivers).resolve() if a.drivers else None,set(a.cases.split(',')) if a.cases else set(),(ROOT/a.wb).resolve() if a.wb else None,a.mode=='smoke')

if __name__=='__main__':main()
