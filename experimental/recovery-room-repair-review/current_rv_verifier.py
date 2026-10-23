"""Retain historic driver provenance; admit exactly one current runtime RV change."""
from pathlib import Path
import sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import prepare as old
ROOT,M52,GAME,RUNNER,PINNED=old.ROOT,old.M52,old.GAME,old.RUNNER,old.PINNED
sha,read,save=old.sha,old.read,old.save
HERE=Path(__file__).resolve().parent
BASE=M52/'recovery-room-current-driver-01';SCENE=M52/'recovery-room-scene-driver-02'
BASE_SHA='34364016738c79140b8354769e7e0c1d1980b31368d4e50e7c20e45fa2ba075e'
SCENE_SHA='bd4d38143b3b2f6bbba4d0e457cec4c69962e460150bde821ae1f97cf0d1959c'
RV='mods/RealisticVision/release/RealisticVisionMod.swf'
OLD_RV='6dbbae60eb09ff8f42d34e31edc92fb9f83009ba918e9145980c6d289723d8ba'
NEW_RV='0dbe0d7a95b8e496fb393d7fcd75f88d60c34a1d0fabb33266b122e3fa04f2bf'
RECEIPT=GAME/'mods/RealisticVision/knowledge/experiments/effect-visibility-v0338-20261023/deployment/receipt.json'
def historical():
 assert sha(BASE/'prepared.json')==BASE_SHA
 value=read(BASE/'prepared.json')['installation_before']
 assert len(value)==22 and value[RV]==OLD_RV
 return value
def installation():
 sys.path.insert(0,str(ROOT/'tools/validation'))
 from run_security_terminals import installation as inventory
 before=historical();expected=dict(before);expected[RV]=NEW_RV
 current=inventory();assert current==expected,'Runtime changed outside the exact RV 6DBA -> 0DBE transition'
 receipt=read(RECEIPT)
 assert receipt['result']=='PASS' and receipt['old']==OLD_RV and receipt['new']==NEW_RV
 assert receipt['own_process_closed'] is True and receipt['descriptor_removed'] is True
 return current
def artifacts(out,digest,kind,commands):
 assert sha(out/'prepared.json')==digest
 m=read(out/'prepared.json');assert m['kind']==kind and m['compiled'] is True and m['external'] is True
 assert len(m['commands'])==commands and all(c['exit_code']==0 for c in m['commands'])
 assert m['installation_before']==historical()
 for n,h in m['inputs'].items():assert sha(n)==h,n
 for n,h in m['files'].items():assert sha(out/n)==h,n
 return m
def verify(out):
 out=Path(out).resolve();assert out in (BASE,SCENE)
 # old.inputs has no current-installation assertion; it verifies the exact
 # original room12 closure. Do not call old.verify and pretend it admitted RV.
 for n,h in old.inputs().items():assert sha(n)==h,n
 base=artifacts(BASE,BASE_SHA,'current-installed-room12-compatible-driver',2)
 if out==BASE:m=base
 else:
  m=artifacts(SCENE,SCENE_SHA,'room-scene-preconnection-preference-driver',1)
  assert m['ordinary_timing_byte_exact'] is True
  assert sha(HERE/'prepare_scene_v2.py')=='1b644d79fffa7fbbdc4573b8e94374df7311fbe790036b5bd38f73cd55afae91'
  for n in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):assert sha(SCENE/'tests'/n)==sha(BASE/'tests'/n)
  assert sha(SCENE/'timing/EffectsDriver.swf')==sha(BASE/'timing/EffectsDriver.swf')
 installation();return m
def evidence():
 return dict(kind='historic-driver-current-rv-runtime',historical_installation=historical(),runtime_installation=installation(),
  sole_change=dict(path=RV,before=OLD_RV,after=NEW_RV),deployment_receipt=str(RECEIPT),deployment_receipt_sha256=sha(RECEIPT),
  old_verifier_reused_as_current_qualification=False)
