"""Build an immutable M50 candidate; never use build_mod's release default."""
import argparse, subprocess, sys
from validation_baseline import ROOT, read, sha, verify_protected
from run_final_regressions import JAVA

ap=argparse.ArgumentParser();ap.add_argument('snapshot');args=ap.parse_args()
out=(ROOT/args.snapshot).resolve()
assert out.parent==ROOT/'build/m50' and out.name.startswith('final')
m=read(out/'source-input.json');verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(out/n)==h,n
for n,h in read(out/'verified-test-input.json').items():assert sha(ROOT/n)==h,n
assert not (out/'RConnectMod.swf').exists() and not (out/'build.log').exists()
with (out/'build.log').open('w',encoding='utf-8') as log:
    result=subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/build_mod.py'),'--java',JAVA,
                           '--output',str(out/'RConnectMod.swf')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
assert result.returncode==0, 'Build failed; retain this directory and inspect build.log'
with (out/'classes.txt').open('w',encoding='utf-8') as log:
    subprocess.run([JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar',
                    '-dumpAS3',str(out/'RConnectMod.swf')],cwd=ROOT,stdout=log,check=True)
subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/validation/prepare_m50.py'),'built',str(out)],cwd=ROOT,check=True)
