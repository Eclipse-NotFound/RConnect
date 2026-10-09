"""Compile new independent drivers against an immutable diagnostic snapshot.

Does not run AIR and never writes release. Compile-only outputs cannot be
mistaken for the separately named runtime drivers or passing runtime results.
"""
import argparse,json,subprocess,sys
from validation_baseline import ROOT,read,sha,verify_protected
from run_final_regressions import JAVA,M50_REQUIRED
ap=argparse.ArgumentParser();ap.add_argument('snapshot');a=ap.parse_args()
out=(ROOT/a.snapshot).resolve()
assert out.parent==ROOT/'build/m50' and out.name.startswith('probe-')
m=read(out/'inputs.json');verify_protected(m)
for n,h in m['files'].items():assert sha(out/n)==h,n
entries=M50_REQUIRED[M50_REQUIRED.index('PeerVisualTestDoc'):]
records=[]
for entry in entries:
    target=out/'build/compile-only'/entry;assert not target.exists(),target
    target.parent.mkdir(parents=True,exist_ok=True)
    logfile=out/'build/compile-only'/(entry+'.log');assert not logfile.exists()
    with logfile.open('w',encoding='utf-8') as log:
        r=subprocess.run([sys.executable,'-X','utf8',str(out/'tools/build_effects_driver.py'),
            '--candidate',str(out/'RConnectMod.swf'),'--source-root',str(out/'src'),
            '--java',JAVA,'--output',str(target),'--entry',entry],cwd=out,stdout=log,stderr=subprocess.STDOUT)
    records.append(dict(entry=entry,exit=r.returncode,log_sha256=sha(logfile)))
    print(json.dumps(records[-1]),flush=True)
    if r.returncode:
        print(logfile.read_bytes().decode('gb18030',errors='replace')[-2600:],flush=True)
        if r.returncode==2:break # A common invocation error precedes compilation.
for n,h in m['files'].items():assert sha(out/n)==h,n
(out/'build/compile-only/results.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
raise SystemExit(1 if any(r['exit'] for r in records) else 0)
