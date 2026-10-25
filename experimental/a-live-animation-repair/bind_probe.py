"""Reuse exact external test bytes against a same-API candidate; keep origin receipts."""
from pathlib import Path
import json,shutil,sys
from build_probe import ROOT,sha,save
origin=(ROOT/sys.argv[1]).resolve();candidate=(ROOT/sys.argv[2]).resolve();out=(ROOT/sys.argv[3]).resolve()
assert origin.parent==candidate.parent.parent==out.parent==ROOT/'build/m52' and not out.exists()
receipt=json.loads((origin/'compile.json').read_text('utf8'))
assert receipt['compiled'] and receipt['reaped'] and receipt['installation_unchanged']
assert sha(origin/'EffectsDriver.swf')==receipt['driver_sha256']
product=json.loads((candidate.parent/'compile.json').read_text('utf8'))
assert product['compiled'] and product['reaped'] and sha(candidate)==product['candidate_sha256']
source=json.loads((candidate.parent/'prepared.json').read_text('utf8'))
assert set(source['overlay'])=={'RConnectMod.as','rconnect/game/GameBridge.as','rconnect/game/UnitPresentation.as','rconnect/game/ProjectileVisuals.as','rconnect/game/RemoteMotion.as'}
# The only changed public declaration adds an optional argument; existing probe
# calls are dynamic, and its referenced public fields/types remain unchanged.
out.mkdir()
for name in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(origin/name,out/name)
save(out/'driver-input.json',dict(candidate_sha256=sha(candidate),reused_from=str(origin),
 origin_compile_sha256=sha(origin/'compile.json'),driver_sha256=sha(out/'EffectsDriver.swf'),
 harness_sha256=sha(out/'EffectsHarness.swf'),candidate_prepared_sha256=sha(candidate.parent/'prepared.json')))
print(str(out))
