"""Reuse exact final production bytes after test-only changes; never promote probes."""
import argparse, json, shutil, subprocess, sys
from pathlib import Path
from validation_baseline import ROOT, sha, read, verify_protected

ap=argparse.ArgumentParser()
ap.add_argument('--from-snapshot',type=Path,required=True)
ap.add_argument('--snapshot',type=Path,required=True)
a=ap.parse_args();old,out=a.from_snapshot.resolve(),a.snapshot.resolve()
for path in (old,out):assert path.parent==ROOT/'build/m50' and path.name.startswith('final')
assert old!=out
before,m=read(old/'source-input.json'),read(out/'source-input.json')
ov,nv=read(old/'verified-test-input.json'),read(out/'verified-test-input.json')
assert before['version']==m['version']=='0.2.22-dev' and before['source']==m['source']
verify_protected(m)
for n,h in m['source'].items():assert sha(ROOT/n)==sha(old/n)==sha(out/n)==h,n
for n,h in nv.items():assert sha(ROOT/n)==sha(out/'verified-files'/n)==h,n
for n,h in ov.items():
    assert sha(old/'verified-files'/n)==h,n
    if n.startswith('tools/stubs/') or n in ('tools/build_mod.py','tools/build_effects_driver.py'):
        assert nv[n]==h,n
assert sha(old/'RConnectMod.swf')==before['candidate_sha256'] and before['build_exit']==0
assert sha(old/'GameCombatStubs.swc')==sha(ROOT/'build/GameCombatStubs.swc')==before['stub_sha256']
assert sha(old/'classes.txt')==before['class_list_sha256']
for n in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):
    assert not (out/n).exists();shutil.copy2(old/n,out/n)
(out/'candidate-reuse.json').write_text(json.dumps(dict(kind='exact final bytes, not a new compile',
    origin=old.relative_to(ROOT).as_posix(),production_sha256=before['candidate_sha256'],
    origin_manifest_sha256=sha(old/'source-input.json')),indent=2),encoding='utf-8')
subprocess.run([sys.executable,'-X','utf8',str(ROOT/'tools/validation/prepare_m50.py'),'built',str(out)],check=True,cwd=ROOT)
