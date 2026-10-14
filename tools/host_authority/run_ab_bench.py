"""Matched isolated A22/B193 trials. Same observer/workload, original production bytes."""
import argparse, ctypes, json, os, shutil, socket, subprocess, time, uuid
from pathlib import Path
from common import ROOT, inside_build, read, save, sha, verify_baseline, verify_files
from run_probe import records

class Memory(ctypes.Structure):
    _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(n,ctypes.c_ulonglong) for n in ('total','available','commitLimit','commitAvailable','virtual','virtualAvailable','extended')]

def machine():
    m=Memory();m.length=ctypes.sizeof(m);ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
    values=[ctypes.c_ulonglong() for _ in range(3)];ctypes.windll.kernel32.GetSystemTimes(*[ctypes.byref(v) for v in values])
    return dict(time=time.time(),available=m.available,commitAvailable=m.commitAvailable,cpuTicks=[v.value for v in values])

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--variant',choices=['A','B'],required=True);ap.add_argument('--driver',required=True);ap.add_argument('--output',required=True)
    ap.add_argument('--seconds',type=int,default=45);ap.add_argument('--timeout',type=int,default=420)
    ap.add_argument('--candidate',default='b3-build-193',help='Frozen B build directory name below build/ab')
    ap.add_argument('--profile',action='store_true',help='Collect nested production timings during B phases')
    a=ap.parse_args()
    if Path(a.candidate).name!=a.candidate:ap.error('Candidate must be a build directory name')
    if a.profile and a.variant!='B':ap.error('Production profiling is available only for B')
    if not 10<=a.seconds<=180:ap.error('Bounded per-phase duration required')
    baseline=ROOT/'build/ab/baseline-001';base=verify_baseline(baseline)
    driver=inside_build(ROOT/a.driver);d=read(driver/'build-input.json');verify_files(driver,d['sources']);verify_files(driver,d['files'])
    if d['family']!='rconnect-ab-bench-v1':raise ValueError('Explicit benchmark driver required')
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    if machine()['commitAvailable']<6*2**30:raise RuntimeError('Insufficient available commit for dual AIR')
    if shutil.disk_usage(ROOT).free<3*sum((baseline/'game'/p).stat().st_size for p in base['files']):raise RuntimeError('Insufficient runtime-copy space')
    out.mkdir(parents=True);(out/'tools').mkdir()
    for name in ('run_ab_bench.py','common.py','run_probe.py'):shutil.copy2(Path(__file__).parent/name,out/'tools'/name)
    shutil.copy2(driver/'build-input.json',out/'driver-input.json')
    overrides={};manifests={}
    if a.variant=='B':
        for folder,manifest,artifact,target in [
            (a.candidate,'build-input.json','RConnectMod.swf','mods/Rconnect/release/RConnectMod.swf'),
            ('native-hooks-019','native-input.json','pfe.swf','pfe.swf'),
            ('tdfc-build-004','build-input.json','TDFCMod.swf','mods/TDFC/release/TDFCMod.swf'),
            ('rv-build-003','build-input.json','RealisticVisionMod.swf','mods/RealisticVision/release/RealisticVisionMod.swf'),
            ('msw-build-011','build-input.json','MoreSkillsWeaponsMod.swf','mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf'),
            ('sandy-build-001','build-input.json','SandevistanMod.swf','mods/Sandevistan/release/SandevistanMod.swf')]:
            p=ROOT/'build/ab'/folder;m=read(p/manifest);verify_files(p,m['sources'])
            if sha(p/artifact)!=m['candidate_sha256']:raise ValueError('Frozen build changed: '+folder)
            overrides[target]=p/artifact;manifests[folder]=sha(p/manifest)
    run=uuid.uuid4().hex[:12]
    with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
    installed=ROOT.parents[1];protected={p:sha(installed/p) for p in base['files'] if p.lower().endswith(('.swf','config.txt','config.json'))}
    receipt=dict(phase='AB-native-comparison',experimental_only=True,variant=a.variant,run=run,baseline_sha256=sha(baseline/'baseline.json'),driver_sha256=sha(driver/'build-input.json'),build_manifests=manifests,protected_before=protected,roles={},complete=False,policy='default OS scheduling; no priority, power, focus or user-process changes')
    launches=[];processes=[];streams=[];environment=[]
    for role in ('host','join'):
        directory=out/role;shutil.copytree(baseline/'game',directory)
        for name,p in overrides.items():shutil.copy2(p,directory/name)
        config=dict(experimental=True,role=role,session=run,port=port,autoGame=True,land='rbl',probe=True,scenario='stress',stressExternal=True) if a.variant=='B' else dict(nickname=role,hostIp='127.0.0.1',port=port,autoRole=role,autoGame='1',autoTravelLand='rbl' if role=='host' else '',autoFollow='1',autoHeal='',freezeAI='1',worldInject='1',ghostCombat='1',followTeammate='0')
        if a.variant=='B':
            for folder,key in [('tdfc-build-004','tdfc'),('rv-build-003','rv'),('msw-build-011','msw'),('sandy-build-001','sandy')]:config[key]=read(ROOT/'build/ab'/folder/'build-input.json')['candidate_sha256']
        save(directory/'mods/Rconnect/release/config.txt',config)
        bench=dict(variant=a.variant,role=role,seconds=a.seconds,source=d['source_id'],profile=a.profile);save(directory/'ab-bench.json',bench)
        dest=directory/'mods/ABBench/release';dest.mkdir(parents=True)
        for name in d['files']:shutil.copy2(driver/name,dest/name)
        manifest=directory/'mods/loader-manifest.txt';rows=[]
        for line in manifest.read_text(encoding='utf-8-sig').splitlines():
            parts=line.split('|')
            if len(parts)==5 and parts[1]=='RConnectMod':parts[2]='0';line='|'.join(parts)
            rows.append(line)
        manifest.write_text('\n'.join(rows).rstrip()+'\nABBench|ABBenchMod|1|0|0\n',encoding='utf-8')
        appid=('pfe-modsettings-rconnect-b-ab-' if a.variant=='B' else 'pfe-modsettings-rconnect-ab-')+role+'-'+run
        store=Path(os.environ['APPDATA'])/appid/'Local Store'
        if store.exists():raise FileExistsError('Fresh app storage required')
        descriptor=directory/'ab-test.xml';descriptor.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>RConnect AB '+a.variant+' '+role+'</filename><initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
        files={p.relative_to(directory).as_posix():sha(p) for p in directory.rglob('*') if p.is_file()}
        receipt['roles'][role]=dict(appid=appid,files=files,candidate_sha256=sha(directory/'mods/Rconnect/release/RConnectMod.swf'),config=config)
        launches.append((role,directory,descriptor,store))
    save(out/'run.json',receipt)
    try:
        for role,directory,descriptor,store in launches:
            if role=='join':time.sleep(8)
            stream=(out/(role+'.stdout.log')).open('x',encoding='utf-8');streams.append(stream)
            command=[str(directory/'adl64.exe'),'-runtime',str(directory/'runtimes/air/win64'),str(descriptor)]
            p=subprocess.Popen(command,cwd=directory,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);processes.append(p)
            receipt['roles'][role].update(pid=p.pid,command=command);save(out/'run.json',receipt);print(json.dumps(dict(role=role,pid=p.pid,appid=receipt['roles'][role]['appid'])),flush=True)
        end=time.monotonic()+a.timeout
        while time.monotonic()<end:
            values=[records(store/'ABBench.log') for _,_,_,store in launches];environment.append(machine())
            if any(any(x['kind']=='fatal' for x in v) for v in values):raise RuntimeError('Fixture fatal; inspect retained logs')
            if all(any(x['kind']=='done' for x in v) for v in values):receipt['complete']=True;break
            if any(p.poll() is not None for p in processes):raise RuntimeError('Owned AIR exited before completion')
            time.sleep(2)
        if not receipt['complete']:raise TimeoutError('Bounded A/B trial timeout')
    except Exception as error:receipt['error']=str(error)
    finally:
        for p in processes:
            if p.poll() is None:
                p.terminate()
                try:p.wait(timeout=10)
                except subprocess.TimeoutExpired:p.kill();p.wait(timeout=10)
        for stream in streams:stream.close()
        for role,directory,descriptor,store in launches:
            dest=out/'evidence'/role;dest.mkdir(parents=True)
            for p in store.glob('*'):
                if p.is_file() and (p.suffix in ('.log','.png') or p.name.endswith('modlog.txt')):shutil.copy2(p,dest/p.name)
            try:verify_files(directory,receipt['roles'][role]['files']);receipt['roles'][role]['runtime_unchanged']=True
            except Exception as error:receipt['roles'][role].update(runtime_unchanged=False,runtime_error=str(error))
            values=records(store/'ABBench.log');receipt['roles'][role]['done']=any(v['kind']=='done' for v in values)
        receipt['owned_processes_exited']=all(p.poll() is not None for p in processes)
        receipt['process_exit_codes']=[dict(pid=p.pid,code=p.poll()) for p in processes]
        receipt['protected_after']={p:sha(installed/p) for p in protected};receipt['installation_unchanged']=protected==receipt['protected_after']
        save(out/'machine.json',environment);save(out/'run.json',receipt)
    print(json.dumps(dict(output=str(out),complete=receipt['complete'],error=receipt.get('error')),ensure_ascii=False),flush=True)
    raise SystemExit(0 if receipt['complete'] and receipt['installation_unchanged'] and all(v['runtime_unchanged'] for v in receipt['roles'].values()) else 1)
if __name__=='__main__':main()
