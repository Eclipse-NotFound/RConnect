"""B-only sustained LMG workload, separately frozen from original AB007."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import uuid
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools' / 'host_authority' / 'field2_driver'))
from run import ROOT, GAME, Registration, HiddenProcess, available_gib, read, save, sha, verify_files, inside_build, events

def commit_available_gib():
    class Memory(ctypes.Structure):
        _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(key,ctypes.c_ulonglong) for key in ('total','available','commit','available_commit','virtual','available_virtual','extended')]
    value=Memory();value.length=ctypes.sizeof(value)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(value)):raise ctypes.WinError()
    return value.available_commit/2**30

def memory_guard():
    if available_gib()<0.5 or commit_available_gib()<0.75:raise RuntimeError('Memory guard: physical/commit reserve')

def machine():
    values=[ctypes.c_ulonglong() for _ in range(3)]
    ctypes.windll.kernel32.GetSystemTimes(*[ctypes.byref(v) for v in values])
    return dict(time=time.time(),free_gib=available_gib(),commit_free_gib=commit_available_gib(),cpuTicks=[v.value for v in values])

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--workspace',required=True);ap.add_argument('--candidate',required=True)
    ap.add_argument('--native',required=True);ap.add_argument('--result',required=True);ap.add_argument('--profile',action='store_true');ap.add_argument('--seconds',type=int,default=30)
    ap.add_argument('--driver',default='build/ab/ab-sustained-003');ap.add_argument('--prior-preparation',default='prepared.json')
    ap.add_argument('--diagnostic',action='store_true')
    a=ap.parse_args()
    if not 10<=a.seconds<=90:raise ValueError('Bounded phases required')
    workspace=inside_build(ROOT/a.workspace);result=inside_build(ROOT/a.result);candidate=inside_build(ROOT/a.candidate)
    if (workspace/'stop-before-next-sustained').exists():
        print(json.dumps(dict(stopped_before_start=True,result=str(result),reason='Owned series stopped for fixture investigation')))
        return 2
    build=read(candidate/'build-input.json');verify_files(candidate,build['sources'])
    if sha(candidate/'RConnectMod.swf')!=build['candidate_sha256']:raise ValueError('Candidate changed')
    driver=inside_build(ROOT/a.driver)
    if driver.parent!=ROOT/'build/ab' or not driver.name.startswith('ab-sustained-') or not driver.name[13:].isdigit():raise ValueError('Explicit sustained driver required')
    preparation='prepared-'+driver.name[3:]+'.json'
    if Path(a.prior_preparation).name!=a.prior_preparation:raise ValueError('Prior preparation must be a file in this workspace')
    driver_input=read(driver/'build-input.json');verify_files(driver,driver_input['files']);verify_files(driver,driver_input['sources'])
    playable=ROOT/'build/ab/b3-playable-190';manual=read(playable/'manual-input.json');verify_files(playable/'game',manual['files'])
    if result.exists():raise FileExistsError(result)
    with Registration(owner='RConnect B / 性能对照',purpose='Sustained LMG B '+('profile' if a.profile else 'clean')+' '+candidate.name,run_dir=result,evidence=result/'result.json',wait=1200) as reg:
        if available_gib()<6:raise RuntimeError('Dual AIR needs 6 GiB')
        if commit_available_gib()<3:raise RuntimeError('Dual AIR needs 3 GiB available commit')
        result.mkdir(parents=True);shutil.copy2(__file__,result/'runner.py')
        receipt=dict(complete=False,candidate_sha256=build['candidate_sha256'],candidate_source=build['source_id'],driver_sha256=sha(driver/'build-input.json'),manual_sha256=sha(playable/'manual-input.json'),profile=a.profile,seconds=a.seconds,roles={},private_desktop=True,diagnostic_only=a.diagnostic)
        # Reuse the owned benchmark copies. Verify original preparation first;
        # only the three external driver SWFs change. Keep both manifests.
        if not (workspace/preparation).exists():
            original=read(workspace/a.prior_preparation);prepared={}
            for role in ('host','join'):
                game=workspace/role
                mutable={'mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt','pfe.swf'}
                verify_files(game,{k:v for k,v in original[role].items() if k.lower() not in mutable})
                prepared[role]=dict(original[role])
                for name in driver_input['files']:
                    relative='mods/ABBench/release/'+name
                    key=next(k for k in prepared[role] if k.lower()==relative.lower())
                    shutil.copy2(driver/name,game/relative)
                    prepared[role][key]=sha(game/relative)
            save(workspace/preparation,prepared)
        prepared=read(workspace/preparation);processes=[];streams=[];environment=[]
        run_id=uuid.uuid4().hex[:12]
        with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
        try:
            for role in ('host','join'):
                game=workspace/role
                mutable={'mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt','pfe.swf'}
                verify_files(game,{k:v for k,v in prepared[role].items() if k.lower() not in mutable})
                shutil.copy2(candidate/'RConnectMod.swf',game/'mods/Rconnect/release/RConnectMod.swf')
                native=inside_build(ROOT/a.native);shutil.copy2(native,game/'pfe.swf')
                receipt['native_source']=str(native);receipt['native_sha256']=sha(native)
                config=dict(manual['config']);config.update(experimental=True,role=role,session=run_id,port=port,autoGame=True,land='rbl',probe=False,frameProfile=True)
                save(game/'mods/Rconnect/release/config.txt',config)
                save(game/'ab-bench.json',dict(variant='B',role=role,seconds=a.seconds,source=driver_input['source_id'],profile=a.profile))
                appid='pfe-modsettings-rconnect-b-ab-'+role+'-'+run_id
                store=Path(os.environ['APPDATA'])/appid/'Local Store'
                if store.exists():raise FileExistsError(store)
                descriptor=game/'ab-test.xml';descriptor.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>B Performance Test</filename><initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
                files=dict(prepared[role])
                for name in ['mods/Rconnect/release/RConnectMod.swf','mods/Rconnect/release/config.txt','pfe.swf','ab-bench.json','ab-test.xml']:
                    key=next((k for k in files if k.lower()==name.lower()),name);files[key]=sha(game/name)
                receipt['roles'][role]=dict(appid=appid,storage=str(store),files=files)
                save(result/'result.json',receipt)
                reg.before_launch(role+' / '+appid)
                if commit_available_gib()<1.5:raise RuntimeError('Insufficient commit before AIR launch')
                stream=(result/(role+'.stdout.log')).open('x',encoding='utf-8');streams.append(stream)
                p=HiddenProcess([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(descriptor)],cwd=game,stdout=stream,stderr=stream)
                processes.append(p);reg.child(p.pid);receipt['roles'][role].update(pid=p.pid,desktop=p.desktop)
                if role=='host':
                    until=time.monotonic()+120
                    while time.monotonic()<until:
                        if any(v['kind']=='listening' for v in events(store/'RConnect-B.log')):break
                        if p.poll() is not None:raise RuntimeError('Host exited before listening')
                        memory_guard()
                        time.sleep(1)
                    else:raise TimeoutError('Host did not listen')
            until=time.monotonic()+a.seconds*2+180
            while time.monotonic()<until:
                environment.append(machine())
                logs=[events(Path(v['storage'])/'ABBench.log') for v in receipt['roles'].values()]
                if any(any(v['kind']=='fatal' for v in log) for log in logs):raise RuntimeError('Benchmark failed; logs retained')
                if all(any(v['kind']=='done' for v in log) for log in logs):receipt['complete']=True;break
                if any(p.poll() is not None for p in processes):raise RuntimeError('AIR exited')
                memory_guard()
                time.sleep(1)
            if not receipt['complete']:raise TimeoutError('Benchmark timeout')
        except Exception as error:receipt['error']=str(error)
        finally:
            for p in processes:
                if p.poll() is None:p.kill();p.wait(timeout=20)
                p.close()
            for stream in streams:stream.close()
            for role,entry in receipt['roles'].items():
                store=Path(entry['storage']);dest=result/role;dest.mkdir()
                for path in store.glob('*'):
                    if path.is_file() and (path.suffix in ('.log','.png') or path.name.endswith('modlog.txt')):shutil.copy2(path,dest/path.name)
                entry['runtime_changes']=[name for name,digest in entry['files'].items() if sha(workspace/role/name)!=digest]
                values=events(store/'ABBench.log');entry['results']=[v['data'] for v in values if v['kind']=='result']
                entry['fatal']=[v for v in events(store/'RConnect-B.log') if v['kind']=='FATAL']
                entry['done']=any(v['kind']=='done' for v in values)
            receipt['passed']=receipt['complete'] and all(v['done'] and not v['runtime_changes'] and not v['fatal'] and len(v['results'])==2 for v in receipt['roles'].values())
            save(result/'machine.json',environment);save(result/'result.json',receipt)
            reg.child_stopped();reg.outcome='passed' if receipt['passed'] else 'failed';reg.note='独立持续射击负载；8/80敌人、双人1000发弹匣；原AB007失败保留'
        print(json.dumps(dict(result=str(result),passed=receipt['passed'],error=receipt.get('error')),ensure_ascii=False))
        return 0 if receipt['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
