"""Cheap structural/model checks only; not an AS compiler or runtime verdict."""
import ast
import hashlib
import itertools
import json
from pathlib import Path
from prepare import BASE, HERE, method, sha, write


def main():
    audit=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
    for name, entry in audit['files'].items():
        assert sha(BASE/'rconnect'/name)==entry['base_sha256']
        assert sha(HERE/'src/rconnect'/name)==entry['overlay_sha256']
    unchanged={
        'game/UnitPresentation.as':['capture','observeWeapon','captureMotion','observeFinal','captureFlight'],
        'game/EnergyImpactVisuals.as':['capture','observeWeapon','receive'],
        'game/ProjectileFrameStream.as':['samePoint','after','merge','receiveClock','sourceTime','shiftClock'],
        'game/WallImpactVisuals.as':['observe','report','updates','sentUpdates','acknowledge','receive','packed'],
        'game/GameBridge.as':['readTilePatch','scanWallReports'],
    }
    verified=[]
    for name, methods in unchanged.items():
        old=(BASE/'rconnect'/name).read_text(encoding='utf-8-sig')
        new=(HERE/'src/rconnect'/name).read_text(encoding='utf-8-sig')
        for item in methods:
            assert method(old,item)==method(new,item),(name,item)
            verified.append(name+'::'+item)
    for file in HERE.glob('*.py'):ast.parse(file.read_text(encoding='utf-8'))
    for file in (HERE/'components').rglob('*.as'):
        text=file.read_text(encoding='utf-8')
        assert text.count('{')==text.count('}'),file
    # Exhaustive finite point MODEL: index/order are compared, including two
    # thresholds (missing fastAt's old null->0 revision behavior). Actual AS
    # field/value semantics and whole capture output are the pending component.
    cases=0
    alphabet=[(0,0),(1,0),(1,1),(2,0),(2,1)]
    for length in range(7):
        for frames in itertools.product(alphabet,repeat=length):
            for threshold,revision,previous in [(1,1,(1,0)),(-float('inf'),0,(0,0)),(1,1,None),(2,1,(1,0))]:
                old=[i for i,p in enumerate(frames) if p[0]>threshold]
                if previous is not None:
                    for i,p in enumerate(frames):
                        if p[0]==revision and p!=previous:
                            old.insert(0,i);break
                new=[];changed=None
                for i,p in enumerate(frames):
                    if p[0]>threshold:new.append(i)
                    if changed is None and previous is not None and p[0]==revision and p!=previous:changed=i
                if changed is not None:new.insert(0,changed)
                assert old==new,(frames,threshold,revision,previous,old,new)
                cases+=1
    result=dict(unchanged_methods=verified,finite_order_model_cases=cases,
        source_extraction_checked=True,AS_compiled=False,AS_component_run=False,
        JVM_started=False,AIR_started=False,
        note='Python finite input model is not an AS runtime equivalence or performance result.')
    result['files']={f.relative_to(HERE).as_posix():sha(f) for f in HERE.rglob('*')
        if f.is_file() and f.name!='static-checks.json' and '__pycache__' not in f.parts}
    write('static-checks.json',json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('files','unchanged_methods')}))


if __name__=='__main__':main()
