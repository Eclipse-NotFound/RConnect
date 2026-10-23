"""Apply only the room19/loading changes to the installed aura1 source.

Every changed context must match exactly; unrelated aura/offline changes stay.
This creates an isolated source candidate, never an installed artifact.
"""
from pathlib import Path
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'build/m52/coop-bundle-04'
ROOM = ROOT / 'build/m52/room-entry-fast-19'
BASE = ROOT / 'build/m52/recovery-aura-offline-01'
VERSION = '0.2.24-roomfix1'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def inventory(p):
    return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*')) if f.is_file()}


def main():
    assert sha(OLD / 'RConnectMod.swf') == '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
    assert sha(ROOM / 'RConnectMod.swf') == '051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea'
    assert sha(BASE / 'RConnectMod.swf') == 'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
    baseline = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
    assert inventory(BASE / 'src') == baseline['source']
    assert not (HERE / 'src').exists()
    changes = {}
    for donor in sorted((ROOM / 'src').rglob('*.as')):
        name = donor.relative_to(ROOM / 'src').as_posix()
        if name == 'RConnectMod.as':
            continue
        prior = OLD / 'src' / name
        original = prior.read_text(encoding='utf-8-sig') if prior.exists() else ''
        updated = donor.read_text(encoding='utf-8-sig')
        if original == updated:
            continue
        current = BASE / 'src' / name
        body = current.read_text(encoding='utf-8-sig') if current.exists() else ''
        if not original:
            assert not body
            body = updated
        else:
            a, b = original.splitlines(True), updated.splitlines(True)
            groups = list(difflib.SequenceMatcher(None, a, b, autojunk=False).get_grouped_opcodes(3))
            for group in reversed(groups):
                old = ''.join(a[group[0][1]:group[-1][2]])
                new = ''.join(b[group[0][3]:group[-1][4]])
                assert body.count(old) == 1, (name, group[0], 'exact context conflict')
                body = body.replace(old, new, 1)
        changes[name] = body
    changes['rconnect/ui/RoomEntryView.as'] = (ROOT / 'experimental/recovery-loading/src/rconnect/ui/RoomEntryView.as').read_text(encoding='utf-8-sig')
    # Native artwork is the sole loading presentation. Error notices remain.
    key = 'rconnect/core/RoomSync.as'
    changes[key] = changes[key].replace('blocked?status:"房间交接中…"', 'blocked?status:""').replace('status="房间交接中…";', 'status="";')
    entry = (BASE / 'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    changes['RConnectMod.as'], count = re.subn(r'(VERSION:String\s*=\s*")[^"]+(";)', lambda m:m[1]+VERSION+m[2], entry)
    assert count == 1
    rows, diff = {}, []
    for name, body in changes.items():
        out = HERE / 'src' / name
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body, encoding='utf-8', newline='\n')
        prior = BASE / 'src' / name
        old = prior.read_text(encoding='utf-8-sig') if prior.exists() else ''
        rows[name] = dict(base_sha256=sha(prior) if prior.exists() else None, candidate_sha256=sha(out))
        diff += list(difflib.unified_diff(old.splitlines(True), body.splitlines(True), fromfile='aura1/'+name, tofile=VERSION+'/'+name))
    (HERE / 'source.diff').write_text(''.join(diff), encoding='utf-8', newline='\n')
    receipt = dict(version=VERSION, base=str(BASE), base_sha256=sha(BASE/'RConnectMod.swf'), donor=str(ROOM),
                   donor_sha256=sha(ROOM/'RConnectMod.swf'), changes=rows, recipe_sha256=sha(Path(__file__)),
                   compiled=False, tested=False, installed=False)
    (HERE/'source-manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(version=VERSION, changed=list(rows)), ensure_ascii=False))


if __name__ == '__main__':
    main()
