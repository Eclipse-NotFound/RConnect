"""Record the observed WallBlend update as a new diagnostic integration input.

No baseline is overwritten and no installation file is changed. These inputs
need a fresh installed-22 control; old successes do not qualify this transition.
"""
import copy,json
from validation_baseline import ROOT,GAME,M51_BASELINE,M51_MAP_BASELINE,read,sha
old=read(ROOT/M51_BASELINE/'inputs.json')
changes={n:dict(before=h,after=sha(GAME/n)) for n,h in old['protected'].items() if sha(GAME/n)!=h}
expected={'mods/WallBlend/release/WallBlendMod.swf':dict(
    before='b4cf9a3d9cd45da2174fe56dc924ccda2c12b10ebe7caf2e8dcec08ac9952bc7',
    after='1bb9b65af80a946f6758824a72eed941173d0ae40b8c09c084ecf12b92458820')}
assert changes==expected,changes
m=copy.deepcopy(old)
for n,pair in changes.items():
    m['protected'][n]=pair['after']
    for k in m['runtime_modules']:
        if k.replace('\\','/').lower()==n.lower():m['runtime_modules'][k]=pair['after']
m.update(diagnostic_only=True,previous_baseline=M51_BASELINE,
    previous_baseline_sha256=sha(ROOT/M51_BASELINE/'inputs.json'),
    observed_external_transition=changes,transition_validated=False,
    purpose='Native map diagnosis after an external WallBlend deployment; requires fresh old/new controls')
out=ROOT/M51_MAP_BASELINE;out.mkdir(exist_ok=False)
(out/'inputs.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(path=str(out),protected=len(m['protected']),changes=changes),ensure_ascii=False))
