"""Freeze the reviewed crossing fixes on the tested roomfix1 overlay."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-aura-offline-01'
PREVIOUS = ROOT/'experimental/recovery-room-production'
REVIEW = ROOT/'experimental/recovery-room-repair-review'
VERSION = '0.2.24-roomfix2'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def inventory(p):
    return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}

def main():
    assert not (HERE/'src').exists()
    old=json.loads((PREVIOUS/'source-manifest.json').read_text(encoding='utf-8'))
    assert inventory(PREVIOUS/'src')=={k:v['candidate_sha256'] for k,v in old['changes'].items()}
    replacement=REVIEW/'components/crossing-v2/rconnect/core/RoomSync.as'
    assert sha(replacement)=='0874c604817bdf9e1c8e48fce6e9717effa245e523bb4cd4916f276dafe09cc5'
    assert sha(ROOT/'build/m52/recovery-room-production-01/RConnectMod.swf')=='4d9f1cbd69d8608df525477b81c9232631cbc0032c4018bc9846e6f3b9c40341'
    assert sha(BASE/'RConnectMod.swf')==old['base_sha256']
    shutil.copytree(PREVIOUS/'src',HERE/'src')
    shutil.copyfile(replacement,HERE/'src/rconnect/core/RoomSync.as')
    entry=HERE/'src/RConnectMod.as'
    body=entry.read_text(encoding='utf-8')
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
        previous_overlay_sha256=sha(PREVIOUS/'source-manifest.json'),review_source_sha256=sha(replacement),
        changes=changes,recipe_sha256=sha(Path(__file__)),compiled=False,tested=False,installed=False)
    (HERE/'source-manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    shutil.copyfile(PREVIOUS/'build.py',HERE/'build.py')
    print(json.dumps(dict(version=VERSION,changed=list(changes)),ensure_ascii=False))

if __name__=='__main__':main()
