"""Lossless finalized-run archive. Keep logs/manifests; deduplicate frozen bytes.

Every source file is verified against a separately read, compressed SHA-256 blob
before its redundant runtime copy is removed. This never touches builds, the
baseline, installed files, AIR stores, or still-running runs. A failed/timed-out
probe is eligible only after the runner verifies inputs and exits owned PIDs. Restore writes
fresh physical copies, never hardlinks, into a new directory.
"""
import argparse
import hashlib
import json
import shutil
import zlib
from pathlib import Path
from common import ROOT, BUILD, inside_build, read, save, sha, verify_files


def blob_data(store, digest):
    if len(digest) != 64 or any(c not in '0123456789abcdef' for c in digest):
        raise ValueError('Invalid archive digest')
    data = zlib.decompress((store/digest[:2]/(digest+'.z')).read_bytes())
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError('Archive content hash differs: '+digest)
    return data


def archive(run, store):
    run = inside_build(run)
    receipt = read(run/'run.json')
    # B1/B2 used the same frozen files/exit/integrity receipt contract under
    # the earlier phase name. Keep every other finalization check unchanged.
    if (receipt.get('phase') not in ('B1-native-probe', 'B-native-probe', 'AB-native-comparison') or not receipt.get('experimental_only')
            or not receipt.get('owned_processes_exited') or not receipt.get('process_exit_codes')
            or any(p.get('code') is None for p in receipt['process_exit_codes'])
            or not receipt.get('installation_unchanged')
            or set(receipt['roles']) != {'host', 'join'}
            or not all(r.get('runtime_unchanged') for r in receipt['roles'].values())):
        raise ValueError('Not a verified, finalized, isolated run: '+run.name)
    manifest_path = run/'runtime-archive.json'
    if manifest_path.exists():
        manifest = read(manifest_path)
        if manifest['store'] != str(store.relative_to(ROOT)):
            raise ValueError('Archive store changed')
    else:
        for role, r in receipt['roles'].items():
            verify_files(run/role, r['files'])
        files = {}
        # Resolve and reject links before any file is removed.
        for role in ('host', 'join'):
            for path in sorted((run/role).rglob('*')):
                if path.is_symlink() or not path.resolve().is_relative_to((run/role).resolve()):
                    raise ValueError('Linked runtime input is not archivable')
                if not path.is_file():
                    continue
                data = path.read_bytes()
                digest = hashlib.sha256(data).hexdigest()
                dest = store/digest[:2]/(digest+'.z')
                if not dest.exists():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    with dest.open('xb') as stream:
                        stream.write(zlib.compress(data, 6))
                if blob_data(store, digest) != data:
                    raise ValueError('Archive round trip differs')
                files[path.relative_to(run).as_posix()] = {'sha256': digest, 'size': len(data)}
        manifest = {'format': 'rconnect-runtime-archive-v1', 'store': str(store.relative_to(ROOT)),
                    'run_receipt_sha256': sha(run/'run.json'), 'files': files, 'complete': False}
        # Durable index precedes removal, so interruption remains recoverable.
        save(manifest_path, manifest)
    if manifest['run_receipt_sha256'] != sha(run/'run.json'):
        raise ValueError('Original run receipt changed')
    removed = 0
    for name, info in manifest['files'].items():
        if Path(name).parts[0] not in ('host', 'join'):
            raise ValueError('Only redundant physical runtime files may be removed')
        path = (run/name).resolve()
        if not path.is_relative_to(run) or path.is_symlink():
            raise ValueError('Runtime target escaped its verified directory')
        data = blob_data(store, info['sha256'])
        if len(data) != info['size']:
            raise ValueError('Archive size differs')
        if path.exists():
            if sha(path) != info['sha256']:
                raise ValueError('Source changed after archive verification')
            path.unlink()  # A verified, restorable second copy exists in store.
            removed += info['size']
    manifest['complete'] = True
    save(manifest_path, manifest)
    print(json.dumps({'run': run.name, 'files': len(manifest['files']),
                      'redundant_bytes_removed': removed, 'free_gb': round(shutil.disk_usage(ROOT).free/2**30, 2)}), flush=True)


def restore(run, out):
    run, out = inside_build(run), inside_build(out)
    if out.exists():
        raise FileExistsError('Restore requires a new independent directory')
    m = read(run/'runtime-archive.json')
    store = inside_build(ROOT/m['store'])
    if m['run_receipt_sha256'] != sha(run/'run.json'):
        raise ValueError('Original receipt changed')
    out.mkdir(parents=True)
    for name, info in m['files'].items():
        target = (out/name).resolve()
        if not target.is_relative_to(out):
            raise ValueError('Invalid archive path')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(blob_data(store, info['sha256']))
        if sha(target) != info['sha256']:
            raise ValueError('Restored physical input differs')
    save(out/'restore.json', {'source': str(run.relative_to(ROOT)), 'verified': True, 'files': len(m['files'])})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', nargs='+', required=True)
    ap.add_argument('--store', default='build/ab/evidence-store-001')
    ap.add_argument('--restore-to')
    args = ap.parse_args()
    if args.restore_to:
        if len(args.runs) != 1:
            raise ValueError('Restore exactly one run')
        restore(ROOT/args.runs[0], ROOT/args.restore_to)
    else:
        store = inside_build(ROOT/args.store)
        store.mkdir(parents=True, exist_ok=True)
        for run in args.runs:
            archive(ROOT/run, store)


if __name__ == '__main__':
    main()
