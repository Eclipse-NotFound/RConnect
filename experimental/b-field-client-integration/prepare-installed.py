"""Bind the existing isolated observer to actual installed B environment bytes.
Fresh AIR IDs and copied seeds remain the field runner's responsibility.
No player process, player store or installed file is changed here.
"""
from pathlib import Path
import argparse,importlib.util,shutil,subprocess,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('clientenv_release',HERE/'release.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
sys.path.insert(0,str(ROOT/'tools/host_authority/field2_driver'))
from run import Registration,read,save,sha,verify_files
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--transaction',required=True);ap.add_argument('--preparation',required=True);ap.add_argument('--out',required=True);a=ap.parse_args()
 out=r.folder(a.transaction);plan=r.readplan(out);r.require(plan['status']=='installed_pending_smoke','Installation must precede installed-byte preparation')
 work=ROOT/'build/ab/b-field2-runtime-01';game=work/'game';oldpath=work/a.preparation;old=read(oldpath)
 r.require(Path(a.out).name==a.out and a.out.startswith('prepared-clientenv-installed-'),'New installed preparation basename required')
 target=work/a.out;r.require(not target.exists(),'Preparation already exists')
 assembly=read(ROOT/plan['overlay']/'assembly.json');record=work/(Path(a.out).stem+'-input');record.mkdir()
 with Registration(owner='RConnect B / installed environment',purpose='Prepare owned observer from actual installed bytes',run_dir=work,evidence=target,wait=900) as reg:
  manifest=r.d.package()
  verify_files(game,{k:v for k,v in old['files'].items() if k.lower() not in r.d.RUNTIME_MUTABLE})
  changes={}
  for name,h in manifest['files'].items():
   source=r.G/name;dest=r.d.member(game,name)
   r.require(sha(source)==h,'Installed source changed')
   if not dest.is_file() or sha(dest)!=h:
    before=sha(dest) if dest.is_file() else None
    dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);r.require(sha(dest)==h,'Installed copy mismatch')
    changes[name]=dict(before=before,after=h)
  enabled=[v for v in assembly['enabled'] if v!='RConnectMod']+['BStartupDriverMod']
  cmd=[str(game/'mods/ModLoader/RemainsModLauncher.exe'),'--root',str(game),'--only',','.join(enabled),'--no-ui','--report',str(record/'selection.json')]
  result=subprocess.run(cmd,capture_output=True,timeout=90);(record/'selection.log').write_bytes(result.stdout+result.stderr)
  r.require(result.returncode==0,'Test selection failed');r.selection(game/'mods/loader-manifest.txt',enabled)
  files=dict(old['files'])
  for name in manifest['files']:
   key=next((k for k in files if k.lower()==name.lower()),name);files[key]=sha(game/name)
  files['mods/loader-manifest.txt']=sha(game/'mods/loader-manifest.txt')
  updated=dict(old,files=files,test_config=manifest['config'],installed_transaction=r.d.rel(out),installed_manifest_sha256=sha(r.P/'manual-input.json'),
    installed_files=dict(manifest['files']),parent_preparation=a.preparation,parent_sha256=sha(oldpath),launcher_command=cmd)
  save(record/'input.json',dict(changes=changes,installed_files=manifest['files'],transaction=r.d.rel(out),source_script_sha256=sha(__file__)))
  verify_files(r.G,manifest['files']);save(target,updated);reg.outcome='passed'
 print(str(target))
if __name__=='__main__':main()
