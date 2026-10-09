"""Freeze the installed 21 baseline and independent 21/22 peer presentation checks."""
import argparse, ast, datetime, json, re, shutil
from validation_baseline import ROOT, GAME, M50_BASELINE, M50_ORIGINAL_BASELINE, M50_WALL_BASELINE, M50_SHA, sha, read, verify_protected
from native_runtime_assets import asset_hashes
from run_final_regressions import M50_REQUIRED

ap=argparse.ArgumentParser()
ap.add_argument('mode', choices=['baseline','external-update','asset-update','freeze','built','installed-control'])
ap.add_argument('snapshot', nargs='?')
a=ap.parse_args()
def save(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
previous=ROOT/'build/m49/final-lifecycle-16'
if a.mode=='baseline':
    receipt=read(previous/'deployment.json')
    assert receipt['status']=='deployed-smoke-passed' and receipt['sha256']==M50_SHA
    evidence=read(ROOT/'knowledge/experiments/m49-validation-evidence.json')
    protected=dict(evidence['protected']['hashes'])
    protected['mods/RConnect/release/RConnectMod.swf']=M50_SHA
    # The user installation gained WallBlend after M49; preserve that external
    # change explicitly. All previous binaries/configs still have to match.
    changed={n:dict(before=h,after=sha(GAME/n)) for n,h in protected.items() if sha(GAME/n)!=h}
    assert changed=={'mods/loader-manifest.txt':dict(before='2d4a64a608a6482168fbfe9e8cd7bb53f006ab1f8993fcc737cf9d32f2293592',after='5ec171aecab8590434c04b4f995b24b638dd88f0ec97f8078acea89a419ab18c')},changed
    protected['mods/loader-manifest.txt']=changed['mods/loader-manifest.txt']['after']
    for row in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if row.startswith('#') or '|' not in row:continue
        directory,entry=row.split('|')[:2]
        for filename in (entry+'.swf','config.txt'):
            path=GAME/'mods'/directory/'release'/filename
            if path.is_file():protected[path.relative_to(GAME).as_posix()]=sha(path)
    for n,h in protected.items():assert sha(GAME/n)==h,n
    out=ROOT/M50_ORIGINAL_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    save(out/'inputs.json',dict(version='0.2.21-dev',release_sha256=M50_SHA,protected=protected,external_changes=changed,
         at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
         previous_deployment=str(previous.relative_to(ROOT)/'deployment.json'),
         previous_deployment_sha256=sha(previous/'deployment.json')))
    print(json.dumps(dict(baseline=M50_ORIGINAL_BASELINE,protected=len(protected))))
elif a.mode=='external-update':
    old=ROOT/M50_ORIGINAL_BASELINE
    original=read(old/'inputs.json');protected=dict(original['protected'])
    changed={n:dict(before=h,after=sha(GAME/n)) for n,h in protected.items() if sha(GAME/n)!=h}
    wall='mods/WallBlend/release/WallBlendMod.swf'
    assert changed=={wall:dict(before='014be5a3b63b20d609c159c424d4e9dc260df742c7ba1e4984fc0b6a06ca6821',
                             after='5b35cae5a2700e6e340af905e45d56e08c6f5f7a0be622ec910d2d2f2fa3bae3')},changed
    protected[wall]=changed[wall]['after']
    modules,configs={},{}
    for row in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if row.startswith('#') or '|' not in row:continue
        directory,entry=row.split('|')[:2]
        if directory.lower()=='rconnect':continue
        for filename in (entry+'.swf','config.txt','config.json'):
            p=GAME/'mods'/directory/'release'/filename
            if p.is_file():
                n=p.relative_to(GAME).as_posix();h=sha(p)
                protected[n]=h
                (modules if p.suffix=='.swf' else configs)[n]=h
    assert sha(ROOT/'release/RConnectMod.swf')==M50_SHA
    out=ROOT/M50_WALL_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    save(out/'inputs.json',dict(version='0.2.21-dev',release_sha256=M50_SHA,protected=protected,
         runtime_modules=modules,runtime_config=configs,external_changes=changed,
         previous_baseline=M50_ORIGINAL_BASELINE,previous_inputs_sha256=sha(old/'inputs.json'),
         external_receipt='mods/WallBlend/build/backups/upgrade-20261009-101821/receipt.json',
         external_receipt_sha256=sha(GAME/'mods/WallBlend/build/backups/upgrade-20261009-101821/receipt.json'),
         at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()))
    print(json.dumps(dict(baseline=M50_WALL_BASELINE,protected=len(protected),external_modules=len(modules),configs=len(configs))))
elif a.mode=='asset-update':
    old=ROOT/M50_WALL_BASELINE
    original=verify_protected(dict(version='0.2.22-dev',baseline_path=M50_WALL_BASELINE,baseline_inputs_sha256=sha(old/'inputs.json')))
    assets=asset_hashes(GAME);protected=dict(original['protected'])
    for n,h in assets.items():
        assert n not in protected or protected[n]==h,n
        protected[n]=h
    out=ROOT/M50_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    save(out/'inputs.json',dict(version='0.2.21-dev',release_sha256=M50_SHA,protected=protected,
         runtime_modules=original['runtime_modules'],runtime_config=original['runtime_config'],runtime_assets=assets,
         previous_baseline=M50_WALL_BASELINE,previous_inputs_sha256=sha(old/'inputs.json'),
         reason='Preserve native Music and bind all copied native runtime assets; no installation changed',
         at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()))
    print(json.dumps(dict(baseline=M50_BASELINE,protected=len(protected),native_assets=len(assets))))
else:
    out=(ROOT/a.snapshot).resolve()
    assert out.parent==ROOT/'build/m50' and out.name.startswith(('final','red-')),out
    if a.mode=='freeze':
        version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(ROOT/'src/RConnectMod.as').read_text(encoding='utf-8-sig')).group(1)
        if out.name.startswith("red-"): version="0.2.21-dev"
        assert version==('0.2.21-dev' if out.name.startswith('red-') else '0.2.22-dev')
        entries=list(M50_REQUIRED)
        for entry in entries:assert (ROOT/'tests'/(entry+'.as')).is_file(),entry
        m=dict(version=version,baseline_path=M50_BASELINE,baseline_inputs_sha256=sha(ROOT/M50_BASELINE/'inputs.json'),required_entries=entries,
               visible_windows=True)
        verify_protected(m);out.mkdir(parents=True,exist_ok=False);m['source']={}
        source_origin=previous if out.name.startswith('red-') else ROOT
        for p in sorted((source_origin/'src').rglob('*')):
            if p.is_file():n=p.relative_to(source_origin).as_posix();copy(p,out/n);m['source'][n]=sha(p)
        paths=sorted((ROOT/'tests').rglob('*.as'))+sorted((ROOT/'tools/stubs').rglob('*.as'))
        paths += [ROOT/'tools'/n for n in ('build_mod.py','build_effects_driver.py','run_coop_regression.py','RConnect.Process.ps1','keep_test_responsive.ps1','verify_mask_png.py')]
        paths += sorted((ROOT/'tools/validation').glob('*.py'));m['profiles']={}
        for role in ('host','join'):
            profile=read(previous/'source-input.json')['profiles'][role];p=ROOT/profile['path'];assert sha(p)==profile['sha256']
            dest=out/'profiles'/p.name;copy(p,dest);paths.append(dest)
            m['profiles'][role]=dict(path=dest.relative_to(ROOT).as_posix(),sha256=sha(dest))
        v={}
        for p in paths:
            n=p.relative_to(ROOT).as_posix();copy(p,out/'verified-files'/n);v[n]=sha(p)
            if p.suffix=='.py':ast.parse(p.read_text(encoding='utf-8-sig'))
        save(out/'source-input.json',m);save(out/'verified-test-input.json',v)
        print(json.dumps(dict(version=version,sources=len(m['source']),verification=len(v))))
    else:
        m=read(out/'source-input.json');verify_protected(m)
        for n,h in m['source'].items():
            assert sha(out/n)==h,n
            if not out.name.startswith('red-'):assert sha(ROOT/n)==h,n
        if a.mode=='installed-control':
            old=read(previous/'source-input.json');assert m['source']==old['source']
            for n in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):copy(previous/n,out/n)
            assert sha(out/'RConnectMod.swf')==M50_SHA
            save(out/'candidate-reuse.json',dict(origin=previous.relative_to(ROOT).as_posix(),sha256=M50_SHA,kind='installed-21-negative-control'))
        else:copy(ROOT/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
        actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
        expected={s.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for s in (out/'src').rglob('*.as')}
        assert actual==expected,(actual-expected,expected-actual)
        m.update(candidate_sha256=sha(out/'RConnectMod.swf'),size=(out/'RConnectMod.swf').stat().st_size,classes=len(actual),
                 stub_sha256=sha(out/'GameCombatStubs.swc'),class_list_sha256=sha(out/'classes.txt'),build_exit=0)
        save(out/'source-input.json',m);print(json.dumps({k:m[k] for k in ('candidate_sha256','classes','size')}))
