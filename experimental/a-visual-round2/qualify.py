"""Pin the functional evidence and explicit limits for the local release."""
import json
from build import RC,HERE,sha,save,inventory

FINAL=RC/'build/m52/visual2-combined-04'
PREVIOUS=RC/'build/m52/visual2-combined-03'
FINAL_HASH='eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127'
PRIOR_HASH='1421a3877d4b0e657200ca4b52f86049488b1885a8bb05df800359fb3250fd05'
meta=json.loads((FINAL/'compile.json').read_text('utf8'))
assert meta['compiled'] and sha(FINAL/'RConnectMod.swf')==meta['candidate_sha256']==FINAL_HASH
assert inventory(FINAL/'src')==meta['source']
audit=json.loads((FINAL/'class-audit.json').read_text('utf8'))
assert audit['passed'] and audit['candidate_sha256']==FINAL_HASH and audit['classes']==85
before=inventory(PREVIOUS/'src');after=inventory(FINAL/'src')
changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
assert changed==['rconnect/game/MeleeVisuals.as','rconnect/game/UnitPresentation.as']
assert inventory(PREVIOUS/'stubs')==inventory(FINAL/'stubs')
evidence={}
for run,expected in [('2e24094452',FINAL_HASH),('02364cdc46',PRIOR_HASH),('737e1ba68c',PRIOR_HASH),('a7a84ad6d5',PRIOR_HASH)]:
 folder=RC/'build/cooperation'/run
 proof=json.loads((folder/'result.json').read_text('utf8'));inputs=json.loads((folder/'input.json').read_text('utf8'))
 assert proof['passed'] and proof['installation_unchanged'] and inputs['candidate_sha256']==expected
 details={}
 for role in ('host','join'):
  path=folder/'logs'/role/'stutter-result.json';data=json.loads(path.read_text('utf8'))
  assert data['completed'] and not data['error'] and data['audioVolume']==0
  assert all(c.get('ok') is True for c in data['checks'])
  if run=='a7a84ad6d5':assert data['passed']
  log=(folder/'logs'/role/'RConnect.log').read_text('utf8')
  assert 'v0.2.24-animfix3 initialized' in log and 'RConnectText:' not in log
  details[role]={'samples_sha256':sha(path),'checks':len(data['checks'])}
 evidence[run]={'candidate_sha256':expected,'result_sha256':sha(folder/'result.json'),'input_sha256':sha(folder/'input.json'),'roles':details}
component=RC/'build/m52/visual2-projectile-component-02'
assert json.loads((component/'result.json').read_text('utf8'))['passed']
assert sha(component/'src/rconnect/game/ProjectilePlayback.as')==sha(FINAL/'src/rconnect/game/ProjectilePlayback.as')
feedback=HERE.parent/'a-visual-round2-feedback/analysis/02364cdc46.json'
assert not json.loads(feedback.read_text('utf8'))['failed']
reports=[feedback,HERE.parent/'a-visual-round2-weapons/analysis/b49865e3c1-vs-2e24094452.json',
 HERE.parent/'a-visual-round2-weapons/analysis/melee-suffix-equivalence.json',
 HERE.parent/'a-visual-round2-projectiles/tests/analysis-a7a84ad6d5-vs-44a160a7a9.json']
result=dict(passed=True,candidate_sha256=FINAL_HASH,source=after,evidence=evidence,
 reports={str(p.relative_to(RC)):sha(p) for p in reports},component_result_sha256=sha(component/'result.json'),
 carry_forward={'from_sha256':PRIOR_HASH,'changed_classes':changed,
  'reason':'Only high-frequency WClub history window changes; full capture and receiver unchanged. Final exact-byte weapon run validates this path. Terrain, native feedback, projectile playback and all other source/stub bytes are identical.'},
 limitations=['No general FPS or absence-of-regression qualification: coexist single runs have mixed long-frame results.',
  'Ordinary bullets still inherit occasional whole-frame stalls; no complete stutter-resolution claim.',
  'Feedback probe executes native damageWall, not complete E-key input; final t_throw=1 input was not independently logged.',
  'Seven alicorn shots support only narrow lightning continuity evidence.'])
save(FINAL/'release-qualification.json',result)
print(json.dumps({'passed':True,'candidate_sha256':FINAL_HASH,'runtime_runs':list(evidence)}))
