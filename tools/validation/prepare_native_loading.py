"""Freeze the native loading UI on exact room19; never touch the active overlay."""
import argparse
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, JAVA, SDK, save, sha, inventory
from audit_room_entry_candidate import audit


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output');ap.add_argument('--build',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=300)
    args=ap.parse_args()
    out=(ROOT/args.output).resolve();assert out.parent==M52 and not out.exists()
    base=M52/'room-entry-fast-19';meta=audit(base)
    assert meta['sha256']=='051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea'
    for name in ('src','tools'):shutil.copytree(base/name,out/name)
    overlay=ROOT/'experimental/native-loading-ui/src'
    for p in overlay.rglob('*.as'):shutil.copyfile(p,out/'src'/p.relative_to(overlay))
    version='0.2.24-native-loading1'
    p=out/'src/RConnectMod.as';text=p.read_text(encoding='utf-8-sig');assert text.count(meta['version'])==1
    p.write_text(text.replace(meta['version'],version),encoding='utf-8')
    manifest=dict(kind='isolated-room-entry-fast',base_sha256=meta['base_sha256'],
        room19_sha256=meta['sha256'],room19_manifest=sha(base/'prepared.json'),version=version,
        source=inventory(out/'src'),inputs=inventory(out/'tools'),recipe_sha256=sha(__file__),compiled=False)
    save(out/'prepared.json',manifest)
    if args.build:
        sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
        from test_registry import Registration
        with Registration(owner='RConnect (2) / 原版加载界面编译',purpose=version+' 编译（无游戏）',
                          run_dir=out,evidence=out/'compile.log',wait=args.registry_wait) as record:
            cmd=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
                 '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
            with (out/'compile.log').open('w',encoding='utf-8') as log:
                subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
            manifest.update(compiled=True,sha256=sha(out/'RConnectMod.swf'));save(out/'prepared.json',manifest)
            record.outcome='passed';record.note='编译完成；不是原生验收'
    print(out,manifest.get('sha256'))


if __name__=='__main__':main()
