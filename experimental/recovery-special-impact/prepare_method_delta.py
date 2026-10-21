"""Generate a review-only method delta on frozen recovery05; never write it."""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
BASE = RC/'build/m52/recovery-05/src'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def method(text, name):
    match = re.search(r'^      (?:public|private) function '+re.escape(name)+r'\(', text, re.M)
    assert match, name
    start = match.start()
    brace = text.index('{', match.end())
    depth = 1
    end = brace+1
    # These specific methods contain no unmatched braces in comments/strings.
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return start, end, text[start:end]


def replace_method(old, candidate, name):
    start, end, unused = method(old, name)
    return old[:start]+method(candidate,name)[2]+old[end:]


def main():
    output = []
    inventory = {}
    for name in ['UnitPresentation','ProjectileVisuals','ImpactEventQueue']:
        relative = f'rconnect/game/{name}.as'
        base = BASE/relative
        candidate = HERE/'src'/relative
        old = base.read_text(encoding='utf-8')
        proposal = candidate.read_text(encoding='utf-8')
        merged = old
        methods = {'UnitPresentation':['capture','captureEffects'],
                   'ProjectileVisuals':['tickBeam'],'ImpactEventQueue':['receive','tick']}[name]
        for changed in methods:
            merged = replace_method(merged,proposal,changed)
        if name == 'ImpactEventQueue':
            assert 'private function enqueue' not in old
            at = method(merged,'tick')[0]
            merged = merged[:at]+method(proposal,'enqueue')[2]+'\n'+merged[at:]
            assert method(merged,'forget')[2] == method(old,'forget')[2]
            assert 'channel:channel' in method(merged,'enqueue')[2]
            assert method(merged,'setPaused')[2] == method(old,'setPaused')[2]
        if name == 'ProjectileVisuals':
            assert method(merged,'forget')[2] == method(old,'forget')[2]
        output.extend(difflib.unified_diff(old.splitlines(True),merged.splitlines(True),
                       'recovery05/'+relative,'special-impact-on05/'+relative))
        inventory[relative] = {'base_sha256':sha(base),'proposal_sha256':sha(candidate),
                              'modified_methods':methods,'added_methods':['enqueue'] if name=='ImpactEventQueue' else [],
                              'merged_text_sha256':hashlib.sha256(merged.encode('utf-8')).hexdigest()}
    (HERE/'method-delta-on05.patch').write_text(''.join(output),encoding='utf-8')
    (HERE/'method-delta-on05.json').write_text(json.dumps({'base':str(BASE),'files':inventory,
         'integrated_written':False,'compiled':False},ensure_ascii=False,indent=2),encoding='utf-8')
    native=HERE/'native/MSWNoVisualExplosionTestDoc.as'
    external=RC/'build/m52/recovery-drivers-09/ProductionDeclarations.swc'
    stubs=RC/'build/m52/recovery-drivers-09/inputs/GameCombatStubs.swc'
    harness=RC/'build/m52/recovery-drivers-09/EffectsHarness.swf'
    (HERE/'native-plan.json').write_text(json.dumps({'entry':native.stem,'source':str(native),'source_sha256':sha(native),
         'external_only':[{'path':str(p),'sha256':sha(p)} for p in [external,stubs]],
         'harness':{'path':str(harness),'sha256':sha(harness)},'logical_rounds':2,
         'done_marker':'COOP EFFECTS DONE msw-no-visual','compiled':False,'air_started':False,
         'gameplay_damage_qualified':False,'performance_qualified':False},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'review_patch':str(HERE/'method-delta-on05.patch'),'written_to_integrated':False}))


if __name__ == '__main__':
    main()
