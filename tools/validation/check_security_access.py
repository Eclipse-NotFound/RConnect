"""Compile/run the actual AS3 access ledger without native game assets."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from prepare_security_terminals import ROOT,OVERLAY,sha
from runtime_memory import snapshot,wait_owned
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,SDK

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output',type=Path);ap.add_argument('--run',action='store_true');a=ap.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists();out.mkdir()
    src=out/'src';shutil.copytree(ROOT/'tests/security-terminals',src)
    prod=OVERLAY/'rconnect/game/SecurityAccessState.as';dest=src/'rconnect/game/SecurityAccessState.as';dest.parent.mkdir(parents=True);shutil.copyfile(prod,dest)
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        subprocess.run([str(JAVA),'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38',
          '-source-path='+str(src),'-output='+str(out/'SecurityAccessChecks.swf'),str(src/'SecurityAccessChecks.as')],stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    (out/'inputs.json').write_text(json.dumps(dict(production_sha256=sha(prod),script_sha256=sha(__file__),tests_sha256=sha(src/'SecurityAccessChecks.as'))))
    if not a.run:return
    memory=snapshot();(out/'memory-before.json').write_text(json.dumps(memory));assert memory['free_commit_bytes']>=1024**3
    appid='rconnect-security-ledger-'+uuid.uuid4().hex;descriptor=out/'application.xml';game=ROOT.parents[1]
    descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>SecurityAccessChecks</filename><initialWindow><content>SecurityAccessChecks.swf</content><visible>false</visible></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>')
    with (out/'stdout.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(descriptor)],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        (out/'process.json').write_text(json.dumps(dict(pid=process.pid,app_id=appid)))
        code=wait_owned(process,40,out/'memory-timeline.json')
    result=Path(os.environ['APPDATA'])/appid/'Local Store/result.json';data={}
    if result.is_file():shutil.copyfile(result,out/'result.json');data=json.loads(result.read_text())
    receipt=dict(exit=code,assertions=len(data.get('assertions',[])),failed=data.get('failed'),passed=code==0 and data.get('passed') is True,native_game_test=False)
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt));raise SystemExit(0 if receipt['passed'] else 1)
if __name__=='__main__':main()
