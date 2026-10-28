"""Rebase PI's one changed Weapon.shoot source anchor onto native021.
The compiler hoists its local declarations; no semantic B code is removed.
"""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=HERE/'injury-sources-01';out=HERE/'injury-native-sources-02'
if out.exists():raise FileExistsError('Keep previous native source revisions immutable')
patch=(source/'patch-native.cjs').read_text(encoding='utf-8')
a=" r('         var _loc3_:* = 0;\\n         while(_loc3_ < this.kol)','         var piShotId:Number = Number(World.w.pers.piEvent(\"shot\"));\\n         var _loc3_:* = 0;\\n         while(_loc3_ < this.kol)');"
b=" r('         _loc3_ = 0;\\n         while(_loc3_ < this.kol)','         var piShotId:Number = Number(World.w.pers.piEvent(\"shot\"));\\n         _loc3_ = 0;\\n         while(_loc3_ < this.kol)');"
if patch.count(a)!=1:raise ValueError('Original Weapon patch anchor changed')
out.mkdir();(out/'patch-native.cjs').write_text(patch.replace(a,b),encoding='utf-8')
(out/'MethodPatch.java').write_bytes((source/'MethodPatch.java').read_bytes())
proof=dict(kind='pi-native021-source-rebase',parent_patch_sha256=sha(source/'patch-native.cjs'),
  native021_export_sha256=sha(source/'native-03/host/scripts/fe/weapon/Weapon.as'),
  files={p.name:sha(p) for p in out.iterdir()},change='Weapon.shoot declares _loc3_ at method top; replace its single assignment before pellet loop, preserving declaration.')
(out/'prepared.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding='utf-8')
print(out)
