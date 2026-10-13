"""Load the frozen manual B bytes with automation disabled and fresh AIR stores.

Checks ordinary loading only, not human mouse/IME interaction or gameplay.
Never launches the stable player profiles or replaces an installed artifact.
"""
import argparse
import os
import shutil
import subprocess
import time
import uuid
from pathlib import Path
from common import ROOT, inside_build, read, save, sha, verify_files
from run_probe import records


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manual', required=True)
    ap.add_argument('--candidate', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--seconds', type=int, default=75)
    args = ap.parse_args()
    manual, candidate, out = [inside_build(ROOT/p) for p in (args.manual, args.candidate, args.output)]
    prepared = read(manual/'manual-input.json')
    built = read(candidate/'build-input.json')
    verify_files(manual/'game', prepared['files'])
    verify_files(candidate, built['sources'])
    if sha(candidate/'build-input.json') != prepared['candidate_manifest_sha256']:
        raise ValueError('Manual candidate differs from the frozen build')
    if not 40 <= args.seconds <= 180:
        ap.error('Use 40..180 seconds for ordinary loading')
    if prepared['config'].get('probe') is not False or prepared['config'].get('autoGame') is not False or prepared['config'].get('role'):
        raise ValueError('Automation must be disabled in the manual candidate')
    if out.exists():
        raise FileExistsError('Preserve every startup attempt in a fresh directory')
    out.mkdir(parents=True)
    run_id = uuid.uuid4().hex[:12]
    installed = ROOT.parents[1]
    protected_names = ('pfe.swf', 'mods/Rconnect/release/RConnectMod.swf', 'mods/TDFC/release/TDFCMod.swf',
                       'mods/RealisticVision/release/RealisticVisionMod.swf', 'mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf',
                       'mods/Sandevistan/release/SandevistanMod.swf', 'mods/Sandevistan/release/config.txt')
    protected = {name:sha(installed/name) for name in protected_names}
    receipt = dict(experimental_only=True, phase='ordinary-startup-no-driver', run=run_id, complete=False,
                   script_sha256=sha(__file__), manual_manifest_sha256=sha(manual/'manual-input.json'),
                   candidate_sha256=built['candidate_sha256'], source_id=built['source_id'],
                   protected_before=protected, roles={},
                   limitation='Only ordinary loading; no human mouse, IME, saves or gameplay are exercised.')
    processes, streams, launches = [], [], []
    for role in ('host', 'join'):
        directory = out/role
        shutil.copytree(manual/'game', directory)
        verify_files(directory, prepared['files'])
        appid = 'pfe-modsettings-rconnect-b-startup-'+role+'-'+run_id
        storage = Path(os.environ['APPDATA'])/appid/'Local Store'
        if storage.exists():
            raise FileExistsError('Unique startup profile required')
        descriptor = directory/'startup-test.xml'
        descriptor.write_text('<?xml version="1.0" encoding="utf-8"?>'
            '<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id>'
            '<versionNumber>1.0</versionNumber><filename>RConnect B ordinary startup '+role+'</filename>'
            '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height>'
            '</initialWindow></application>', encoding='utf-8')
        receipt['roles'][role] = dict(appid=appid, files=prepared['files'], config=prepared['config'],
            config_sha256=sha(directory/'mods/Rconnect/release/config.txt'), descriptor_sha256=sha(descriptor))
        launches.append((role, directory, descriptor, storage/'RConnect-B.log'))
    save(out/'run.json', receipt)
    try:
        for role, directory, descriptor, log in launches:
            stream = (out/(role+'.stdout.log')).open('x', encoding='utf-8'); streams.append(stream)
            command = [str(directory/'adl64.exe'), '-runtime', str(directory/'runtimes/air/win64'), str(descriptor)]
            process = subprocess.Popen(command, cwd=directory, stdout=stream, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            processes.append(process)
            receipt['roles'][role].update(pid=process.pid, command=command)
            save(out/'run.json', receipt)
            print(dict(role=role, pid=process.pid, appid=receipt['roles'][role]['appid']), flush=True)
        deadline = time.monotonic()+args.seconds
        while time.monotonic() < deadline:
            if any(process.poll() is not None for process in processes):
                raise RuntimeError('An owned AIR instance exited during ordinary startup')
            if any(any(e['kind'] in ('error', 'FATAL') for e in records(log)) for _, _, _, log in launches):
                raise RuntimeError('Ordinary startup reported a runtime error')
            time.sleep(1)
        receipt['complete'] = True
    except Exception as error:
        receipt['error'] = str(error)
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=8)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=8)
        for stream in streams: stream.close()
        for role, directory, descriptor, log in launches:
            if log.is_file(): shutil.copy2(log, out/(role+'.log'))
            events = records(log)
            boot = [e for e in events if e['kind'] == 'boot']
            stdout = (out/(role+'.stdout.log')).read_text(encoding='utf-8', errors='replace') if (out/(role+'.stdout.log')).is_file() else ''
            checks = dict(correct_build=bool(boot) and boot[0]['data'].get('source') == built['source_id'],
                          offline_menu=bool(boot) and boot[0]['data'].get('role') == '',
                          no_test_driver=not any(e['kind'] in ('native-new-game', 'PASS', 'FAIL', 'DONE', 'listening', 'joined') for e in events),
                          no_runtime_error=not any(e['kind'] in ('error', 'FATAL') for e in events),
                          loader_succeeded='ModLoader[err_' not in stdout and 'Error #' not in stdout
                              and all('ModLoader[ok_'+name+']' in stdout for name in
                                      ('RConnectMod', 'SandevistanMod', 'TDFCMod', 'MoreSkillsWeaponsMod', 'RealisticVisionMod')))
            receipt['roles'][role].update(checks=checks, passed=sum(checks.values()), failed=sum(not ok for ok in checks.values()))
            try:
                verify_files(directory, prepared['files'])
                if sha(descriptor) != receipt['roles'][role]['descriptor_sha256']:
                    raise ValueError('Startup descriptor changed')
                receipt['roles'][role]['runtime_unchanged'] = True
            except Exception as error:
                receipt['roles'][role].update(runtime_unchanged=False, runtime_error=str(error))
        receipt['protected_after'] = {name:sha(installed/name) for name in protected_names}
        receipt['installation_unchanged'] = receipt['protected_after'] == protected
        receipt['owned_processes_exited'] = all(process.poll() is not None for process in processes)
        receipt['process_exit_codes'] = [dict(pid=process.pid, code=process.poll()) for process in processes]
        save(out/'run.json', receipt)
    ok = receipt['complete'] and receipt['installation_unchanged'] and receipt['owned_processes_exited']
    ok = ok and all(r['failed'] == 0 and r['runtime_unchanged'] for r in receipt['roles'].values())
    print(dict(ok=ok, error=receipt.get('error'), path=str(out),
               roles={role:r['checks'] for role, r in receipt['roles'].items()}), flush=True)
    raise SystemExit(0 if ok else 1)


if __name__ == '__main__':
    main()
