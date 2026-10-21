"""Freeze only the motion-continuity overlay onto installed bundle2.

No room-entry, transport-motion1 or other conversations' changes are included.
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from check_coop_bundle import ROOT, M52, JAVA, SDK, save, sha, inventory, verify


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path)
    ap.add_argument('--version',required=True)
    ap.add_argument('--build',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=300)
    args=ap.parse_args()
    if args.build:
        sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
        from test_registry import Registration
        with Registration(owner='RConnect / 运动连续性候选',purpose=args.version+' 正式编译（不部署）',
                          run_dir=ROOT/args.output,evidence=ROOT/args.output/'prepared.json',wait=args.registry_wait) as record:
            prepare(args);record.outcome='passed';record.note='候选编译通过，原生验收仍待执行'
    else:prepare(args)


def prepare(args):
    out=(ROOT/args.output).resolve()
    assert out.parent==M52 and not out.exists()
    base=M52/'coop-bundle-04';manifest=verify(base)
    assert sha(base/'RConnectMod.swf')=='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
    shutil.copytree(base/'src',out/'src');shutil.copytree(base/'tools',out/'tools')
    overlay=ROOT/'experimental/motion-continuity/src'
    changes={}
    for p in overlay.rglob('*.as'):
        relative=p.relative_to(overlay)
        destination=out/'src'/relative;destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(p,destination);changes[relative.as_posix()]=sha(p)
    entry=out/'src/RConnectMod.as';text=entry.read_text(encoding='utf-8-sig')
    assert text.count(manifest['version'])==1
    entry.write_text(text.replace(manifest['version'],args.version),encoding='utf-8')
    record=dict(kind='isolated-motion-continuity',base_sha256=sha(base/'RConnectMod.swf'),
                base_manifest_sha256=sha(base/'prepared.json'),version=args.version,overlay=changes,
                source={'src/'+k:v for k,v in inventory(out/'src').items()},
                inputs={'tools/'+k:v for k,v in inventory(out/'tools').items()},recipe_sha256=sha(__file__),
                compiled=False,installed=False,gameplay_qualified=False)
    save(out/'prepared.json',record)
    if args.build:
        command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
                 '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            code=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT).returncode
        record.update(compile_exit=code,compile_log_sha256=sha(out/'compile.log'))
        if code==0:record.update(compiled=True,sha256=sha(out/'RConnectMod.swf'),candidate_sha256=sha(out/'RConnectMod.swf'))
        save(out/'prepared.json',record)
        if code:raise SystemExit(code)
    print(out,record.get('sha256'),flush=True)


if __name__=='__main__':main()
