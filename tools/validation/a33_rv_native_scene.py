"""Native training-room pixel equivalence for both modes and wall-bright settings.

Reuses the RV owner's reviewed scene fixture, freezing every transform here.
No production binary, native asset, user config or save is modified.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid
from PIL import Image, ImageChops
from prepare_a33_rv import ROOT, RV, GAME, BASE, BASE_SHA, compile_as, sha


def prepare(out, bundle):
    m = json.loads((out/'prepared.json').read_text(encoding='utf-8'))
    for n,h in m['source'].items():
        assert sha(out/n)==h,n
    for n,h in m['parent_source'].items():
        assert sha(BASE/n)==h,n
    assert sha(BASE/'RealisticVisionMod.swf')==BASE_SHA
    scene = out/'native-scene'
    scene.mkdir()
    text = (RV/'build/wall-options/WallSurfaceProbe.as').read_text(encoding='utf-8-sig')
    parent_probe_sha = sha(RV/'build/wall-options/WallSurfaceProbe.as')
    # Benchmark function is unrelated to this capture; omit it from the frozen probe.
    text = text[:text.index('      private function bench(w:*):Boolean')]+'   }\n}\n'
    replacements = [
        ('      private static const BENCH:Boolean=CONFIG::wallBench;\n',''),
        ('if(!(BENCH?bench(w):capture(w)))return;','if(!capture(w))return;'),
        ('/RealisticVision/build/wall-options-output/','/RConnect/build/m52/'+out.name+'/native-scene/runtime'),
        ('["baseline","off","on"][captureState.variant]',
         '["baseline-off","baseline-on","candidate-off","candidate-on"][captureState.variant]'),
        ('classes[variant=="baseline"?"baseline":"candidate"]',
         'classes[variant.indexOf("baseline-")==0?"baseline":"candidate"]'),
        ('if(variant!="baseline")m.cfgWallBright=variant=="on";',
         'm.cfgWallBright=variant.indexOf("-on")>0;'),
        ('var key:String=mode+"-"+step;',
         'var key:String=mode+"-"+step+"-"+m.cfgWallBright;'),
        ('if(variant=="baseline")references[key]=identity;',
         'if(variant.indexOf("baseline-")==0)references[key]=identity;'),
        ('if(variant=="off"){','if(variant=="candidate-off"){'),
        ('if(variant=="on"){','if(variant=="candidate-on"){'),
        ('return captureState.variant==3;','return captureState.variant==4;'),
    ]
    for old,new in replacements:
        assert text.count(old)==1,old
        text=text.replace(old,new)
    source = scene/'src'
    source.mkdir()
    air = GAME/'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'
    for material in ('metal','rock'):
        directory=source/material;directory.mkdir()
        (directory/'WallSurfaceProbe.as').write_text(text.replace('CONFIG::rockFixture',str(material=='rock').lower()),encoding='utf-8')
        compile_as(directory/'WallSurfaceProbe.as',scene/(material+'.swf'),[directory],[air])
    for variant,origin in [('baseline',BASE/'src'),('candidate',out/'src')]:
        directory=source/variant
        for path in origin.rglob('*.as'):
            target=directory/path.relative_to(origin);target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(re.sub(r'\bprivate\b','public',path.read_text(encoding='utf-8-sig')),encoding='utf-8')
        compile_as(directory/'RealisticVisionMod.as',scene/(variant+'.swf'),[directory],[air,out/'GameStubs.swc'])
    manifest = dict(parent_probe_sha256=parent_probe_sha,prepared_sha256=sha(out/'prepared.json'),
        runtime_sha256=sha(bundle/'inputs.json'),
        source={p.relative_to(scene).as_posix():sha(p) for p in source.rglob('*') if p.is_file()},
        binaries={p.name:sha(p) for p in scene.glob('*.swf')})
    (scene/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Prepared native scene checks',out.name,flush=True)


def run(out,bundle):
    scene=out/'native-scene';m=json.loads((scene/'inputs.json').read_text(encoding='utf-8'))
    assert sha(out/'prepared.json')==m['prepared_sha256'] and sha(bundle/'inputs.json')==m['runtime_sha256']
    for n,h in {**m['source'],**m['binaries']}.items():
        assert sha(scene/n)==h,n
    frozen=json.loads((bundle/'inputs.json').read_text(encoding='utf-8'))['files']
    installed={n:sha(GAME/n) for n in frozen}
    for n,h in frozen.items():
        assert sha(bundle/'game'/n)==h,n
    runtime=scene/'runtime'
    assert not runtime.exists()
    shutil.copytree(bundle/'game',runtime)
    boot=runtime/'mods/WallSurfaceProbe/release';boot.mkdir(parents=True)
    (runtime/'mods/loader-manifest.txt').write_text('WallSurfaceProbe|WallSurfaceProbe|1|0|0\n',encoding='utf-8')
    for variant in ('baseline','candidate'):
        shutil.copyfile(scene/(variant+'.swf'),runtime/(variant+'.swf'))
    try:
        for material in ('metal','rock'):
            evidence=scene/material
            evidence.mkdir()
            (runtime/'evidence').mkdir()
            shutil.copyfile(scene/(material+'.swf'),boot/'WallSurfaceProbe.swf')
            app_id='pfe-modsettings-rv-native-'+uuid.uuid4().hex
            desc=runtime/'scene.xml'
            desc.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+app_id+
                '</id><versionNumber>1.0</versionNumber><filename>RVScene</filename><initialWindow><content>pfe.swf</content>'+
                '<visible>false</visible><width>1280</width><height>720</height><renderMode>direct</renderMode></initialWindow></application>',encoding='utf-8')
            with (evidence/'native.log').open('w',encoding='utf-8') as log:
                process=subprocess.Popen([str(runtime/'adl64.exe'),'-runtime',str(runtime/'runtimes/air/win64'),str(desc),'-nodebug'],
                    cwd=runtime,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                try: code=process.wait(timeout=300)
                except subprocess.TimeoutExpired:
                    process.kill();process.wait();code=124
            for path in (runtime/'evidence').iterdir():
                shutil.copy2(path,evidence/path.name)
            # This known transient folder contains only copies already preserved above.
            assert (runtime/'evidence').resolve().is_relative_to(scene.resolve())
            shutil.rmtree(runtime/'evidence')
            log=(evidence/'native.log').read_text(encoding='utf-8',errors='replace')
            result=dict(exit=code,app_id=app_id,pid=process.pid,complete='SURFACE GAME COMPLETE' in log,
                passed=len(re.findall(r'^PASS ',log,re.M)),failed=len(re.findall(r'^FAIL ',log,re.M)),
                input_sha256=sha(scene/'inputs.json'),pixels=[],installation_changes={n:sha(GAME/n) for n,h in installed.items() if sha(GAME/n)!=h})
            for mode in ('classic','current'):
                for bright in ('off','on'):
                    for position in ('upper','lower'):
                        for suffix in ('','-fog'):
                            tag=bright+'-'+position+'-'+mode+suffix+'.png'
                            a,b=[evidence/(v+'-'+tag) for v in ('baseline','candidate')]
                            equal=a.exists() and b.exists() and ImageChops.difference(Image.open(a).convert('RGB'),Image.open(b).convert('RGB')).getbbox() is None
                            result['pixels'].append(dict(case=tag,equal=equal))
            (evidence/'receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
            print(json.dumps(result,ensure_ascii=False),flush=True)
            if code or not result['complete'] or result['failed'] or result['installation_changes'] or not all(p['equal'] for p in result['pixels']):
                print('\n'.join(log.splitlines()[-15:]),flush=True)
                raise SystemExit(1)
    finally:
        # Retain logs, screenshots, frozen source and binaries, discard repeat assets.
        assert runtime.resolve().parent==scene.resolve() and scene.resolve().is_relative_to(ROOT/'build/m52')
        shutil.rmtree(runtime)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action',choices=['prepare','run'])
    ap.add_argument('--candidate',required=True,type=Path)
    ap.add_argument('--bundle',required=True,type=Path)
    args=ap.parse_args()
    out,bundle=[(ROOT/p).resolve() for p in (args.candidate,args.bundle)]
    assert out.parent==bundle.parent==ROOT/'build/m52'
    (prepare if args.action=='prepare' else run)(out,bundle)


if __name__=='__main__':
    main()
