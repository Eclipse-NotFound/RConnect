"""Rebind the unchanged v18 functional driver/seed fixture to installed field22, retaining ancestry."""
from pathlib import Path
import sys,json,shutil
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/host_authority/field2_driver'))
from run import Registration,read,sha,save,verify_files
workspace=ROOT/'build/ab/b-field2-runtime-01'
target=workspace/'prepared-v19.json'
playable=ROOT/'build/ab/b3-playable-190'
old_manual_path=ROOT/'build/ab/b-field-deploy-20261026-01/before/manual-input.json'
with Registration(owner='RConnect B / fixture reuse',purpose='Bind frozen v18 fixture to field22 without another game copy',run_dir=workspace,evidence=target,wait=900) as reg:
 if target.exists():raise FileExistsError(target)
 old=read(workspace/'prepared-v18.json');manual=read(playable/'manual-input.json');prior=read(old_manual_path)
 assert old['manual_manifest']==sha(old_manual_path) and old['original_files']==prior['files']
 assert manual['candidate_sha256']=='3706828fd10cf30c133826d17fd8cef939444f790a33a70d58c2a2b0779c90bf'
 assert prior['config']==manual['config']
 assert set(prior['files'])==set(manual['files'])
 changed={k.lower() for k in prior['files'] if prior['files'][k]!=manual['files'][k]}
 assert changed=={'pfe.swf','mods/rconnect/release/rconnectmod.swf'}
 verify_files(playable/'game',manual['files'])
 mutable={'pfe.swf','mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt'}
 verify_files(workspace/'game',{k:v for k,v in old['files'].items() if k.lower() not in mutable})
 source=Path(old['compiler_command'][-1]);assert sha(source)==old['driver'];verify_files(source.parent,old['helpers'])
 for role,seed in old['seeds'].items():assert sha(workspace/(role+'-save0.sol'))==seed['sha256']
 for name in manual['files']:
  if name.lower() not in changed:continue
  shutil.copy2(playable/'game'/name,workspace/'game'/name)
  for k in old['files']:
   if k.lower()==name.lower():old['files'][k]=sha(workspace/'game'/name)
 config=dict(manual['config'],role='',autoGame=False,probe=False)
 cfg=workspace/'game/mods/Rconnect/release/config.txt';save(cfg,config)
 for k in old['files']:
  if k.lower()=='mods/rconnect/release/config.txt':old['files'][k]=sha(cfg)
 old.update(manual_manifest=sha(playable/'manual-input.json'),original_files=manual['files'],
  ancestry={'preparation':'prepared-v18.json','sha256':sha(workspace/'prepared-v18.json'),'prior_manual':str(old_manual_path),'prior_manual_sha256':sha(old_manual_path),'reason':'Only deployed native/product bytes changed; driver, dependencies, config and copied saves unchanged.'})
 save(target,old);reg.outcome='passed'
 print(target)
