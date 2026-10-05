import ast,datetime,hashlib,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy_new(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True)
    if dst.exists():assert dst.read_bytes()==src.read_bytes(),str(dst)
    else:shutil.copy2(src,dst)
mode=sys.argv[1]
def snapshot():
    out=(ROOT/(sys.argv[2] if len(sys.argv)>2 else 'build/m46/final')).resolve()
    assert out.parent==ROOT/'build/m46' and out.name.startswith('final'),out
    return out
if mode=='baseline':
    out=ROOT/'build/m46/integration-baseline'
    expected='59a03d1eb3ca7d8467015c709301bc1fbe6d585342de5857e984344a33572790'
    assert sha(ROOT/'release/RConnectMod.swf')==expected
    out.mkdir(parents=True,exist_ok=False)
    copy_new(ROOT/'release/RConnectMod.swf',out/'RConnectMod.swf')
    paths=[GAME/p for p in ('pfe.swf','DLC/pfe.swf','DLC/pfeUI.swf','application.xml','mods/loader-manifest.txt')]
    paths+=list((GAME/'mods').glob('*/release/*.swf'))+list((GAME/'mods').glob('*/release/*.txt'))
    protected={p.relative_to(GAME).as_posix():sha(p) for p in paths if p.is_file()}
    data={'at':datetime.datetime.now().astimezone().isoformat(),'release_sha256':expected,'protected':protected,'release_source_manifest':'build/m45/final/source-input.json'}
    (out/'inputs.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    print(json.dumps({'baseline':expected,'protected':len(protected)}))
elif mode=='freeze':
    out=snapshot();out.mkdir(parents=True,exist_ok=False)
    assert 'VERSION:String = "0.2.17-dev"' in (ROOT/'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    sources={}
    for p in sorted((ROOT/'src').rglob('*')):
        if p.is_file():
            key=p.relative_to(ROOT).as_posix();copy_new(p,out/key);sources[key]=sha(p)
    paths=sorted((ROOT/'tests').rglob('*.as'))+sorted((ROOT/'tools/stubs').rglob('*.as'))
    paths += [ROOT/'tools'/n for n in ('build_mod.py','build_effects_driver.py','run_coop_regression.py','RConnect.Process.ps1','keep_test_responsive.ps1','verify_mask_png.py')]
    paths += [ROOT/'build/m46'/n for n in ('prepare_integration.py','run_final_regressions.py','refreeze_diagnostic.py',
        'finalize_restore_build.py','audit_final.py','deploy_verified.py','run_smoke.py')]
    profiles={}
    for role,expected in (('host','9c5b3eea2f9480b208c546750e26e0da828932b50048acace14cf39e4970ccc2'),('join','e17dda5168a40509f4ccc430806ceb0a2cab9acc8500ffb9c772b008a2601c3f')):
        profile=ROOT/'build/grip-20261005/profiles'/(role+'-PFEgame0.sol')
        assert sha(profile)==expected,role+' profile changed since paired R2 tests'
        frozen=out/'profiles'/profile.name;copy_new(profile,frozen);paths.append(frozen)
        profiles[role]={'path':frozen.relative_to(ROOT).as_posix(),'sha256':expected}
    tests={}
    for p in paths:
        key=p.relative_to(ROOT).as_posix();copy_new(p,out/'verified-files'/key);tests[key]=sha(p)
        if p.suffix=='.py':ast.parse(p.read_text(encoding='utf-8-sig'))
    (out/'source-input.json').write_text(json.dumps({'version':'0.2.17-dev','source':sources,'profiles':profiles},indent=2),encoding='utf-8')
    (out/'verified-test-input.json').write_text(json.dumps(tests,indent=2),encoding='utf-8')
    print(json.dumps({'sources':len(sources),'verification':len(tests)}))
elif mode=='built':
    out=snapshot();p=out/'source-input.json';data=json.loads(p.read_text(encoding='utf-8'))
    for key,digest in data['source'].items():assert sha(ROOT/key)==digest,key
    data['candidate_sha256']=sha(out/'RConnectMod.swf');data['size']=(out/'RConnectMod.swf').stat().st_size
    p.write_text(json.dumps(data,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in data.items() if k!='source'}))
else:raise ValueError(mode)
