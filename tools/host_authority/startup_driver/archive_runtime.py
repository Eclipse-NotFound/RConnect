"""Retain unique test inputs before removing this task's reproducible game copy."""
from pathlib import Path
import shutil
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT, sha, read, save, verify_files


def main():
    workspace=ROOT/'build/ab/startup-repair-20261025-01'
    runtime=workspace/'game'
    package=ROOT/'build/ab/b3-playable-190/game'
    receipt=read(ROOT/'build/ab/b190-startup2-deploy-20261025-01/deployment.json')
    if receipt['status']!='verified':raise ValueError('Deployment must be verified first')
    retained=workspace/'retained-runtime'
    retained.mkdir()
    files={};total=0;unique=0
    for path in sorted(runtime.rglob('*')):
        if path.is_symlink():raise ValueError('Unexpected reparse input')
        if not path.is_file():continue
        name=path.relative_to(runtime).as_posix();digest=sha(path);total+=path.stat().st_size
        original=package/name
        if original.is_file() and sha(original)==digest:
            reference=original
        else:
            reference=retained/name;reference.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,reference);unique+=path.stat().st_size
        if sha(reference)!=digest:raise ValueError('Retention mismatch: '+name)
        files[name]=dict(sha256=digest,reference=str(reference.relative_to(ROOT)).replace('\\','/'))
    tools_dir=workspace/'retained-tools';tools_dir.mkdir()
    for source in Path(__file__).parent.glob('*'):
        if source.is_file():shutil.copy2(source,tools_dir/source.name)
    save(workspace/'cleanup.json',dict(status='unique_inputs_preserved_pending_removal',runtime=str(runtime),
        runtime_bytes=total,unique_bytes=unique,reclaim_bytes=total-unique,files=files,script_sha256=sha(__file__)))
    print('Retained unique inputs; reproducible runtime bytes: '+str(total-unique))


if __name__=='__main__':main()
