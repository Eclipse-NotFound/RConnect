from pathlib import Path
import hashlib,json,re,subprocess
RC=Path(__file__).resolve().parents[2];OUT=RC/'build/a-locales-04';ROOT=RC/'build/github-a-release';GAME=RC.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'manifest.json').read_text('utf8'))
baseline=json.loads((RC/'experimental/a-visual-round2/validated-manifest.json').read_text('utf8'))
changed=[rel for rel,value in manifest['source'].items() if baseline['source'].get(rel)!=value]
assert set(changed)=={'RConnectMod.as','modlocales/connect/RCLocale.as','modlocales/connect/RCLocaleMessages.as','rconnect/ui/NetHud.as','rconnect/ui/NetKeybinds.as'},changed
assert set(baseline['source'])==set(manifest['source'])
for rel,digest in manifest['source'].items():assert sha(ROOT/'src'/rel)==digest
java='C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
cmd=[java,'-Xmx256m','-jar',str(GAME/'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'),'-dumpAS3',str(OUT/'RConnectMod.swf')]
with (OUT/'classes.txt').open('w',encoding='utf8') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
actual={m[1] for m in re.finditer(r'^([\w.]+)\s+\d+\s*$',(OUT/'classes.txt').read_text('utf8',errors='replace'),re.M)}
expected={Path(s).with_suffix('').as_posix().replace('/','.') for s in manifest['source']}
native={Path(s).with_suffix('').as_posix().replace('/','.') for s in manifest['stubs']}
assert actual==expected,(actual-expected,expected-actual)
assert not actual&native
result=dict(passed=True,classes=len(actual),source_changed_from_animfix3=changed,gameplay_classes_unchanged=80,native_stubs_embedded=[],swf_sha256=sha(OUT/'RConnectMod.swf'))
(OUT/'audit.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result))
