"""Add a native artwork observer to frozen room12 entry tests, not production."""
import argparse
import os
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT,M52,JAVA,SDK,read,save,sha,inventory


def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--registry-wait',type=float,default=300);a=ap.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists()
    base=M52/'room-travel-driver-12';meta=read(base/'prepared.json')
    for name,digest in meta['files'].items():assert sha(base/name)==digest,name
    shutil.copytree(base/'tests',out/'tests')
    shutil.copyfile(base/'ProductionDeclarations.swc',out/'ProductionDeclarations.swc')
    shutil.copyfile(ROOT/'tests/native-loading/NativeLoadingProbe.as',out/'tests/NativeLoadingProbe.as')
    p=out/'tests/RoomEntryProbe.as';body=p.read_text(encoding='utf-8-sig')
    for old,new in [
        ('      private var mod:RConnectMod,confirmedRoom:', '      private var nativeLoading:NativeLoadingProbe;\n      private var mod:RConnectMod,confirmedRoom:'),
        ('         mod=m;m.stage.addEventListener', '         mod=m;nativeLoading=new NativeLoadingProbe(m);m.stage.addEventListener'),
        ('         if(finished)return;finished=true;', '         if(finished)return;finished=true;nativeLoading.finish();')]:
        assert body.count(old)==1,old
        body=body.replace(old,new)
    p.write_text(body,encoding='utf-8')
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect (2) / 原版加载外部驱动编译',purpose='原生资源与屏幕观察驱动',
                      run_dir=out,evidence=out/'compile.log',wait=a.registry_wait) as record:
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            for name,entry in [('entry-room','A22RoomEntryTestDoc'),('entry-map','A22MapEntryTestDoc')]:
                target=out/name;target.mkdir();shutil.copyfile(base/name/'EffectsHarness.swf',target/'EffectsHarness.swf')
                cmd=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
                    '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
                    '-source-path='+str(out/'tests'),'-external-library-path+='+str(out/'ProductionDeclarations.swc'),
                    '-external-library-path+='+str(M52/'coop-bundle-04/build/GameCombatStubs.swc'),
                    '-output='+str(target/'EffectsDriver.swf'),str(out/'tests'/(entry+'.as'))]
                subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
        save(out/'prepared.json',dict(files=inventory(out),recipe_sha256=sha(__file__),external=True,
                                     diagnostic_only=False,base_manifest=sha(base/'prepared.json'),native_loading_observer=True))
        record.outcome='passed';record.note='外部显示断言驱动编译；未运行游戏'
    print(out)


if __name__=='__main__':main()
