"""Lossless cleanup of this task's three finished physical runtime copies."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import stat
import zlib
from run import ROOT, Registration, read, save, sha, verify_files, inside_build
from archive_evidence import blob_data

ap=argparse.ArgumentParser();ap.add_argument('--field-result',default='build/ab/b-field-installed-smoke-01/result.json')
ap.add_argument('--restore-to');a=ap.parse_args()
index=ROOT/'build/ab/b-field-runtime-archive-20261025.json'
store=inside_build(ROOT/'build/ab/evidence-store-001')
if a.restore_to:
    manifest=read(index);out=inside_build(ROOT/a.restore_to)
    if out.exists():raise FileExistsError(out)
    out.mkdir()
    for name,info in manifest['files'].items():
        target=(out/name).resolve()
        if not target.is_relative_to(out):raise ValueError('Invalid restore path')
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(blob_data(store,info['sha256']))
    print('Restored to '+str(out));raise SystemExit()

field=read(ROOT/a.field_result);bench=read(ROOT/'build/ab/b-field-clean-fixed9-02/result.json')
if not field.get('complete') or not field.get('runtime_unchanged') or not bench.get('complete'):
    raise ValueError('Unfinished test input cannot be archived')
targets={'field':ROOT/'build/ab/b-field-20261025-01/game',
         'host':ROOT/'build/ab/b-field-bench-20261025-01/host',
         'join':ROOT/'build/ab/b-field-bench-20261025-01/join'}
for root in targets.values():
    if inside_build(root)!=root.absolute() or getattr(root.lstat(),'st_file_attributes',0)&stat.FILE_ATTRIBUTE_REPARSE_POINT:
        raise ValueError('The named runtime root must not redirect elsewhere')
with Registration(owner='RConnect B / 测试副本归档',purpose='保留完整内容后清理本轮三个运行副本',run_dir=index.parent,evidence=index,wait=1200) as reg:
    command="Get-CimInstance Win32_Process -Filter \"Name='adl64.exe'\" | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    result=subprocess.run(['powershell','-NoProfile','-Command',command],check=True,capture_output=True,text=True)
    processes=json.loads(result.stdout) if result.stdout.strip() else []
    if isinstance(processes,dict):processes=[processes]
    for p in processes:
        cmd=p.get('CommandLine')
        if not cmd or any(str(path).lower() in cmd.lower() for path in targets.values()):raise ValueError('A runtime may still be open')
    verify_files(targets['field'],field['runtime_files'])
    for role in ('host','join'):
        if bench['roles'][role]['runtime_changes']:raise ValueError('Changed benchmark input')
        verify_files(targets[role],bench['roles'][role]['files'])
    if index.exists():raise FileExistsError(index)
    files={};original=0;new=0
    for role,root in targets.items():
        for path in sorted(root.rglob('*')):
            if path.is_symlink() or getattr(path.lstat(),'st_file_attributes',0)&stat.FILE_ATTRIBUTE_REPARSE_POINT or not path.resolve().is_relative_to(root):raise ValueError('Linked or escaped input')
            if not path.is_file():continue
            data=path.read_bytes();digest=hashlib.sha256(data).hexdigest();dest=store/digest[:2]/(digest+'.z')
            if not dest.exists():
                dest.parent.mkdir(parents=True,exist_ok=True)
                compressed=zlib.compress(data,6)
                with dest.open('xb') as stream:stream.write(compressed)
                new+=len(compressed)
            if blob_data(store,digest)!=data:raise ValueError('Archive round trip differs')
            name=role+'/'+path.relative_to(root).as_posix();files[name]={'sha256':digest,'size':len(data)};original+=len(data)
    manifest=dict(format='b-field-runtime-archive-v1',complete=False,files=files,targets={k:str(v) for k,v in targets.items()},
        store=str(store.relative_to(ROOT)),original_bytes=original,new_archive_bytes=new,reclaimed_net_bytes=0,
        field_result={'path':a.field_result,'sha256':sha(ROOT/a.field_result)},
        benchmark_sha256=sha(ROOT/'build/ab/b-field-clean-fixed9-02/result.json'),script_sha256=sha(__file__))
    save(index,manifest)
    for name,info in files.items():
        role,relative=name.split('/',1);root=targets[role];target=(root/relative).resolve()
        if not target.is_relative_to(root) or target.is_symlink() or sha(target)!=info['sha256']:raise ValueError('Changed deletion target')
        if len(blob_data(store,info['sha256']))!=info['size']:raise ValueError('Retention lost')
        target.unlink()
    for root in targets.values():
        for path in sorted(root.rglob('*'),key=lambda p:len(p.parts),reverse=True):
            if path.is_dir() and path.resolve().is_relative_to(root):path.rmdir()
        root.rmdir()
    manifest.update(complete=True,reclaimed_net_bytes=original-new);save(index,manifest)
    reg.outcome='passed';print(json.dumps({k:manifest[k] for k in ('original_bytes','new_archive_bytes','reclaimed_net_bytes')},ensure_ascii=False))
