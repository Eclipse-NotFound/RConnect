"""Sustained LMG comparison using the refreshed environment, never installed B.
Derived from field2_driver/bench_sustained.py; driver SWFs are unchanged.
--check is read-only. --run launches only owned isolated benchmark instances.
Optional --compare-with runs A,B,A,B under one unchanged environment receipt.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,socket,sys,time,uuid
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority/field2_driver'))
from run import Registration,HiddenProcess,available_gib,read,save,sha,verify_files,inside_build,events
from bench_sustained import commit_available_gib,memory_guard,machine
import importlib.util
spec=importlib.util.spec_from_file_location('bench_environment_prepare',HERE/'prepare-bench.py')
prepmod=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepmod)
WORK=prepmod.WORK;MUTABLE=prepmod.MUTABLE
def toolpins():
 paths=[Path(__file__),HERE/'prepare-bench.py',RC/'tools/host_authority/field2_driver/bench_sustained.py',RC/'tools/host_authority/field2_driver/run.py',RC/'tools/host_authority/common.py',RC.parents[1]/'mods/ModLoader/tools/test_registry.py',RC.parents[1]/'mods/ModLoader/tools/air_test_process.py']
 return {str(p):sha(p) for p in paths}
def candidate(path):
 p=Path(path);p=(p if p.is_absolute() else RC/p).resolve();p=inside_build(p)
 data=read(p/'build-input.json');verify_files(p,data['sources'])
 if sha(p/'RConnectMod.swf')!=data['candidate_sha256']:raise ValueError('Candidate SWF changed')
 return {'path':str(p),'sha256':data['candidate_sha256'],'source':data['source_id'],'input_sha256':sha(p/'build-input.json')}
def verified_preparation(name):
 if Path(name).name!=name:raise ValueError('Preparation must be a workspace basename')
 p=WORK/name;v=read(p)
 if v.get('kind')!='b-sustained-current-environment' or not v.get('complete'):raise ValueError('Completed refreshed benchmark preparation required')
 if Path(v['workspace']).resolve()!=WORK:raise ValueError('Unexpected reusable workspace')
 for key,path in [('prior_sha256',v['prior_preparation']),('functional_sha256',v['functional_preparation']),('overlay_sha256',str(Path(v['overlay'])/'assembly.json')),('driver_sha256',str(Path(v['driver'])/'build-input.json'))]:
  if sha(path)!=v[key]:raise ValueError('Changed preparation input: '+key)
 driver=read(Path(v['driver'])/'build-input.json');verify_files(Path(v['driver']),driver['files']);verify_files(Path(v['driver']),driver['sources'])
 verify_files(Path(v['overlay']),read(Path(v['overlay'])/'assembly.json')['files'])
 if 'rv' in v['test_config'] or v['test_config']['environment']!=v['overlay_sha256']:raise ValueError('Wrong functional test configuration')
 for role in ('host','join'):
  verify_files(WORK/role,{k:h for k,h in v['roles'][role]['files'].items() if k.lower() not in MUTABLE})
  prepmod.verify_selection(WORK/role,v['enabled'])
 stable={role:{k:h for k,h in row['files'].items() if k.lower() not in MUTABLE} for role,row in v['roles'].items()}
 config={k:x for k,x in v['test_config'].items() if k not in ('role','session','port','autoGame','probe')}
 if prepmod.canonical(stable)!=v['environment_files_sha256'] or prepmod.canonical({'roles':stable,'native':v['native_sha256'],'test_config':config,'driver_source':driver['source_id'],'overlay':v['overlay_sha256']})!=v['full_environment_sha256']:
  raise ValueError('Environment fingerprint does not describe preparation')
 return p,v,driver
def run_one(reg,choice,native,out,prepared,driver,preparation_sha,seconds,profile,diagnostic):
 if out.exists():raise FileExistsError(out)
 if available_gib()<6 or commit_available_gib()<3:raise RuntimeError('Dual AIR needs 6 GiB physical and 3 GiB commit headroom')
 if (WORK/'stop-before-next-sustained').exists():raise RuntimeError('Owned series stop marker is present')
 out.mkdir(parents=True);shutil.copy2(__file__,out/'runner.py')
 receipt=dict(complete=False,passed=False,candidate_sha256=choice['sha256'],candidate_source=choice['source'],candidate_input_sha256=choice['input_sha256'],
  native_source=str(native),native_sha256=sha(native),driver_sha256=prepared['driver_sha256'],driver_source=driver['source_id'],
  preparation_sha256=preparation_sha,environment_sha256=prepared['full_environment_sha256'],overlay_sha256=prepared['overlay_sha256'],tool_sha256=toolpins(),
  enabled=prepared['enabled'],disabled=prepared['disabled'],profile=profile,seconds=seconds,roles={},private_desktop=True,diagnostic_only=diagnostic)
 processes=[];streams=[];environment=[];run_id=uuid.uuid4().hex[:12]
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 try:
  if candidate(choice['path'])!=choice:raise ValueError('Candidate changed before execution')
  if sha(native)!=prepared['native_sha256']:raise ValueError('Native must match the refreshed environment')
  for role in ('host','join'):
   game=WORK/role;verify_files(game,{k:h for k,h in prepared['roles'][role]['files'].items() if k.lower() not in MUTABLE})
   shutil.copy2(Path(choice['path'])/'RConnectMod.swf',game/'mods/Rconnect/release/RConnectMod.swf');shutil.copy2(native,game/'pfe.swf')
   config=dict(prepared['test_config']);config.update(experimental=True,role=role,session=run_id,port=port,autoGame=True,land='rbl',probe=True,scenario='stress',stressExternal=True)
   save(game/'mods/Rconnect/release/config.txt',config)
   save(game/'ab-bench.json',dict(variant='B',role=role,seconds=seconds,source=driver['source_id'],profile=profile))
   appid='pfe-modsettings-rconnect-b-ab-'+role+'-'+run_id;store=Path(os.environ['APPDATA'])/appid/'Local Store'
   if store.exists():raise FileExistsError(store)
   descriptor=game/'ab-test.xml';descriptor.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>B Environment Performance Test</filename><initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
   runtime_files=dict(prepared['roles'][role]['files'])
   for name in ['mods/Rconnect/release/RConnectMod.swf','mods/Rconnect/release/config.txt','pfe.swf','ab-bench.json','ab-test.xml']:
    key=next((k for k in runtime_files if k.lower()==name.lower()),name);runtime_files[key]=sha(game/name)
   verify_files(game,runtime_files);prepmod.verify_selection(game,prepared['enabled'])
   receipt['roles'][role]=dict(appid=appid,storage=str(store),files=runtime_files,files_sha256=prepmod.canonical(runtime_files),config=config)
   save(out/'result.json',receipt);reg.before_launch(role+' / '+appid)
   if commit_available_gib()<1.5:raise RuntimeError('Insufficient commit before AIR launch')
   stream=(out/(role+'.stdout.log')).open('x',encoding='utf-8');streams.append(stream)
   p=HiddenProcess([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(descriptor)],cwd=game,stdout=stream,stderr=stream)
   processes.append(p);reg.child(p.pid);receipt['roles'][role].update(pid=p.pid,desktop=p.desktop)
   if role=='host':
    until=time.monotonic()+120
    while time.monotonic()<until:
     if any(v['kind']=='listening' for v in events(store/'RConnect-B.log')):break
     if p.poll() is not None:raise RuntimeError('Host exited before listening')
     memory_guard();time.sleep(1)
    else:raise TimeoutError('Host did not listen')
  until=time.monotonic()+seconds*2+180
  while time.monotonic()<until:
   environment.append(machine());logs=[events(Path(v['storage'])/'ABBench.log') for v in receipt['roles'].values()]
   if any(any(v['kind']=='fatal' for v in log) for log in logs):raise RuntimeError('Benchmark failed; logs retained')
   if all(any(v['kind']=='done' for v in log) for log in logs):receipt['complete']=True;break
   if any(p.poll() is not None for p in processes):raise RuntimeError('AIR exited')
   memory_guard();time.sleep(1)
  if not receipt['complete']:raise TimeoutError('Benchmark timeout')
 except Exception as error:receipt['error']=str(error)
 finally:
  for p in processes:
   if p.poll() is None:p.kill();p.wait(timeout=20)
   p.close()
  for stream in streams:stream.close()
  for role,entry in receipt['roles'].items():
   store=Path(entry['storage']);dest=out/role;dest.mkdir()
   for p in store.glob('*'):
    if p.is_file() and (p.suffix in ('.log','.png') or p.name.endswith('modlog.txt')):shutil.copy2(p,dest/p.name)
   entry['runtime_changes']=[name for name,h in entry['files'].items() if not(WORK/role/name).is_file() or sha(WORK/role/name)!=h]
   values=events(store/'ABBench.log');entry['results']=[v['data'] for v in values if v['kind']=='result']
   entry['fatal']=[v for v in events(store/'RConnect-B.log') if v['kind']=='FATAL'];entry['done']=any(v['kind']=='done' for v in values)
  receipt['passed']=receipt['complete'] and len(receipt['roles'])==2 and all(v['done'] and not v['runtime_changes'] and not v['fatal'] and len(v['results'])==2 for v in receipt['roles'].values())
  save(out/'machine.json',environment);save(out/'result.json',receipt);reg.child_stopped()
 return receipt
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--preparation',default='prepared-environment-001.json');ap.add_argument('--candidate',required=True);ap.add_argument('--compare-with')
 ap.add_argument('--native');ap.add_argument('--result',required=True);ap.add_argument('--profile',action='store_true');ap.add_argument('--diagnostic',action='store_true');ap.add_argument('--seconds',type=int,default=30);ap.add_argument('--order',default='ABAB')
 mode=ap.add_mutually_exclusive_group(required=True);mode.add_argument('--check',action='store_true');mode.add_argument('--run',action='store_true');a=ap.parse_args()
 if not 10<=a.seconds<=90:raise ValueError('Bounded phases required')
 preparation,prepared,driver=verified_preparation(a.preparation);choices={'A':candidate(a.candidate)}
 if a.compare_with:choices['B']=candidate(a.compare_with)
 order=a.order if a.compare_with else 'A'
 if a.compare_with and (len(order)!=4 or order.count('A')!=2 or order.count('B')!=2):raise ValueError('Comparison needs two runs of each candidate')
 native=Path(a.native or prepared['native_source']);native=(native if native.is_absolute() else RC/native).resolve()
 if not(native.is_relative_to(RC/'experimental') or native.is_relative_to(RC/'build/ab')) or sha(native)!=prepared['native_sha256']:raise ValueError('Pinned independent native host required')
 output=inside_build(RC/a.result)
 if output.exists():raise FileExistsError(output)
 plan={'kind':'b-sustained-same-environment-comparison','preparation':str(preparation),'preparation_sha256':sha(preparation),'environment_sha256':prepared['full_environment_sha256'],
  'overlay_sha256':prepared['overlay_sha256'],'native':str(native),'native_sha256':sha(native),'choices':choices,'order':order,'seconds':a.seconds,'profile':a.profile,'tools':toolpins(),'results':[],'started':False,'installed':False}
 if a.check:print(json.dumps(plan,ensure_ascii=False,indent=2));return 0
 with Registration(owner='RConnect B / 新环境性能对照',resource='game',purpose='Same 11-mod environment sustained LMG '+order,run_dir=output,evidence=output/'series.json',wait=1200) as reg:
  fresh,check,_=verified_preparation(a.preparation)
  if sha(fresh)!=plan['preparation_sha256']:raise ValueError('Preparation changed while waiting')
  output.mkdir(parents=True);plan['started']=True;save(output/'series.json',plan)
  for index,label in enumerate(order):
   if toolpins()!=plan['tools']:raise ValueError('Runner or its read-only dependencies changed')
   result=run_one(reg,choices[label],native,output/(str(index+1).zfill(2)+'-'+label),prepared,driver,plan['preparation_sha256'],a.seconds,a.profile,a.diagnostic)
   plan['results'].append({'label':label,'path':str(output/(str(index+1).zfill(2)+'-'+label)),'passed':result['passed'],'candidate_sha256':result['candidate_sha256'],'environment_sha256':result['environment_sha256']});save(output/'series.json',plan)
   if not result['passed']:break
  plan['passed']=len(plan['results'])==len(order) and all(r['passed'] for r in plan['results']);save(output/'series.json',plan)
  reg.outcome='passed' if plan['passed'] else 'failed';reg.note='Unchanged sustained003 driver; same new mod environment; performance comparison requires separate analysis'
 print(json.dumps({'result':str(output),'passed':plan['passed'],'runs':len(plan['results'])},ensure_ascii=False));return 0 if plan['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
