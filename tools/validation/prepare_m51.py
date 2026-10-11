"""Immutable installed-22 baseline, diagnostic snapshots, and final-23 inputs."""
import argparse, datetime, json, re, shutil, subprocess, sys
from validation_baseline import ROOT, GAME, M51_BASELINE, M51_MAP_BASELINE, M51_PRE_VISION_BASELINE, M51_SHA, sha, read, verify_protected
from native_runtime_assets import asset_hashes
from run_final_regressions import JAVA, M51_REQUIRED

ap=argparse.ArgumentParser()
ap.add_argument('mode', choices=['baseline','freeze','control','build'])
ap.add_argument('snapshot', nargs='?')
ap.add_argument('--baseline', choices=[M51_BASELINE,M51_MAP_BASELINE],default=M51_BASELINE)
a=ap.parse_args()
previous=ROOT/'build/m50/final-presentation-30'
def save(path,value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def copy(src,dst): dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
if a.mode=='baseline':
    receipt=read(previous/'deployment.json')
    assert receipt['status']=='deployed-smoke-passed' and receipt['sha256']==M51_SHA
    assert sha(ROOT/'release/RConnectMod.swf')==M51_SHA
    old=read(ROOT/'knowledge/experiments/m50-validation-evidence.json')['protected']['hashes']
    protected={n:sha(GAME/n) for n in old}
    changes={n:dict(before=h,after=protected[n]) for n,h in old.items() if h!=protected[n]}
    modules,configs={},{}
    for row in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if row.startswith('#') or '|' not in row: continue
        directory,entry=row.split('|')[:2]
        if directory.lower()=='rconnect': continue
        for filename in (entry+'.swf','config.txt','config.json'):
            p=GAME/'mods'/directory/'release'/filename
            if p.is_file():
                n=p.relative_to(GAME).as_posix();protected[n]=sha(p)
                (modules if p.suffix=='.swf' else configs)[n]=sha(p)
    assets=asset_hashes(GAME);protected.update(assets)
    protected['mods/RConnect/release/RConnectMod.swf']=M51_SHA
    prior=read(ROOT/M51_PRE_VISION_BASELINE/'inputs.json')
    transition={n:dict(before=h,after=protected[n]) for n,h in prior['protected'].items() if h!=protected[n]}
    rv_receipt=GAME/'mods/RealisticVision/build/exploration-cache-20261010-02/deployment.json'
    rv=read(rv_receipt);assert rv['status']=='deployed-smoke-passed'
    assert transition=={'mods/RealisticVision/release/RealisticVisionMod.swf':dict(before=rv['previous_sha256'],after=rv['sha256'])},transition
    out=ROOT/M51_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    save(out/'inputs.json',dict(version='0.2.22-dev',release_sha256=M51_SHA,protected=protected,
        runtime_modules=modules,runtime_config=configs,runtime_assets=assets,external_changes=changes,
        previous_baseline=M51_PRE_VISION_BASELINE,previous_baseline_sha256=sha(ROOT/M51_PRE_VISION_BASELINE/'inputs.json'),
        authorized_external_transition=transition,external_deployment_receipt=rv_receipt.relative_to(GAME).as_posix(),external_deployment_sha256=sha(rv_receipt),
        previous_deployment='build/m50/final-presentation-30/deployment.json',previous_deployment_sha256=sha(previous/'deployment.json'),
        at=datetime.datetime.now().astimezone().isoformat()))
    print(json.dumps(dict(baseline=M51_BASELINE,protected=len(protected),changes=changes),ensure_ascii=False))
    raise SystemExit(0)
out=(ROOT/a.snapshot).resolve()
assert out.parent==ROOT/'build/m51' and out.name.startswith(('final-','red-','probe-')),out
if a.mode in ('freeze','control'):
    if a.baseline==M51_MAP_BASELINE:assert not out.name.startswith('final-'),'Diagnostic-only map baseline'
    out.mkdir(parents=True,exist_ok=False)
    origin=previous if a.mode=='control' else ROOT
    version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(origin/'src/RConnectMod.as').read_text(encoding='utf-8-sig')).group(1)
    m=dict(version=version,baseline_path=a.baseline,baseline_inputs_sha256=sha(ROOT/a.baseline/'inputs.json'),
        source={},verification={},visible_windows=True,concurrent_user_windows=True)
    verify_protected(m)
    for directory in ('src','tests','tools/stubs'):
        source=origin if directory=='src' else ROOT
        for p in sorted((source/directory).rglob('*')):
            if not p.is_file():continue
            n=p.relative_to(source).as_posix();copy(p,out/n)
            (m['source'] if directory=='src' else m['verification'])[n]=sha(p)
    for p in sorted((ROOT/'tools').glob('*.py'))+sorted((ROOT/'tools').glob('*.ps1'))+sorted((ROOT/'tools/validation').glob('*.py')):
        n=p.relative_to(ROOT).as_posix();copy(p,out/n);m['verification'][n]=sha(p)
    if a.mode=='control':
        for n in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):copy(previous/n,out/n)
        copy(previous/'GameCombatStubs.swc',out/'build/GameCombatStubs.swc')
        assert sha(out/'RConnectMod.swf')==M51_SHA
        m.update(candidate_sha256=M51_SHA,reuse='exact installed 22; original compilation in M50 final27')
    if out.name.startswith('final-'):
        m['required_entries']=M51_REQUIRED
        m['profiles']={}
        for role,profile in read(previous/'source-input.json')['profiles'].items():
            src=ROOT/profile['path'];assert sha(src)==profile['sha256']
            dest=out/'profiles'/src.name;copy(src,dest)
            m['profiles'][role]=dict(path=dest.relative_to(ROOT).as_posix(),sha256=sha(dest))
        v=dict(m['verification'])
        for n,h in v.items():copy(ROOT/n,out/'verified-files'/n)
        for profile in m['profiles'].values():
            n=profile['path'];copy(ROOT/n,out/'verified-files'/n);v[n]=profile['sha256']
        save(out/'verified-test-input.json',v)
    save(out/'source-input.json',m)
    print(json.dumps(dict(snapshot=str(out),version=version,sources=len(m['source']))))
else:
    m=read(out/'source-input.json');verify_protected(m)
    for n,h in {**m['source'],**m['verification']}.items():assert sha(out/n)==h,n
    assert not (out/'RConnectMod.swf').exists()
    with (out/'build.log').open('w',encoding='utf-8') as log:
        r=subprocess.run([sys.executable,'-X','utf8',str(out/'tools/build_mod.py'),'--java',JAVA,
            '--output',str(out/'RConnectMod.swf')],cwd=out,stdout=log,stderr=subprocess.STDOUT)
    if r.returncode:
        print((out/'build.log').read_bytes().decode('gb18030',errors='replace')[-6000:]);raise SystemExit(r.returncode)
    with (out/'classes.txt').open('w',encoding='utf-8') as log:
        subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar','-dumpAS3',str(out/'RConnectMod.swf')],stdout=log,check=True)
    actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
    expected={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
    assert actual==expected
    copy(out/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
    m.update(candidate_sha256=sha(out/'RConnectMod.swf'),build_exit=0,size=(out/'RConnectMod.swf').stat().st_size,
        classes=len(actual),stub_sha256=sha(out/'GameCombatStubs.swc'),class_list_sha256=sha(out/'classes.txt'))
    save(out/'source-input.json',m);print(json.dumps({k:m[k] for k in ('candidate_sha256','size','classes')}))
