from pathlib import Path
import argparse,json,subprocess,re
from build import RC,GAME,JAVA,sha,inventory,save,Registration
p=argparse.ArgumentParser();p.add_argument('candidate',type=Path);a=p.parse_args();out=a.candidate.resolve()
assert out.is_relative_to(RC/'build')
meta=json.loads((out/'compile.json').read_text('utf8'))
assert meta['compiled'] and sha(out/'RConnectMod.swf')==meta['candidate_sha256']
assert inventory(out/'src')==meta['source']
tool=GAME/'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
cmd=[str(JAVA),'-Xmx256m','-jar',str(tool),'-dumpAS3',str(out/'RConnectMod.swf')]
result={'passed':False,'candidate_sha256':meta['candidate_sha256'],'command':cmd,'tool_sha256':sha(tool)}
with Registration(owner='RConnect / 视觉候选核对',purpose='Read compiled definitions only',run_dir=out,evidence=out/'class-audit.json',wait=300) as reg:
 try:
  with (out/'classes.txt').open('x',encoding='utf8') as log:
   proc=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);reg.child(proc.pid)
   try:assert proc.wait(timeout=120)==0
   finally:
    if proc.poll() is None:proc.kill();proc.wait()
    reg.child_stopped()
  actual={m.group(1) for m in re.finditer(r'^([\w.]+)\s+\d+\s*$',(out/'classes.txt').read_text('utf8',errors='replace'),re.M)}
  expected={Path(s).with_suffix('').as_posix().replace('/','.') for s in meta['source']}
  native={p.relative_to(out/'stubs').with_suffix('').as_posix().replace('/','.') for p in (out/'stubs').rglob('*.as')}
  assert actual==expected,(sorted(actual-expected),sorted(expected-actual))
  assert not actual&native
  result.update(passed=True,classes=len(actual),native_stubs_embedded=[],source=meta['source'],log_sha256=sha(out/'classes.txt'))
  reg.outcome='passed';reg.note='Exact product definitions, no native stubs embedded'
 finally:save(out/'class-audit.json',result)
print(json.dumps({'passed':result['passed'],'classes':result.get('classes')}))
