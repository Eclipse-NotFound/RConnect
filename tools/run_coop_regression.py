"""Unique AIR ids and independent game copies; no installed SWF/save mutations.
Only terminates the processes created by this invocation. Uses fresh characters.
"""
import argparse
import hashlib
import json
import os
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
    ap.add_argument('--seconds',type=int,default=115)
    ap.add_argument('--keep-copies', action='store_true')
    ap.add_argument('--smoke', action='store_true', help='Validate a production candidate without test classes')
    args=ap.parse_args()
    token=uuid.uuid4().hex[:10]
    output=ROOT/'build'/'cooperation'/token
    output.mkdir(parents=True)
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
    procs=[]; artifacts=[]
    try:
        for role in ('host','join'):
            folder=output/role; folder.mkdir()
            for source in GAME.iterdir():
                if source.is_file() and source.suffix in ('.swf','.xml','.cfg'):
                    shutil.copy2(source,folder/source.name)
            shutil.copytree(GAME/'Rooms',folder/'Rooms')
            release=folder/'mods'/'Rconnect'/'release'; release.mkdir(parents=True)
            shutil.copy2(args.candidate,release/'RConnectMod.swf')
            cfg=dict(nickname=role,hostIp='127.0.0.1',port=port,tickMs=50,
                     autoRole=role,autoGame='1',autoFollow='1',freezeAI='1',
                     worldInject='1',ghostCombat='1',autoHeal='1')
            (release/'config.txt').write_text(json.dumps(cfg),encoding='utf-8')
            appid='pfe-rconnect-coop-'+role+'-'+token
            desc=folder/'coop.xml'
            desc.write_text('''<?xml version="1.0" encoding="utf-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
<id>'''+appid+'''</id><versionNumber>1.0</versionNumber><filename>RConnectTest</filename>
<initialWindow><content>pfe.swf</content><visible>false</visible><renderMode>direct</renderMode></initialWindow>
</application>''',encoding='utf-8')
            storage=Path(os.environ['APPDATA'])/appid/'Local Store'
            artifacts.append((role,storage/'RConnect.log'))
            stdout=(output/(role+'.stdout.log')).open('w',encoding='utf-8')
            proc=subprocess.Popen([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc)],
                       cwd=folder,stdout=stdout,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            procs.append(proc)
            print(json.dumps(dict(role=role,pid=proc.pid,appid=appid,log=str(storage/'RConnect.log'))),flush=True)
            time.sleep(15 if role=='host' else 0)
        (output/'run.json').write_text(json.dumps(dict(port=port,pids=[p.pid for p in procs],
            candidate=str(args.candidate.resolve()),sha256=hashlib.sha256(args.candidate.read_bytes()).hexdigest()),indent=2))
        print('OUTPUT '+str(output),flush=True)
        time.sleep(args.seconds)
    finally:
        for p in procs:
            if p.poll() is None:
                p.terminate()
                try: p.wait(timeout=10)
                except subprocess.TimeoutExpired: p.kill(); p.wait()
        for role,path in artifacts:
            if path.exists(): shutil.copy2(path,output/(role+'.log'))
        if not args.keep_copies:
            for role in ('host','join'):
                folder=(output/role).resolve()
                assert folder.parent == output.resolve() and folder.name in ('host','join')
                if folder.exists(): shutil.rmtree(folder)
    ok=True
    for role,_ in artifacts:
        path=output/(role+'.log')
        content=path.read_text(encoding='utf-8',errors='replace') if path.exists() else ''
        bad=[s for s in content.splitlines() if 'COOP FAIL' in s or 'game error dialog' in s]
        if role=='host':
            if args.smoke: ok=ok and 'v0.2.0-dev initialized' in content and 'tick 200' in content
            else: ok=ok and 'COOP DONE' in content and 'failed=0' in content
        else: ok=ok and 'welcome id=' in content and 'unitsync matched' in content
        ok=ok and not bad and (args.smoke or 'COOP NETWORK DONE' in content)
        print(role+' failures: '+json.dumps(bad,ensure_ascii=False),flush=True)
        for line in content.splitlines():
            if 'COOP ' in line: print(line,flush=True)
    print('RESULT '+('PASS' if ok else 'FAIL'),flush=True)
    raise SystemExit(0 if ok else 1)
if __name__=='__main__': main()
