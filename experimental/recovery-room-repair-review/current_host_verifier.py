"""Historical driver/build proofs and two exact, independently deployed runtime changes."""
from pathlib import Path
import sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import current_rv_verifier as rv
ROOT,M52,GAME,RUNNER,PINNED=rv.ROOT,rv.M52,rv.GAME,rv.RUNNER,rv.PINNED
sha,read,save=rv.sha,rv.read,rv.save
HERE=Path(__file__).resolve().parent
RECEIPT=rv.RECEIPT
HOST_RECEIPT=GAME/'mods/ContinuousScene/state/vertical-camera-band-deployment-20261023.json'
HOST_PROOF=GAME/'mods/ContinuousScene/build/generated/vertical-camera-band-20261023'
OLD_HOST='80cfd8cf3138ee59cbf6eda0a1824a9ec960f413bd95e4b90d41dd0322b4fd3d'
NEW_HOST='abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a'
PROOF_PINS={
 HERE/'current_rv_verifier.py':'a12bd5788bfb3ddf7634c9115fe9784934bc7880d24748222de1b533b9df4c8b',
 RECEIPT:'e35627492493e90d92a28204f3ef1fa683651866570f8b55b6f23a1c78ec8eb3',
 HOST_RECEIPT:'df8ffe32a96488b3efc839d50bce86f7b6c44456ab682987b69df4ac91dc8dd1',
 HOST_PROOF/'build.json':'5b37b61e1552082022a423adfb24597360010ebf9eea8b8d44fe1defdcb85e5f',
 HOST_PROOF/'semantic-audit.json':'f8147e6f0e6939e65387f5a15fe9e80322ef925a306096f8816a490f401ae4b1',
 HOST_PROOF/'release-qualification.json':'399404c3e9cc985a141f46ef90645b069435090d073db62acbccffe9f2f48800'}
PRODUCT=M52/'recovery-room-production-04'
PRODUCT_SHA='34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703'
PRODUCT_PREPARED='093916cf37eb1502fbc3b63f88da208d680e8314a4903840807fc0e09a775807'
PRODUCT_COMPILE='3cde928e206d5083ea826c8b62b05ad206ea2ad311e2c2e0875ae7e2e994e370'

def historical():
 value=rv.historical();assert value['pfe.swf']==OLD_HOST
 return value

def build_environment():
 """The actual roomfix4 compile environment, never relabelled as the new host."""
 value=dict(historical());value[rv.RV]=rv.NEW_RV
 return value

def proof_inputs():
 for path,digest in PROOF_PINS.items():assert sha(path)==digest,str(path)
 host=read(HOST_RECEIPT);vision=read(RECEIPT)
 assert vision['result']=='PASS' and vision['old']==rv.OLD_RV and vision['new']==rv.NEW_RV
 assert vision['own_process_closed'] is True and vision['descriptor_removed'] is True
 assert host['status']=='verified' and host['target']=='pfe.swf'
 assert host['before'].lower()==OLD_HOST and host['after'].lower()==NEW_HOST
 assert host['productionHasTelemetry'] is False
 assert Path(host['sourceBuild']).resolve()==(HOST_PROOF/'build.json').resolve()
 assert host['sourceBuildSHA256'].lower()==PROOF_PINS[HOST_PROOF/'build.json']
 assert host['semanticAuditSHA256'].lower()==PROOF_PINS[HOST_PROOF/'semantic-audit.json']
 assert Path(host['qualificationPath']).resolve()==(HOST_PROOF/'release-qualification.json').resolve()
 assert host['qualificationSHA256'].lower()==PROOF_PINS[HOST_PROOF/'release-qualification.json']
 before={n:h.lower() for n,h in host['baseline'].items()}
 after={n:h.lower() for n,h in host['installed'].items()}
 expected=dict(before);expected['pfe.swf']=NEW_HOST
 assert before['pfe.swf']==OLD_HOST and after==expected,'CS receipt contains an additional deployment change'
 for n,h in build_environment().items():assert before[n]==h,n
 audit=read(HOST_PROOF/'semantic-audit.json')
 assert audit['passed'] is True and audit['baseSHA256'].lower()==OLD_HOST and audit['candidateSHA256'].lower()==NEW_HOST
 assert audit['allowedChangedMethods']==audit['actualChangedBodies']==['fe.inter.Camera::0:1:calc']
 for name in ('methodAndClassIndicesPreserved','originalConstantPoolPreserved','nonABCSWFEnvelopePreserved',
              'preservedOriginalLayout','constructorsPreserved','priorLightingPatchPreserved','productionCandidate'):
  assert audit[name] is True,name
 assert audit['addedFields']==[] and audit['addedMethods']==[] and audit['importedClassCopied'] is False
 qualification=read(HOST_PROOF/'release-qualification.json')
 assert qualification['passed'] is True and qualification['baselineHostSHA256'].lower()==OLD_HOST
 assert qualification['candidateHostSHA256'].lower()==NEW_HOST
 assert qualification['sourceBuildSHA256'].lower()==PROOF_PINS[HOST_PROOF/'build.json']
 assert qualification['semanticAuditSHA256'].lower()==PROOF_PINS[HOST_PROOF/'semantic-audit.json']
 pins={str(p):h for p,h in PROOF_PINS.items()}
 for n,h in host['sourceInputs'].items():
  assert sha(n)==h.lower(),n
  pins[n]=h.lower()
 return pins

