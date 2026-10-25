"""Classify an already completed dump; preserve its failed parser receipt."""
from pathlib import Path
import json,re,sys
from build_probe import ROOT,sha,save,installation
from build_product import inventory,BASE
out=(ROOT/sys.argv[1]).resolve();assert out.parent==ROOT/'build/m52'
previous=json.loads((out/'class-audit.json').read_text('utf8'))
meta=json.loads((out/'prepared.json').read_text('utf8'))
assert previous['exit_code']==0 and previous['reaped'] and previous['installation_unchanged']
assert previous['candidate_sha256']==sha(out/'RConnectMod.swf')
assert inventory(out/'src')==meta['source']
listing=(out/'classes.txt').read_text('utf-8',errors='replace')
matches=re.findall(r'^([\w.]+)\s+(\d+)\s*$',listing,re.M)
actual={name for name,index in matches}
expected={Path(p).with_suffix('').as_posix().replace('/','.') for p in meta['source']}
native={p.relative_to(BASE/'tools/stubs').with_suffix('').as_posix().replace('/','.') for p in (BASE/'tools/stubs').rglob('*.as')}
assert actual==expected and not actual.intersection(native)
assert len(matches)==len(expected) and sorted(int(i) for n,i in matches)==list(range(len(expected)))
save(out/'class-audit-review.json',dict(passed=True,previous_receipt_sha256=sha(out/'class-audit.json'),
 original_parser_passed=previous['passed'],listing_sha256=sha(out/'classes.txt'),candidate_sha256=sha(out/'RConnectMod.swf'),
 classes=sorted(actual),native_stubs_embedded=[],parser=sha(__file__),new_processes_started=False,
 note='Re-read existing successful FFDec dump. Its logging warning and failed utf8-sig parser receipt remain unchanged.'))
print(json.dumps(dict(passed=True,classes=len(actual),new_processes_started=False)))
