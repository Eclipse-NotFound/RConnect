"""Build isolated hit-artwork changes on installed bundle04, never root src."""
import argparse
import os
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, JAVA, SDK, sha, inventory, save, verify

BASE_SHA='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
ENTRIES=['WallBallisticTestDoc','WallEnergyTestDoc','WallMagicTestDoc']

def prepare(out,version):
    base=M52/'coop-bundle-04';m=verify(base)
    assert sha(base/'RConnectMod.swf')==BASE_SHA
    assert out.parent==M52 and not out.exists()
    shutil.copytree(base/'src',out/'src');shutil.copytree(base/'tools',out/'tools')
    overlay=ROOT/'experimental/wall-impact-effects'
    for p in (overlay/'src').rglob('*.as'):shutil.copyfile(p,out/'src'/p.relative_to(overlay/'src'))
    p=out/'src/RConnectMod.as';s=p.read_text('utf-8-sig');assert s.count(m['version'])==1
    p.write_text(s.replace(m['version'],version),'utf-8')
    shutil.copytree(overlay/'tests',out/'tests');shutil.copytree(ROOT/'tests/harness',out/'tests/harness')
    manifest=dict(kind='isolated-wall-impact-effects',version=version,base_sha256=BASE_SHA,
                  source=inventory(out/'src'),tools=inventory(out/'tools'),tests=inventory(out/'tests'),
                  recipe_sha256=sha(__file__),compiled=False)
    save(out/'prepared.json',manifest)
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        subprocess.run([sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
                        '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')],
                       stdout=log,stderr=subprocess.STDOUT,check=True)
    manifest.update(compiled=True,sha256=sha(out/'RConnectMod.swf'));save(out/'prepared.json',manifest)
    compiler=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
              '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
    env=dict(os.environ,AIR_HOME=str(SDK))
    declarations=compiler.copy();declarations[3]=str(SDK/'lib/compc.jar')
    external=out/'build/ProductionDeclarations.swc';stub=out/'build/GameCombatStubs.swc'
    with (out/'driver-build.log').open('w',encoding='utf-8') as log:
        def call(args):subprocess.run(args,stdout=log,stderr=subprocess.STDOUT,env=env,check=True)
        classes=['.'.join(p.relative_to(out/'src').with_suffix('').parts) for p in (out/'src').rglob('*.as')]
        call(declarations+['-source-path='+str(out/'src'),'-external-library-path+='+str(stub),
                          '-include-classes='+','.join(classes),'-output='+str(external)])
        harness=out/'build/EffectsHarness.swf'
        call(compiler+['-source-path='+str(out/'tests/harness'),'-output='+str(harness),str(out/'tests/harness/RConnectDoc.as')])
        for entry in ENTRIES:
            driver=out/'drivers'/entry;driver.mkdir(parents=True)
            call(compiler+['-source-path='+str(out/'tests'),'-external-library-path+='+str(external),
                           '-external-library-path+='+str(stub),'-output='+str(driver/'EffectsDriver.swf'),str(out/'tests'/(entry+'.as'))])
            shutil.copyfile(harness,driver/'EffectsHarness.swf')
            save(driver/'driver-input.json',dict(candidate_sha256=manifest['sha256'],entry=entry))
            control=out/'control'/entry;shutil.copytree(driver,control)
            save(control/'driver-input.json',dict(candidate_sha256=BASE_SHA,entry=entry))
    manifest['drivers']=inventory(out/'drivers');save(out/'prepared.json',manifest)
    print(out,manifest['sha256'],flush=True)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--version',required=True)
    ap.add_argument('--registry-wait',type=float,default=300);args=ap.parse_args()
    out=(ROOT/args.output).resolve()
    sys.path.insert(0,str(ROOT.parents[1]/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect (5) / 命中特效编译',purpose=args.version+' 编译，无游戏',
                      run_dir=out,evidence=out/'compile.log',wait=args.registry_wait) as record:
        prepare(out,args.version);record.outcome='passed';record.note='生产与外置驱动编译通过；原生测试另记'

if __name__=='__main__':main()