def installation():
 proof_inputs()
 sys.path.insert(0,str(ROOT/'tools/validation'))
 from run_security_terminals import installation as inventory
 expected=build_environment();expected['pfe.swf']=NEW_HOST
 current=inventory();assert current==expected,'Runtime changed outside RV 6DBA -> 0DBE and host 80CF -> ABE2'
 return current

def verify(out):
 out=Path(out).resolve();assert out in (rv.BASE,rv.SCENE)
 # Reuse only the historical artifact checks; rv.verify requires its old host.
 for n,h in rv.old.inputs().items():assert sha(n)==h,n
 base=rv.artifacts(rv.BASE,rv.BASE_SHA,'current-installed-room12-compatible-driver',2)
 if out==rv.BASE:m=base
 else:
  m=rv.artifacts(rv.SCENE,rv.SCENE_SHA,'room-scene-preconnection-preference-driver',1)
  assert m['ordinary_timing_byte_exact'] is True
  assert sha(HERE/'prepare_scene_v2.py')=='1b644d79fffa7fbbdc4573b8e94374df7311fbe790036b5bd38f73cd55afae91'
  for n in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):assert sha(rv.SCENE/'tests'/n)==sha(rv.BASE/'tests'/n)
  assert sha(rv.SCENE/'timing/EffectsDriver.swf')==sha(rv.BASE/'timing/EffectsDriver.swf')
 installation();return m

def verify_product(path=PRODUCT):
 path=Path(path).resolve();assert path==PRODUCT.resolve()
 assert sha(path/'prepared.json')==PRODUCT_PREPARED and sha(path/'compile.json')==PRODUCT_COMPILE
 built=read(path/'compile.json');prepared=read(path/'prepared.json')
 assert built['compiled'] is True and built['sources_unchanged'] is True and built['installation_unchanged'] is True
 assert len(built['commands'])==2 and all(c['exit_code']==0 for c in built['commands'])
 assert built['installation_before']==built['installation_after']==build_environment()
 assert sha(path/'RConnectMod.swf')==built['candidate_sha256']==PRODUCT_SHA
 assert prepared['kind']=='room-repair-overlay' and prepared['version']=='0.2.24-roomfix4'
 assert prepared['base_sha256']==historical()['mods/Rconnect/release/RConnectMod.swf']
 for n,h in prepared['source'].items():assert sha(path/'src'/n)==h,n
 installation();return built

def evidence():
 return dict(kind='historic-room-driver-current-host-rv-runtime',historical_driver_installation=historical(),
  roomfix4_compile_installation=build_environment(),runtime_installation=installation(),
  exact_changes=[dict(path=rv.RV,before=rv.OLD_RV,after=rv.NEW_RV),dict(path='pfe.swf',before=OLD_HOST,after=NEW_HOST)],
  proof_inputs=proof_inputs(),old_verifier_reused_as_current_qualification=False,
  compile_relabelled_as_current_runtime=False)
