"""Refresh only the owned sustained benchmark's small mod environment.
No compilation or AIR. Original prepared-sustained-003.json remains immutable.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority/field2_driver'))
from run import Registration,read,sha,save,verify_files
WORK=RC/'build/ab/b-field2-bench-20261025-01'
PRIOR=WORK/'prepared-sustained-003.json'
FUNCTIONAL=RC/'build/ab/b-field2-runtime-01/prepared-clientenv-03.json'
OVERLAY=RC/'experimental/b-field-env-refresh/overlay-01'
DRIVER=RC/'build/ab/ab-sustained-003'
MUTABLE={'pfe.swf','mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt','ab-bench.json','ab-test.xml'}
DISABLED={'ContinuousSceneMod','RealisticVisionMod','LightAndDarknessMod'}
def canonical(value):return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def target(game,name):
 p=(game/name).resolve()
 if not p.is_relative_to(game.resolve()) or p==game.resolve():raise ValueError('Outside owned test root: '+name)
 return p
def files(game):return {p.relative_to(game).as_posix():sha(p) for p in sorted(game.rglob('*')) if p.is_file()}
def idle():
 import psutil
 for process in psutil.process_iter(['name']):
  if str(process.info['name'] or '').lower()!='adl64.exe':continue
  try:command=' '.join(process.cmdline()).lower().replace('\\','/')
  except psutil.NoSuchProcess:continue
  except psutil.AccessDenied:raise RuntimeError('Cannot verify an AIR process identity: '+str(process.pid))
  if any(str(WORK/role).lower().replace('\\','/') in command for role in ('host','join')):raise RuntimeError('Owned benchmark directory is still running: '+str(process.pid))
def verify_selection(game,expected):
 selected=set()
 for line in (game/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
  if line.startswith('#') or not line.strip():continue
  fields=line.split('|')
  if len(fields)!=5:raise ValueError('Unexpected loader row')
  if fields[2]=='1':selected.add(fields[1])
 if selected!=set(expected):raise ValueError('Wrong actual 1.02 loader selection: '+str(selected))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',default='prepared-environment-001.json');ap.add_argument('--wait',type=float,default=900)
 ap.add_argument('--overlay',default=str(OVERLAY));ap.add_argument('--functional-preparation',default=str(FUNCTIONAL));ap.add_argument('--prior-preparation',default=PRIOR.name)
 ap.add_argument('--check',action='store_true',help='Read-only input checks; do not refresh the benchmark')
 a=ap.parse_args()
 if Path(a.output).name!=a.output or not a.output.startswith('prepared-environment-') or not a.output.endswith('.json'):raise ValueError('New preparation basename required')
 receipt=WORK/a.output;transaction=HERE/('bench-'+Path(a.output).stem)
 if receipt.exists() or transaction.exists():raise FileExistsError('Keep completed preparation and before files immutable')
 overlay=Path(a.overlay);overlay=(overlay if overlay.is_absolute() else RC/overlay).resolve()
 functional_path=Path(a.functional_preparation);functional_path=(functional_path if functional_path.is_absolute() else RC/functional_path).resolve()
 if not overlay.is_relative_to(RC/'experimental/b-field-env-refresh') or not functional_path.is_relative_to(RC/'build/ab/b-field2-runtime-01'):raise ValueError('Independent environment/functional receipt required')
 if Path(a.prior_preparation).name!=a.prior_preparation:raise ValueError('Prior preparation must remain inside workspace')
 prior_path=WORK/a.prior_preparation;prior=read(prior_path);functional=read(functional_path);plan=read(overlay/'assembly.json');driver=read(DRIVER/'build-input.json')
 previous={role:prior['roles'][role]['files'] if prior.get('kind')=='b-sustained-current-environment' else prior[role] for role in ('host','join')}
 verify_files(overlay,plan['files']);verify_files(DRIVER,driver['files']);verify_files(DRIVER,driver['sources'])
 if set(plan['disabled'])!=DISABLED or len(plan['files'])!=23 or 'mods/Sandevistan/release/sandy_theme.mp3' not in plan['files']:raise ValueError('Expected reviewed 23-file environment overlay including the default Sandy theme')
 if functional['environment_sha256']!=sha(overlay/'assembly.json') or functional['test_config']['environment']!=sha(overlay/'assembly.json'):raise ValueError('Functional environment does not match overlay')
 config=dict(functional['test_config'])
 if 'rv' in config:raise ValueError('RV must be absent, not silently attached')
 for key,entry in {'tdfc':'TDFCMod','msw':'MoreSkillsWeaponsMod','sandy':'SandevistanMod','injury':'PermanentInjuryMod','fa':'FirearmAttachmentsMod','addiction':'AddictionSystemMod'}.items():
  row=next(m for m in plan['source_lock']['mods'] if m['entry']==entry)
  if config[key]!=sha(overlay/row['path']):raise ValueError('Functional API fingerprint mismatch: '+key)
 parent_sha=sha(prior_path);functional_sha=sha(functional_path);overlay_sha=sha(overlay/'assembly.json');driver_sha=sha(DRIVER/'build-input.json')
 # Dynamic test files legitimately differ after earlier runs; every immutable
 # old prepared file is verified, and all dynamic originals are journaled.
 for role in ('host','join'):verify_files(WORK/role,{k:v for k,v in previous[role].items() if k.lower() not in MUTABLE})
 if a.check:
  print(json.dumps({'checked':True,'prior_sha256':parent_sha,'overlay_sha256':overlay_sha,'functional_sha256':functional_sha,'driver_sha256':driver_sha}));return
 with Registration(owner='RConnect B / new environment benchmark preparation',resource='game',purpose='Refresh existing owned host/join benchmark mods; no AIR or compiler',run_dir=WORK,evidence=receipt,wait=a.wait) as reg:
  if sha(prior_path)!=parent_sha or sha(functional_path)!=functional_sha or sha(overlay/'assembly.json')!=overlay_sha:raise ValueError('Preparation changed while waiting')
  idle()
  for role in ('host','join'):verify_files(WORK/role,{k:v for k,v in previous[role].items() if k.lower() not in MUTABLE})
  transaction.mkdir();(transaction/'before').mkdir();changes={};backups={};failed=None
  enabled=[e for e in plan['enabled'] if e!='RConnectMod']+['ABBenchMod']
  result=dict(kind='b-sustained-current-environment',schema=1,workspace=str(WORK),prior_preparation=str(prior_path),prior_sha256=parent_sha,
    functional_preparation=str(functional_path),functional_sha256=functional_sha,overlay=str(overlay),overlay_sha256=overlay_sha,
    driver=str(DRIVER),driver_sha256=driver_sha,driver_source=driver['source_id'],driver_files=driver['files'],
    enabled=enabled,disabled=sorted(DISABLED),test_config=config,roles={},changes=changes,backups=backups,
    source_script_sha256=sha(__file__),air_started=False,compiled=False,installed=False,complete=False)
  def before(role,name):
   key=role+'/'+name
   if key in changes:return
   dest=target(WORK/role,name);h=sha(dest) if dest.is_file() else None
   changes[key]={'before':h,'after':None}
   if h is not None and h not in backups:
    # The only large mutable item is already frozen native021. Reuse that
    # accurate immutable witness; never copy all game resources as a backup.
    witnesses=[RC/'build/ab/native-hooks-021/pfe.swf',overlay/'pfe.swf']
    if prior.get('native_source'):witnesses.append(Path(prior['native_source']))
    native=next((p for p in witnesses if p.is_file() and sha(p)==h),None) if dest.stat().st_size>8*1024**2 else None
    if native is not None:
     backups[h]={'path':str(native),'reused_immutable_native':True}
    else:
     backup=transaction/'before'/h;shutil.copy2(dest,backup)
     if sha(backup)!=h:raise ValueError('Backup mismatch')
     backups[h]={'path':str(backup),'reused_immutable_native':False}
   save(transaction/'transaction.json',result)
  try:
   for role in ('host','join'):
    game=WORK/role
    for name,h in plan['files'].items():
     before(role,name);dest=target(game,name);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(overlay/name,dest)
     if sha(dest)!=h:raise ValueError('Overlay copy mismatch '+name)
     changes[role+'/'+name]['after']=h
    for name in plan['clear_only_in_isolated_test']:
     dest=target(game,name)
     if dest.is_file():before(role,name);dest.unlink();changes[role+'/'+name]['after']=None
    for name,h in driver['files'].items():
     relative='mods/ABBench/release/'+name;before(role,relative);dest=target(game,relative);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(DRIVER/name,dest)
     if sha(dest)!=h:raise ValueError('ABBench driver changed')
     changes[role+'/'+relative]['after']=h
    relative='mods/RConnect/release/config.txt';before(role,relative)
    role_config=dict(config,experimental=True,role=role,session='prepared-environment',port=23457,autoGame=True,land='rbl',probe=True,scenario='stress',stressExternal=True)
    save(game/relative,role_config);changes[role+'/'+relative]['after']=sha(game/relative)
    before(role,'mods/loader-manifest.txt')
    command=[str(game/'mods/ModLoader/RemainsModLauncher.exe'),'--root',str(game),'--only',','.join(enabled),'--no-ui','--report',str(transaction/(role+'-selection.json'))]
    p=subprocess.run(command,capture_output=True,timeout=90)
    (transaction/(role+'-selection.stdout.log')).write_bytes(p.stdout+p.stderr)
    if p.returncode:raise RuntimeError('Launcher selection failed '+role)
    verify_selection(game,enabled);changes[role+'/mods/loader-manifest.txt']['after']=sha(game/'mods/loader-manifest.txt')
    result['roles'][role]={'files':files(game),'selection_command':command,'selection_sha256':sha(transaction/(role+'-selection.json'))}
   verify_files(overlay,plan['files']);verify_files(DRIVER,driver['files'])
   if sha(prior_path)!=parent_sha or sha(functional_path)!=functional_sha:raise ValueError('Old/frozen preparation changed')
   stable={role:{k:v for k,v in row['files'].items() if k.lower() not in MUTABLE} for role,row in result['roles'].items()}
   baseconfig={k:v for k,v in config.items() if k not in ('role','session','port','autoGame','probe')}
   result['native_sha256']=plan['files']['pfe.swf'];result['native_source']=str(overlay/'pfe.swf')
   result['environment_files_sha256']=canonical(stable)
   result['full_environment_sha256']=canonical({'roles':stable,'native':result['native_sha256'],'test_config':baseconfig,'driver_source':driver['source_id'],'overlay':overlay_sha})
   result['complete']=True;save(receipt,result);reg.outcome='passed';reg.note='23 overlay files refreshed per role; exact driver retained; no AIR or full resource copy'
  except BaseException as e:
   failed=e;result['error']=str(e);result['rolled_back']=True
   for key,change in reversed(list(changes.items())):
    role,name=key.split('/',1);dest=target(WORK/role,name);h=change['before']
    if h is None:
     if dest.exists():dest.unlink()
    else:
     source=Path(backups[h]['path'])
     if sha(source)!=h:raise RuntimeError('Cannot roll back changed before witness: '+key)
     dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
     if sha(dest)!=h:raise RuntimeError('Rollback readback failed '+key)
  finally:save(transaction/'transaction.json',result)
  if failed:raise failed
 print(json.dumps({'prepared':str(receipt),'sha256':sha(receipt),'full_environment_sha256':result['full_environment_sha256'],'air_started':False},ensure_ascii=False))
if __name__=='__main__':main()
