"""Exact B190 startup2 + reviewed field-fix overlay, never the unqualified B195 tree."""
import argparse
from pathlib import Path
import shutil
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT, read, save, sha, verify_files, inside_build

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    base=ROOT/'build/ab/b190-startup2-build';manifest=read(base/'build-input.json')
    verify_files(base,manifest['sources'])
    if sha(base/'RConnectMod.swf')!=manifest['candidate_sha256']:raise ValueError('Frozen baseline changed')
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    out.mkdir()
    for folder in ('src','stubs'):shutil.copytree(base/folder,out/folder)
    changes={}
    for path in sorted((ROOT/'experimental/b190-field-fixes/src').rglob('*.as')):
        name='src/'+path.relative_to(ROOT/'experimental/b190-field-fixes/src').as_posix()
        changes[name]=dict(before=sha(out/name) if (out/name).exists() else None,after=sha(path))
        (out/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,out/name)
    stamp=out/'src/authority/BuildInfo.as'
    stamp.write_text(stamp.read_text().replace(manifest['source_id'],'__SOURCE_HASH__'),encoding='utf-8')
    save(out/'recipe.json',dict(base_manifest_sha256=sha(base/'build-input.json'),changed=changes,script_sha256=sha(__file__)))
    print(str(out))
if __name__=='__main__':main()
