"""Unique AIR ids and independent game copies; no installed SWF/save mutations.
Only terminates the processes created by this invocation. Uses fresh characters.
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
    ap.add_argument('--all-mods', action='store_true', help='Presentation scenario with all installed manifest modules')
    ap.add_argument('--expected-version',default=re.search(r'VERSION:String\s*=\s*"([^"]+)"',
                    (ROOT/'src'/'RConnectMod.as').read_text(encoding='utf-8')).group(1))
    args=ap.parse_args()
    if args.all_mods and not (args.presentation or args.effects): ap.error('--all-mods requires --presentation or --effects')
    if args.presentation and not args.land: args.land='random_mane'
    if args.vision_candidate: args.with_vision=True
    game=args.game_root.resolve()
    token=uuid.uuid4().hex[:10]
    output=ROOT/'build'/'cooperation'/token
    output.mkdir(parents=True)
    # Freeze one binary for both roles; rebuilding the candidate while host boots
    # must not silently give the joiner a different version.
    candidate=output/'candidate.swf'
    candidate.write_bytes(args.candidate.read_bytes())
    candidate_hash=hashlib.sha256(candidate.read_bytes()).hexdigest()
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
    procs=[]; artifacts=[]; inputs={}
    # Snapshot all shared inputs once before either process starts. Other mod
    # tasks may deploy while this pair is running.
    runtime_swfs={'pfe.swf','sound.swf','sound_unit.swf','sound_weapon.swf',
                  'sprite.swf','sprite1.swf','texture.swf','texture1.swf'}
    assets=[p for p in game.iterdir() if p.is_file() and
            (p.suffix in ('.xml','.cfg') or p.name in runtime_swfs)]
    required_bytes=sum(p.stat().st_size for p in assets)*3+32*1024*1024
    if shutil.disk_usage(output).free < required_bytes:
        raise SystemExit('Insufficient space for isolated test copies; no AIR instance started')
    frozen=output/'frozen'; frozen.mkdir()
    for source in assets:
        shutil.copy2(source,frozen/source.name)
    shutil.copytree(game/'Rooms',frozen/'Rooms')
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
            for filename in (entry+'.swf','config.txt'):
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
    try:
        for role in ('host','join'):
            folder=output/role; shutil.copytree(frozen,folder)
            release=folder/'mods'/'Rconnect'/'release'
            inputs[role]={'game':hashlib.sha256((folder/'pfe.swf').read_bytes()).hexdigest()}
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
            artifacts.append((role,storage/'RConnect.log'))
            stdout=(output/(role+'.stdout.log')).open('w',encoding='utf-8')
            proc=subprocess.Popen([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)],
                       cwd=folder,stdout=stdout,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            procs.append(proc)
            print(json.dumps(dict(role=role,pid=proc.pid,appid=appid,log=str(storage/'RConnect.log'))),flush=True)
            time.sleep(15 if role=='host' else 0)
        (output/'run.json').write_text(json.dumps(dict(port=port,pids=[p.pid for p in procs],
            candidate=str(args.candidate.resolve()),sha256=candidate_hash,inputs=inputs),indent=2))
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
            or (' failed:' in s and ('RConnectGame: unit effects ' in s or 'RConnectGame: presentation ' in s))))
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
