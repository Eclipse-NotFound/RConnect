"""Install this qualified A mod only, with guarded atomic replacement and rollback."""
import json,os,shutil,uuid
from build import RC,GAME,sha,save,inventory
OLD='f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb'
NEW='eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127'
folder=RC/'build/m52/visual2-combined-04';candidate=folder/'RConnectMod.swf';target=RC/'release/RConnectMod.swf'
proof=json.loads((folder/'release-qualification.json').read_text('utf8'))
assert proof['passed'] and proof['candidate_sha256']==sha(candidate)==NEW
assert inventory(folder/'src')==proof['source'] and sha(target)==OLD
out=RC/'build/m52'/('visual2-deploy-'+uuid.uuid4().hex[:8]);out.mkdir()
backup=out/'RConnectMod.before.swf';shutil.copy2(target,backup);assert sha(backup)==OLD
untouched=[GAME/'pfe.swf',GAME/'application.xml',RC/'release/config.txt']
before={str(p):sha(p) for p in untouched}
receipt={'status':'prepared','version':'0.2.24-animfix3','previous_sha256':OLD,'candidate_sha256':NEW,
 'backup':str(backup),'source_directory':str(folder/'src'),'qualification_sha256':sha(folder/'release-qualification.json'),
 'untouched_before':before,'limitations':proof['limitations']}
save(out/'deployment.json',receipt)
pending=target.parent/('.RConnectMod-'+out.name+'.pending');rollback=target.parent/('.RConnectMod-'+out.name+'.rollback')
assert not pending.exists() and not rollback.exists()
try:
 shutil.copy2(candidate,pending);assert sha(pending)==NEW and sha(target)==OLD
 os.replace(pending,target);assert sha(target)==NEW
 receipt['untouched_after']={str(p):sha(p) for p in untouched}
 assert receipt['untouched_after']==before
 receipt['status']='verified'
except BaseException as error:
 receipt['status']='failed';receipt['error']=repr(error)
 if target.exists() and sha(target)==NEW:
  shutil.copy2(backup,rollback);assert sha(rollback)==OLD and sha(target)==NEW
  os.replace(rollback,target);receipt['rollback_verified']=sha(target)==OLD
 raise
finally:
 for temporary in (pending,rollback):
  if temporary.exists():temporary.unlink()
 receipt['installed_sha256']=sha(target);save(out/'deployment.json',receipt)
print(json.dumps({'directory':str(out),'status':receipt['status'],'installed_sha256':receipt['installed_sha256']}))
