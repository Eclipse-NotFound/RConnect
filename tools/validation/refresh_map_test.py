"""Freeze test-only map diagnostics while preserving exact production bytes."""
import argparse
import copy
import json
import shutil
from pathlib import Path
from validation_baseline import ROOT, read, sha, read_baseline
from freeze_map_runtime import verify_bundle


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('origin')
    ap.add_argument('output')
    ap.add_argument('--runtime', required=True)
    ap.add_argument('--test', action='append', required=True)
    args = ap.parse_args()
    origin, out = [(ROOT/name).resolve() for name in (args.origin, args.output)]
    for path in (origin, out):
        assert path.parent == ROOT/'build/m51' and path.name.startswith('probe-')
    assert not out.exists()
    before = read(origin/'source-input.json')
    read_baseline(before)
    bundle = (ROOT/args.runtime).resolve()
    verify_bundle(bundle)
    for name, digest in {**before['source'], **before['verification']}.items():
        assert sha(origin/name) == digest, name
    for name, digest in before['source'].items():
        assert sha(ROOT/name) == digest, 'Production source changed: '+name
    assert sha(origin/'RConnectMod.swf') == before['candidate_sha256']
    assert sha(origin/'GameCombatStubs.swc') == before['stub_sha256']
    assert sha(origin/'classes.txt') == before['class_list_sha256']
    replacements = {}
    for name in args.test:
        path = (ROOT/name).resolve()
        assert path.is_relative_to(ROOT/'tests') and path.suffix == '.as'
        key = path.relative_to(ROOT).as_posix()
        assert key in before['verification'] and sha(path) != before['verification'][key]
        replacements[key] = sha(path)
    out.mkdir()
    m = copy.deepcopy(before)
    for name in {**before['source'], **before['verification']}:
        source = ROOT/name if name in replacements else origin/name
        target = out/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        assert sha(target) == replacements.get(name, {**before['source'], **before['verification']}[name]), name
    m['verification'].update(replacements)
    for name in ('RConnectMod.swf', 'GameCombatStubs.swc', 'classes.txt', 'build/GameCombatStubs.swc'):
        target = out/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin/name, target)
    reuse = dict(diagnostic_only=True, origin=origin.relative_to(ROOT).as_posix(),
        origin_manifest_sha256=sha(origin/'source-input.json'), candidate_sha256=before['candidate_sha256'],
        changed_tests={name: dict(before=before['verification'][name], after=digest) for name, digest in replacements.items()},
        runtime=str(bundle), runtime_inputs_sha256=sha(bundle/'runtime-input.json'),
        script='tools/validation/refresh_map_test.py', script_sha256=sha(Path(__file__)))
    m.update(diagnostic_only=True, reuse='Exact production from '+reuse['origin']+'; no checks carried forward', test_refresh=reuse)
    (out/'source-input.json').write_text(json.dumps(m, indent=2), encoding='utf-8')
    (out/'candidate-reuse.json').write_text(json.dumps(reuse, indent=2), encoding='utf-8')
    print(json.dumps(reuse))


if __name__ == '__main__':
    main()
