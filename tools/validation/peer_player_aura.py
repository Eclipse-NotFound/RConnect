"""Freeze and exercise the player aura increment on installed bundle2 only."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from check_coop_bundle import ROOT, M52, JAVA, SDK, inventory, read, save, sha, verify
from run_security_terminals import installation, test_port

BASE = M52/'coop-bundle-04'
BASE_SHA = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
OVERLAY = ROOT/'experimental/peer-player-aura'
CHANGED = {'RConnectMod.as', 'rconnect/core/PeerGrip.as', 'rconnect/game/TelekinesisVisuals.as',
           'rconnect/game/PlayerBodyEffects.as', 'rconnect/game/GameBridge.as'}


def frozen(candidate):
    m=read(candidate/'prepared.json')
    assert m['kind']=='peer-player-aura' and m['base_sha256']==BASE_SHA
    for n,h in m['source'].items(): assert sha(candidate/'src'/n)==h,n
    for n,h in m['inputs'].items(): assert sha(candidate/'tools'/n)==h,n
    assert m['compiled'] and sha(candidate/'RConnectMod.swf')==m['sha256']
    return m


def prepare(out):
    assert not out.exists()
    b=verify(BASE);assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    shutil.copytree(BASE/'src',out/'src');shutil.copytree(BASE/'tools',out/'tools')
    for p in (OVERLAY/'src').rglob('*.as'):
        shutil.copyfile(p,out/'src'/p.relative_to(OVERLAY/'src'))
    p=out/'src/RConnectMod.as';s=p.read_text(encoding='utf-8-sig')
    assert s.count(b['version'])==1
    version='0.2.24-peer-aura1'
    p.write_text(s.replace(b['version'],version),encoding='utf-8',newline='\n')
    sources=inventory(out/'src');original=inventory(BASE/'src')
    assert {n for n,h in sources.items() if original.get(n)!=h}==CHANGED
    save(out/'prepared.json',dict(kind='peer-player-aura',version=version,base_sha256=BASE_SHA,
        base_manifest=sha(BASE/'prepared.json'),source=sources,inputs=inventory(out/'tools'),
        recipe_sha256=sha(__file__),compiled=False,installation_modified=False))


def compile_all(candidate, out):
    assert not out.exists();out.mkdir()
    m=read(candidate/'prepared.json')
    for n,h in m['source'].items(): assert sha(candidate/'src'/n)==h,n
    for n,h in m['inputs'].items(): assert sha(candidate/'tools'/n)==h,n
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 玩家念力光晕编译',purpose='正式候选及独立驱动编译，无游戏',
                      run_dir=out,evidence=out/'compile.log',wait=900) as record:
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            def call(command):
                subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True,
                               env=dict(os.environ,AIR_HOME=str(SDK)))
            if not m['compiled']:
                call([sys.executable,'-B','-X','utf8',str(candidate/'tools/build_mod.py'),'--java',str(JAVA),
                      '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(candidate/'RConnectMod.swf')])
                m.update(compiled=True,sha256=sha(candidate/'RConnectMod.swf'));save(candidate/'prepared.json',m)
            else:
                frozen(candidate)
            tests=out/'tests';shutil.copytree(ROOT/'tests',tests)
            for p in (OVERLAY/'tests').rglob('*.as'):
                shutil.copyfile(p,tests/p.relative_to(OVERLAY/'tests'))
            compiler=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
                      '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
            decl=compiler.copy();decl[3]=str(SDK/'lib/compc.jar')
            extern=out/'ProductionDeclarations.swc';stub=candidate/'build/GameCombatStubs.swc'
            classes=['.'.join(p.relative_to(candidate/'src').with_suffix('').parts) for p in sorted((candidate/'src').rglob('*.as'))]
            call(decl+['-source-path='+str(candidate/'src'),'-external-library-path+='+str(stub),
                       '-include-classes='+','.join(classes),'-output='+str(extern)])
            for entry in ['PeerGripTestDoc','PeerThrowDamageTestDoc']:
                folder=out/entry;folder.mkdir()
                call(compiler+['-source-path='+str(tests),'-external-library-path+='+str(extern),
                     '-external-library-path+='+str(stub),'-output='+str(folder/'EffectsDriver.swf'),str(tests/(entry+'.as'))])
                call(compiler+['-source-path='+str(tests/'harness'),'-output='+str(folder/'EffectsHarness.swf'),str(tests/'harness/RConnectDoc.as')])
            files=inventory(out);files.pop('compile.log',None)
            save(out/'prepared.json',dict(candidate_sha256=m['sha256'],files=files,recipe_sha256=sha(__file__)))
        record.outcome='passed';record.note='生产与外部专项驱动编译通过，尚未验证功能'
    print(json.dumps(dict(candidate=m['sha256'],driver=str(out))),flush=True)


def run(candidate, drivers, out, control, entry):
    assert not out.exists()
    m=frozen(candidate);dm=read(drivers/'prepared.json')
    assert dm['candidate_sha256']==m['sha256']
    for n,h in dm['files'].items():assert sha(drivers/n)==h,n
    origin=BASE if control else candidate
    version=read(BASE/'prepared.json')['version'] if control else m['version']
    binary=origin/'RConnectMod.swf';digest=sha(binary)
    before=installation();out.mkdir();binding=out/'driver';binding.mkdir()
    for n in ['EffectsDriver.swf','EffectsHarness.swf']:shutil.copyfile(drivers/entry/n,binding/n)
    save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf')))
    cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
         '--candidate',str(binary),'--effects','--effects-driver',str(binding),'--all-mods',
         '--land','random_mane','--seconds','420','--expected-version',version,'--port',str(test_port()),
         '--private-desktop','--defer-visible','--wait-host-world','--registry-wait','900']
    save(out/'intent.json',dict(candidate_sha256=digest,driver_manifest=sha(drivers/'prepared.json'),
        entry=entry,control=control,installation_before=before,command=cmd,wrapper_sha256=sha(__file__),
        runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),functional_only=True,
        timing_claims=False,allow_existing_user_air=True))
    with (out/'runner.log').open('w',encoding='utf-8') as log:
        p=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
    match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',raw,re.M)
    after=installation();result=dict(exit_code=p.returncode,run=match[1] if match else None,
        installation_unchanged=before==after,passed=False,roles={})
    if match:
        folder=ROOT/'build/cooperation'/match[1];info=read(folder/'run.json')
        for role in ['host','join']:
            inp=info['inputs'][role]
            assert inp['production']==digest and inp['driver']==sha(binding/'EffectsDriver.swf')
            assert inp['game']==before['pfe.swf']
            path=folder/(role+'.log');text=path.read_text(encoding='utf-8-sig',errors='replace')
            all_text=text+'\n'+(folder/(role+'.stdout.log')).read_text(encoding='utf-8',errors='replace')
            for extra in (folder/'module-logs'/role).glob('*.log'):
                if extra.name!='RConnect.log':all_text+='\n'+extra.read_text(encoding='utf-8',errors='replace')
            errors=[line for line in all_text.splitlines() if 'COOP FAIL ' in line or 'game error dialog' in line
                or ('RConnect' in line and ' failed ' in line)
                or re.search(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line,re.I)]
            scene_log=folder/'module-logs'/role/'ContinuousScene.log'
            scene_text=scene_log.read_text(encoding='utf-8',errors='replace') if scene_log.exists() else ''
            if '[ContinuousScene] registered ' not in scene_text:errors.append('ContinuousScene initialization was not confirmed')
            scene_asset='mods/ContinuousScene/release/scene.xml'
            if inp.get('mod_assets',{}).get(scene_asset)!=before.get(scene_asset):errors.append('ContinuousScene scene asset differs or is missing')
            result['roles'][role]=dict(checks=len(re.findall(r'^COOP PASS ',text,re.M)),errors=list(dict.fromkeys(errors)),
                done='COOP EFFECTS DONE' in text,version='v'+version+' initialized' in text,log_sha256=sha(path))
        result['passed']=p.returncode==0 and before==after and all(
            r['checks']>0 and r['done'] and r['version'] and not r['errors'] for r in result['roles'].values())
    save(out/'result.json',result);print(json.dumps(result,ensure_ascii=False),flush=True)
    if not result['passed']:raise SystemExit(1)


def component(candidate,out,control):
    frozen(candidate);verify(BASE);assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert not out.exists();out.mkdir()
    source=BASE if control else candidate;src=out/'src'
    shutil.copytree(OVERLAY/'component',src)
    originals={}
    for name in ['TelekinesisVisuals','PlayerBodyEffects']:
        p=source/'src/rconnect/game'/(name+'.as');originals[str(p)]=sha(p)
        shutil.copyfile(p,src/'rconnect/game'/p.name)
    before=installation()
    save(out/'inputs.json',dict(source=str(source),originals=originals,files=inventory(src),
         installation=before,wrapper_sha256=sha(__file__),game_loaded=False))
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    from air_test_process import HiddenProcess
    from runtime_memory import snapshot,wait_owned
    with Registration(owner='RConnect (3) / 玩家光晕显示组件',purpose='实际AIR滤镜/像素与显示所有权；不是原生双人验收',
                      run_dir=out,evidence=out/'receipt.json',wait=900) as record:
        cmd=[str(JAVA),'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
             '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
             '-source-path='+str(src),'-output='+str(out/'Checks.swf'),str(src/'PlayerAuraChecks.as')]
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
        memory=snapshot();save(out/'memory-before.json',memory)
        assert memory['free_commit_bytes']>=3*1024**3,'Less than 3 GiB headroom; no component AIR started'
        appid='rconnect-player-aura-'+uuid.uuid4().hex;app=out/'application.xml'
        app.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+
            '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>'+
            '<content>Checks.swf</content><visible>false</visible><width>120</width><height>120</height>'+
            '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>',encoding='utf-8')
        with (out/'stdout.log').open('w',encoding='utf-8') as log:
            record.before_launch('component / '+appid)
            process=HiddenProcess([str(ROOT.parents[1]/'adl64.exe'),'-runtime',str(ROOT.parents[1]/'runtimes/air/win64'),str(app)],
                                  cwd=out,stdout=log,stderr=log)
            record.child(process.pid);save(out/'process.json',dict(pid=process.pid,appid=appid,desktop=process.desktop))
            try:code=wait_owned(process,40,out/'memory-timeline.json')
            finally:
                if process.poll() is None:process.kill();process.wait()
                process.close();record.child_stopped()
        result_path=Path(os.environ['APPDATA'])/appid/'Local Store/result.json';results={}
        if result_path.is_file():
            shutil.copyfile(result_path,out/'result.json');results=read(out/'result.json')
        result=dict(exit=code,pass_count=results.get('pass'),fail_count=results.get('fail'),
            installation_unchanged=before==installation(),source_unchanged=all(sha(Path(p))==h for p,h in originals.items()),
            compiled_sha256=sha(out/'Checks.swf'),native_pair_qualified=False)
        save(out/'receipt.json',result);print(json.dumps(result),flush=True)
        for row in results.get('checks',[]):
            if not row['pass']:print(json.dumps(row),flush=True)
        if code or results.get('fail')!=0 or not result['installation_unchanged'] or not result['source_unchanged']:raise SystemExit(code or 1)
        record.outcome='passed';record.note='AIR显示组件通过；原生抓取与TCP双人验收仍待进行'


def main():
    ap=argparse.ArgumentParser();ap.add_argument('mode',choices=['prepare','build','run','component'])
    ap.add_argument('--candidate',required=True);ap.add_argument('--output');ap.add_argument('--drivers')
    ap.add_argument('--control',action='store_true')
    ap.add_argument('--entry',default='PeerGripTestDoc',choices=['PeerGripTestDoc','PeerThrowDamageTestDoc'])
    a=ap.parse_args();candidate=(ROOT/a.candidate).resolve()
    assert candidate.parent==M52
    out=(ROOT/a.output).resolve() if a.output else None
    if out:assert out.parent==M52
    if a.mode=='prepare':prepare(candidate)
    elif a.mode=='build':compile_all(candidate,out)
    elif a.mode=='component':component(candidate,out,a.control)
    else:
        drivers=(ROOT/a.drivers).resolve();assert drivers.parent==M52
        run(candidate,drivers,out,a.control,a.entry)


if __name__=='__main__':main()
