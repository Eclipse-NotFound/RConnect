"""Independent exact-byte dual run. No frozen runner adaptation or installation writes."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, socket, subprocess, sys, time, uuid
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; RC=HERE.parents[1]; GAME=RC.parents[1]
sys.path[:0]=[str(GAME/'mods/ModLoader/tools'),str(RC/'tools/validation')]
from test_registry import Registration
from air_test_process import HiddenProcess
from test_resources import snapshot, comparison_environment
from native_runtime_assets import native_runtime_files
from inspect_native_sol import decode_sol
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf8')
def current_inputs():
 paths=[GAME/'pfe.swf',GAME/'mods/loader-manifest.txt',GAME/'mods/ModLoader/RemainsModLauncher.exe',GAME/'mods/ModLoader/supported-mods.txt']
 paths+=list((GAME/'mods').glob('*/release/*'))
 return {str(p):sha(p) for p in paths if p.is_file() and p.suffix.lower() in ('.swf','.txt','.json','.xml','.exe')}
def resource_snapshot():
 try:return snapshot()
 except Exception as e:return {'error':str(e)}
def manifest(path):
 return [line.split('|') for line in path.read_text('utf-8-sig').splitlines() if line.strip() and not line.startswith('#')]
def prepare(out,candidate,driver,port):
 frozen=out/'frozen';frozen.mkdir()
 for src in native_runtime_files(GAME):
  dst=frozen/src.relative_to(GAME);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 for parts in manifest(GAME/'mods/loader-manifest.txt'):
  directory,entry=parts[:2];src=GAME/'mods'/directory/'release';dst=frozen/'mods'/directory/'release';dst.mkdir(parents=True,exist_ok=True)
  for p in src.iterdir():
   if p.is_file() and p.suffix.lower() in ('.swf','.txt','.json','.xml'):shutil.copy2(p,dst/p.name)
 shutil.copy2(GAME/'mods/loader-manifest.txt',frozen/'mods/loader-manifest.txt')
 (frozen/'mods/ModLoader').mkdir(exist_ok=True)
 shutil.copy2(GAME/'mods/ModLoader/supported-mods.txt',frozen/'mods/ModLoader/supported-mods.txt')
 (frozen/'tests').mkdir()
 shutil.copy2(candidate,frozen/'tests/RConnectProduction.swf')
 shutil.copy2(driver/'EffectsDriver.swf',frozen/'tests/EffectsDriver.swf')
 shutil.copy2(driver/'EffectsHarness.swf',frozen/'mods/Rconnect/release/RConnectMod.swf')
 launcher=GAME/'mods/ModLoader/RemainsModLauncher.exe'
 command=[str(launcher),'--root',str(frozen),'--version','1.02','--only','RConnectMod','--no-ui','--report',str(out/'selection.json')]
 # This tool only writes the isolated module selection, never launches a game.
 proc=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
 (out/'selection.log').write_text(proc.stdout+'\n'+proc.stderr,encoding='utf8');assert proc.returncode==0,'Official selector failed'
 selection=json.loads((out/'selection.json').read_text('utf-8-sig'))['configuration']
 assert set(selection['selected'])=={'RConnectMod'} and Path(selection['gameRoot']).resolve()==frozen
 assert {p[1] for p in manifest(frozen/'mods/loader-manifest.txt') if p[2]=='1'}=={'RConnectMod'}
 files={p.relative_to(frozen).as_posix():sha(p) for p in frozen.rglob('*') if p.is_file()}
 roles=[]
 for role in ('host','join'):
  folder=out/role
  # Immutable assets are linked only among owned copies, never to installed files.
  shutil.copytree(frozen,folder,copy_function=os.link)
  config=folder/'mods/Rconnect/release/config.txt'
  if config.exists():config.unlink()  # detach owned hardlink before role-specific write
  config.write_text(json.dumps(dict(nickname=role,hostIp='127.0.0.1',port=port,tickMs=50,autoRole=role,
   autoGame='1',autoFollow='1',freezeAI='1',worldInject='1',ghostCombat='1',autoHeal='1')),encoding='utf8')
  appid='pfe-modsettings-rconnect-coop-'+role+'-'+out.name
  desc=folder/'coop.xml'
  desc.write_text('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>RConnectStutterTest</filename><initialWindow><content>pfe.swf</content><visible>true</visible><renderMode>direct</renderMode></initialWindow></application>',encoding='utf8')
  storage=Path(os.environ['APPDATA'])/appid/'Local Store'
  assert not storage.exists(),'Random test storage collision'
  roles.append((role,folder,desc,storage,appid))
 save(out/'input.json',dict(candidate_sha256=sha(candidate),driver_sha256=sha(driver/'EffectsDriver.swf'),harness_sha256=sha(driver/'EffectsHarness.swf'),assets=files,port=port,
  roles={r:dict(appid=a,descriptor=d.read_text('utf8'),config=(f/'mods/Rconnect/release/config.txt').read_text('utf8')) for r,f,d,s,a in roles}))
 return roles
def main():
 p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);p.add_argument('--driver',type=Path,required=True)
 p.add_argument('--profile',choices=('coexist','benchmark'),default='coexist');p.add_argument('--wait',type=int,default=300);p.add_argument('--seconds',type=int,default=240)
 p.add_argument('--keep-runtime',action='store_true');a=p.parse_args()
 assert a.candidate.is_file() and all((a.driver/n).is_file() for n in ('EffectsDriver.swf','EffectsHarness.swf','compile.json'))
 build=json.loads((a.driver/'compile.json').read_text('utf8'));assert build['compiled'] and sha(a.driver/'EffectsDriver.swf')==build['driver_sha256'] and sha(a.driver/'EffectsHarness.swf')==build['harness_sha256']
 out=RC/'build/cooperation'/uuid.uuid4().hex[:10];out.mkdir(parents=True);print(str(out),flush=True)
 result={'passed':False,'profile':a.profile,'roles':{},'installation_before':current_inputs()};procs=[];streams=[];roles=[]
 try:
  with Registration(owner='RConnect / 双向卡顿历史对照',purpose='Real player input, rapid gunfire, plasma and rocket cooldown; RConnect only',run_dir=out,evidence=out/'result.json',wait=a.wait) as reg:
   with socket.socket() as sock:
    if hasattr(socket,'SO_EXCLUSIVEADDRUSE'):sock.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
    sock.bind(('0.0.0.0',0));port=sock.getsockname()[1]
   roles=prepare(out,a.candidate,a.driver,port)
   before=resource_snapshot();result['resource_before']=before;save(out/'resource-before.json',before)
   try:
    for role,folder,desc,storage,appid in roles:
     reg.before_launch(role+' / '+appid)
     log=(out/(role+'.stdout.log')).open('w',encoding='utf8');streams.append(log)
     proc=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc)],cwd=folder,stdout=log,stderr=log)
     procs.append(proc);reg.child(proc.pid);result['roles'][role]={'pid':proc.pid,'appId':appid,'resource_policy':proc.resource_policy}
     print(json.dumps({'role':role,'pid':proc.pid}),flush=True)
     if role=='host':time.sleep(12)
    deadline=time.monotonic()+a.seconds
    while time.monotonic()<deadline:
     if (out/'cancel-request.json').exists():raise RuntimeError('Owned test cancelled')
     if all((s/'stutter-result.json').exists() for r,f,d,s,i in roles):break
     if any(proc.poll() not in (None,0) for proc in procs):break
     time.sleep(1)
   finally:
    for proc in procs:
     if proc.poll() is None:
      try:proc.wait(timeout=3)
      except subprocess.TimeoutExpired:proc.kill()
     proc.wait();proc.close()
    reg.child_stopped()
    for stream in streams:stream.close()
   after=resource_snapshot();result['resource_after']=after
   for role,folder,desc,storage,appid in roles:
    dest=out/'logs'/role;dest.mkdir(parents=True)
    product_log=folder/'mods/Rconnect/RConnect.log'
    if not product_log.is_file():product_log=storage/'RConnect.log'
    if product_log.is_file():shutil.copy2(product_log,dest/'RConnect.log')
    if (storage/'stutter-result.json').is_file():shutil.copy2(storage/'stutter-result.json',dest/'stutter-result.json')
    record=result['roles'][role]
    samples=dest/'stutter-result.json';record['completed']=samples.exists() and json.loads(samples.read_text('utf8')).get('completed') is True
    sol=list((storage/'#SharedObjects').rglob('ModLoader.sol'))
    if len(sol)==1:
     shutil.copy2(sol[0],dest/'ModLoader.sol');name,status=decode_sol(sol[0].read_bytes())
     requested={k[10:] for k in status if k.startswith('requested_')};ok={k[3:] for k in status if k.startswith('ok_')};errors=[k for k in status if k.startswith('err_')]
     record['selection_ok']=name=='ModLoader' and requested==ok=={'RConnectMod'} and not errors
     save(dest/'loader-status.json',status)
    else:record['selection_ok']=False
    record['environment']=comparison_environment(a.profile,before,after,record['resource_policy'])
   result['passed']=all(r.get('completed') and r.get('selection_ok') for r in result['roles'].values()) and len(result['roles'])==2
   reg.outcome='passed' if result['passed'] else 'failed';reg.note='Execution completed; evaluate frame/trajectory evidence separately'
 except BaseException as error:
  result['error']=repr(error);raise
 finally:
  # Preserve diagnostics even if one process failed during launch/handshake.
  for role,folder,desc,storage,appid in roles:
   dest=out/'logs'/role;dest.mkdir(parents=True,exist_ok=True)
   for source,name in ((folder/'mods/Rconnect/RConnect.log','RConnect.log'),(storage/'RConnect.log','RConnect-storage.log'),(storage/'stutter-result.json','stutter-result.json')):
    if source.is_file() and not (dest/name).exists():shutil.copy2(source,dest/name)
  result['installation_after']=current_inputs();result['installation_unchanged']=result['installation_before']==result['installation_after']
  result['passed']=result['passed'] and result['installation_unchanged'];save(out/'result.json',result)
  if not a.keep_runtime and all(proc.poll() is not None for proc in procs):
   for name in ('host','join','frozen'):
    target=(out/name).resolve();assert target.parent==out.resolve() and out.resolve().is_relative_to(RC/'build/cooperation')
    if target.exists():shutil.rmtree(target)
 print(json.dumps({'output':str(out),'passed':result['passed']}))
if __name__=='__main__':main()
