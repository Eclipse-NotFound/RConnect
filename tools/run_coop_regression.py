"""Unique AIR ids and independent game copies; no installed SWF/save mutations.
Only terminates the processes created by this invocation. Uses fresh characters
unless explicit read-only save templates are supplied for an isolated replay.
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
import time
import uuid
from validation.native_runtime_assets import native_runtime_files, asset_hashes
ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT.parents[1]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--game-root',type=Path,default=GAME)
    ap.add_argument('--seconds',type=int,default=115)
    ap.add_argument('--keep-copies', action='store_true')
    ap.add_argument('--with-vision', action='store_true', help='Load the installed RealisticVision SWF in isolated copies')
    ap.add_argument('--vision-candidate',type=Path,help='Load this optional RV candidate instead of the installed SWF')
    ap.add_argument('--smoke', action='store_true', help='Validate a production candidate without test classes')
    ap.add_argument('--presentation', action='store_true', help='Validate the dedicated dark-room rendering test document')
    ap.add_argument('--effects', action='store_true', help='Validate native weapon/death and terrain changes over TCP')
    ap.add_argument('--effects-driver',type=Path,help='Directory containing an external EffectsDriver and EffectsHarness for exact production-byte tests')
    ap.add_argument('--land', default='', help='Host travels to this real mission before a scenario starts')
    ap.add_argument('--all-mods', action='store_true', help='Load all installed manifest modules in the isolated scenario')
    ap.add_argument('--responsive', action='store_true', help='Use the same process-local HighQoS policy as Start-Coop.bat')
    ap.add_argument('--host-save-template',type=Path,help='Copy this slot-zero SOL into isolated slot nine; never modify the source')
    ap.add_argument('--join-save-template',type=Path,help='Copy this slot-zero SOL into isolated slot nine; never modify the source')
    ap.add_argument('--connect-after-load',action='store_true',help='External scenario driver loads isolated saves before starting TCP')
    ap.add_argument('--host-vision-config-template',type=Path,help='Read-only RV settings copied into unique host storage')
    ap.add_argument('--join-vision-config-template',type=Path,help='Read-only RV settings copied into unique join storage')
    ap.add_argument('--expected-version',default=re.search(r'VERSION:String\s*=\s*"([^"]+)"',
                    (ROOT/'src'/'RConnectMod.as').read_text(encoding='utf-8')).group(1))
    args=ap.parse_args()
    if args.all_mods and not (args.presentation or args.effects or args.smoke): ap.error('--all-mods requires --presentation, --effects or --smoke')
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
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
    procs=[]; artifacts=[]; inputs={}
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
    release=frozen/'mods'/'Rconnect'/'release'; release.mkdir(parents=True)
    shutil.copy2(candidate,release/'RConnectMod.swf')
    if args.effects_driver:
        assert json.loads((args.effects_driver/'driver-input.json').read_text())['candidate_sha256']==candidate_hash, 'External driver was built for a different candidate'
        driver_dir=frozen/'tests';driver_dir.mkdir()
        shutil.copy2(candidate,driver_dir/'RConnectProduction.swf')
        shutil.copy2(args.effects_driver/'EffectsDriver.swf',driver_dir/'EffectsDriver.swf')
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
            for filename in (entry+'.swf','config.txt','config.json'):
                path=source/filename
                if name.lower()=='realisticvision' and filename==entry+'.swf' and args.vision_candidate:
                    path=args.vision_candidate.resolve()
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
        for role in ('host','join'):
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
                inputs[role]['harness']=hashlib.sha256((release/'RConnectMod.swf').read_bytes()).hexdigest()
            if args.with_vision:
                vision=folder/'mods'/'RealisticVision'/'release'
                inputs[role]['vision']=hashlib.sha256((vision/'RealisticVisionMod.swf').read_bytes()).hexdigest()
            if args.all_mods:
                inputs[role]['modules']={str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in (folder/'mods').glob('*/release/*.swf')}
            cfg=dict(nickname=role,hostIp='127.0.0.1',port=port,tickMs=50,
                     autoRole=role,autoGame='1',autoFollow='1',freezeAI='1',
                     worldInject='1',ghostCombat='1',autoHeal='1')
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
<initialWindow><content>pfe.swf</content><visible>false</visible><renderMode>direct</renderMode></initialWindow>
</application>''',encoding='utf-8')
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
                                  if p.is_file() and p.suffix.lower() in ('.txt','.json'))
            for config_path in config_paths:
                relative=config_path.relative_to(folder).as_posix()
                payload=config_path.read_bytes()
                preserved=output/'configuration'/role/relative
                preserved.parent.mkdir(parents=True,exist_ok=True);preserved.write_bytes(payload)
                configuration_files[role][relative]=hashlib.sha256(payload).hexdigest()
            descriptors[role]=hashlib.sha256(desc.read_bytes()).hexdigest()
            artifacts.append((role,storage/'RConnect.log'))
            launches.append((role,folder,desc,storage,appid))
        # Both role inputs and configuration bytes exist before either AIR
        # instance starts. Keep configuration evidence after runtime cleanup.
        (output/'input.json').write_text(json.dumps(dict(candidate_sha256=candidate_hash,inputs=inputs,
            configuration_files=configuration_files,descriptors=descriptors,
            save_templates=save_inputs,vision_config_templates=vision_inputs),indent=2))
        for role,folder,desc,storage,appid in launches:
            stdout=(output/(role+'.stdout.log')).open('w',encoding='utf-8')
            proc=subprocess.Popen([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)],
                       cwd=folder,stdout=stdout,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            procs.append(proc)
            if args.responsive:
                policy=subprocess.run(['powershell.exe','-NoLogo','-NoProfile','-File',str(folder/'tools/keep_test_responsive.ps1'),
                    '-OwnedProcessId',str(proc.pid),'-Descriptor',str(desc)],capture_output=True,text=True,check=True)
                status=json.loads(policy.stdout.strip())
                assert status['pid']==proc.pid and status['control']&1 and not status['state']&1
                (output/(role+'.process-policy.json')).write_text(json.dumps(status,indent=2))
            print(json.dumps(dict(role=role,pid=proc.pid,appid=appid,log=str(storage/'RConnect.log'))),flush=True)
            time.sleep(15 if role=='host' else 0)
        (output/'run.json').write_text(json.dumps(dict(port=port,pids=[p.pid for p in procs],
            candidate=str(args.candidate.resolve()),sha256=candidate_hash,inputs=inputs,save_templates=save_inputs,
            vision_config_templates=vision_inputs,configuration_files=configuration_files,descriptors=descriptors,
            input_manifest_sha256=hashlib.sha256((output/'input.json').read_bytes()).hexdigest()),indent=2))
        print('OUTPUT '+str(output),flush=True)
        deadline=time.monotonic()+args.seconds
        while time.monotonic()<deadline:
            complete=True
            for role,path in artifacts:
                content=path.read_text(encoding='utf-8',errors='replace') if path.exists() else ''
                if args.effects: complete=complete and 'COOP EFFECTS DONE' in content
                elif args.presentation: complete=complete and 'COOP PRESENTATION DONE' in content
                elif args.smoke: complete=complete and ('v'+args.expected_version+' initialized') in content and 'tick 200' in content
                else: complete=complete and 'COOP NETWORK DONE' in content and 'COOP LMG NETWORK DONE' in content and (role!='host' or ('COOP COMBAT DONE' in content and 'COOP APPEARANCE DAMAGE DONE' in content))
            if complete: break
            time.sleep(2)
    finally:
        for p in procs:
            if p.poll() is None:
                p.terminate()
                try: p.wait(timeout=10)
                except subprocess.TimeoutExpired: p.kill(); p.wait()
        for role,path in artifacts:
            if path.exists(): shutil.copy2(path,output/(role+'.log'))
            vision_log=path.parent/'RVision.log'
            if vision_log.exists(): shutil.copy2(vision_log,output/(role+'-vision.log'))
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
    ok=inputs.get('host')==inputs.get('join')
    for role,_ in artifacts:
        path=output/(role+'.log')
        content=path.read_text(encoding='utf-8',errors='replace') if path.exists() else ''
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
    print('RESULT '+('PASS' if ok else 'FAIL'),flush=True)
    raise SystemExit(0 if ok else 1)
if __name__=='__main__': main()
