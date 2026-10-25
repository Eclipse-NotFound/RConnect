"""Read compiled definitions; reject native stub/test classes before release."""
from pathlib import Path
import json,subprocess,sys,re
from build_probe import ROOT,GAME,JAVA,SDK,sha,save,installation,snapshot,wait_owned,Registration
from build_product import inventory,BASE
out=(ROOT/sys.argv[1]).resolve();assert out.parent==ROOT/'build/m52'
meta=json.loads((out/'prepared.json').read_text('utf8'));receipt=json.loads((out/'compile.json').read_text('utf8'))
assert receipt['compiled'] and receipt['reaped'] and receipt['installation_unchanged']
assert inventory(out/'src')==meta['source'] and sha(out/'RConnectMod.swf')==receipt['candidate_sha256']
assert set(meta['overlay'])=={'RConnectMod.as','rconnect/game/GameBridge.as','rconnect/game/UnitPresentation.as','rconnect/game/ProjectileVisuals.as','rconnect/game/RemoteMotion.as'}
before=installation();tool=GAME/'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
command=[str(JAVA),'-Xmx256m','-jar',str(tool),'-dumpAS3',str(out/'RConnectMod.swf')]
result=dict(passed=False,command=command,tool_sha256=sha(tool),candidate_sha256=sha(out/'RConnectMod.swf'),installation_before=before)
try:
 with Registration(owner='RConnect / 动画发布核对',purpose='Inspect candidate class definitions; no AIR',run_dir=out,evidence=out/'class-audit.json',wait=900) as reg:
  assert snapshot()['free_commit_bytes']>=1024**3;proc=None
  try:
   reg.before_launch('Read-only candidate class inspection')
   with (out/'classes.txt').open('x',encoding='utf8') as log:
    proc=subprocess.Popen(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    result['pid']=proc.pid;reg.child(proc.pid);result['exit_code']=wait_owned(proc,300,out/'class-audit-memory.json')
   assert result['exit_code']==0
  finally:
   if proc is not None:
    if proc.poll() is None:proc.kill()
    proc.wait();result['reaped']=True;reg.child_stopped()
  actual={m.group(1) for m in re.finditer(r'^([\w.]+)\s+\d+\s*$',(out/'classes.txt').read_text('utf-8',errors='replace'),re.M)}
  expected={p.with_suffix('').as_posix().replace('/','.') for p in map(Path,meta['source'])}
  native={p.relative_to(BASE/'tools/stubs').with_suffix('').as_posix().replace('/','.') for p in (BASE/'tools/stubs').rglob('*.as')}
  assert actual==expected,(sorted(actual-expected),sorted(expected-actual))
  assert not actual.intersection(native) and not any('Probe' in n and n not in expected for n in actual)
  assert installation()==before and inventory(out/'src')==meta['source']
  result.update(passed=True,classes=sorted(actual),native_stubs_embedded=[],air_started=False);reg.outcome='passed';reg.note='Exact source definitions; native stubs absent. Gameplay gate separate.'
finally:
 result['installation_after']=installation();result['installation_unchanged']=result['installation_after']==before;save(out/'class-audit.json',result)
print(json.dumps({k:result[k] for k in ('passed','reaped','exit_code','installation_unchanged')}))
