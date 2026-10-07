"""Immutable 18 installation baseline and 18/19 presentation candidates."""
import argparse, ast, datetime, json, re, shutil
from validation_baseline import ROOT, GAME, AFTER_UI, M47_BASELINE, M47_SHA, sha, read, verify_protected
from run_final_regressions import REQUIRED

ap=argparse.ArgumentParser()
ap.add_argument('mode', choices=['baseline','freeze','built'])
ap.add_argument('snapshot', nargs='?')
a=ap.parse_args()

def save(path, value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def copy(src,dst): dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)

if a.mode=='baseline':
    previous=ROOT/'build/m46/final-after-ui-clock-05'
    receipt=read(previous/'deployment.json')
    assert receipt['status']=='deployed-smoke-passed' and receipt['sha256']==M47_SHA
    protected=dict(read(ROOT/AFTER_UI/'inputs.json')['protected'])
    own=next(n for n in protected if n.lower()=='mods/rconnect/release/rconnectmod.swf')
    protected[own]=M47_SHA
    for n,h in protected.items():assert sha(GAME/n)==h,n
    out=ROOT/M47_BASELINE;out.mkdir(parents=True,exist_ok=False)
    copy(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    data=dict(version='0.2.18-dev',release_sha256=M47_SHA,protected=protected,
              at=datetime.datetime.now().astimezone().isoformat(),
              previous_deployment=str(previous.relative_to(ROOT)/'deployment.json'),
              previous_deployment_sha256=sha(previous/'deployment.json'))
    save(out/'inputs.json',data);print(json.dumps({'baseline':M47_BASELINE,'protected':len(protected)}))
else:
    out=(ROOT/a.snapshot).resolve()
    assert out.parent==ROOT/'build/m47' and out.name.startswith(('final','red-')),out
    if a.mode=='freeze':
        version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(ROOT/'src/RConnectMod.as').read_text(encoding='utf-8-sig')).group(1)
        assert version==('0.2.18-dev' if out.name.startswith('red-') else '0.2.19-dev')
        m=dict(version=version,baseline_path=M47_BASELINE,baseline_inputs_sha256=sha(ROOT/M47_BASELINE/'inputs.json'),
               required_entries=REQUIRED+['HudTestDoc']+([] if version=='0.2.18-dev' else ['FastHeldTestDoc','WeaponAngleTestDoc']))
        verify_protected(m);out.mkdir(parents=True,exist_ok=False)
        m['source']={}
        for p in sorted((ROOT/'src').rglob('*')):
            if p.is_file():n=p.relative_to(ROOT).as_posix();copy(p,out/n);m['source'][n]=sha(p)
        paths=sorted((ROOT/'tests').rglob('*.as'))+sorted((ROOT/'tools/stubs').rglob('*.as'))
        paths += [ROOT/'tools'/n for n in ('build_mod.py','build_effects_driver.py','run_coop_regression.py','RConnect.Process.ps1','keep_test_responsive.ps1','verify_mask_png.py')]
        paths += sorted((ROOT/'tools/validation').glob('*.py'))
        m['profiles']={}
        for role,h in [('host','9c5b3eea2f9480b208c546750e26e0da828932b50048acace14cf39e4970ccc2'),('join','e17dda5168a40509f4ccc430806ceb0a2cab9acc8500ffb9c772b008a2601c3f')]:
            p=ROOT/'build/grip-20261005/profiles'/(role+'-PFEgame0.sol');assert sha(p)==h
            dest=out/'profiles'/p.name;copy(p,dest);paths.append(dest)
            m['profiles'][role]=dict(path=dest.relative_to(ROOT).as_posix(),sha256=h)
        v={}
        for p in paths:
            n=p.relative_to(ROOT).as_posix();copy(p,out/'verified-files'/n);v[n]=sha(p)
            if p.suffix=='.py':ast.parse(p.read_text(encoding='utf-8-sig'))
        save(out/'source-input.json',m);save(out/'verified-test-input.json',v)
        print(json.dumps({'version':version,'sources':len(m['source']),'verification':len(v)}))
    else:
        m=read(out/'source-input.json');verify_protected(m)
        for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
        actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
        expected={s.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for s in (out/'src').rglob('*.as')}
        assert actual==expected,(actual-expected,expected-actual)
        copy(ROOT/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
        m.update(candidate_sha256=sha(out/'RConnectMod.swf'),size=(out/'RConnectMod.swf').stat().st_size,
                 classes=len(actual),stub_sha256=sha(out/'GameCombatStubs.swc'),class_list_sha256=sha(out/'classes.txt'),build_exit=0)
        save(out/'source-input.json',m);print(json.dumps({k:m[k] for k in ('candidate_sha256','classes','size')}))
