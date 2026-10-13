"""Launch only uniquely owned B test processes against pinned physical inputs.

Uses fresh AIR stores, no user save reads/writes, no live release replacement.
Retains all inputs and failed runs. No native-game result is inherited.
"""
import argparse
import json
import os
import shutil
import socket
import subprocess
import time
import uuid
from pathlib import Path
from common import ROOT, inside_build, read, save, sha, verify_baseline, verify_files
from jitter_proxy import JitterProxy


def records(path):
    if not path.is_file():
        return []
    result = []
    for line in path.read_text(encoding='utf-8-sig', errors='replace').splitlines():
        try:
            value=json.loads(line)
            if isinstance(value,dict) and isinstance(value.get('kind'),str):result.append(value)
        except json.JSONDecodeError:
            continue  # A currently open append may end in a partial final line.
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline', required=True)
    ap.add_argument('--candidate', required=True)
    ap.add_argument('--native', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--seconds', type=int, default=140)
    ap.add_argument('--scenario', choices=('native-gun','ownership','split-rooms','cooperation','lifecycle','sats','pause-cycles','pause-holders','travel','friendly','friendly-melee','friendly-magic','grabs','enemy-grabs','personal','throw','vectors','mines','areas','party','hud','menus','dialogue','vision','stress','explosives','impulse','magic','angles','enemies','sound','music','movement','motion','guns','melee','terrain','teleport','body-effects','time-control','time-special','time-journey','time-exit-record','time-exit-replay','msw','msw-sweep','msw-lifecycle'), default='native-gun')
    ap.add_argument('--swap', action='store_true')
    ap.add_argument('--field-profile', action='store_true', help='Paired field-capture timings on real native objects, native-gun only')
    ap.add_argument('--enemy', choices=('native','tdfc'), default='native')
    ap.add_argument('--tdfc', help='Optional frozen TDFC authority-v1 build directory')
    ap.add_argument('--rv', help='Optional frozen independent RV authority-v1 build')
    ap.add_argument('--msw', help='Optional frozen independent MSW authority-v1 build')
    ap.add_argument('--sandy', help='Optional frozen independent Sandevistan authority-v1 build')
    ap.add_argument('--stress-driver', help='Explicit external continuous-shooting test fixture, stress only')
    ap.add_argument('--jitter-ms', help='Isolated loopback relay delay schedule, comma-separated milliseconds in 0..450')
    ap.add_argument('--stress-seconds', type=int, default=20, help='Measured dense-scene duration, 20..1800 seconds, stress scenario only')
    args = ap.parse_args()
    driver, driver_build = None, None
    if args.stress_driver:
        if args.scenario != 'stress':ap.error('--stress-driver requires stress')
        driver=inside_build(ROOT/args.stress_driver);driver_build=read(driver/'build-input.json')
        if driver_build.get('family')!='rconnect-external-stress-driver-v1' or driver_build.get('experimental_only') is not True:
            raise ValueError('Not an explicit isolated stress driver')
        verify_files(driver,driver_build['sources']);verify_files(driver,driver_build['files'])
    if args.field_profile and args.scenario != 'native-gun':
        ap.error('--field-profile requires native-gun')
    if not 20 <= args.stress_seconds <= 1800 or args.scenario != 'stress' and args.stress_seconds != 20:
        ap.error('--stress-seconds requires stress and a duration in 20..1800')
    baseline, candidate, native, out = [inside_build(ROOT/p) for p in (args.baseline, args.candidate, args.native, args.output)]
    b = verify_baseline(baseline)
    build, patch = read(candidate/'build-input.json'), read(native/'native-input.json')
    if not build.get('native_capability') or build['native_capability'] != patch['capability']:
        raise ValueError('Mod and native game capabilities differ')
    verify_files(candidate, build['sources'])
    verify_files(native, patch['sources'])
    if patch['baseline_manifest_sha256'] != sha(baseline/'baseline.json'):
        raise ValueError('Native patch uses a different baseline')
    if sha(native/'pfe.swf') != patch['candidate_sha256'] or sha(candidate/'RConnectMod.swf') != build['candidate_sha256']:
        raise ValueError('Candidate bytes changed')
    tactics, tactics_build = None, None
    if args.tdfc:
        tactics = inside_build(ROOT/args.tdfc)
        tactics_build = read(tactics/'build-input.json')
        if tactics_build.get('family') != 'tdfc-authority-v1' or not tactics_build.get('experimental_only'):
            raise ValueError('Not an isolated TDFC authority candidate')
        verify_files(tactics, tactics_build['sources'])
        if sha(tactics/'TDFCMod.swf') != tactics_build['candidate_sha256']:
            raise ValueError('TDFC candidate bytes changed')
    view, view_build = None, None
    if args.rv:
        view = inside_build(ROOT/args.rv)
        view_build = read(view/'build-input.json')
        if view_build.get('family') != 'rv-authority-v1' or not view_build.get('experimental_only'):
            raise ValueError('Not an isolated RV authority candidate')
        verify_files(view, view_build['sources'])
        if sha(view/'RealisticVisionMod.swf') != view_build['candidate_sha256']:
            raise ValueError('RV candidate bytes changed')
    weapons, weapons_build = None, None
    if args.msw:
        weapons = inside_build(ROOT/args.msw)
        weapons_build = read(weapons/'build-input.json')
        if weapons_build.get('family') != 'msw-authority-v1' or not weapons_build.get('experimental_only'):
            raise ValueError('Not an isolated MSW authority candidate')
        verify_files(weapons, weapons_build['sources'])
        if sha(weapons/'MoreSkillsWeaponsMod.swf') != weapons_build['candidate_sha256']:
            raise ValueError('MSW candidate bytes changed')
    sandy, sandy_build = None, None
    if args.sandy:
        sandy = inside_build(ROOT/args.sandy)
        sandy_build = read(sandy/'build-input.json')
        if sandy_build.get('family') != 'sandy-authority-v1' or not sandy_build.get('experimental_only'):
            raise ValueError('Not an isolated Sandevistan authority candidate')
        verify_files(sandy, sandy_build['sources'])
        if sha(sandy/'SandevistanMod.swf') != sandy_build['candidate_sha256']:
            raise ValueError('Sandevistan candidate bytes changed')
    if out.exists():
        raise FileExistsError('Every attempt needs a new run directory')
    game = baseline/'game'
    if shutil.disk_usage(ROOT).free < sum((game/n).stat().st_size for n in b['files'])*3:
        raise RuntimeError('Insufficient space for independent runtime copies')
    out.mkdir(parents=True)
    (out/'tools').mkdir()
    for name in ('run_probe.py','common.py','jitter_proxy.py'):
        shutil.copy2(Path(__file__).parent/name,out/'tools'/name)
    run_id = uuid.uuid4().hex[:12]
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    relay = JitterProxy(port, [int(x) for x in args.jitter_ms.split(',')]) if args.jitter_ms else None
    launches, processes, streams = [], [], []
    installed = ROOT.parents[1]
    protected = {n:sha(installed/n) for n in ('pfe.swf','mods/Rconnect/release/RConnectMod.swf','mods/TDFC/release/TDFCMod.swf','mods/RealisticVision/release/RealisticVisionMod.swf','mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf','mods/Sandevistan/release/SandevistanMod.swf','mods/Sandevistan/release/config.txt')}
    receipt = dict(experimental_only=True, phase='B-native-probe', run=run_id, baseline_manifest_sha256=sha(baseline/'baseline.json'),
        build_manifest_sha256=sha(candidate/'build-input.json'), native_manifest_sha256=sha(native/'native-input.json'),
        candidate_sha256=build['candidate_sha256'], native_sha256=patch['candidate_sha256'],
        protected_before=protected, script_sha256=sha(__file__), roles={}, complete=False)
    if tactics:
        receipt['tdfc_manifest_sha256'] = sha(tactics/'build-input.json')
        receipt['tdfc_sha256'] = tactics_build['candidate_sha256']
    if view:
        receipt['rv_manifest_sha256'] = sha(view/'build-input.json')
        receipt['rv_sha256'] = view_build['candidate_sha256']
    if weapons:
        receipt['msw_manifest_sha256'] = sha(weapons/'build-input.json')
        receipt['msw_sha256'] = weapons_build['candidate_sha256']
    if sandy:
        receipt['sandy_manifest_sha256'] = sha(sandy/'build-input.json')
        receipt['sandy_sha256'] = sandy_build['candidate_sha256']
    if driver:
        receipt['stress_driver'] = dict(path=str(driver.relative_to(ROOT)), manifest_sha256=sha(driver/'build-input.json'),
                                        source_id=driver_build['source_id'], files=driver_build['files'], loads_original_B=True)
        shutil.copy2(driver/'build-input.json',out/'tools/stress-driver-build-input.json')
    if relay:
        receipt['network_fixture'] = dict(host_port=port, join_port=relay.port, delays_ms=relay.delays,
                                         script_sha256=sha(Path(__file__).parent/'jitter_proxy.py'))
    for role in ('host','join'):
        directory = out/role
        shutil.copytree(game, directory)
        shutil.copy2(native/'pfe.swf', directory/'pfe.swf')
        shutil.copy2(candidate/'RConnectMod.swf', directory/'mods/Rconnect/release/RConnectMod.swf')
        configuration = dict(experimental=True, role=role, session=run_id, port=port, autoGame=True, land='random_mane', probe=True, scenario=args.scenario, swap=args.swap, enemy=args.enemy)
        if args.field_profile:
            configuration['fieldProfile'] = True
        if args.scenario == 'stress':
            configuration['stressSeconds'] = args.stress_seconds
        if driver:
            configuration['stressExternal'] = True
            dest=directory/'mods/RConnectStressDriver/release';dest.mkdir(parents=True)
            for name in driver_build['files']:shutil.copy2(driver/name,dest/name)
            manifest=directory/'mods/loader-manifest.txt'
            rows=[]
            for line in manifest.read_text(encoding='utf-8-sig').splitlines():
                parts=line.split('|')
                if len(parts)==5 and parts[1]=='RConnectMod':
                    parts[2]='0'  # The external fixture loads the same B bytes once into its known domain.
                    line='|'.join(parts)
                rows.append(line)
            manifest.write_text('\n'.join(rows).rstrip()+'\nRConnectStressDriver|RConnectStressDriverMod|1|0|0\n',encoding='utf-8')
        if relay and role == 'join':
            configuration['port'] = relay.port
        configuration['sharedPause'] = args.scenario in ('sats','pause-cycles')
        if tactics:
            shutil.copy2(tactics/'TDFCMod.swf',directory/'mods/TDFC/release/TDFCMod.swf')
            configuration['tdfc'] = tactics_build['candidate_sha256']
        if view:
            shutil.copy2(view/'RealisticVisionMod.swf',directory/'mods/RealisticVision/release/RealisticVisionMod.swf')
            configuration['rv'] = view_build['candidate_sha256']
        if weapons:
            shutil.copy2(weapons/'MoreSkillsWeaponsMod.swf',directory/'mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf')
            configuration['msw'] = weapons_build['candidate_sha256']
        if sandy:
            shutil.copy2(sandy/'SandevistanMod.swf',directory/'mods/Sandevistan/release/SandevistanMod.swf')
            configuration['sandy'] = sandy_build['candidate_sha256']
        cfg = directory/'mods/Rconnect/release/config.txt'
        save(cfg, configuration)
        # Installed MSW excludes this prefix; TDFC tests require their exact ID.
        appid = 'pfe-modsettings-rconnect-b-'+role+'-'+run_id
        storage = Path(os.environ['APPDATA'])/appid/'Local Store'
        if storage.exists():
            raise FileExistsError('Refuse to reuse AIR data')
        desc = directory/'authority-test.xml'
        desc.write_text('<?xml version="1.0" encoding="utf-8"?>\n'
            '<application xmlns="http://ns.adobe.com/air/application/30.0">'
            '<id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>RConnect B '+role+'</filename>'
            '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow>'
            '</application>', encoding='utf-8')
        expected = dict(b['files'])
        for key in expected:
            if key.lower() == 'pfe.swf':
                expected[key] = patch['candidate_sha256']
            elif key.lower() == 'mods/rconnect/release/rconnectmod.swf':
                expected[key] = build['candidate_sha256']
            elif key.lower() == 'mods/rconnect/release/config.txt':
                expected[key] = sha(cfg)
            elif tactics and key.lower() == 'mods/tdfc/release/tdfcmod.swf':
                expected[key] = tactics_build['candidate_sha256']
            elif view and key.lower() == 'mods/realisticvision/release/realisticvisionmod.swf':
                expected[key] = view_build['candidate_sha256']
            elif weapons and key.lower() == 'mods/moreskills&weapons/release/moreskillsweaponsmod.swf':
                expected[key] = weapons_build['candidate_sha256']
            elif sandy and key.lower() == 'mods/sandevistan/release/sandevistanmod.swf':
                expected[key] = sandy_build['candidate_sha256']
            elif driver and key.lower() == 'mods/loader-manifest.txt':
                expected[key] = sha(directory/key)
        if driver:
            for name,digest in driver_build['files'].items():expected['mods/RConnectStressDriver/release/'+name]=digest
        verify_files(directory, expected)
        receipt['roles'][role] = dict(appid=appid, descriptor_sha256=sha(desc), config=configuration, config_sha256=sha(cfg), files=expected)
        launches.append((role,directory,desc,storage/'RConnect-B.log'))
    save(out/'run.json', receipt)
    try:
        if relay:
            relay.start()
        for role,directory,desc,log in launches:
            if role=='join':
                host_log = launches[0][3]
                until = time.monotonic()+args.seconds
                while time.monotonic()<until:
                    events = records(host_log)
                    if any(x['kind']=='FATAL' for x in events):
                        raise RuntimeError('Host failed before listening')
                    if any(x['kind']=='listening' for x in events):
                        if driver:
                            installed_driver=records(launches[0][3].parent/'RConnectStressDriver.log')
                            if not any(x['kind']=='installed' and x['data'].get('source')==driver_build['source_id']
                                       and x['data'].get('bSource')==build['source_id'] for x in installed_driver):
                                raise RuntimeError('External fixture did not attach to the pinned B domain before networking')
                        break
                    if processes[0].poll() is not None:
                        raise RuntimeError('Host exited before listening')
                    time.sleep(1)
                else:
                    raise TimeoutError('Host boot/listen timeout')
            stream=(out/(role+'.stdout.log')).open('w', encoding='utf-8');streams.append(stream)
            command=[str(directory/'adl64.exe'),'-runtime',str(directory/'runtimes/air/win64'),str(desc)]
            process=subprocess.Popen(command,cwd=directory,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            processes.append(process)
            receipt['roles'][role].update(pid=process.pid,command=command)
            save(out/'run.json',receipt)
            print(json.dumps(dict(role=role,pid=process.pid,appid=receipt['roles'][role]['appid'])),flush=True)
        deadline=time.monotonic()+args.seconds
        while time.monotonic()<deadline:
            samples=[records(log) for _,_,_,log in launches]
            ends=[any(x['kind']=='DONE' for x in events) for events in samples]
            if all(ends):
                receipt['complete']=True
                break
            if any(any(x['kind']=='FATAL' for x in events) for events in samples):
                raise RuntimeError('Probe reported a fatal error; preserve evidence and stop owned instances')
            if any(p.poll() is not None for p in processes):
                raise RuntimeError('AIR exited before probe completed')
            time.sleep(1)
    except Exception as error:
        receipt['error']=str(error)
    finally:
        # Stop the owned relay before killing its AIR peers. Otherwise our own
        # cleanup can be recorded as a connection reset in an already completed
        # delay test. Preserve genuine earlier relay errors in its result.
        if relay:
            try:
                receipt['network_fixture']['result'] = relay.stop()
            except Exception as error:
                receipt['network_fixture']['result'] = dict(error=str(error), owned_thread_exited=False)
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try:process.wait(timeout=10)
                except subprocess.TimeoutExpired:process.kill();process.wait(timeout=10)
        for stream in streams:stream.close()
        for role,directory,desc,log in launches:
            if log.is_file():shutil.copy2(log,out/(role+'.log'))
            auxiliary={}
            for name in ('tdfc.log','RVision.log','ModSettings.log','WallBlend.log','LootEditor.receipt.json','sandy_modlog.txt','RConnectStressDriver.log'):
                source=log.parent/name
                if source.is_file():
                    target=out/(role+'.'+name)
                    shutil.copy2(source,target)
                    auxiliary[name]=sha(target)
            pictures={}
            for source in sorted(log.parent.glob('*.png')):
                target=out/'pictures'/role/source.name
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(source,target)
                pictures[source.name]=sha(target)
            events=records(log)
            receipt['roles'][role].update(passed=sum(x['kind']=='PASS' for x in events),failed=sum(x['kind']=='FAIL' for x in events),
                fatal=[x for x in events if x['kind']=='FATAL'],done=any(x['kind']=='DONE' for x in events),auxiliary_logs=auxiliary,pictures=pictures)
            try:
                verify_files(directory,receipt['roles'][role]['files'])
                if sha(desc)!=receipt['roles'][role]['descriptor_sha256'] or sha(directory/'mods/Rconnect/release/config.txt')!=receipt['roles'][role]['config_sha256']:
                    raise ValueError('Generated configuration or descriptor changed')
                receipt['roles'][role]['runtime_unchanged']=True
            except Exception as error:
                receipt['roles'][role].update(runtime_unchanged=False,runtime_error=str(error))
        receipt['protected_after']={n:sha(installed/n) for n in protected}
        receipt['installation_unchanged']=receipt['protected_after']==protected
        receipt['owned_processes_exited']=all(p.poll() is not None for p in processes)
        receipt['process_exit_codes']=[dict(pid=p.pid,code=p.poll()) for p in processes]
        save(out/'run.json',receipt)
    verify_baseline(baseline)
    ok=receipt['complete'] and receipt['installation_unchanged'] and receipt['owned_processes_exited']
    ok=ok and all(r['done'] and r['failed']==0 and not r['fatal'] and r['passed']>0 and r['runtime_unchanged'] for r in receipt['roles'].values())
    if relay:
        relay_result=receipt['network_fixture']['result']
        ok=ok and relay_result.get('owned_thread_exited') is True and relay_result.get('error') is None
    print(json.dumps(dict(path=str(out),ok=ok,error=receipt.get('error'),roles={role:{k:v for k,v in r.items() if k in ('passed','failed','done','fatal')} for role,r in receipt['roles'].items()}),ensure_ascii=False),flush=True)
    raise SystemExit(0 if ok else 1)


if __name__=='__main__':
    main()
