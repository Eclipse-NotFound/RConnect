"""Attach an exact prior SWF to an unbuilt diagnostic freeze with identical source.

Only negative/probe snapshots are accepted. This is not a production rebuild
or a way to carry runtime checks between different inputs.
"""
import argparse, json, shutil
from validation_baseline import ROOT, read, sha, verify_protected
ap=argparse.ArgumentParser();ap.add_argument('snapshot');ap.add_argument('origin');a=ap.parse_args()
out=(ROOT/a.snapshot).resolve();origin=(ROOT/a.origin).resolve()
assert out.parent==origin.parent==ROOT/'build/m51'
assert out.name.startswith(('red-','probe-'))
m=read(out/'source-input.json');old=read(origin/'source-input.json');verify_protected(m)
assert m['source']==old['source'] and m['version']==old['version']
assert sha(origin/'RConnectMod.swf')==old['candidate_sha256']
assert 'candidate_sha256' not in m and not (out/'RConnectMod.swf').exists()
for n,h in {**m['source'],**m['verification']}.items():assert sha(out/n)==h,n
for n,h in old['source'].items():assert sha(origin/n)==h,n
for n in ('RConnectMod.swf','GameCombatStubs.swc','classes.txt'):
    shutil.copy2(origin/n,out/n)
(out/'build').mkdir(exist_ok=True)
shutil.copy2(origin/'GameCombatStubs.swc',out/'build/GameCombatStubs.swc')
for k in ('candidate_sha256','build_exit','size','classes','stub_sha256','class_list_sha256'):m[k]=old[k]
m['reuse']={'origin':origin.relative_to(ROOT).as_posix(),'source_manifest_sha256':sha(origin/'source-input.json'),
    'scope':'Exact previously compiled bytes; no recompile and no reused runtime results'}
(out/'source-input.json').write_text(json.dumps(m,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'snapshot':str(out),'sha256':m['candidate_sha256'],'origin':str(origin)}))
