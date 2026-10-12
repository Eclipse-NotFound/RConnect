"""Exercise the unclaimed native callbacks and the default TDFC loop in one isolated game."""
import argparse
import os
import shutil
import subprocess
import time
import uuid
from pathlib import Path
from common import ROOT, EXPERIMENT, SDK, JAVA, inside_build, read, save, sha, verify_baseline, verify_files
from run_probe import records


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--baseline',required=True)
    ap.add_argument('--tdfc',required=True)
    ap.add_argument('--native',help='Omit to use the original pinned native SWF')
    ap.add_argument('--rv',help='Independent RV candidate; leave its B API unattached')
    ap.add_argument('--msw',help='Independent MSW candidate; leave its B API unattached')
    ap.add_argument('--sandy',help='Independent Sandevistan candidate; leave its B API unattached')
    ap.add_argument('--seconds',type=int,default=300)
    ap.add_argument('--compile-only',action='store_true',help='Freeze and compile the isolated default driver without copying or launching a game')
    ap.add_argument('--output',required=True)
    args=ap.parse_args()
    baseline,tdfc,out=[inside_build(ROOT/p) for p in (args.baseline,args.tdfc,args.output)]
    b=verify_baseline(baseline);tb=read(tdfc/'build-input.json');verify_files(tdfc,tb['sources'])
    if sha(tdfc/'TDFCMod.swf')!=tb['candidate_sha256']:raise ValueError('TDFC bytes changed')
    native=inside_build(ROOT/args.native) if args.native else None
    if native:
        n=read(native/'native-input.json');verify_files(native,n['sources'])
        if n['baseline_manifest_sha256']!=sha(baseline/'baseline.json') or sha(native/'pfe.swf')!=n['candidate_sha256']:raise ValueError('Native bytes changed')
    extras=[]
    for name,filename,family in (('rv','mods/RealisticVision/release/RealisticVisionMod.swf','rv-authority-v1'),
                                  ('msw','mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf','msw-authority-v1'),
                                  ('sandy','mods/Sandevistan/release/SandevistanMod.swf','sandy-authority-v1')):
        if getattr(args,name):
            directory=inside_build(ROOT/getattr(args,name));manifest=read(directory/'build-input.json')
            verify_files(directory,manifest['sources'])
            artifact=directory/Path(filename).name
            if manifest.get('family')!=family or not manifest.get('experimental_only') or sha(artifact)!=manifest['candidate_sha256']:
                raise ValueError('Independent '+name+' candidate differs')
            extras.append((name,directory,filename,artifact))
    if out.exists():raise FileExistsError('Fresh validation directory required')
    out.mkdir(parents=True);(out/'src').mkdir();(out/'tools').mkdir()
    for name in ('check_native_default.py','common.py','run_probe.py'):
        shutil.copy2(Path(__file__).parent/name,out/'tools'/name)
    source=out/'src/RConnectMod.as';shutil.copy2(EXPERIMENT/'native-default/RConnectMod.as',source)
    cmd=[str(JAVA),'-Xmx512m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
         '-source-path='+str(out/'src'),'-swf-version=38','-debug=true','-optimize=false','-output='+str(out/'RConnectMod.swf'),str(source)]
    with (out/'build.log').open('w',encoding='utf-8') as log:
        subprocess.run(cmd,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
    if args.compile_only:
        save(out/'compile.json',dict(experimental_only=True,compiled=True,runtime_validation=False,
            source_sha256=sha(source),candidate_sha256=sha(out/'RConnectMod.swf'),command=cmd,
            compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'frameworks/libs/air/airglobal.swc')}))
        print(dict(compiled=True,runtime_validation=False,path=str(out)),flush=True)
        return
    game=out/'game';shutil.copytree(baseline/'game',game)
    shutil.copy2(out/'RConnectMod.swf',game/'mods/Rconnect/release/RConnectMod.swf')
    shutil.copy2(tdfc/'TDFCMod.swf',game/'mods/TDFC/release/TDFCMod.swf')
    if native:shutil.copy2(native/'pfe.swf',game/'pfe.swf')
    for _,_,filename,artifact in extras:shutil.copy2(artifact,game/filename)
    expected=dict(b['files'])
    for name in expected:
        if name.lower() in ('pfe.swf','mods/rconnect/release/rconnectmod.swf','mods/tdfc/release/tdfcmod.swf') or any(name.lower()==entry[2].lower() for entry in extras):expected[name]=sha(game/name)
    verify_files(game,expected)
    appid='pfe-modsettings-rconnect-default-'+uuid.uuid4().hex[:12]
    storage=Path(os.environ['APPDATA'])/appid/'Local Store'
    if storage.exists():raise FileExistsError('Fresh AIR store required')
    desc=game/'default-test.xml'
    desc.write_text('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
        '<id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>Native default validation</filename>'
        '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
    protected={name:sha(ROOT.parents[1]/name) for name in ('pfe.swf','mods/Rconnect/release/RConnectMod.swf','mods/TDFC/release/TDFCMod.swf',
        'mods/RealisticVision/release/RealisticVisionMod.swf','mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf',
        'mods/Sandevistan/release/SandevistanMod.swf','mods/Sandevistan/release/config.txt')}
    command=[str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)]
    receipt=dict(appid=appid,command=command,files=expected,protected_before=protected,
        baseline_manifest_sha256=sha(baseline/'baseline.json'),tdfc_manifest_sha256=sha(tdfc/'build-input.json'),
        native_manifest_sha256=sha(native/'native-input.json') if native else None,
        source_sha256=sha(source),descriptor_sha256=sha(desc),compiler_command=cmd,
        compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'frameworks/libs/air/airglobal.swc')})
    receipt['external_manifests']={name:sha(directory/'build-input.json') for name,directory,_,_ in extras}
    with (out/'stdout.log').open('w',encoding='utf-8') as log:
        proc=subprocess.Popen(command,cwd=game,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        receipt['pid']=proc.pid;save(out/'run.json',receipt)
        print(dict(pid=proc.pid,appid=appid),flush=True)
        try:
            deadline=time.monotonic()+args.seconds
            while time.monotonic()<deadline and proc.poll() is None:
                if any(r['kind']=='DONE' for r in records(storage/'RConnect-B.log')):break
                time.sleep(1)
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:proc.wait(timeout=10)
                except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=10)
    for name in ('RConnect-B.log','tdfc.log','RVision.log','ModSettings.log','sandy_modlog.txt'):
        if (storage/name).is_file():shutil.copy2(storage/name,out/name)
    events=records(storage/'RConnect-B.log')
    receipt.update(passed=sum(r['kind']=='PASS' for r in events),failed=sum(r['kind']=='FAIL' for r in events),
        fatal=[r for r in events if r['kind']=='FATAL'],done=any(r['kind']=='DONE' for r in events),
        owned_process_exited=proc.poll() is not None,process_exit=proc.returncode)
    tactics=(out/'tdfc.log').read_text(encoding='utf-8') if (out/'tdfc.log').exists() else ''
    receipt['default_tdfc_observed']='heartbeat' in tactics and 'decision' in tactics and 'authority attached' not in tactics and '] error ' not in tactics
    verify_files(game,expected)
    receipt['runtime_unchanged']=sha(desc)==receipt['descriptor_sha256']
    receipt['installation_unchanged']=all(sha(ROOT.parents[1]/name)==digest for name,digest in protected.items())
    save(out/'run.json',receipt)
    ok=receipt['done'] and receipt['failed']==0 and not receipt['fatal'] and receipt['default_tdfc_observed'] and receipt['installation_unchanged'] and receipt['runtime_unchanged']
    print(dict(path=str(out),ok=ok,passed=receipt['passed'],failed=receipt['failed'],fatal=receipt['fatal']),flush=True)
    raise SystemExit(0 if ok else 1)


if __name__=='__main__':main()
