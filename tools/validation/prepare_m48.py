"""Freeze the installed 19 baseline and independent 19/20 continuity checks."""
import argparse, ast, datetime, json, re, shutil
from validation_baseline import ROOT, GAME, M48_BASELINE, M48_SHA, sha, read, verify_protected
from run_final_regressions import REQUIRED

ap=argparse.ArgumentParser()
ap.add_argument('mode', choices=['baseline','freeze','built','installed-control'])
ap.add_argument('snapshot', nargs='?')
a=ap.parse_args()
def save(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
previous=ROOT/'build/m47/final-presentation-07'
if a.mode=='baseline':
    receipt=read(previous/'deployment.json')
    assert receipt['status']=='deployed-smoke-passed' and receipt['sha256']==M48_SHA
    evidence=read(ROOT/'knowledge/experiments/m47-validation-evidence.json')
    protected=dict(evidence['protected']['hashes'])
    protected['mods/RConnect/release/RConnectMod.swf']=M48_SHA
    for n,h in protected.items():assert sha(GAME/n)==h,n
    out=ROOT/M48_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    save(out/'inputs.json',dict(version='0.2.19-dev',release_sha256=M48_SHA,protected=protected,
         at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
         previous_deployment=str(previous.relative_to(ROOT)/'deployment.json'),
         previous_deployment_sha256=sha(previous/'deployment.json')))
    print(json.dumps(dict(baseline=M48_BASELINE,protected=len(protected))))
else:
    out=(ROOT/a.snapshot).resolve()
    assert out.parent==ROOT/'build/m48' and out.name.startswith(('final','red-')),out
    if a.mode=='freeze':
        version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(ROOT/'src/RConnectMod.as').read_text(encoding='utf-8-sig')).group(1)
        assert version==('0.2.19-dev' if out.name.startswith('red-') else '0.2.20-dev')
        entries=REQUIRED+['HudTestDoc','FastHeldTestDoc','WeaponAngleTestDoc']
        if version=='0.2.20-dev':entries+=['PresentationContinuityTestDoc']
        m=dict(version=version,baseline_path=M48_BASELINE,baseline_inputs_sha256=sha(ROOT/M48_BASELINE/'inputs.json'),required_entries=entries)
        verify_protected(m);out.mkdir(parents=True,exist_ok=False);m['source']={}
        for p in sorted((ROOT/'src').rglob('*')):
            if p.is_file():n=p.relative_to(ROOT).as_posix();copy(p,out/n);m['source'][n]=sha(p)
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
        for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
        if a.mode=='installed-control':
            old=read(previous/'source-input.json');assert m['source']==old['source']
            for n in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):copy(previous/n,out/n)
            assert sha(out/'RConnectMod.swf')==M48_SHA
            save(out/'candidate-reuse.json',dict(origin=previous.relative_to(ROOT).as_posix(),sha256=M48_SHA,kind='installed-19-negative-control'))
        else:copy(ROOT/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
        actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
        expected={s.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for s in (out/'src').rglob('*.as')}
        assert actual==expected,(actual-expected,expected-actual)
        m.update(candidate_sha256=sha(out/'RConnectMod.swf'),size=(out/'RConnectMod.swf').stat().st_size,classes=len(actual),
                 stub_sha256=sha(out/'GameCombatStubs.swc'),class_list_sha256=sha(out/'classes.txt'),build_exit=0)
        save(out/'source-input.json',m);print(json.dumps({k:m[k] for k in ('candidate_sha256','classes','size')}))
