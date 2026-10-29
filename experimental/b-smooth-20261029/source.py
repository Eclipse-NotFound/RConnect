"""Archive or restore B source only; never writes a runtime or compiles."""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PARENT = ROOT / 'experimental/b-field-client-integration'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p)
            for folder in ('src', 'stubs') for p in (path / folder).rglob('*.as')}
def identity(files): return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
def working(value):
    p = (ROOT / value).resolve()
    if p.parent != ROOT / 'build/ab' or not p.name.startswith('b190-visual-motion') or not p.name.endswith('-source'):
        raise ValueError('Explicit B working source directory required')
    return p

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=('archive', 'restore'))
    ap.add_argument('--snapshot', required=True)
    ap.add_argument('--source', required=True)
    ap.add_argument('--build')
    a = ap.parse_args()
    snapshot = (HERE / a.snapshot).resolve()
    if snapshot.parent != HERE or not snapshot.name.startswith('source-'):
        raise ValueError('Direct source snapshot required')
    parent = PARENT / 'source-07/source-manifest.json'
    base = read(parent)
    if base['source_id'] != '5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd':
        raise ValueError('Parent identity changed')
    source = working(a.source)
    if a.action == 'archive':
        if snapshot.exists(): raise FileExistsError(snapshot)
        build = (ROOT / a.build).resolve()
        if build.parent != ROOT / 'build/ab': raise ValueError('B frozen build required')
        manifest = read(build / 'build-input.json')
        files = inventory(source)
        if identity(files) != manifest['source_id']: raise ValueError('Working source differs from build')
        for name, digest in manifest['sources'].items():
            if sha(build / name) != digest: raise ValueError('Frozen build source changed: ' + name)
            expected = (source / name).read_bytes()
            if name == 'src/authority/BuildInfo.as':
                expected_text = (source / name).read_text(encoding='utf-8').replace('__SOURCE_HASH__', manifest['source_id'])
                if (build / name).read_text(encoding='utf-8') != expected_text: raise ValueError('Compiled stamp differs')
            elif (build / name).read_bytes() != expected: raise ValueError('Compiled source mismatch: ' + name)
        overlay = {k: v for k, v in files.items() if base['sources'].get(k) != v}
        snapshot.mkdir()
        for name in overlay:
            target = snapshot / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((source / name).read_bytes())
        record = dict(kind='archived-source-not-a-deployment-qualification', parent=str(parent.relative_to(ROOT)),
            parent_sha256=sha(parent), restore_sha256=sha(PARENT / 'restore-source.py'),
            source_id=identity(files), sources=files, overlay=overlay,
            build=str(build.relative_to(ROOT)), build_manifest_sha256=sha(build / 'build-input.json'))
        (snapshot / 'source-manifest.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    else:
        record = read(snapshot / 'source-manifest.json')
        if sha(parent) != record['parent_sha256'] or sha(PARENT / 'restore-source.py') != record['restore_sha256']:
            raise ValueError('Parent source/assembler changed')
        if inventory(snapshot) != record['overlay']: raise ValueError('Archived overlay changed')
        if source.exists(): raise FileExistsError(source)
        subprocess.run([sys.executable, str(PARENT / 'restore-source.py'), '--snapshot', 'source-07', '--output', a.source], cwd=ROOT, check=True)
        for name in record['overlay']:
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((snapshot / name).read_bytes())
        if inventory(source) != record['sources']: raise ValueError('Restoration differs')
    print(json.dumps(dict(source_id=record['source_id'], files=len(record['sources']), overlay=len(record['overlay']), compiled=False)))

if __name__ == '__main__': main()
