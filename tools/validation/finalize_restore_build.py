import hashlib,json,shutil,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=(root/sys.argv[1]).resolve()
assert out.parent==root/'build/m46' and out.name.startswith('final')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=out/'source-input.json';m=json.loads(p.read_text(encoding='utf-8'))
for n,d in m['source'].items():assert sha(root/n)==sha(out/n)==d,n
actual={s.split()[0] for s in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if s.strip()}
expected={s.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for s in (out/'src').rglob('*.as')}
assert actual==expected,(actual-expected,expected-actual)
shutil.copy2(root/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
m.update(candidate_sha256=sha(out/'RConnectMod.swf'),size=(out/'RConnectMod.swf').stat().st_size,
   stub_sha256=sha(out/'GameCombatStubs.swc'),classes=len(actual),class_list_sha256=sha(out/'classes.txt'),build_exit=0,
   compiled_candidate_origin=out.relative_to(root).as_posix()+'/RConnectMod.swf')
p.write_text(json.dumps(m,indent=2),encoding='utf-8')
for n,d in json.loads((root/'build/m46/integration-baseline/inputs.json').read_text(encoding='utf-8'))['protected'].items():assert sha(root.parents[1]/n)==d,n
print(json.dumps({k:m[k] for k in ('candidate_sha256','size','classes','stub_sha256')}))
