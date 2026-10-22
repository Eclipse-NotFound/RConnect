"""External Socket dispatch observer; reuse the registered driver03 build."""
import argparse
import json
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROFILE = ROOT/'experimental/recovery-density-profile-settings'
SOURCE = ROOT/'build/m52/recovery-density-corridor-drivers-03'
sys.path.insert(0, str(ROOT/'experimental/recovery-density-corridor-readyfix'))
import prepare as original
sha, read, save, M52 = original.sha, original.read, original.save, original.M52


def frozen_sources():
    inputs, handoff = read(HERE/'inputs.json'), read(HERE/'handoff.json')
    for name, digest in handoff['files'].items():
        assert sha(HERE/name) == digest, 'Probe recipe changed: '+name
    for name, digest in inputs['dependencies'].items():
        assert sha(Path(name)) == digest, 'Probe dependency changed: '+name
    for name, digest in inputs['tests'].items():
        assert sha(SOURCE/name) == digest, 'Frozen driver03 source changed: '+name
    original.verify(SOURCE)
    return inputs


def verify_probe(out):
    inputs = frozen_sources()
    meta = original.verify(out)
    assert meta['entry'] == 'SocketBatchTestDoc' and meta['diagnostic_only'] is True
    assert meta['socket_driver03_sha256'] == sha(SOURCE/'prepared.json')
    assert meta['socket_profile_sha256'] == sha(PROFILE/'handoff.json')
    actual = {p.relative_to(out).as_posix(): sha(p) for p in sorted((out/'tests').rglob('*.as'))}
    expected = dict(inputs['tests'])
    expected.update({p.relative_to(HERE).as_posix(): sha(p) for p in sorted((HERE/'tests').rglob('*.as'))})
    assert actual == expected, 'Only declared external observer hooks/classes may differ'
    return meta


def freeze(out):
    frozen_sources()
    assert out.parent == M52.resolve() and not out.exists()
    meta = original.freeze(out, True)
    for source in sorted((HERE/'tests').rglob('*.as')):
        name = source.relative_to(HERE).as_posix()
        target = out/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        meta['inputs'][name] = sha(target)
        meta['originals'][str(source)] = sha(source)
    meta.update(entry='SocketBatchTestDoc', diagnostic_only=True, performance_qualified=False,
        socket_driver03_sha256=sha(SOURCE/'prepared.json'), socket_profile_sha256=sha(PROFILE/'handoff.json'),
        purpose='External Socket DATA/MESSAGE brackets; exact driver03 stimulus and frozen current RV settings')
    for source in sorted(HERE.iterdir()):
        if not source.is_file(): continue
        target = out/'socket-recipe'/source.name
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(source, target)
        meta['originals'][str(source)] = sha(source)
        meta['inputs'][target.relative_to(out).as_posix()] = sha(target)
    for name, digest in read(HERE/'inputs.json')['dependencies'].items():
        meta['originals'][name] = digest
    save(out/'prepared.json', meta)
    return verify_probe(out)


def write_diagnostic(out):
    from analyze import analyze
    result = read(out/'result.json')
    report = dict(diagnostic_only=True, performance_qualified=False, release_qualified=False,
        original_result_unchanged=True, original_passed=result['passed'], collected=False)
    try:
        report.update(analyze(out))
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as error:
        report['collection_error'] = str(error)
    target = out/'socket-batches.json'
    assert not target.exists()
    save(target, report)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--build', action='store_true')
    p.add_argument('--registry-wait', type=int, default=900)
    a = p.parse_args()
    out = (ROOT/a.output).resolve()
    assert out.parent == M52.resolve() and 0 <= a.registry_wait <= 3600
    meta = verify_probe(out) if out.exists() else freeze(out)
    if a.build:
        meta = original.base.build(out, a.registry_wait)
        verify_probe(out)
    print(json.dumps(dict(output=str(out), compiled=meta['compiled'], entry=meta['entry'],
                         diagnostic_only=True, performance_qualified=False)))


if __name__=='__main__': main()
