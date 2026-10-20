"""External identical timing drivers; production implementation is never linked."""
import argparse
import os
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT,M52,JAVA,SDK,read,save,sha,inventory

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--registry-wait',type=float,default=0);a=ap.parse_args()
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 房间测试驱动编译',purpose='外部驱动编译（无游戏，避免污染其他性能采样）',
                      run_dir=ROOT/a.output,evidence=ROOT/a.output/'compile.log',wait=a.registry_wait) as record:
        build(a);record.outcome='passed';record.note='外部驱动编译完成；不是功能验收'

def build(a):
    out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists();out.mkdir()
    original=M52/'coop-bundle-drivers-04';src=out/'tests';src.mkdir()
    names=('RoomTravelTimingTestDoc','RoomTravelSceneTestDoc','A22RoomEntryTestDoc','A22MapEntryTestDoc',
           'RoomEntryProbe','RoomCooperationTestDoc','A22RoomMetrics','NativeMapGenerationTestDoc','RoomScalarParity')
    for name in names:shutil.copyfile(ROOT/'tests'/(name+'.as'),src/(name+'.as'))
    shutil.copytree(original/'tests/fe',src/'fe')
    for name in ('ProductionDeclarations.swc',):shutil.copyfile(original/name,out/name)
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        for name,entry in [('timing','RoomTravelTimingTestDoc'),('scene','RoomTravelSceneTestDoc'),
                           ('entry-room','A22RoomEntryTestDoc'),('entry-map','A22MapEntryTestDoc')]:
            target=out/name;target.mkdir();shutil.copyfile(original/'EffectsHarness.swf',target/'EffectsHarness.swf')
            cmd=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
                '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
                '-source-path='+str(src),'-external-library-path+='+str(out/'ProductionDeclarations.swc'),
                '-external-library-path+='+str(M52/'coop-bundle-04/build/GameCombatStubs.swc'),
                '-output='+str(target/'EffectsDriver.swf'),str(src/(entry+'.as'))]
            subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    save(out/'prepared.json',dict(files=inventory(out),recipe_sha256=sha(__file__),external=True))
    print(out)

if __name__=='__main__':main()
