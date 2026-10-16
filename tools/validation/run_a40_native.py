"""Serial native WallBlend regression; preserve evidence, reuse frozen read-only assets."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import time
import uuid
from runtime_memory import snapshot, wait_owned

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]
KINDS=('Harness','Destruction','Coverage','Scene','Field')

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')

def run(out,role,kind,m,attempt=None):
    native=out/'native';runtime=Path(m['runtime']);app=native/'app'
    evidence_root=native/'evidence'
    if attempt:evidence_root=evidence_root/attempt
    evidence=evidence_root/role/kind
    assert not evidence.exists(),'Do not overwrite a previous run'
    evidence.mkdir(parents=True)
    memory=snapshot();save(evidence/'memory-before.json',memory)
    assert memory['free_commit_bytes']>=6*1024**3, 'Less than 6 GiB commit headroom; no AIR started'
    installation={p:sha(GAME/p) for p in ['pfe.swf','mods/WallBlend/release/WallBlendMod.swf']}
    assert sha(runtime/'inputs.json')==m['runtime_manifest']
    links=[];process=None
    try:
        for n,h in m['assets'].items():
            source=runtime/'game'/n;assert sha(source)==h,n
            dest=app/n;dest.parent.mkdir(parents=True,exist_ok=True)
            assert not dest.exists()
            os.link(source,dest);links.append(dest)
        entry='WallBlend'+kind
        harness=native/role/(entry+'.swf');assert sha(harness)==m['swfs'][role+'/'+entry+'.swf']
        wb=out/('control.swf' if role=='control' else 'WallBlendMod.swf');assert sha(wb)==m[role]
        shutil.copyfile(wb,app/'WallBlendMod.swf')
        harness_out=app/'mods'/entry/'release'/(entry+'.swf');harness_out.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(harness,harness_out)
        config=app/'mods/WallBlend/release/config.json';config.parent.mkdir(parents=True,exist_ok=True)
        assert sha(native/'config.json')==m['config_sha256'];shutil.copyfile(native/'config.json',config)
        (app/'mods/loader-manifest.txt').write_text(entry+'|'+entry+'|1|0|0\n',encoding='utf-8')
        app_id='wallblend-test-rconnect-a40-'+role+'-'+kind.lower()+'-'+uuid.uuid4().hex[:12]
        desc=app/('app-'+app_id+'.xml')
        desc.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+app_id+
            '</id><versionNumber>1.0</versionNumber><filename>RConnectWallBlendNative</filename><initialWindow>'+
            '<content>pfe.swf</content><visible>false</visible><width>960</width><height>600</height><resizable>true</resizable>'+
            '<maximizable>true</maximizable><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>',encoding='utf-8')
        record=dict(role=role,kind=kind,app_id=app_id,prepared=sha(native/'prepared.json'),
            host=m['assets']['pfe.swf'],mod=m[role],harness=sha(harness),installation_before=installation,
            attempt=attempt,runner_sha256=sha(__file__),memory_reader_sha256=sha(Path(__file__).with_name('runtime_memory.py')))
        save(evidence/'intent.json',record)
        with (evidence/'stdout.log').open('w',encoding='utf-8') as log:
            process=subprocess.Popen([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],
                cwd=app,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
            record['pid']=process.pid;save(evidence/'intent.json',record)
            print(json.dumps(dict(event='started',role=role,kind=kind,pid=process.pid,app_id=app_id)),flush=True)
            code=wait_owned(process,780 if kind=='Coverage' else 240,evidence/'memory-timeline.json')
        store=Path(os.environ['APPDATA'])/app_id/'Local Store'
        if store.exists():
            for source in store.iterdir():
                if source.is_file() and source.suffix in ('.png','.json','.log'):
                    shutil.copy2(source,evidence/source.name)
                    assert sha(source)==sha(evidence/source.name)
        result=read(evidence/'result.json') if (evidence/'result.json').exists() else {}
        changed={n:sha(GAME/n) for n,h in installation.items() if sha(GAME/n)!=h}
        for n,h in m['assets'].items():assert sha(app/n)==sha(runtime/'game'/n)==h,n
        receipt=dict(exit=code,passed=result.get('passed',False),checks=len(result.get('assertions',[])),
            failures=[v for v in result.get('assertions',[]) if not v.get('passed')],message=result.get('message'),
            installation_changes=changed,images={p.name:sha(p) for p in evidence.glob('*.png')})
        save(evidence/'receipt.json',receipt)
        print(json.dumps(dict(event='completed',role=role,kind=kind,**{k:v for k,v in receipt.items() if k!='images'})),flush=True)
        if code or not receipt['passed'] or changed:raise RuntimeError('Native checks failed: '+str(evidence))
    finally:
        if process and process.poll() is None:process.kill();process.wait()
        for p in links:
            assert p.resolve().is_relative_to(app.resolve())
            p.unlink(missing_ok=True) # Read-only duplicated assets, original frozen file remains.
        for p in app.glob('app-wallblend-test-rconnect-a40-*.xml'):p.unlink()

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('candidate',type=Path)
    ap.add_argument('--kinds',default=','.join(KINDS));ap.add_argument('--roles',default='control,candidate')
    ap.add_argument('--attempt',help='Separate evidence for a documented changed condition; never overwrite an earlier run')
    args=ap.parse_args();out=(ROOT/args.candidate).resolve();assert out.parent==ROOT/'build/m52'
    assert args.attempt is None or re.fullmatch(r'[a-z][a-z0-9-]{0,47}',args.attempt)
    m=read(out/'native/prepared.json')
    for name,hashes in m['records'].items():assert sha(out/'native'/name)==hashes['adapted'],name
    kinds=args.kinds.split(',');roles=args.roles.split(',')
    assert set(kinds)<=set(KINDS) and set(roles)<={'control','candidate'}
    for kind in kinds:
        for role in roles:run(out,role,kind,m,args.attempt)

if __name__=='__main__':main()
