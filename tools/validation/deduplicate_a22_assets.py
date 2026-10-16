"""Losslessly deduplicate immutable native assets inside this mod's frozen runtimes.

No installation links, configurations, evidence or sources are touched. Optional
candidate binaries must be covered by an immutable prepared manifest.
Each replacement is an atomic rename of an already verified additional hardlink.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path,PurePosixPath
import re
import shutil
import uuid

ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'build/m52'
BASE=BUILD/'a22-map-runtime-17'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inputs(p):return json.loads((p/'inputs.json').read_text(encoding='utf-8'))['files']
def allowed(n):
    return n in ('adl64.exe','pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf') or n.startswith(('Rooms/','Music/','runtimes/'))
def checked(root,n):
    relative=PurePosixPath(n)
    assert not relative.is_absolute() and '..' not in relative.parts and ':' not in n and '\\' not in n
    p=(root/'game'/n).resolve()
    assert p.is_relative_to((root/'game').resolve()) and p.is_relative_to(BUILD.resolve()) and p.is_file() and not p.is_symlink()
    return p
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--apply',action='store_true')
    ap.add_argument('--candidate-binaries',action='store_true');args=ap.parse_args()
    baseline=inputs(BASE);plan=[];verified={}
    for folder in ([] if args.candidate_binaries else sorted(BUILD.glob('a22-map-runtime-*'))):
        if folder==BASE or not re.fullmatch('a22-map-runtime-[0-9]+',folder.name):continue
        for n,h in inputs(folder).items():
            if not allowed(n) or baseline.get(n)!=h:continue
            target=checked(BASE,n);dest=checked(folder,n)
            if os.path.samefile(dest,target):continue
            if n not in verified:assert sha(target)==h;verified[n]=h
            assert sha(dest)==h
            plan.append(dict(path=str(dest.relative_to(BUILD)),reference=str(target.relative_to(BUILD)),sha256=h,bytes=dest.stat().st_size))
    if args.candidate_binaries:
        references={}
        for manifest in sorted(BUILD.glob('*/prepared.json')):
            m=json.loads(manifest.read_text(encoding='utf-8-sig'))
            if m.get('kind') not in ('isolated-a22-followup','isolated-a22-testpack'):continue
            for n,key in (('RConnectMod.swf','candidate_sha256'),('control.swf','control_sha256'),('native/pfe.swf','candidate_game_sha256')):
                dest=(manifest.parent/n).resolve();h=m.get(key)
                assert dest.is_relative_to(manifest.parent.resolve()) and dest.is_relative_to(BUILD.resolve()) and not dest.is_symlink()
                assert h and dest.is_file() and sha(dest)==h
                if h not in references:references[h]=dest;continue
                target=references[h]
                if not os.path.samefile(dest,target):
                    plan.append(dict(path=str(dest.relative_to(BUILD)),reference=str(target.relative_to(BUILD)),sha256=h,bytes=dest.stat().st_size))
    print(json.dumps(dict(mode='apply' if args.apply else 'preview',files=len(plan),bytes=sum(r['bytes'] for r in plan),free=shutil.disk_usage(ROOT).free)),flush=True)
    if not args.apply:return
    token=uuid.uuid4().hex[:12];receipt=BUILD/('asset-dedup-'+token+'.json')
    record=dict(plan=plan,completed=[],free_before=shutil.disk_usage(ROOT).free)
    receipt.write_text(json.dumps(record,indent=2),encoding='utf-8')
    for row in plan:
        dest=(BUILD/row['path']).resolve();target=(BUILD/row['reference']).resolve()
        assert dest.is_relative_to(BUILD.resolve()) and target.is_relative_to((BUILD if args.candidate_binaries else BASE).resolve())
        assert sha(dest)==sha(target)==row['sha256']
        temporary=dest.with_name(dest.name+'.dedup-'+token)
        assert not temporary.exists()
        try:
            os.link(target,temporary)
            assert sha(temporary)==row['sha256']
            os.replace(temporary,dest)
            assert os.path.samefile(dest,target) and sha(dest)==row['sha256']
            record['completed'].append(row['path'])
        finally:temporary.unlink(missing_ok=True)
    record['free_after']=shutil.disk_usage(ROOT).free
    receipt.write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps(dict(files=len(record['completed']),free_after=record['free_after'],receipt=str(receipt))),flush=True)
if __name__=='__main__':main()
