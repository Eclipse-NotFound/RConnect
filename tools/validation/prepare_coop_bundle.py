"""Merge reviewed feature snapshots into one isolated candidate; never install.

Each contributor is pinned by its tested binary and source manifest. Three-way
merges preserve existing changes and stop on conflicts. Build is a separate step
so exact conflict resolutions can be reviewed before compiling.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'build/m52/a22-fixes-39'
VERSION='0.2.23-coop-bundle1'
FEATURES=[
    ('security-terminals-10','prepared.json','cb94ddd299ef9d5b259b755a2279fb9327e0a988bb9d4970b601bbcd984c63ac'),
    ('a22-room-entry-04','prepared.json','1c451a56cc942e27a136614b5027928955614340f469e9cbb1aa5ac94b435f91'),
    ('peer-vision-port-07','source.json','bf6ab8946a09357788e00d9ffff5b336e61370d970d3fc2cce2619350c8d25f7'),
    ('peer-projectile-grip-04','prepared.json','ccf842e123cdb057e10a0e39a1e85430883a62e0f6cd3d9902269805cf141801'),
]

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p,text):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(text,encoding='utf-8',newline='\n')
def normalized(path,text):
    if path=='src/RConnectMod.as':
        text,n=re.subn(r'(VERSION:String\s*=\s*")[^"]+(";)',r'\g<1>0.2.22-fix39-keybinds\2',text)
        assert n==1
    return text

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path)
    ap.add_argument('--without-peer-port',action='store_true',help='Hold the unqualified optional Q feature outside the release')
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    bm=read(BASE/'prepared.json')
    assert sha(BASE/'RConnectMod.swf')==bm['candidate_sha256']=='a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60'
    for name,digest in bm['source'].items():assert sha(BASE/name)==digest,name
    shutil.copytree(BASE/'src',out/'src')
    shutil.copytree(BASE/'tools/stubs',out/'tools/stubs')
    shutil.copyfile(BASE/'tools/build_mod.py',out/'tools/build_mod.py')
    provenance=[];conflicts=[]
    features=[f for f in FEATURES if not (args.without_peer_port and f[0]=='peer-vision-port-07')]
    for feature,manifest,pin in features:
        folder=ROOT/'build/m52'/feature;m=read(folder/manifest)
        assert sha(folder/'RConnectMod.swf')==pin,feature
        for name,digest in m['source'].items():assert sha(folder/name)==digest,(feature,name)
        changed=[]
        for name in sorted(m['source']):
            original=BASE/name;target=out/name
            b=normalized(name,original.read_text(encoding='utf-8-sig')) if original.exists() else None
            v=normalized(name,(folder/name).read_text(encoding='utf-8-sig'))
            if b==v:continue
            changed.append(name)
            if not target.exists():write(target,v);continue
            c=normalized(name,target.read_text(encoding='utf-8-sig'))
            if c==v:continue
            if c==b:write(target,v);continue
            assert b is not None,(feature,name,'added-file collision')
            if feature=='peer-projectile-grip-04' and name=='src/RConnectMod.as':
                from prepare_peer_projectile_grip import integrate
                assert integrate(name,b)==v
                write(target,integrate(name,c))
                continue
            if feature=='peer-vision-port-07' and name=='src/rconnect/core/Config.as':
                anchor='         friendlyFire: "0",'
                assert b.count(anchor)==1
                assert c==b.replace(anchor,anchor+'\n         sharedSecurityHack: "1",')
                assert v==b.replace(anchor,anchor+'\n         peerVisionTeleport: "0",')
                write(target,c.replace(anchor,anchor+'\n         peerVisionTeleport: "0",'))
                continue
            scratch=out/'merge-inputs'/feature/Path(name).with_suffix('')
            for label,value in [('current',c),('base',b),('incoming',v)]:write(scratch/label,value)
            result=subprocess.run(['git','merge-file','-p','--diff3','-L','combined','-L','fix39','-L',feature,
                str(scratch/'current'),str(scratch/'base'),str(scratch/'incoming')],capture_output=True)
            assert result.returncode>=0 and result.returncode<128,result.stderr.decode(errors='replace')
            merged=result.stdout.decode('utf-8')
            write(target,merged)
            if result.returncode:conflicts.append(dict(feature=feature,file=name,count=result.returncode))
        provenance.append(dict(feature=feature,manifest_sha256=sha(folder/manifest),binary_sha256=pin,changed=changed))
        if conflicts:break
    if not conflicts:
        q=ROOT/'build/m52/peer-vision-port-07';qm=read(q/'source.json')
        # Q's only build changes: native compile-time GUI/UnitPlayer interfaces.
        for name in ['tools/stubs/fe/unit/UnitPlayer.as','tools/stubs/fe/inter/GUI.as','tools/build_mod.py']:
            assert sha(q/name)==qm['inputs'][name],name
            shutil.copyfile(q/name,out/name)
        p=out/'src/RConnectMod.as';text=p.read_text(encoding='utf-8')
        assert text.count('"0.2.22-fix39-keybinds"')==1
        version='0.2.23-coop-bundle2' if args.without_peer_port else VERSION
        write(p,text.replace('"0.2.22-fix39-keybinds"','"'+version+'"'))
    record=dict(kind='isolated-coop-bundle',version='0.2.23-coop-bundle2' if args.without_peer_port else VERSION,base_sha256=bm['candidate_sha256'],
        held_features=['peer-port'] if args.without_peer_port else [],
        features=provenance,conflicts=conflicts,installed=False,compiled=False,recipe_sha256=sha(__file__),
        source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')},
        inputs={p.relative_to(out).as_posix():sha(p) for p in (out/'tools').rglob('*') if p.is_file()})
    write(out/'prepared.json',json.dumps(record,indent=2))
    print(json.dumps(dict(output=str(out),conflicts=conflicts,features=provenance)))
    raise SystemExit(2 if conflicts else 0)

if __name__=='__main__':main()
