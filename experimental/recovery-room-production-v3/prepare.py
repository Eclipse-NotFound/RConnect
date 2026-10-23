"""Freeze the READY observation and native loading text fixes on roomfix2."""
from pathlib import Path
import difflib, hashlib, json, shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-aura-offline-01'
PREVIOUS=ROOT/'experimental/recovery-room-production-v2'
VERSION='0.2.24-roomfix3'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}

def main():
    assert not (HERE/'src').exists()
    old=json.loads((PREVIOUS/'source-manifest.json').read_text(encoding='utf-8'))
    assert inventory(PREVIOUS/'src')=={k:v['candidate_sha256'] for k,v in old['changes'].items()}
    assert sha(ROOT/'build/m52/recovery-room-production-02/RConnectMod.swf')=='c26b1aa7dccf6e96c4027f551332a2b55d413467b24311426a20c8d341058cc0'
    replacements={
        'rconnect/core/RoomSync.as':(ROOT/'experimental/recovery-room-ready-once/src/rconnect/core/RoomSync.as','1c5ac8d9c761c40d0908a2c048062a7b09f604c6b9fa34272cae27e27c52a848'),
        'rconnect/ui/RoomEntryView.as':(ROOT/'experimental/recovery-room-ui-localization/src/rconnect/ui/RoomEntryView.as','4cb479f39262f631b834c6290f78fcaec3b3cc102bb56f9886a71791a05efe0b')}
    assert sha(BASE/'RConnectMod.swf')==old['base_sha256']
    for path,digest in replacements.values():assert sha(path)==digest
    shutil.copytree(PREVIOUS/'src',HERE/'src')
    for rel,(path,digest) in replacements.items():shutil.copyfile(path,HERE/'src'/rel)
    entry=HERE/'src/RConnectMod.as';body=entry.read_text(encoding='utf-8')
    assert body.count(old['version'])==1
    entry.write_text(body.replace(old['version'],VERSION),encoding='utf-8',newline='\n')
    changes={};diff=[]
    for name in inventory(HERE/'src'):
        new=HERE/'src'/name;prior=BASE/'src'/name
        before=prior.read_text(encoding='utf-8-sig') if prior.exists() else ''
        after=new.read_text(encoding='utf-8-sig')
        changes[name]=dict(base_sha256=sha(prior) if prior.exists() else None,candidate_sha256=sha(new))
        diff.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='aura1/'+name,tofile=VERSION+'/'+name))
    (HERE/'source.diff').write_text(''.join(diff),encoding='utf-8',newline='\n')
    receipt=dict(version=VERSION,base=str(BASE),base_sha256=sha(BASE/'RConnectMod.swf'),
        previous_overlay_sha256=sha(PREVIOUS/'source-manifest.json'),review_sources={str(p):h for p,h in replacements.values()},
        changes=changes,recipe_sha256=sha(Path(__file__)),compiled=False,tested=False,installed=False)
    (HERE/'source-manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    shutil.copyfile(PREVIOUS/'build.py',HERE/'build.py')
    print(json.dumps(dict(version=VERSION,changed=list(changes)),ensure_ascii=False))
if __name__=='__main__':main()
