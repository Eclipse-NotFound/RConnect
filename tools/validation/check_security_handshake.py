"""Run the actual security controller with deterministic lost-state delivery.

Only native game adapters are test doubles; controller, ledger and network types
are copied byte-for-byte from a frozen candidate. This is not a game test.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from prepare_security_terminals import ROOT,sha
from runtime_memory import snapshot,wait_owned
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,SDK

STUBS={
'rconnect/core/Session.as':'package rconnect.core {public class Session {public static const HOSTING:String="hosting",CONNECTED:String="connected",OFFLINE:String="offline";}}',
'rconnect/core/Log.as':'package rconnect.core {public class Log {public static function d(s:String):void {trace(s);}}}',
'rconnect/game/GameBridge.as':'package rconnect.game {public class GameBridge {public static function probe(o:Object,k:String):* {return o!=null && k in o?o[k]:null;}}}',
'rconnect/game/MirrorHitUnit.as':'package rconnect.game {public class MirrorHitUnit {public var body:Object;}}',
'fe/unit/RConnectSecurityAccess.as':'''package fe.unit {public class RConnectSecurityAccess {
public static function turret(o:Object):Boolean{return false;}
public static function state(o:Object):Object{return {};}
public static function apply(o:Object,s:int,e:Boolean,a:Boolean):void{}
public static function clearTarget(o:Object,f:Function):void{}
public static function detect(o:Object,t:Object,f:Boolean):Boolean{return false;}}}''',
'fe/serv/RConnectSecurityInteractionAccess.as':'''package fe.serv {public class RConnectSecurityInteractionAccess {
public static function capture(o:Object):Object{return {lock:o.lock};}
public static function restore(o:Object,s:Object):void{o.lock=s.lock;}}}'''
}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path);ap.add_argument('--candidate',required=True,type=Path);ap.add_argument('--run',action='store_true');a=ap.parse_args()
    out=(ROOT/a.output).resolve();candidate=(ROOT/a.candidate).resolve()
    assert out.parent==ROOT/'build/m52' and candidate.parent==out.parent and not out.exists()
    prepared=json.loads((candidate/'prepared.json').read_text(encoding='utf-8-sig'))
    out.mkdir();src=out/'src';sources={}
    for name in ['rconnect/core/SecurityTerminals.as','rconnect/game/SecurityAccessState.as',
                 'rconnect/net/TcpLink.as','rconnect/net/NetMessageEvent.as','rconnect/net/Protocol.as','rconnect/net/BinaryMessageCodec.as']:
        p=candidate/'src'/name;assert sha(p)==prepared['source']['src/'+name]
        t=src/name;t.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,t);sources[name]=sha(p)
    for name in ('SecurityHandshakeChecks.as','SecurityTestLink.as'):
        shutil.copyfile(ROOT/'tests/security-terminals'/name,src/name)
    for name,text in STUBS.items():
        p=src/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        subprocess.run([str(JAVA),'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
          '-swf-version=38','-source-path='+str(src),'-output='+str(out/'SecurityHandshakeChecks.swf'),str(src/'SecurityHandshakeChecks.as')],
          stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    (out/'inputs.json').write_text(json.dumps(dict(candidate=str(candidate),production=sources,script=sha(__file__),
       files={p.relative_to(src).as_posix():sha(p) for p in src.rglob('*.as')},native_game_test=False),indent=2))
    if not a.run:return
    memory=snapshot();(out/'memory-before.json').write_text(json.dumps(memory));assert memory['free_commit_bytes']>=1024**3
    appid='rconnect-security-handshake-'+uuid.uuid4().hex;descriptor=out/'application.xml';game=ROOT.parents[1]
    descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>SecurityHandshakeChecks</filename><initialWindow><content>SecurityHandshakeChecks.swf</content><visible>false</visible></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>')
    with (out/'stdout.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen([str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(descriptor)],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        (out/'process.json').write_text(json.dumps(dict(pid=process.pid,app_id=appid)))
        code=wait_owned(process,40,out/'memory-timeline.json')
    result=Path(os.environ['APPDATA'])/appid/'Local Store/result.json';data={}
    if result.is_file():shutil.copyfile(result,out/'result.json');data=json.loads(result.read_text())
    receipt=dict(exit=code,assertions=len(data.get('assertions',[])),failed=data.get('failed'),passed=code==0 and data.get('passed') is True,native_game_test=False)
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt));raise SystemExit(0 if receipt['passed'] else 1)

if __name__=='__main__':main()
