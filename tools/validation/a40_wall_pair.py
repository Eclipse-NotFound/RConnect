"""Compare both exact WallBlend SWFs against one native scene and random damage stream."""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import uuid
from prepare_a33_rv import compile_as
from run_a40_native import sha,read,save,ROOT,GAME

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('mode',choices=('prepare','run'));ap.add_argument('candidate',type=Path)
    ap.add_argument('--label',default='paired')
    args=ap.parse_args();out=(ROOT/args.candidate).resolve();assert out.parent==ROOT/'build/m52'
    assert re.fullmatch('paired(?:-[0-9]+)?',args.label)
    folder=out/args.label;native=read(out/'native/prepared.json')
    if args.mode=='prepare':
        assert not folder.exists();(folder/'src').mkdir(parents=True)
        for name in ('WallNativePair.as','WallNativePairDoc.as'):shutil.copyfile(ROOT/'tests/wallblend'/name,folder/'src'/name)
        compile_as(folder/'src/WallNativePairDoc.as',folder/'WallNativePair.swf',[folder/'src'],
            [GAME/'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'])
        save(folder/'prepared.json',dict(parent_native=sha(out/'native/prepared.json'),
            inputs={p.relative_to(folder).as_posix():sha(p) for p in (folder/'src').glob('*.as')},
            swf=sha(folder/'WallNativePair.swf'),script=sha(Path(__file__))))
        print(json.dumps(dict(prepared=str(folder))));return
    m=read(folder/'prepared.json');assert m['parent_native']==sha(out/'native/prepared.json')
    for n,h in m['inputs'].items():assert sha(folder/n)==h
    assert sha(folder/'WallNativePair.swf')==m['swf']
    app=folder/'app';evidence=folder/'evidence';assert not evidence.exists();evidence.mkdir()
    app_id='wallblend-test-rconnect-pair-'+uuid.uuid4().hex[:12];runtime=Path(native['runtime']);process=None;links=[]
    installation={n:sha(GAME/n) for n in ('pfe.swf','mods/WallBlend/release/WallBlendMod.swf')}
    try:
        for n,h in native['assets'].items():
            source=runtime/'game'/n;assert sha(source)==h
            p=app/n;p.parent.mkdir(parents=True,exist_ok=True);os.link(source,p);links.append(p)
        for name,source,expected in (('WallBlendControl.swf',out/'control.swf',native['control']),
                ('WallBlendCandidate.swf',out/'WallBlendMod.swf',native['candidate'])):
            assert sha(source)==expected;shutil.copyfile(source,app/name)
        dest=app/'mods/WallNativePair/release/WallNativePair.swf';dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(folder/'WallNativePair.swf',dest)
        dest=app/'mods/WallBlend/release/config.json';dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(out/'native/config.json',dest)
        (app/'mods/loader-manifest.txt').write_text('WallNativePair|WallNativePair|1|0|0\n',encoding='utf-8')
        desc=app/'pair.xml';desc.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+app_id+
            '</id><versionNumber>1.0</versionNumber><filename>WallBlendPairedNative</filename><initialWindow>'+
            '<content>pfe.swf</content><visible>false</visible><width>960</width><height>600</height><resizable>true</resizable>'+
            '<maximizable>true</maximizable><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>',encoding='utf-8')
        with (evidence/'stdout.log').open('w',encoding='utf-8') as log:
            process=subprocess.Popen([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],cwd=app,
                stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            save(evidence/'intent.json',dict(app_id=app_id,pid=process.pid,prepared=sha(folder/'prepared.json'),installation_before=installation))
            print(json.dumps(dict(event='started',pid=process.pid,app_id=app_id)),flush=True)
            try:code=process.wait(timeout=270)
            except subprocess.TimeoutExpired:process.kill();process.wait();code=124
        store=Path(os.environ['APPDATA'])/app_id/'Local Store'
        if store.exists():
            for p in store.iterdir():
                if p.is_file() and p.suffix in ('.json','.png','.log'):shutil.copyfile(p,evidence/p.name)
        result=read(evidence/'result.json') if (evidence/'result.json').exists() else {}
        changes={n:sha(GAME/n) for n,h in installation.items() if sha(GAME/n)!=h}
        for n,h in native['assets'].items():assert sha(app/n)==sha(runtime/'game'/n)==h,n
        receipt=dict(exit=code,passed=result.get('passed',False),checks=len(result.get('assertions',[])),
            failures=[a for a in result.get('assertions',[]) if not a['passed']],installation_changes=changes,
            images={p.name:sha(p) for p in evidence.glob('*.png')})
        save(evidence/'receipt.json',receipt)
        print(json.dumps({k:v for k,v in receipt.items() if k!='images'}),flush=True)
        if code or not receipt['passed'] or changes:raise SystemExit(1)
    finally:
        if process and process.poll() is None:process.kill();process.wait()
        for p in links:
            assert p.resolve().is_relative_to(app.resolve());p.unlink(missing_ok=True)
        (app/'pair.xml').unlink(missing_ok=True)

if __name__=='__main__':main()
