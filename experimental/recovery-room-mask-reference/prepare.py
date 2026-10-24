"""Freeze one conditional-only MirrorMasks proposal and the real old/new component classes."""
from pathlib import Path
import argparse, difflib, hashlib, json, sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-room-production-04/src/rconnect/game/MirrorMasks.as'
BASE_SHA = 'b4283cf68870010c4d454a6c7d511f00dbc5c3540e1839f878dfe680084f5e24'
OLD = b'               if(rootRef!=null)maskReferences(rootRef,refs);'
NEW = b'               if(rootRef!=null && attached(nativeMask,v) && v.mask!==nativeMask)maskReferences(rootRef,refs);'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def expected():
    data = BASE.read_bytes()
    assert sha(BASE) == BASE_SHA and data.count(OLD) == 1
    changed = data.replace(OLD, NEW)
    assert changed.replace(NEW, OLD) == data
    old_class = b'public final class MirrorMasks {'
    assert data.count(old_class) == 1
    reference = data.replace(old_class, b'public final class MirrorMasksReference {')
    return {
        'src/rconnect/game/MirrorMasks.as': changed,
        'component/rconnect/game/MirrorMasks.as': changed,
        'component/rconnect/game/MirrorMasksReference.as': reference,
        'source.diff': ''.join(difflib.unified_diff(data.decode('utf-8').splitlines(True),
                       changed.decode('utf-8').splitlines(True), fromfile='roomfix4/MirrorMasks.as',
                       tofile='proposal/MirrorMasks.as')).encode('utf-8'),
    }


def verify():
    for name, data in expected().items():
        assert (HERE/name).read_bytes() == data, name
    manifest = json.loads((HERE/'source-manifest.json').read_text(encoding='utf-8'))
    assert manifest['baseline_sha256'] == BASE_SHA
    for name, digest in manifest['files'].items():
        assert sha(HERE/name) == digest, name
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert args.prepare != args.check
    if args.prepare:
        assert not (HERE/'source-manifest.json').exists(), 'Existing frozen proposal must not be rewritten'
        for name, data in expected().items():
            target = HERE/name
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
        files = [p for p in HERE.rglob('*') if p.is_file() and p.suffix in ('.as', '.py', '.md', '.diff')]
        manifest = dict(kind='mirror-mask-native-reference-conditional-proposal', baseline=str(BASE),
                        baseline_sha256=BASE_SHA, changed_statements=1,
                        original_reference_change='Class declaration name only; same package and method bodies',
                        game_loaded=False, real_rv_tested=False, compiled=False, installed=False,
                        files={p.relative_to(HERE).as_posix(): sha(p) for p in sorted(files)})
        with (HERE/'source-manifest.json').open('x', encoding='utf-8') as stream:
            json.dump(manifest, stream, ensure_ascii=False, indent=2)
    manifest = verify()
    print(json.dumps(dict(passed=True, read_only=not args.prepare,
                          proposal_sha256=sha(HERE/'src/rconnect/game/MirrorMasks.as'),
                          manifest_sha256=sha(HERE/'source-manifest.json'),
                          changed_statements=1, compiled=False, air_started=False)))


if __name__ == '__main__':
    main()
