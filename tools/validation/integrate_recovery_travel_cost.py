"""Apply reviewed native-travel and cost deltas to recovery2 active source only.

No compiler, installation or frozen source is modified. Every planned result is
validated before the first write. The two overlapping files use exact reviewed
method anchors instead of replacing the native-travel changes wholesale.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT/'experimental/recovery-integrated'
TRAVEL = ROOT/'experimental/recovery-native-travel'
COST = ROOT/'experimental/recovery-cost'
BASE1 = ROOT/'build/m52/recovery-01/src'
BASE2 = ROOT/'build/m52/recovery-02/src'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def replace(data, old, new):
    old, new = old.encode(), new.encode()
    assert data.count(old) == 1, 'Ambiguous merge anchor: '+old.decode()
    return data.replace(old, new)


def main():
    for directory, count in [('recovery-cost-component-02',499),
                              ('recovery-native-room-component-02',50),
                              ('recovery-native-plan-component-01',33)]:
        receipt=read(ROOT/'build/m52'/directory/'receipt.json')
        assert receipt['passed'] and receipt['observed_checks']==count
        assert receipt['installation_unchanged'] and receipt['source_unchanged']
    meta=read(ACTIVE/'integration.json')
    assert meta['version']=='0.2.24-recovery2', 'Single-use source integration'
    planned={row['path']:(ACTIVE/'src'/row['path']).read_bytes() for row in meta['source']}
    assert all(digest(planned[row['path']])==row['sha256'] for row in meta['source'])
    travel=read(TRAVEL/'integration.json')
    for name, value in travel['source_inputs'].items():
        assert digest((TRAVEL/name).read_bytes())==value, name
    changes=[]
    for source in sorted((TRAVEL/'src').rglob('*.as')):
        name=source.relative_to(TRAVEL/'src').as_posix()
        if name=='RConnectMod.as':
            continue
        before=planned.get(name)
        ancestor=(BASE1/name).read_bytes() if (BASE1/name).is_file() else None
        assert before==ancestor, 'Travel layer requires an explicit overlap merge: '+name
        content=source.read_bytes()
        changes.append(dict(path=name,ancestor_sha256=digest(ancestor) if ancestor else None,
            before_sha256=digest(before) if before else None,source_sha256=digest(content),
            merged_sha256=digest(content),merge='exact delta from unchanged recovery1 ancestor'))
        planned[name]=content
    meta['layers'].append(dict(name='native-travel-with-stale-grant-guard',
        source='experimental/recovery-native-travel/src',ancestor='build/m52/recovery-01/src',files=changes))
    cost=read(COST/'inputs.json')
    changes=[]
    for relative, hashes in cost['files'].items():
        name='rconnect/'+relative
        ancestor=(BASE2/name).read_bytes()
        content=(COST/'src'/name).read_bytes()
        assert digest(ancestor)==hashes['base_sha256'] and digest(content)==hashes['overlay_sha256']
        before=planned[name]
        if relative=='game/GameBridge.as':
            edits=[('         var paint:Object=_wall.report(loc);','         var paint:Object=_wall.report(loc,false);'),
                ('public function readWallPaint():Array {return _wall.snapshot(loc);}',
                 'public function readWallPaint(observeNow:Boolean=true):Array {return _wall.snapshot(loc,observeNow);}')]
        elif relative=='core/Session.as':
            edits=[('               usMsg.wallPaint=mod.game.readWallPaint();',
                    '               // readTilePatch just observed native contacts and this terrain delta.\n'
                    '               usMsg.wallPaint=mod.game.readWallPaint(false);')]
        else:
            edits=[]
        if edits:
            check=ancestor;merged=before
            for old,new in edits:
                check=replace(check,old,new);merged=replace(merged,old,new)
            assert check==content, 'Anchor edits must account for the entire cost delta: '+name
        else:
            assert before==ancestor, 'Unexpected cost overlap: '+name
            merged=content
        changes.append(dict(path=name,ancestor_sha256=digest(ancestor),source_sha256=digest(content),
            before_sha256=digest(before),merged_sha256=digest(merged),
            merge='exact reviewed method anchors' if edits else 'unchanged recovery2 ancestor'))
        planned[name]=merged
    meta['layers'].append(dict(name='equivalent-capture-deduplication',source='experimental/recovery-cost/src',
                              ancestor='build/m52/recovery-02/src',files=changes))
    planned['RConnectMod.as']=replace(planned['RConnectMod.as'],'0.2.24-recovery2','0.2.24-recovery3')
    baseline=ROOT/'build/m52/coop-bundle-04/src'
    meta['source']=[]
    for name,content in sorted(planned.items()):
        assert b'<<<<<<<' not in content and b'>>>>>>>' not in content, name
        original=baseline/name
        base_digest=digest(original.read_bytes()) if original.is_file() else None
        meta['source'].append(dict(path=name,sha256=digest(content),baseline_sha256=base_digest,
                                   changed=digest(content)!=base_digest))
    meta.update(version='0.2.24-recovery3',compiled=False,runtime_tested=False,static_errors=[],
        followup_review='Exact method merges; cost499, RoomSync50, plan33 component checks. Native gameplay and performance pending.',
        native_host_candidate='build/m52/recovery-native-travel-host-01',
        native_host_sha256='e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c')
    meta['static_checks']={'input_hashes':True,'exact_overlap_anchors':True,'no_conflict_markers':True,
                           'version':True,'compiler_checked':False}
    for name,content in planned.items():
        dest=ACTIVE/'src'/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(content)
    (ACTIVE/'integration.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(version=meta['version'],source_files=len(planned),compiled=False,installed=False)))


if __name__=='__main__':
    main()
