"""Refresh the existing isolated B fixture with a pinned small environment overlay."""
import argparse,json,os,shutil,subprocess,sys
from pathlib import Path
RC=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(RC/'tools/host_authority/field2_driver'))
from run import Registration,read,sha,save,verify_files,inside_build,JAVA,SDK,HERE

def main():
 p=argparse.ArgumentParser();p.add_argument('--overlay',required=True);p.add_argument('--preparation',required=True);p.add_argument('--out',required=True)
 a=p.parse_args();work=RC/'build/ab/b-field2-runtime-01';game=work/'game';overlay=(RC/a.overlay).resolve()
 if not overlay.is_relative_to(RC/'experimental/b-field-env-refresh'):raise ValueError('Unreviewed overlay location')
 if Path(a.out).name!=a.out or not a.out.startswith('prepared-') or not a.out.endswith('.json'):raise ValueError('New preparation basename required')
 target=work/a.out
 if target.exists():raise FileExistsError(target)
 plan=read(overlay/'assembly.json');old=read(work/a.preparation)
 verify_files(overlay,plan['files'])
 with Registration(owner='RConnect B / mod environment',purpose='Prepare current default mod environment and external observer',run_dir=work,evidence=target,wait=900) as reg:
  mutable={'pfe.swf','mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt'}
  verify_files(game,{k:v for k,v in old['files'].items() if k.lower() not in mutable})
  for role,record in old['seeds'].items():
   if sha(work/(role+'-save0.sol'))!=record['sha256']:raise ValueError('Copied seed changed')
  folder=work/('driver-'+Path(a.out).stem);folder.mkdir()
  before=folder/'before';before.mkdir()
  changes={}
  for name,digest in plan['files'].items():
   src=overlay/name;dest=game/name
   if dest.exists():
    backup=before/name;backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup)
   changes[name]={'before':sha(dest) if dest.exists() else None,'after':digest}
   dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
  for name in plan['clear_only_in_isolated_test']:
   dest=(game/name).resolve()
   if not dest.is_relative_to(game):raise ValueError('Out of test game')
   if dest.exists():
    backup=before/name;backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(dest,backup);dest.unlink()
    changes[name]={'before':sha(backup),'after':None}
  config=read(game/'mods/RConnect/release/config.txt');config.pop('rv',None)
  mapping={'tdfc':'TDFCMod','msw':'MoreSkillsWeaponsMod','sandy':'SandevistanMod','injury':'PermanentInjuryMod','fa':'FirearmAttachmentsMod','addiction':'AddictionSystemMod'}
  for key,entry in mapping.items():
   row=next(m for m in plan['source_lock']['mods'] if m['entry']==entry);config[key]=sha(game/row['path'])
  config.update(environment=sha(overlay/'assembly.json'),role='',autoGame=False,probe=False)
  save(game/'mods/RConnect/release/config.txt',config)
  source=folder/'BStartupDriverMod.as';shutil.copy2(HERE/source.name,source)
  helpers=sorted(set(f for pattern in ('B*Cases.as','B*Checks.as','B*Inputs.as','B*Trace.as') for f in HERE.glob(pattern)))
  for f in helpers:shutil.copy2(f,folder/f.name)
  swf=folder/'BStartupDriverMod.swf'
  command=[str(JAVA),'-Xmx512m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-source-path='+str(folder),'-swf-version=38','-debug=true','-optimize=true','-output='+str(swf),str(source)]
  save(folder/'input.json',dict(overlay=str(overlay),overlay_sha256=sha(overlay/'assembly.json'),changes=changes,command=command))
  with (folder/'build.log').open('x',encoding='utf-8') as log:
   reg.before_launch('environment observer compiler');proc=subprocess.Popen(command,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT);reg.child(proc.pid)
   try:
    if proc.wait()!=0:raise RuntimeError('Observer compile failed')
   finally:
    if proc.poll() is None:proc.terminate();proc.wait()
    reg.child_stopped()
  shutil.copy2(swf,game/'mods/BStartupDriver/release/BStartupDriverMod.swf')
  enabled=[entry for entry in plan['enabled'] if entry!='RConnectMod']+['BStartupDriverMod']
  selection=[str(game/'mods/ModLoader/RemainsModLauncher.exe'),'--root',str(game),'--only',','.join(enabled),'--no-ui','--report',str(folder/'selection.json')]
  subprocess.run(selection,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
  files=dict(old['files'])
  for name in list(files):
   if not (game/name).exists():del files[name]
   else:files[name]=sha(game/name)
  for name in plan['files']:files[name]=sha(game/name)
  files['mods/loader-manifest.txt']=sha(game/'mods/loader-manifest.txt')
  updated=dict(old,files=files,compiler_command=command,driver=sha(source),helpers={f.name:sha(folder/f.name) for f in helpers},launcher_command=selection,
   environment_overlay=str(overlay),environment_sha256=sha(overlay/'assembly.json'),default_disabled=plan['disabled'],test_config=config,
   parent_preparation=a.preparation,parent_sha256=sha(work/a.preparation))
  save(target,updated);reg.outcome='passed'
 print(json.dumps({'prepared':str(target),'sha256':sha(target),'enabled':enabled,'disabled':plan['disabled']}))
if __name__=='__main__':main()
