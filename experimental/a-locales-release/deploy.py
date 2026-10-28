from pathlib import Path
import hashlib,json,shutil
RC=Path(__file__).resolve().parents[2];OUT=RC/'build/a-locales-04';GAME=RC.parents[1]
before='eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127'
after='239252df5ea24ec6da5005bd80bfeb31a91e393d6b2bfe7b1fd7b371cd4e618c'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
test=json.loads((RC/'build/cooperation/8a120eb346/result.json').read_text('utf8'))
assert test['passed'] and test['installation_unchanged']
assert json.loads((OUT/'audit.json').read_text('utf8'))['passed']
target=RC/'release/RConnectMod.swf';candidate=OUT/'RConnectMod.swf'
assert sha(target)==before and sha(candidate)==after
backup=RC/'build/a-locales-deploy-20261029';backup.mkdir()
shutil.copy2(target,backup/'RConnectMod.before.swf');assert sha(backup/'RConnectMod.before.swf')==before
protected={str(p):sha(p) for p in [GAME/'pfe.swf',GAME/'application.xml',GAME/'mods/loader-manifest.txt',RC/'release/config.txt'] if p.exists()}
try:
    shutil.copy2(candidate,target);assert sha(target)==after
    assert all(sha(Path(p))==digest for p,digest in protected.items())
except BaseException:
    if sha(target)==after:shutil.copy2(backup/'RConnectMod.before.swf',target)
    raise
result=dict(status='verified',before=before,after=after,backup=str(backup/'RConnectMod.before.swf'),candidate=str(candidate),runtime='8a120eb346',protected_unchanged=True)
(backup/'deployment.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result))
