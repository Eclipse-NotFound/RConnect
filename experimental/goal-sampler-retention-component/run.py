"""Three bounded sampler mechanism observations; reuse the registered component runner."""
from pathlib import Path
import argparse
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
ORIGINAL = ROOT / 'tools/validation/run_recovery_component.py'
ORIGINAL_SHA = '9952aeeaa37f6eead636cceff9f25fabff3045671d3c4cbb60c326909d1e572d'
OLD = "'-debug=true', '-source-path='"
NEW = "'-debug=false', '-optimize=true', '-source-path='"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source():
    assert sha(ORIGINAL) == ORIGINAL_SHA
    text = ORIGINAL.read_text(encoding='utf-8-sig')
    assert text.count(OLD) == 1
    return text.replace(OLD, NEW, 1)


def verify():
    manifest = json.loads((HERE / 'source-manifest.json').read_text(encoding='utf-8'))
    assert manifest['kind'] == 'sampler-retention-component-source-v1'
    assert manifest['expected'] == 9
    assert manifest['compiled'] is False and manifest['air_started'] is False
    assert manifest['performance_qualified'] is False
    for name, digest in manifest['files'].items():
        path = (HERE / name).resolve()
        assert path.is_relative_to(HERE) and sha(path) == digest, name
    assert set(manifest['files']) == {'run.py', 'check.py', 'README.md', 'component/SamplerRetentionDoc.as'}
    for name, digest in manifest['originals'].items():
        assert sha(name) == digest, name
    assert manifest['originals'][str(ORIGINAL)] == ORIGINAL_SHA
    assert sha(HERE / 'component/SamplerRetentionDoc.as') == manifest['source_sha256']
    assert hashlib.sha256(source().encode('utf-8')).hexdigest() == manifest['adapted_runner_sha256']
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    assert args.registry_wait >= 0
    proof = verify()
    if args.check:
        assert args.output is None
        print(json.dumps(dict(ready=True, expected=9, source_sha256=proof['source_sha256'],
                              compiled=False, air_started=False)))
        return 0
    assert args.output is not None
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and out.name.startswith('goal-sampler-retention-component-') and not out.exists()
    text = source()
    runtime = {name: digest for name, digest in proof['originals'].items()
               if name.endswith('adl64.exe') or name.endswith('Adobe AIR.dll')}
    evidence = dict(wrapper_sha256=sha(__file__), manifest_sha256=sha(HERE / 'source-manifest.json'),
                    original=str(ORIGINAL), original_sha256=ORIGINAL_SHA,
                    adapted_source_sha256=hashlib.sha256(text.encode('utf-8')).hexdigest(),
                    edits=[dict(old=OLD, new=NEW)], runtime=runtime,
                    diagnostic_only=True, performance_qualified=False)
    previous = sys.argv
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    try:
        sys.argv = [str(ORIGINAL), '--source', str(HERE / 'component'), '--entry', 'SamplerRetentionDoc.as',
                    '--output', str(out), '--expected', '9', '--registry-wait', str(args.registry_wait)]
        scope = dict(__file__=str(ORIGINAL), __name__='retention_real_component_runner')
        exec(compile(text, str(ORIGINAL), 'exec'), scope)
        scope['main']()
        assert verify() == proof
    finally:
        sys.argv = previous
        if out.is_dir():
            evidence['inputs_unchanged'] = all(sha(HERE / n) == h for n, h in proof['files'].items())
            evidence['runtime_unchanged'] = all(sha(n) == h for n, h in runtime.items())
            with (out / 'retention-adaptation.json').open('x', encoding='utf-8') as stream:
                json.dump(evidence, stream, ensure_ascii=False, indent=2)
                stream.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
