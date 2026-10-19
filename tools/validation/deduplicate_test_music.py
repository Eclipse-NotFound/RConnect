"""Plan, atomically deduplicate, and verify RConnect test Music/*.mp3.

Never remove a directory, change a non-MP3, or link to the game installation.
Run only outside timing benchmarks. Explicit exclusions are recorded in plan.
"""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from shared_music import MusicCache, digest_file, inside, is_music, signature

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / 'build'
DEFAULT_EXCLUDE = ('m52/security-native-02', 'cooperation/351dbd7262',
                   'cooperation/fcee59d6c2', 'cooperation/0d3d8971f3')


def write_new(path, value):
    path = inside(path, BUILD)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)


def excluded(path, prefixes):
    relative = path.relative_to(BUILD).as_posix().lower()
    if relative.startswith('m52/coop-bundle'):
        return True
    return any(relative == prefix.lower() or relative.startswith(prefix.lower().rstrip('/') + '/')
               for prefix in prefixes)


def audit_receipts(paths):
    # Preserve all small top-level receipts of the affected run/frozen trees.
    files = set()
    for path in paths:
        for directory in path.parents:
            if directory == BUILD:
                break
            for name in ('run.json', 'input.json', 'inputs.json', 'prepared.json', 'runtime-archive.json'):
                p = directory / name
                if p.is_file():
                    files.add(p)
    return {str(p.relative_to(BUILD)): digest_file(p) for p in sorted(files)}


def plan(output, exclusions):
    # rg avoids traversing every compiler's many source files in Python.
    result = subprocess.run(['rg', '--files', '--hidden', '--no-ignore', '--null',
                             '-g', '*.mp3', '-g', '*.MP3', str(BUILD)],
                            capture_output=True, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    rows = []
    cached = {}
    for raw in sorted(result.stdout.split(b'\0')):
        if not raw:
            continue
        path = Path(os.fsdecode(raw))
        if not is_music(path) or excluded(path, exclusions):
            continue
        path = inside(path, BUILD)
        sig = signature(path)
        if sig not in cached:
            cached[sig] = digest_file(path)
        s = path.stat()
        rows.append(dict(path=path.relative_to(BUILD).as_posix(), sha256=cached[sig],
                         signature=list(sig), bytes=s.st_size, links=s.st_nlink))
    counts = Counter(row['sha256'] for row in rows)
    chosen = [row for row in rows if counts[row['sha256']] > 1]
    value = dict(schema=1, build=str(BUILD), created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 excluded=list(exclusions), excluded_prefix='m52/coop-bundle*',
                 files=chosen, receipts=audit_receipts([BUILD/row['path'] for row in chosen]),
                 logical_bytes=sum(row['bytes'] for row in chosen),
                 unique_file_bytes=sum({tuple(row['signature'][:2]): row['bytes'] for row in chosen}.values()),
                 unique_content_bytes=sum({row['sha256']: row['bytes'] for row in chosen}.values()))
    write_new(output, value)
    print(json.dumps({k: v for k, v in value.items() if k not in ('files', 'receipts')}))
    print('Planned files:', len(chosen), 'Receipts:', len(value['receipts']), flush=True)


def load_plan(path):
    path = inside(path, BUILD)
    value = json.loads(path.read_text(encoding='utf-8'))
    if value.get('schema') != 1 or value.get('build') != str(BUILD):
        raise ValueError('Plan belongs to a different build root')
    for row in value['files']:
        target = inside(BUILD / row['path'], BUILD)
        if not is_music(target) or excluded(target, value['excluded']):
            raise ValueError('Invalid/excluded plan target: ' + str(target))
    return value


def verify_receipts(value):
    for name, expected in value['receipts'].items():
        if digest_file(inside(BUILD/name, BUILD)) != expected:
            raise ValueError('Original test receipt changed: ' + name)


def apply(path, output):
    value = load_plan(path)
    verify_receipts(value)
    cache = MusicCache(BUILD)
    free_before = shutil.disk_usage(BUILD).free
    entries = []
    journal = inside(output.with_suffix('.jsonl'), BUILD)
    # Every completed replacement is journaled even if execution is interrupted.
    with journal.open('x', encoding='utf-8', buffering=1) as stream:
        for n, row in enumerate(value['files']):
            try:
                item = cache.replace_duplicate(BUILD/row['path'], row['sha256'], row['signature'])
            except OSError as error:
                item = dict(changed=False, freed_file_bytes=0, retained_error=str(error))
            item['path'] = row['path']
            entries.append(item)
            stream.write(json.dumps(item, ensure_ascii=False) + '\n')
            if (n + 1) % 350 == 0:
                print('Verified replacements:', n + 1, flush=True)
    verify_receipts(value)
    result = dict(plan_sha256=digest_file(path), changed=sum(x['changed'] for x in entries),
                  retained_errors=[x for x in entries if 'retained_error' in x],
                  freed_file_bytes=sum(x['freed_file_bytes'] for x in entries),
                  new_cache_bytes=cache.created_bytes,
                  net_file_bytes_saved=sum(x['freed_file_bytes'] for x in entries)-cache.created_bytes,
                  free_before=free_before, free_after=shutil.disk_usage(BUILD).free,
                  receipts_unchanged=True, entries=entries)
    write_new(output, result)
    print(json.dumps({k: v for k, v in result.items() if k != 'entries'}, ensure_ascii=False))


def verify(path, output):
    value = load_plan(path)
    ids = {}
    for row in value['files']:
        target = inside(BUILD/row['path'], BUILD)
        if digest_file(target) != row['sha256']:
            raise ValueError('Music content differs: ' + row['path'])
        s = target.stat()
        ids[(s.st_dev, s.st_ino)] = s.st_size
    verify_receipts(value)
    result = dict(verified_files=len(value['files']), unique_file_ids=len(ids),
                  unique_file_bytes=sum(ids.values()), receipts_unchanged=True,
                  original_paths_and_hashes_unchanged=True)
    write_new(output, result)
    print(json.dumps(result))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('mode', choices=['plan', 'apply', 'verify'])
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--plan', type=Path)
    ap.add_argument('--exclude', action='append', default=[])
    args = ap.parse_args()
    output = inside(ROOT/args.output, BUILD)
    if output.exists():
        raise FileExistsError(output)
    if args.mode == 'plan':
        plan(output, list(DEFAULT_EXCLUDE) + args.exclude)
    else:
        if args.plan is None:
            ap.error('--plan is required')
        source = inside(ROOT/args.plan, BUILD)
        (apply if args.mode == 'apply' else verify)(source, output)


if __name__ == '__main__':
    main()
