"""Read-only checks plus a new small audit receipt, no games or installation."""
from pathlib import Path
import argparse, hashlib, json
HERE = Path(__file__).resolve().parent; ROOT = HERE.parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);a=ap.parse_args()
    out=(ROOT/a.out).resolve()
    if not out.is_relative_to(HERE) or out.exists(): raise ValueError('Use a fresh receipt in this experiment')
    old=ROOT/'build/ab/b-clientenv-bridge-07-build'; new=ROOT/'build/ab/b-smooth-04-build'
    before=read(old/'build-input.json');after=read(new/'build-input.json')
    for root,manifest in ((old,before),(new,after)):
        for name,h in manifest['sources'].items():
            if sha(root/name)!=h:raise ValueError('Frozen source changed: '+name)
        if sha(root/'RConnectMod.swf')!=manifest['candidate_sha256']:raise ValueError('Binary changed')
        if sha(root/'classes.txt')!=manifest['classes_sha256']:raise ValueError('Class inventory changed')
    names=lambda p:{row.rsplit(' ',1)[0] for row in p.read_text(encoding='utf-8-sig').splitlines() if row.strip()}
    classes=names(new/'classes.txt')
    if classes!=names(old/'classes.txt'):raise ValueError('Unexpected embedded classes')
    changed=sorted(k for k in set(before['sources'])|set(after['sources']) if before['sources'].get(k)!=after['sources'].get(k))
    expected={'src/RConnectMod.as','src/authority/BuildInfo.as','src/authority/FrameDelta.as','src/authority/NativeFields.as','src/authority/PoseTween.as','src/authority/VisualPose.as'}
    if set(changed)!=expected:raise ValueError('Unexpected changed source')
    scripts={}
    for p in HERE.glob('*.py'):
        compile(p.read_text(encoding='utf-8-sig'),str(p),'exec');scripts[p.name]=sha(p)
    receipt=dict(passed=True,candidate_sha256=after['candidate_sha256'],source_id=after['source_id'],
        build_manifest_sha256=sha(new/'build-input.json'),class_count=len(classes),classes_unchanged=True,
        changed_sources=changed,health_bar_source_unchanged=True,scripts=scripts,
        limits='Static/source checks; not runtime or performance qualification.')
    out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(json.dumps(receipt))
if __name__=='__main__':main()
