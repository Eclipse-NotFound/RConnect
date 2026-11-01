"""Same functional workload; allow 30 minutes in the shared queue. Trial timeouts unchanged."""
"""B-only native pointer and physical room-exit regressions, isolated from live saves."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time
import uuid

HERE = Path(__file__).resolve().parents[2] / 'tools/host_authority/field2_driver'
sys.path.insert(0, str(HERE.parent))
from common import ROOT, JAVA, SDK, sha, read, save, verify_files, inside_build
GAME = ROOT.parents[1]
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from test_registry import Registration
from air_test_process import HiddenProcess


def available_gib():
    class Memory(ctypes.Structure):
        _fields_ = [('length', ctypes.c_ulong), ('load', ctypes.c_ulong)] + [
            (name, ctypes.c_ulonglong) for name in ('total', 'available', 'page', 'available_page', 'virtual', 'available_virtual', 'extended')]
    value = Memory(); value.length = ctypes.sizeof(value)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(value)):
        raise ctypes.WinError()
    return value.available / 2**30


def events(path):
    result = []
    if path.exists():
        for line in path.read_text(encoding='utf-8-sig', errors='replace').splitlines():
            try: result.append(json.loads(line))
            except ValueError: pass
    return result


def freeze_save(source, target):
    for attempt in range(3):
        before = sha(source)
        shutil.copy2(source, target)
        if before == sha(source) == sha(target):
            return before
    raise RuntimeError('Save changed during read; source was never written')


def prepare(out, resume=False):
    playable = ROOT / 'build/ab/b3-playable-190'
    manifest = read(playable/'manual-input.json')
    verify_files(playable/'game', manifest['files'])
    game = out/'game'
    source = out/'BStartupDriverMod.as'
    dest = game/'mods/BStartupDriver/release'
    if resume:
        if (out/'prepared.json').exists() or sha(source)!=sha(HERE/'BStartupDriverMod.as'):
            raise ValueError('Only the unchanged, incomplete preparation can resume')
        verify_files(game,{k:v for k,v in manifest['files'].items() if k!='mods/loader-manifest.txt'})
    else:
        out.mkdir(parents=True);game.mkdir()
        for name in manifest['files']:
            destination = game/name; destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(playable/'game'/name, destination)
        shutil.copy2(HERE/'BStartupDriverMod.as', source)
        for helper in list(HERE.glob('B*Cases.as'))+list(HERE.glob('B*Checks.as'))+list(HERE.glob('B*Inputs.as'))+list(HERE.glob('B*Trace.as')):shutil.copy2(helper,out/helper.name)
        dest.mkdir(parents=True)
    command = [str(JAVA), '-Xmx512m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
               '+flexlib='+str(SDK/'frameworks'), '-source-path='+str(out), '-swf-version=38',
               '-debug=true', '-optimize=true', '-output='+str(dest/'BStartupDriverMod.swf'), str(source)]
    if not resume:
        with (out/'build.log').open('x', encoding='utf-8') as log:
            subprocess.run(command, env=dict(os.environ, AIR_HOME=str(SDK)), stdout=log, stderr=subprocess.STDOUT, check=True)
    shutil.copy2(GAME/'mods/ModLoader/supported-mods.txt',game/'mods/ModLoader/supported-mods.txt')
    selected = ['ModLoaderMod','SandevistanMod','RealisticVisionMod','MoreSkillsWeaponsMod','TDFCMod',
                'RandomRoomsMod','LootEditorMod','WallBlendMod','BStartupDriverMod']
    attempt=len(list(out.glob('selection*.stdout.log')))+1
    selection_cmd = [str(GAME/'mods/ModLoader/RemainsModLauncher.exe'), '--root', str(game), '--only', ','.join(selected),
                     '--no-ui', '--report', str(out/f'selection-{attempt:02d}.json')]
    with (out/f'selection-{attempt:02d}.stdout.log').open('x', encoding='utf-8') as log:
        subprocess.run(selection_cmd, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=90)
    config = read(playable/'game/mods/Rconnect/release/config.txt')
    if config!=manifest['config']:raise ValueError('Manual B configuration changed')
    config.update(role='', autoGame=False, probe=False)
    save(game/'mods/Rconnect/release/config.txt', config)
    seeds = {}
    for role, number in [('host', 1), ('join', 2)]:
        seed = Path(os.environ['APPDATA']) / ('pfe-modsettings-rconnect-b-player-'+str(number)) / 'Local Store/#SharedObjects/pfe.swf/PFEgame0.sol'
        target = out/(role+'-save0.sol')
        seeds[role] = dict(source=str(seed), sha256=freeze_save(seed, target), size=target.stat().st_size)
    files = {p.relative_to(game).as_posix():sha(p) for p in game.rglob('*') if p.is_file()}
    save(out/'prepared.json', dict(manual_manifest=sha(playable/'manual-input.json'), original_files=manifest['files'],
         files=files, compiler_command=command, driver=sha(source), helpers={p.name:sha(p) for p in list(out.glob('B*Cases.as'))+list(out.glob('B*Checks.as'))+list(out.glob('B*Inputs.as'))+list(out.glob('B*Trace.as'))}, launcher_command=selection_cmd, seeds=seeds))
    print(json.dumps(dict(prepared=str(out), seeds=seeds), ensure_ascii=False), flush=True)


def validate_terrain_seed(scenario, terrain_seed):
    if terrain_seed is not None and (scenario != 'terrainlive' or type(terrain_seed) is not int or not 1 <= terrain_seed <= 0xffffffff):
        raise ValueError('Diagnostic terrain seed requires terrainlive and an integer from 1 to 4294967295')


def run(out, scenario, candidate, result, preparation, native=None, terrain_seed=None):
    validate_terrain_seed(scenario, terrain_seed)
    game = out/'game'; prepared = read(out/preparation)
    # Only the tested RConnect SWF/config and generated descriptors vary between runs.
    mutable = {'mods/rconnect/release/rconnectmod.swf', 'mods/rconnect/release/config.txt','pfe.swf'}
    verify_files(game, {k:v for k,v in prepared['files'].items() if k.lower() not in mutable})
    if result.exists(): raise FileExistsError(result)
    result.mkdir(parents=True)
    shutil.copy2(__file__,result/'runner.py')
    reservation = socket.socket(); reservation.bind(('127.0.0.1', 0)); port = reservation.getsockname()[1]
    if scenario == 'host-bind-failure': reservation.listen(1)
    else: reservation.close()
    config = read(game/'mods/Rconnect/release/config.txt'); config['port'] = port
    timeout=960 if scenario in ('enemies','teleport','rockets','terrain') else 300
    runtime_files=dict(prepared['files'])
    roles = ['host','join']
    receipt = dict(scenario=scenario, candidate_sha256=sha(candidate), roles={}, private_desktop=True,
                   seed_hashes={k:v['sha256'] for k,v in prepared['seeds'].items()}, complete=False,
                   runtime_files=runtime_files,runner_sha256=sha(__file__),preparation_sha256=sha(out/preparation),
                   candidate_path=str(candidate))
    if terrain_seed is not None: receipt.update(diagnostic_only=True, terrain_seed=terrain_seed)
    processes=[]; streams=[]
    required = 6 if len(roles)==2 else 3
    with Registration(owner='RConnect B / 交互、出口和性能', purpose='B field '+scenario, run_dir=result, evidence=result/'result.json', wait=1800) as reg:
        try:
            # Claim the shared game resource before changing this reusable copy.
            # A second queued scenario must not rewrite the first one's config.
            verify_files(game, {k:v for k,v in prepared['files'].items() if k.lower() not in mutable})
            shutil.copy2(candidate, game/'mods/Rconnect/release/RConnectMod.swf')
            native_source=Path(native) if native else ROOT/'build/ab/b3-playable-190/game/pfe.swf'
            shutil.copy2(native_source,game/'pfe.swf');runtime_files['pfe.swf']=sha(native_source)
            receipt['native_source']=str(native_source)
            save(game/'mods/Rconnect/release/config.txt', config)
            startup=dict(scenario=scenario, port=port, timeout=timeout, evidenceDirectory=str(result),clockTrace=scenario=='rockets')
            if terrain_seed is not None: startup['terrainSeed']=terrain_seed
            save(game/'startup-test.json', startup)
            for name in ('mods/Rconnect/release/RConnectMod.swf','mods/Rconnect/release/config.txt','startup-test.json'):
                # Older preparations contain both RConnect and Rconnect. On
                # Windows these name the same file; update every alias when
                # pinning this run, leaving the old preparation unchanged.
                keys=[k for k in runtime_files if k.lower()==name.lower()] or [name]
                for key in keys:runtime_files[key]=sha(game/name)
            free=available_gib(); receipt['free_gib']=free
            if free<required: raise RuntimeError(f'Only {free:.3f} GiB available; need {required} GiB')
            for role in roles:
                appid='pfe-modsettings-rconnect-b-startup-'+role+'-'+uuid.uuid4().hex
                store=Path(os.environ['APPDATA'])/appid/'Local Store'
                if store.exists(): raise FileExistsError(store)
                seed=store/'#SharedObjects/pfe.swf/PFEgame0.sol'; seed.parent.mkdir(parents=True)
                shutil.copy2(out/(role+'-save0.sol'), seed)
                desc=game/(appid+'.xml')
                desc.write_text('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
                    f'<id>{appid}</id><versionNumber>1.0</versionNumber><filename>B Startup Test</filename>'
                    '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
                stream=(result/(role+'.stdout.log')).open('x',encoding='utf-8');streams.append(stream)
                command=[str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)]
                reg.before_launch(role+' / '+appid)
                process=HiddenProcess(command,cwd=game,stdout=stream,stderr=stream);processes.append(process);reg.child(process.pid)
                receipt['roles'][role]=dict(appid=appid,storage=str(store),descriptor=str(desc),descriptor_sha256=sha(desc),pid=process.pid,desktop=process.desktop)
                save(result/'result.json',receipt)
                if role=='host' and len(roles)==2:
                    deadline=time.monotonic()+160
                    while time.monotonic()<deadline:
                        if any(e['kind']=='listening' for e in events(store/'RConnect-B.log')): break
                        if process.poll() is not None: raise RuntimeError('Host exited before listening')
                        if any(e['kind']=='DONE' for e in events(store/'BStartupDriver.log')): raise RuntimeError('Host probe ended before joining')
                        if available_gib()<0.5: raise RuntimeError('Memory guard below 512 MiB')
                        time.sleep(1)
                    else: raise TimeoutError('Host never listened')
            deadline=time.monotonic()+timeout+20
            failed_at=None
            while time.monotonic()<deadline:
                data=[events(Path(v['storage'])/'BStartupDriver.log') for v in receipt['roles'].values()]
                if any(any(e['kind']=='DRIVER_IO_FAILED' for e in row) for row in data):raise RuntimeError('External evidence write failed; queued temporary files retained')
                if any(any(e['kind']=='DONE' and e.get('data',{}).get('failed',0)>0 for e in row) for row in data):
                    # Keep the failure. Give the peer a bounded chance to export
                    # its already-collected evidence before terminating our AIRs.
                    if failed_at is None:failed_at=time.monotonic()
                    if time.monotonic()-failed_at>=15:raise RuntimeError('Driver completed with failed assertions; evidence grace expired')
                if all(any(e['kind']=='DONE' for e in row) for row in data): receipt['complete']=True;break
                if any(p.poll() is not None for p in processes): raise RuntimeError('AIR ended before DONE')
                if available_gib()<0.5: raise RuntimeError('Memory guard below 512 MiB')
                time.sleep(1)
            if not receipt['complete']: raise TimeoutError('Probe timeout')
        except Exception as error:
            receipt['error']=str(error)
        finally:
            for process in processes:
                if process.poll() is None: process.kill();process.wait(timeout=20)
                process.close()
            for stream in streams:stream.close()
            reservation.close()
            for role, entry in receipt['roles'].items():
                store=Path(entry['storage'])
                # This is a fresh owned test identity. Keep every module's log
                # so failures in newly enabled dependencies remain diagnosable.
                for log in store.iterdir() if store.is_dir() else []:
                    if log.is_file() and (log.suffix.lower()=='.log' or log.name.endswith('modlog.txt')):
                        shutil.copy2(log,result/(role+'.'+log.name))
                for picture in store.glob('*.png'):shutil.copy2(picture,result/(role+'.'+picture.name))
                data=events(store/'BStartupDriver.log')
                entry['passed']=sum(x['kind']=='PASS' for x in data);entry['failed']=sum(x['kind']=='FAIL' for x in data)
                entry['done']=any(x['kind']=='DONE' for x in data)
                entry['fatal']=[x for x in events(store/'RConnect-B.log') if x['kind']=='FATAL']
                entry['logs']={p.name:sha(p) for p in result.glob(role+'.*')
                               if p.is_file() and (p.suffix.lower()=='.log' or p.name.endswith('modlog.txt'))}
            receipt['runtime_changes']=[name for name,digest in runtime_files.items() if sha(game/name)!=digest]
            receipt['runtime_unchanged']=not receipt['runtime_changes']
            receipt['passed']=receipt['complete'] and receipt['runtime_unchanged'] and all(
                v['done'] and v['failed']==0 and not v['fatal'] for v in receipt['roles'].values())
            save(result/'result.json',receipt)
            reg.child_stopped();reg.outcome='passed' if receipt['passed'] else 'failed';reg.note='B新反馈控制与原生回归；保留所有失败'
    print(json.dumps({k:v for k,v in receipt.items() if k!='runtime_files'},ensure_ascii=False),flush=True)
    return 0 if receipt['passed'] else 1


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--workspace',required=True);ap.add_argument('--prepare',action='store_true')
    ap.add_argument('--resume-preparation',action='store_true')
    ap.add_argument('--preparation',default='prepared.json')
    ap.add_argument('--refresh-driver',action='store_true')
    ap.add_argument('--scenario',choices=['hover','boundary','enemies','controls','ui','darkteleport','security','textmotion','terrainlive','motion','visualfield','teleport','rockets','terrain','loading','horseshoe','addiction','injury','attachments'])
    ap.add_argument('--terrain-seed', type=int, help='Diagnostic terrainlive only: replay one recorded native layout seed')
    ap.add_argument('--native');ap.add_argument('--candidate');ap.add_argument('--result');a=ap.parse_args()
    validate_terrain_seed(a.scenario, a.terrain_seed)
    if a.terrain_seed is not None and (a.prepare or a.resume_preparation or a.refresh_driver):
        ap.error('--terrain-seed is only accepted for a terrainlive run')
    out=inside_build(ROOT/a.workspace)
    if a.refresh_driver:
        with Registration(owner='RConnect B / 交互和出口',purpose='外置驱动修订',run_dir=out,evidence=out/a.preparation) as registration:
            if available_gib()<1:raise RuntimeError('Compiler needs 1 GiB')
            if (out/a.preparation).exists():raise FileExistsError(out/a.preparation)
            previous=read(out/'prepared.json');source=out/('driver-'+Path(a.preparation).stem)/'BStartupDriverMod.as'
            source.parent.mkdir();shutil.copy2(HERE/'BStartupDriverMod.as',source)
            for helper in list(HERE.glob('B*Cases.as'))+list(HERE.glob('B*Checks.as'))+list(HERE.glob('B*Inputs.as'))+list(HERE.glob('B*Trace.as')):shutil.copy2(helper,source.parent/helper.name)
            destination=out/'game/mods/BStartupDriver/release/BStartupDriverMod.swf'
            command=[str(JAVA),'-Xmx512m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-source-path='+str(source.parent),'-swf-version=38','-debug=true','-optimize=true','-output='+str(destination),str(source)]
            with (source.parent/'build.log').open('x',encoding='utf-8') as log:subprocess.run(command,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
            shutil.copy2(destination,source.parent/'BStartupDriverMod.swf')
            previous['files']['mods/BStartupDriver/release/BStartupDriverMod.swf']=sha(destination)
            previous.update(driver=sha(source),helpers={p.name:sha(p) for p in list(source.parent.glob('B*Cases.as'))+list(source.parent.glob('B*Checks.as'))+list(source.parent.glob('B*Inputs.as'))+list(source.parent.glob('B*Trace.as'))},compiler_command=command)
            save(out/a.preparation,previous);registration.outcome='passed'
        return 0
    if a.prepare or a.resume_preparation:
        if a.prepare and out.exists():raise FileExistsError(out)
        with Registration(owner='RConnect B / 交互和出口',purpose='外置驱动编译准备',run_dir=out,evidence=out/'prepared.json') as registration:
            if available_gib()<1:raise RuntimeError('Compiler needs 1 GiB')
            prepare(out,a.resume_preparation);registration.outcome='passed'
        return 0
    return run(out,a.scenario,ROOT/a.candidate,inside_build(ROOT/a.result),a.preparation,ROOT/a.native if a.native else None,a.terrain_seed)


if __name__=='__main__':raise SystemExit(main())
