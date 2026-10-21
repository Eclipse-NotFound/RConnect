from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))
"""Unique AIR ids and independent game copies; no installed SWF/save mutations.
Only terminates the processes created by this invocation. Uses fresh characters
unless explicit read-only save templates are supplied for an isolated replay.
To cancel voluntarily, create cancel-request.json in the printed QUEUED_OUTPUT directory
(optionally {"reason": "..."}). Its presence is sufficient, even if JSON is
incomplete. A queued request is checked immediately after registration is acquired;
the shared registry wait itself is unchanged. Cancellation exits 130, never passes,
and preserves cancel-result.json plus logs after normal owned-process cleanup.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time
import uuid
from validation.native_runtime_assets import native_runtime_files, asset_hashes
from validation.runtime_memory import snapshot as memory_snapshot
from validation.air_test_inventory import air_processes
ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]

class RunCancelled(Exception):
    def __init__(self, evidence):
        self.evidence=evidence
        super().__init__('Cancellation requested at '+evidence['phase'])


def check_cancel_requested(output,phase):
    marker=output/'cancel-request.json'
    if not marker.exists():return
    evidence=dict(cancelled=True,passed=False,phase=phase,request=str(marker),
                  observed_utc_ms=int(time.time()*1000))
    try:
        raw=marker.read_bytes()
        evidence['request_sha256']=hashlib.sha256(raw).hexdigest()
        request=json.loads(raw.decode('utf-8-sig'))
        if isinstance(request,dict) and isinstance(request.get('reason'),str):
            evidence['reason']=request['reason'][:2048]
    except (OSError,ValueError):
        # A writer may still be filling the file. Never turn a partial request
        # into permission to launch another instance.
        evidence['request_note']='Marker present; content unreadable or incomplete'
    raise RunCancelled(evidence)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--game-root',type=Path,default=GAME)
    ap.add_argument('--game-candidate',type=Path,help='Diagnostic-only game SWF copied into isolated instances; installation stays read-only')
    ap.add_argument('--seconds',type=int,default=115)
    ap.add_argument('--port',type=int,default=0,help='Optional isolated test listener port; zero asks the OS')
    ap.add_argument('--solo',action='store_true',help='Launch one offline instance; never host or connect')
    ap.add_argument('--keep-copies', action='store_true')
    ap.add_argument('--with-vision', action='store_true', help='Load the installed RealisticVision SWF in isolated copies')
    ap.add_argument('--vision-candidate',type=Path,help='Load this optional RV candidate instead of the installed SWF')
    ap.add_argument('--wallblend-candidate',type=Path,help='Optional verified WallBlend comparison candidate, isolated copies only')
    ap.add_argument('--msw-candidate',type=Path,help='Optional MSW compatibility candidate, copied only into isolated instances')
    ap.add_argument('--fa-candidate',type=Path,help='Optional FirearmAttachments compatibility candidate, copied only into isolated instances')
    ap.add_argument('--smoke', action='store_true', help='Validate a production candidate without test classes')
    ap.add_argument('--vision-smoke-version',help='Additionally require this RV startup version and its tick-181 heartbeat')
    ap.add_argument('--presentation', action='store_true', help='Validate the dedicated dark-room rendering test document')
    ap.add_argument('--effects', action='store_true', help='Validate native weapon/death and terrain changes over TCP')
    ap.add_argument('--effects-driver',type=Path,help='Directory containing an external EffectsDriver and EffectsHarness for exact production-byte tests')
    ap.add_argument('--land', default='', help='Host travels to this real mission before a scenario starts')
    ap.add_argument('--all-mods', action='store_true', help='Load all installed manifest modules in the isolated scenario')
    ap.add_argument('--responsive', action='store_true', help='Use the same process-local HighQoS policy as Start-Coop.bat')
    ap.add_argument('--visible-windows', action='store_true', help='Render visible native game windows, as in normal play')
    ap.add_argument('--private-desktop', action='store_true', help='Keep the entire owned AIR process on a private Windows desktop')
    ap.add_argument('--wait-host-world', action='store_true', help='Complete host bootstrap before starting the peer; no scenario travel is timed here')
    ap.add_argument('--require-exclusive-air',action='store_true',help='Reject overlapping AIR processes; never stop a process owned by another task')
    ap.add_argument('--registry-wait',type=float,default=0,help='Seconds to wait for shared test registration; zero defers without starting AIR')
    ap.add_argument('--defer-visible', action='store_true', help='External effects harness shows the window after native UI initialization; avoids the native pre-PipBuck resize race')
    ap.add_argument('--host-save-template',type=Path,help='Copy this slot-zero SOL into isolated slot nine; never modify the source')
    ap.add_argument('--join-save-template',type=Path,help='Copy this slot-zero SOL into isolated slot nine; never modify the source')
    ap.add_argument('--connect-after-load',action='store_true',help='External scenario driver loads isolated saves before starting TCP')
    ap.add_argument('--host-vision-config-template',type=Path,help='Read-only RV settings copied into unique host storage')
    ap.add_argument('--join-vision-config-template',type=Path,help='Read-only RV settings copied into unique join storage')
    ap.add_argument('--expected-version',default=re.search(r'VERSION:String\s*=\s*"([^"]+)"',
                    (ROOT/'src'/'RConnectMod.as').read_text(encoding='utf-8')).group(1))
    args=ap.parse_args()
    if args.private_desktop and args.visible_windows:ap.error('Private desktop and visible windows are mutually exclusive')
    if args.solo and (args.connect_after_load or args.join_save_template or args.presentation):
        ap.error('--solo cannot use a join save, deferred connection or paired presentation test')
    roles=('host',) if args.solo else ('host','join')
    if args.all_mods and not (args.presentation or args.effects or args.smoke): ap.error('--all-mods requires --presentation, --effects or --smoke')
    if args.msw_candidate:
        assert args.all_mods and args.msw_candidate.resolve().is_relative_to(ROOT/'build')
    if args.fa_candidate:
        assert args.all_mods and args.fa_candidate.resolve().is_relative_to(ROOT/'build')
    if args.wallblend_candidate:
        assert args.all_mods and args.wallblend_candidate.resolve().is_relative_to(ROOT/'build')
    if args.vision_smoke_version and not (args.smoke and args.all_mods): ap.error('--vision-smoke-version requires normal all-mod smoke')
    if args.connect_after_load and (not args.effects_driver or not args.host_save_template or not args.join_save_template):
        ap.error('--connect-after-load requires an external driver and both isolated save templates')
    if args.presentation and not args.land: args.land='random_mane'
    if args.vision_candidate: args.with_vision=True
    if (args.host_vision_config_template or args.join_vision_config_template) and not (args.all_mods or args.with_vision):
        ap.error('Vision config templates require --all-mods or --with-vision')
    game=args.game_root.resolve()
    token=uuid.uuid4().hex[:10]
    output=ROOT/'build'/'cooperation'/token
    output.mkdir(parents=True)
    # Publish before waiting so a queued invocation can be cancelled by marker.
    print('QUEUED_OUTPUT '+str(output),flush=True)
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    cancelled=False
    with Registration(owner='RConnect / 房间与合作回归',purpose=args.expected_version+' '+('solo' if args.solo else 'host/join'),
                      run_dir=output,evidence=output/'registry-result.json',wait=args.registry_wait) as record:
        try:
            ok=run_registered(args,ap,output,record)
        except RunCancelled as error:
            ok=False;cancelled=True
            (output/'cancel-result.json').write_text(json.dumps(error.evidence,ensure_ascii=False,indent=2),encoding='utf-8')
            print('RESULT CANCELLED: '+str(error),flush=True)
        record.outcome='interrupted' if cancelled else ('passed' if ok else 'failed')
        record.note='自愿取消；自有实例已清理，原始日志保留，未判定通过' if cancelled else '运行器断言及模组日志检查'+('通过；专项范围见结果' if ok else '未通过，原始日志保留')
        (output/'registry-result.json').write_text(json.dumps(dict(id=record.id,passed=ok,cancelled=cancelled,note=record.note),ensure_ascii=False,indent=2),encoding='utf-8')
    raise SystemExit(130 if cancelled else (0 if ok else 1))

def run_registered(args,ap,output,record):
    # First operation after Registration.__enter__: a queued marker cannot be
    # overlooked during memory checks, input freezing or launch preparation.
    check_cancel_requested(output,'registration acquired')
    game=args.game_root.resolve();token=output.name
    roles=('host',) if args.solo else ('host','join')
    memory_before=memory_snapshot()
    (output/'memory-before.json').write_text(json.dumps(memory_before,indent=2))
    if args.require_exclusive_air:
        foreign=air_processes()
        (output/'air-before.json').write_text(json.dumps(foreign),encoding='utf-8')
        if foreign:raise SystemExit('Other AIR processes exist; timing run not started: '+str(foreign))
    minimum_start_gib=3 if args.solo else 6
    if memory_before['free_commit_bytes']<minimum_start_gib*1024**3:
        raise SystemExit('Less than '+str(minimum_start_gib)+' GiB commit headroom; no AIR instance started')
    memory_rows=[memory_before];memory_stopped=False;isolation_stopped=False
    memory_reader_hash=hashlib.sha256((ROOT/'tools/validation/runtime_memory.py').read_bytes()).hexdigest()
    def record_memory():
        nonlocal memory_stopped,isolation_stopped
        row=memory_snapshot();memory_rows.append(row)
        if args.require_exclusive_air:
            own={p.pid for p in procs}
            row['foreign_air']=[p for p in air_processes() if p['pid'] not in own]
            if row['foreign_air']:isolation_stopped=True
        if row['free_commit_bytes']<512*1024**2:
            memory_stopped=True
        return not memory_stopped and not isolation_stopped
    # Freeze one binary for both roles; rebuilding the candidate while host boots
    # must not silently give the joiner a different version.
    candidate=output/'candidate.swf'
    candidate.write_bytes(args.candidate.read_bytes())
    candidate_hash=hashlib.sha256(candidate.read_bytes()).hexdigest()
    save_templates={};save_inputs={}
    for role,path in [('host',args.host_save_template),('join',args.join_save_template)]:
        if path is None: continue
        data=path.read_bytes()
        # Native newGame bootstrap clears slot zero before comLoad is ready.
        # A separate slot preserves the replay input until native loadGame.
        if data[:2]!=b'\x00\xbf' or data[6:10]!=b'TCSO' or data[16:26]!=b'\x00\x08PFEgame0':
            ap.error(role+' save template must be a native PFEgame0 SOL')
        save_templates[role]=data[:18]+b'PFEgame9'+data[26:]
        save_inputs[role]={'source_sha256':hashlib.sha256(data).hexdigest(),
                          'isolated_sha256':hashlib.sha256(save_templates[role]).hexdigest(),'slot':9}
    vision_templates={role:path.read_bytes() for role,path in [
        ('host',args.host_vision_config_template),('join',args.join_vision_config_template)] if path is not None}
    vision_inputs={role:hashlib.sha256(data).hexdigest() for role,data in vision_templates.items()}
    if not 0 <= args.port <= 65535:
        ap.error('port must be between 0 and 65535')
    with socket.socket() as probe:
        # AIR HostServer binds all interfaces. Probe the same address scope.
        if hasattr(socket,'SO_EXCLUSIVEADDRUSE'):
            probe.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
        probe.bind(('0.0.0.0',args.port)); port=probe.getsockname()[1]
    procs=[]; stdout_files=[]; artifacts=[]; inputs={}
    # Snapshot all shared inputs once before either process starts. Other mod
    # tasks may deploy while this pair is running.
    # Preserve native music playback too. A missing-Music diagnostic captured
    # a 485 ms Sound.play stall; the isolated copy must include real assets.
    assets=native_runtime_files(game)
    asset_names=[p.relative_to(game).as_posix() for p in assets]
    required_bytes=sum(p.stat().st_size for p in assets)*3+32*1024*1024
    if shutil.disk_usage(output).free < required_bytes:
        raise SystemExit('Insufficient space for isolated test copies; no AIR instance started')
    frozen=output/'frozen'; frozen.mkdir()
    if args.responsive:
        (frozen/'tools').mkdir()
        for name in ('RConnect.Process.ps1','keep_test_responsive.ps1'):
            shutil.copy2(ROOT/'tools'/name,frozen/'tools'/name)
    for source in assets:
        destination=frozen/source.relative_to(game)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,destination)
    if args.game_candidate:
        patch=args.game_candidate.resolve()
        assert patch.is_relative_to(ROOT/'build') and patch.name=='pfe.swf'
        shutil.copy2(patch,frozen/'pfe.swf')
    release=frozen/'mods'/'Rconnect'/'release'; release.mkdir(parents=True)
    shutil.copy2(candidate,release/'RConnectMod.swf')
    if args.effects_driver:
        assert json.loads((args.effects_driver/'driver-input.json').read_text())['candidate_sha256']==candidate_hash, 'External driver was built for a different candidate'
        driver_dir=frozen/'tests';driver_dir.mkdir()
        shutil.copy2(candidate,driver_dir/'RConnectProduction.swf')
        shutil.copy2(args.effects_driver/'EffectsDriver.swf',driver_dir/'EffectsDriver.swf')
        gate_intent=json.loads((args.effects_driver/'seed-gate-intent.json').read_text(encoding='utf-8'))
        assert gate_intent['schema']==1 and type(gate_intent['expectSeedTicket']) is bool and gate_intent['candidateSha']==candidate_hash
        shutil.copy2(args.effects_driver/'seed-gate-intent.json',driver_dir/'seed-gate-intent.json')
        shutil.copy2(args.effects_driver/'EffectsHarness.swf',release/'RConnectMod.swf')
    manifest=game/'mods'/'loader-manifest.txt'
    allowed={'rconnect'}
    if args.with_vision: allowed.add('realisticvision')
    if manifest.exists():
        lines=[line for line in manifest.read_text(encoding='utf-8-sig').splitlines()
               if (args.all_mods and '|' in line and not line.startswith('#'))
               or line.split('|')[0].strip().lower() in allowed]
        for line in lines:
            name,entry=line.split('|')[0:2]
            if name.lower()=='rconnect': continue
            destination=frozen/'mods'/name/'release';destination.mkdir(parents=True,exist_ok=True)
            source=game/'mods'/name/'release'
            filenames=[entry+'.swf','config.txt','config.json']
            if name.lower()=='continuousscene':
                # Required by register() even when native map merging is off.
                # Without it the module silently fails before attaching its API.
                assert (source/'scene.xml').is_file(), 'ContinuousScene scene.xml is missing'
                filenames.append('scene.xml')
            for filename in filenames:
                path=source/filename
                if name.lower()=='realisticvision' and filename==entry+'.swf' and args.vision_candidate:
                    path=args.vision_candidate.resolve()
                if name.lower()=='moreskills&weapons' and filename==entry+'.swf' and args.msw_candidate:
                    path=args.msw_candidate.resolve()
                if name.lower()=='firearmattachments' and filename==entry+'.swf' and args.fa_candidate:
                    path=args.fa_candidate.resolve()
                if name.lower()=='wallblend' and filename==entry+'.swf' and args.wallblend_candidate:
                    path=args.wallblend_candidate.resolve()
                if path.exists(): shutil.copy2(path,destination/filename)
        (frozen/'mods'/'loader-manifest.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    elif args.with_vision:
        vision=frozen/'mods'/'RealisticVision'/'release';vision.mkdir(parents=True)
        for name in ('RealisticVisionMod.swf','config.txt'):
            source=game/'mods'/'RealisticVision'/'release'/name
            if name=='RealisticVisionMod.swf' and args.vision_candidate: source=args.vision_candidate.resolve()
            if source.exists(): shutil.copy2(source,vision/name)
    configuration_files={};descriptors={};launches=[]
    try:
        for role in roles:
            check_cancel_requested(output,'preparing '+role)
            folder=output/role; shutil.copytree(frozen,folder)
            release=folder/'mods'/'Rconnect'/'release'
            inputs[role]={'game':hashlib.sha256((folder/'pfe.swf').read_bytes()).hexdigest()}
            inputs[role]['assets']=asset_hashes(folder,asset_names)
            if args.responsive:
                inputs[role]['process_policy']={name:hashlib.sha256((folder/'tools'/name).read_bytes()).hexdigest()
                    for name in ('RConnect.Process.ps1','keep_test_responsive.ps1')}
            if args.effects_driver:
                inputs[role]['production']=hashlib.sha256((folder/'tests/RConnectProduction.swf').read_bytes()).hexdigest()
                inputs[role]['driver']=hashlib.sha256((folder/'tests/EffectsDriver.swf').read_bytes()).hexdigest()
                inputs[role]['seed_gate_intent']=hashlib.sha256((folder/'tests/seed-gate-intent.json').read_bytes()).hexdigest()
                inputs[role]['harness']=hashlib.sha256((release/'RConnectMod.swf').read_bytes()).hexdigest()
            if args.with_vision:
                vision=folder/'mods'/'RealisticVision'/'release'
                inputs[role]['vision']=hashlib.sha256((vision/'RealisticVisionMod.swf').read_bytes()).hexdigest()
            if args.all_mods:
                inputs[role]['modules']={str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in (folder/'mods').glob('*/release/*.swf')}
                inputs[role]['mod_assets']={p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                                           for p in (folder/'mods').glob('*/release/*.xml')}
            cfg=dict(nickname=role,hostIp='127.0.0.1',port=port,tickMs=50,
                     autoRole=role,autoGame='1',autoFollow='1',freezeAI='1',
                     worldInject='1',ghostCombat='1',autoHeal='1')
            if args.solo: cfg.update(autoRole='',autoFollow='0',freezeAI='0')
            if role in save_templates: cfg.update(autoGame='',autoLoadSave='9',autoHeal='0')
            elif role=='host' and args.land: cfg['autoTravelLand']=args.land
            if args.connect_after_load:
                # Negative slots disable the production auto-loader. The
                # external scenario recognizes -9 and owns native read/connect
                # sequencing; no new production config fields are required.
                cfg.update(autoRole='',autoGame='1',autoLoadSave='-9')
                if role=='host' and args.land: cfg['autoTravelLand']=args.land
            (release/'config.txt').write_text(json.dumps(cfg),encoding='utf-8')
            # This established integration namespace opts out of MSW's menu
            # auto-driver. The RConnect scenario alone owns test world creation.
            appid=('pfe-modsettings-rconnect-coop-' if args.all_mods else 'pfe-rconnect-coop-')+role+'-'+token
            desc=folder/'coop.xml'
            desc.write_text('''<?xml version="1.0" encoding="utf-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
<id>'''+appid+'''</id><versionNumber>1.0</versionNumber><filename>RConnectTest</filename>
<initialWindow><content>pfe.swf</content><visible>'''+str(args.visible_windows and not args.defer_visible).lower()+'''</visible><renderMode>direct</renderMode></initialWindow>
</application>''',encoding='utf-8')
            if args.defer_visible:
                assert args.effects and (args.visible_windows or args.private_desktop), 'Deferred visibility requires the isolated effects harness and an owned display'
                (folder/'tests/show-window-when-ready.flag').write_text('native UI ready',encoding='utf-8')
            storage=Path(os.environ['APPDATA'])/appid/'Local Store'
            if role in vision_templates:
                settings=storage/'RealisticVision_config.txt'
                settings.parent.mkdir(parents=True,exist_ok=True)
                assert not settings.exists(), 'Unique test storage must not overwrite existing settings'
                settings.write_bytes(vision_templates[role])
            if role in save_templates:
                template=storage/'#SharedObjects'/'pfe.swf'/'PFEgame9.sol'
                template.parent.mkdir(parents=True,exist_ok=True)
                assert not template.exists(), 'Unique test storage must not overwrite an existing save'
                template.write_bytes(save_templates[role])
            configuration_files[role]={}
            config_paths = sorted(p for p in (folder/'mods').glob('*/release/*')
                                  if p.is_file() and p.suffix.lower() in ('.txt','.json','.xml'))
            for config_path in config_paths:
                relative=config_path.relative_to(folder).as_posix()
                payload=config_path.read_bytes()
                preserved=output/'configuration'/role/relative
                preserved.parent.mkdir(parents=True,exist_ok=True);preserved.write_bytes(payload)
                configuration_files[role][relative]=hashlib.sha256(payload).hexdigest()
            descriptors[role]=hashlib.sha256(desc.read_bytes()).hexdigest()
            preserved_descriptor=output/'descriptors'/(role+'.xml')
            preserved_descriptor.parent.mkdir(parents=True,exist_ok=True)
            preserved_descriptor.write_bytes(desc.read_bytes())
            artifacts.append((role,storage/'RConnect.log'))
            launches.append((role,folder,desc,storage,appid))
        # Both role inputs and configuration bytes exist before either AIR
        # instance starts. Keep configuration evidence after runtime cleanup.
        (output/'input.json').write_text(json.dumps(dict(candidate_sha256=candidate_hash,inputs=inputs,
            configuration_files=configuration_files,descriptors=descriptors,visible_windows=args.visible_windows,defer_visible=args.defer_visible,solo=args.solo,
            save_templates=save_inputs,vision_config_templates=vision_inputs,vision_smoke_version=args.vision_smoke_version,
            memory_reader_sha256=memory_reader_hash,minimum_start_gib=minimum_start_gib,private_desktop=args.private_desktop,
            require_exclusive_air=args.require_exclusive_air,air_inventory_sha256=hashlib.sha256((ROOT/'tools/validation/air_test_inventory.py').read_bytes()).hexdigest(),
            desktop_helper_sha256=hashlib.sha256((GAME/'mods/ModLoader/tools/air_test_process.py').read_bytes()).hexdigest() if args.private_desktop else None),indent=2))
        for role,folder,desc,storage,appid in launches:
            check_cancel_requested(output,'before '+role+' launch')
            if not record_memory():break
            stdout=(output/(role+'.stdout.log')).open('w',encoding='utf-8')
            stdout_files.append(stdout)
            record.before_launch(role+' / '+appid+' / '+str(desc))
            if args.private_desktop:
                sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
                from air_test_process import HiddenProcess
                check_cancel_requested(output,'before '+role+' process creation')
                proc=HiddenProcess([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)],
                       cwd=folder,stdout=stdout,stderr=stdout)
            else:
                check_cancel_requested(output,'before '+role+' process creation')
                proc=subprocess.Popen([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)],
                       cwd=folder,stdout=stdout,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            procs.append(proc)
            record.child(proc.pid)
            if args.responsive:
                policy=subprocess.run(['powershell.exe','-NoLogo','-NoProfile','-File',str(folder/'tools/keep_test_responsive.ps1'),
                    '-OwnedProcessId',str(proc.pid),'-Descriptor',str(desc)],capture_output=True,text=True,check=True)
                status=json.loads(policy.stdout.strip())
                assert status['pid']==proc.pid and status['control']&1 and not status['state']&1
                (output/(role+'.process-policy.json')).write_text(json.dumps(status,indent=2))
            print(json.dumps(dict(role=role,pid=proc.pid,appid=appid,log=str(storage/'RConnect.log'))),flush=True)
            boot_until=time.monotonic()+((180 if args.wait_host_world and not args.solo else 15) if role=='host' else 0)
            while time.monotonic()<boot_until:
                check_cancel_requested(output,'host bootstrap')
                if not record_memory():break
                if args.wait_host_world and not args.solo and role=='host':
                    log_path=storage/'RConnect.log'
                    boot_text=log_path.read_text(encoding='utf-8',errors='replace') if log_path.exists() else ''
                    if re.search(r'RConnectDbg: tick .*world='+re.escape(args.land)+r'/[^\r\n]*t_exit=0[^\r\n]*allStat=1[^\r\n]*onPause=false',boot_text):break
                time.sleep(min(1,max(0,boot_until-time.monotonic())))
        (output/'run.json').write_text(json.dumps(dict(port=port,pids=[p.pid for p in procs],
            candidate=str(args.candidate.resolve()),sha256=candidate_hash,inputs=inputs,save_templates=save_inputs,
            vision_config_templates=vision_inputs,configuration_files=configuration_files,descriptors=descriptors,
            visible_windows=args.visible_windows,defer_visible=args.defer_visible,solo=args.solo,private_desktop=args.private_desktop,wait_host_world=args.wait_host_world,
            vision_smoke_version=args.vision_smoke_version,
            input_manifest_sha256=hashlib.sha256((output/'input.json').read_bytes()).hexdigest()),indent=2))
        print('OUTPUT '+str(output),flush=True)
        deadline=time.monotonic()+args.seconds
        while time.monotonic()<deadline:
            check_cancel_requested(output,'runtime loop')
            if not record_memory():break
            complete=True
            for role,path in artifacts:
                content=path.read_text(encoding='utf-8',errors='replace') if path.exists() else ''
                if args.effects: complete=complete and 'COOP EFFECTS DONE' in content
                elif args.presentation: complete=complete and 'COOP PRESENTATION DONE' in content
                elif args.smoke: complete=complete and ('v'+args.expected_version+' initialized') in content and 'tick 200' in content
                else: complete=complete and 'COOP NETWORK DONE' in content and 'COOP LMG NETWORK DONE' in content and (role!='host' or ('COOP COMBAT DONE' in content and 'COOP APPEARANCE DAMAGE DONE' in content))
                if args.vision_smoke_version:
                    vision_log=path.parent/'RVision.log'
                    vision_text=vision_log.read_text(encoding='utf-8',errors='replace') if vision_log.exists() else ''
                    complete=complete and ('init ok '+args.vision_smoke_version) in vision_text and 'tick 181' in vision_text
            check_cancel_requested(output,'runtime completion')
            if complete: break
            time.sleep(2)
        check_cancel_requested(output,'runtime finished')
    finally:
        for p in procs:
            if p.poll() is None:
                if args.private_desktop:p.kill()
                else:p.terminate()
            # Reap even a child which exited by itself; retain registry ownership
            # until all children are known stopped and desktop handles are closed.
            try: p.wait(timeout=10)
            except subprocess.TimeoutExpired: p.kill(); p.wait()
            if args.private_desktop:p.close()
        for stdout in stdout_files:stdout.close()
        record.child_stopped()
        (output/'memory-timeline.json').write_text(json.dumps(dict(rows=memory_rows,
            stopped_for_pressure=memory_stopped,stopped_for_overlap=isolation_stopped,minimum_commit_bytes=512*1024**2,
            reader_sha256=memory_reader_hash),indent=2))
        for role,path in artifacts:
            if path.exists(): shutil.copy2(path,output/(role+'.log'))
            vision_log=path.parent/'RVision.log'
            if vision_log.exists(): shutil.copy2(vision_log,output/(role+'-vision.log'))
            # Mod initialization errors may be written only to a private log.
            # Preserve every log from this run's unique application storage.
            module_logs=output/'module-logs'/role;module_logs.mkdir(parents=True,exist_ok=True)
            for module_log in path.parent.glob('*.log'):
                shutil.copy2(module_log,module_logs/module_log.name)
            for picture in path.parent.glob('presentation-*.png'):
                shutil.copy2(picture,output/(role+'-'+picture.name))
        if not args.keep_copies:
            for role in ('host','join','frozen'):
                folder=(output/role).resolve()
                assert folder.parent == output.resolve() and folder.name in ('host','join','frozen')
                for attempt in range(6):
                    try:
                        if folder.exists(): shutil.rmtree(folder)
                        break
                    except PermissionError:
                        if attempt==5: print('Retained locked test copy: '+str(folder),flush=True)
                        else: time.sleep(0.5)
    check_cancel_requested(output,'after cleanup')
    ok=(set(inputs)=={'host'}) if args.solo else inputs.get('host')==inputs.get('join')
    ok=ok and not memory_stopped and not isolation_stopped
    if isolation_stopped:print('FAIL another AIR instance overlapped; only owned instances stopped',flush=True)
    if memory_stopped:print('FAIL system commit headroom below 512 MiB; owned AIR instances stopped',flush=True)
    for role,_ in artifacts:
        path=output/(role+'.log')
        content=path.read_text(encoding='utf-8',errors='replace') if path.exists() else ''
        module_errors=[]
        for module_log in (output/'module-logs'/role).glob('*.log'):
            for line in module_log.read_text(encoding='utf-8',errors='replace').splitlines():
                if re.search(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line):
                    module_errors.append(module_log.name+': '+line)
        if args.all_mods and any('ContinuousSceneMod.swf' in n for n in inputs.get(role,{}).get('modules',{})):
            scene_log=output/'module-logs'/role/'ContinuousScene.log'
            scene_text=scene_log.read_text(encoding='utf-8',errors='replace') if scene_log.exists() else ''
            if '[ContinuousScene] registered ' not in scene_text:module_errors.append('ContinuousScene did not finish initialization')
        if module_errors:
            ok=False;print(role+' module errors: '+json.dumps(list(dict.fromkeys(module_errors)),ensure_ascii=False),flush=True)
        if args.vision_smoke_version:
            vision_log=output/(role+'-vision.log')
            vision_text=vision_log.read_text(encoding='utf-8',errors='replace') if vision_log.exists() else ''
            vision_ok=('init ok '+args.vision_smoke_version) in vision_text and 'tick 181' in vision_text and 'ERROR' not in vision_text and 'error:' not in vision_text
            ok=ok and vision_ok
            print(role+' RV smoke '+('PASS' if vision_ok else 'FAIL'),flush=True)
        bad=list(dict.fromkeys(s for s in content.splitlines() if 'COOP FAIL' in s or 'game error dialog' in s or 'RConnectRoom: ERROR' in s or 'handoff timed out' in s
            or 'RConnectNavigation: failed' in s or 'RConnectMap: failed' in s or 'RConnectRoomTrace: failed' in s
            or 'RConnectPause: failed' in s or 'RConnectGrip: failed' in s or 'RConnectPeerGrip: failed' in s
            or (' failed:' in s and ('RConnectGame: unit effects ' in s or 'RConnectGame: presentation ' in s or 'RConnectGame: projectile visual ' in s))))
        if args.presentation or args.effects:
            ok=ok and not bad and ('COOP EFFECTS DONE' if args.effects else 'COOP PRESENTATION DONE') in content
            if role=='join': ok=ok and 'welcome id=' in content and 'unitsync matched' in content
            print(role+' failures: '+json.dumps(bad,ensure_ascii=False),flush=True)
            for line in content.splitlines():
                if 'COOP ' in line or 'PRESENT sample' in line: print(line,flush=True)
            continue
        if role=='host':
            if args.smoke: ok=ok and ('v'+args.expected_version+' initialized') in content and 'tick 200' in content
            else: ok=ok and 'COOP DONE' in content and 'failed=0' in content and 'COOP ENEMY DONE' in content and 'COOP COMBAT DONE' in content and 'COOP EXPLORATION DONE' in content
        else:
            ok=ok and 'welcome id=' in content and 'unitsync matched' in content
            if args.smoke: ok=ok and ('v'+args.expected_version+' initialized') in content and 'tick 200' in content
        ok=ok and not bad and (args.smoke or ('COOP NETWORK DONE' in content and 'COOP LMG NETWORK DONE' in content and (role!='host' or 'COOP APPEARANCE DAMAGE DONE' in content)))
        print(role+' failures: '+json.dumps(bad,ensure_ascii=False),flush=True)
        for line in content.splitlines():
            if 'COOP ' in line: print(line,flush=True)
    check_cancel_requested(output,'before result')
    print('RESULT '+('PASS' if ok else 'FAIL'),flush=True)
    return ok
if __name__=='__main__': main()
