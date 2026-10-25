import argparse
from pathlib import Path
import subprocess
import sys
from run import Registration, available_gib, ROOT, GAME, inside_build

ap=argparse.ArgumentParser();ap.add_argument('--source',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
out=inside_build(ROOT/a.output)
with Registration(owner='RConnect B / 交互与出口',purpose='B 独立候选编译',run_dir=out,evidence=out/'build-input.json',wait=600) as reg:
    if available_gib()<1:raise RuntimeError('Compiler needs 1 GiB')
    cmd=[sys.executable,str(Path(__file__).resolve().parents[1]/'build.py'),'--source-root',a.source,'--output',a.output,'--optimized']
    reg.before_launch('B candidate compiler');p=subprocess.Popen(cmd);reg.child(p.pid)
    try:
        code=p.wait()
        if code:raise RuntimeError('Compiler failed; inspect build.log')
    finally:
        if p.poll() is None:p.terminate();p.wait()
        reg.child_stopped()
    reg.outcome='passed'
