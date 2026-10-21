"""Exact AS3 impact queue + renderer boundary checks; not a native-game pass."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from check_coop_bundle import ROOT, M52, JAVA, SDK, sha, inventory, save
from runtime_memory import snapshot, wait_owned

GAME=ROOT.parents[1]
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
from air_test_process import HiddenProcess

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--source',required=True)
    ap.add_argument('--registry-wait',type=float,default=300);args=ap.parse_args()
    out=(ROOT/args.output).resolve();source=(ROOT/args.source).resolve()
    assert out.parent==M52 and not out.exists() and source.is_relative_to(ROOT)
    out.mkdir()
    with Registration(owner='RConnect (5) / 命中特效组件',purpose='实际AS3队列、去重、暂停和退役；无游戏资源',
                      run_dir=out,evidence=out/'receipt.json',wait=args.registry_wait) as record:
        src=out/'src';shutil.copytree(ROOT/'experimental/wall-impact-effects/components',src)
        originals={}
        for name in ['ImpactEventQueue','BallisticImpactVisuals','EnergyImpactVisuals']:
            p=source/'rconnect/game'/(name+'.as');originals[str(p)]=sha(p)
            shutil.copyfile(p,src/'rconnect/game'/(name+'.as'))
        before={str(p):sha(p) for p in [GAME/'pfe.swf',ROOT/'release/RConnectMod.swf']}
        save(out/'inputs.json',dict(production=originals,files=inventory(src),installed=before,game_loaded=False,recipe=sha(__file__)))
        cmd=[str(JAVA),'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
             '-swf-version=38','-debug=true','-source-path='+str(src),'-output='+str(out/'Checks.swf'),str(src/'ImpactQueueChecks.as')]
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            code=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK))).returncode
        if code:
            print((out/'compile.log').read_text('utf-8',errors='replace')[-6000:]);raise SystemExit(code)
        memory=snapshot();save(out/'memory-before.json',memory)
        assert memory['free_commit_bytes']>=1024**3,'Small resource-free component needs 1GiB'
        appid='rconnect-impact-checks-'+uuid.uuid4().hex;descriptor=out/'application.xml'
        descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+
            '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow><content>Checks.swf</content>'+
            '<visible>false</visible><width>100</width><height>100</height></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>','utf-8')
        with (out/'stdout.log').open('w',encoding='utf-8') as log:
            record.before_launch('component '+appid)
            process=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(descriptor)],cwd=out,stdout=log,stderr=log)
            record.child(process.pid);save(out/'process.json',dict(pid=process.pid,appid=appid,desktop=process.desktop))
            try:code=wait_owned(process,40,out/'memory-timeline.json')
            finally:
                if process.poll() is None:process.kill();process.wait()
                process.close();record.child_stopped()
        result={};path=Path(os.environ['APPDATA'])/appid/'Local Store/result.json'
        if path.is_file():shutil.copyfile(path,out/'result.json');result=json.loads(path.read_text('utf-8'))
        receipt=dict(exit=code,passed=result.get('pass'),failed=result.get('fail'),
            source_unchanged=all(sha(Path(p))==h for p,h in originals.items()),
            installation_unchanged=all(sha(Path(p))==h for p,h in before.items()),native_game_pass=False)
        save(out/'receipt.json',receipt);print(json.dumps(receipt))
        for row in result.get('checks',[]):
            if not row['pass']:print(json.dumps(row,ensure_ascii=False))
        if code or result.get('fail')!=0 or not receipt['installation_unchanged'] or not receipt['source_unchanged']:raise SystemExit(code or 1)
        record.outcome='passed';record.note='队列和渲染边界组件通过；不等于原生游戏效果通过'

if __name__=='__main__':main()
