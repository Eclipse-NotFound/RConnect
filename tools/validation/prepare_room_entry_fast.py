"""Freeze narrow room-loading changes on the actually installed bundle2 source."""
import argparse
import os
import re
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, JAVA, SDK, read, save, sha, inventory, verify

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--build',action='store_true');ap.add_argument('--version',required=True);ap.add_argument('--registry-wait',type=float,default=0);a=ap.parse_args()
    if a.build:
        # Compilation also disturbs another mod's performance measurements.
        sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
        from test_registry import Registration
        with Registration(owner='RConnect / 房间候选编译',purpose=a.version+' 编译（无游戏）',
                          run_dir=ROOT/a.output,evidence=ROOT/a.output/'compile.log',wait=a.registry_wait) as record:
            prepare(a);record.outcome='passed';record.note='编译成功；不代表原生功能通过'
    else:prepare(a)

def prepare(a):
    out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists()
    base=M52/'coop-bundle-04';m=verify(base)
    assert sha(base/'RConnectMod.swf')=='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
    shutil.copytree(base/'src',out/'src');shutil.copytree(base/'tools',out/'tools')
    overlay=ROOT/'experimental/room-entry-fast/src'
    for p in overlay.rglob('*.as'):shutil.copyfile(p,out/'src'/p.relative_to(overlay))
    version=a.version
    p=out/'src/RConnectMod.as';s=p.read_text(encoding='utf-8-sig');assert s.count(m['version'])==1
    p.write_text(s.replace(m['version'],version),encoding='utf-8')
    manifest=dict(kind='isolated-room-entry-fast',base_sha256=m['sha256'],base_manifest=sha(base/'prepared.json'),version=version,
        source=inventory(out/'src'),inputs=inventory(out/'tools'),recipe_sha256=sha(__file__),compiled=False)
    save(out/'prepared.json',manifest)
    if a.build:
        command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
            '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
        with (out/'compile.log').open('w',encoding='utf-8') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
        manifest.update(compiled=True,sha256=sha(out/'RConnectMod.swf'));save(out/'prepared.json',manifest)
    print(out,manifest.get('sha256'))

if __name__=='__main__':main()
