"""Save/restore exact B source overlays; no compiled runtime writes."""
from pathlib import Path
import argparse, hashlib, json, shutil
HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def inventory(root): return {p.relative_to(root).as_posix():sha(p) for f in ('src','stubs') for p in (root/f).rglob('*.as')}
def identity(files): return hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('action',choices=['archive','restore'])
    ap.add_argument('--source',required=True);ap.add_argument('--snapshot',required=True);ap.add_argument('--build')
    a=ap.parse_args();work=(RC/a.source).resolve();snap=(HERE/a.snapshot).resolve()
    if work.parent!=RC/'build/ab' or not work.name.startswith('b-entry-'):raise ValueError('B working source required')
    if snap.parent!=HERE or not snap.name.startswith('source-') or snap.name=='source-parent':raise ValueError('New source snapshot required')
    parent=HERE/'source-parent';base=read(parent/'source-manifest.json');assert inventory(parent)==base['sources']
    if a.action=='archive':
        build=(RC/a.build).resolve();assert build.parent==RC/'build/ab'
        m=read(build/'build-input.json');files=inventory(work);assert identity(files)==m['source_id']
        for name,h in m['sources'].items():
            assert sha(build/name)==h
            if name.endswith('/BuildInfo.as'):
                assert (build/name).read_text()==(work/name).read_text().replace('__SOURCE_HASH__',m['source_id'])
            else:assert (build/name).read_bytes()==(work/name).read_bytes()
        overlay={k:v for k,v in files.items() if base['sources'].get(k)!=v};snap.mkdir()
        for k in overlay:
            p=snap/k;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(work/k,p)
        record=dict(source_id=m['source_id'],sources=files,overlay=overlay,parent_sha256=sha(parent/'source-manifest.json'),build=a.build,build_manifest_sha256=sha(build/'build-input.json'))
        (snap/'source-manifest.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    else:
        record=read(snap/'source-manifest.json');assert sha(parent/'source-manifest.json')==record['parent_sha256'] and inventory(snap)==record['overlay']
        work.mkdir()
        for f in ('src','stubs'):shutil.copytree(parent/f,work/f)
        for k in record['overlay']:shutil.copy2(snap/k,work/k)
        assert inventory(work)==record['sources']
    print(json.dumps(dict(source=record['source_id'],files=len(record['sources']),overlay=len(record['overlay']))))
if __name__=='__main__':main()
