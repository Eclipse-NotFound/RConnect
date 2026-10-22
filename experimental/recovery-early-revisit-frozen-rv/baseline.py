"""One explicit installed RV transition; the isolated test still uses the old RV."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
RV_KEY='mods/RealisticVision/release/RealisticVisionMod.swf'
RV_OLD='7852f61e083993e69431d5d8ca2fdf3c07d4068715946d04b3e796cecbe86764'
RV_NEW='ab461ff3bdf77544bfb3e7f45b67265429d52280721fa8b8321ba92be2f23871'
RV_PATH=ROOT.parent/'RealisticVision/build/backups/before-combat-visibility-20261022-182545-6d09e8/RealisticVisionMod.before.swf'
DEPLOYMENT=ROOT.parent/'RealisticVision/build/combat-visibility-output/deployment/receipt.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def assert_current(current,original):
    assert len(current)==len(original)==22
    assert original[RV_KEY]==RV_OLD and current[RV_KEY]==RV_NEW
    expected=dict(original);expected[RV_KEY]=RV_NEW
    assert current==expected,'Only the explicitly pinned RV deployment may differ'
def frozen_vision():
    assert RV_PATH.is_file() and RV_PATH.stat().st_size==41630 and sha(RV_PATH)==RV_OLD
    receipt=json.loads(DEPLOYMENT.read_text(encoding='utf-8-sig'))
    assert receipt['old']==RV_OLD and receipt['new']==RV_NEW and receipt['result']=='PASS'
    assert receipt['backup'].replace('\\','/')=='build/backups/before-combat-visibility-20261022-182545-6d09e8/RealisticVisionMod.before.swf'
    return RV_PATH
