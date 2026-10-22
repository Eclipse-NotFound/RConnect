"""Overlay only the declared diagnostics and entry; reuse driver03's registered build."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
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
        assert sha(HERE/name) == digest, 'Sampler recipe changed: '+name
    for name, digest in inputs['dependencies'].items():
        assert sha(Path(name)) == digest, 'Sampler dependency changed: '+name
    for name, digest in inputs['tests'].items():
        assert sha(SOURCE/name) == digest, 'Frozen driver03 source changed: '+name
    original.verify(SOURCE)
    return inputs


def verify_sampler(out):
    inputs = frozen_sources()
    meta = original.verify(out)
    assert meta['entry'] == 'AfterRenderProfileTestDoc' and meta['diagnostic_only'] is True
    assert meta.get('sampler_driver03_sha256') == sha(SOURCE/'prepared.json')
    assert meta.get('sampler_profile_sha256') == sha(PROFILE/'handoff.json')
    actual = {p.relative_to(out).as_posix(): sha(p) for p in sorted((out/'tests').rglob('*.as'))}
    expected = dict(inputs['tests'])
    expected.update({p.relative_to(HERE).as_posix(): sha(p) for p in sorted((HERE/'tests').rglob('*.as'))})
    assert actual == expected, 'Only declared diagnostic overlay and entry may differ from driver03'
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
    # The existing diagnostic flag otherwise chooses trajectory totals.
    # The overlay changes only diagnostic methods/hooks, plus the explicit entry.
    meta.update(entry='AfterRenderProfileTestDoc', diagnostic_only=True,
        performance_qualified=False, sampler_driver03_sha256=sha(SOURCE/'prepared.json'),
        sampler_profile_sha256=sha(PROFILE/'handoff.json'),
        purpose='Post-RENDER CPU sampler; same driver03 preparation/stimulus, counts and frozen current RV settings')
    for source in sorted(HERE.iterdir()):
        if not source.is_file():
            continue
        target = out/'sampler-recipe'/source.name
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(source, target)
        meta['originals'][str(source)] = sha(source)
        meta['inputs'][target.relative_to(out).as_posix()] = sha(target)
    for name, digest in read(HERE/'inputs.json')['dependencies'].items():
        meta['originals'][name] = digest
    save(out/'prepared.json', meta)
    return verify_sampler(out)


def runtime_errors(text, role):
    errors = []
    for line in text.splitlines():
        if line.startswith('AFTER RENDER CPU PROFILE '):
            try:
                data = json.loads(line[len('AFTER RENDER CPU PROFILE '):])
                assert data['role'] == role and isinstance(data['frames'], list)
            except (AssertionError, KeyError, ValueError, TypeError):
                errors.append('Malformed AFTER RENDER CPU PROFILE data for '+role)
            continue
        if 'COOP FAIL' in line or re.search(
            r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b', line, re.I):
            errors.append(line)
    return errors


def write_diagnostic(out):
    # Read only the declared post-RENDER windows; never qualify FPS from profiling.
    path = HERE/'analyze.py'
    spec = importlib.util.spec_from_file_location('current_profile_analysis', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = read(out/'result.json')
    report = dict(diagnostic_only=True, performance_qualified=False, release_qualified=False,
                  original_result_unchanged=True, original_passed=result['passed'], collected=False)
    try:
        report.update(module.analyze(out))
        for role, row in report['roles'].items():
            folder = ROOT/'build/cooperation'/report['run']
            text = '\n'.join(p.read_text('utf-8-sig', errors='replace') for p in
                (folder/(role+'.log'), folder/(role+'.stdout.log')) if p.exists())
            row['actual_runtime_errors'] = runtime_errors(text, role)
        report['collected'] = all(r['valid_cpu_sample'] for r in report['roles'].values())
        report['vision_templates_confirmed'] = result.get('vision_templates_confirmed') is True
        report['vision_templates_unchanged'] = result.get('vision_templates_unchanged') is True
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as error:
        report['collection_error'] = str(error)
    target = out/'cpu-profile.json'
    assert not target.exists()
    save(target, report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--registry-wait', type=int, default=900)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == M52.resolve() and 0 <= args.registry_wait <= 3600
    meta = verify_sampler(out) if out.exists() else freeze(out)
    if args.build:
        meta = original.base.build(out, args.registry_wait)
        verify_sampler(out)
    print(json.dumps(dict(output=str(out), compiled=meta['compiled'], entry=meta['entry'],
                         diagnostic_only=True, performance_qualified=False)))


if __name__ == '__main__':
    main()
