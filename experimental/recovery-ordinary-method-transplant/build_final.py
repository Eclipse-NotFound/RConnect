"""Prepare/build the final narrow Location transplant over Grafon-only host04.

Only --build starts Java. The rejected host03 and intermediate host04 are never
granted runtime qualification. Changed bindings/CFG require an independent review.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys

if sys.flags.optimize:
    raise RuntimeError('Do not disable admission assertions')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RECIPE = ROOT / 'experimental/recovery-ordinary-wall-sv'
M52 = ROOT / 'build/m52'
DEFAULT = M52 / 'recovery-ordinary-wall-sv-host-05'
STAGE = M52 / 'recovery-ordinary-wall-sv-host-04'
DONOR = M52 / 'recovery-ordinary-wall-sv-location-donor-01'
HELPER = HERE / 'method_transplant.py'
STAGE_SHA = '9b3622541784fdab1104a2fd01b9858e94297388b5df102d50f62e8dba2f913f'
STAGE_RECEIPT_SHA = '442376f68452e3cebdb001f9c73e0f728b56f41cbd04c063ec0e67a212e3bad2'
PINS = {
    HELPER: 'c422c540490d553e6a21415b9cdb4232f287069b4b1f18a075e51d224a59268e',
    RECIPE / 'build_method_stage.py': '5e640d3d0aca5b94afeb40ec9fdec7e3c3ada27600f132ce609bcb0f5760477a',
    RECIPE / 'build_host_v2.py': '34097a08e28a0c3f164bbe5638e4894f5f8b3b503563a06e6f65904c319eec45',
    RECIPE / 'build_location_donor.py': 'afb5dafe3287d3dc9e4185e79a34951a89d9069e5b7b4be295174f0eb2066caf',
    STAGE / 'stage-result.json': STAGE_RECEIPT_SHA,
    STAGE / 'grafon-only.swf': STAGE_SHA,
    DONOR / 'intent.json': '2100afa09ebca42ee03f273bc666f511dc3399fa6c6cc7c0cc91470d0b0b5919',
    DONOR / 'result.json': '03b3c078b73a7c1945c3c5649fad415cbdf7f62dabafd32160d7228380d7ecfe',
    DONOR / 'donor.swf': 'bfc9e672615c1b27c83b41d1158ce0b93349ffa31cc35180b86a223c954c664c',
    DONOR / 'donor.xml': '01b1d3341c4066ab6f52f6b288dc374b428a026f8bedde0eee4beb6947597a59',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def modules():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    donor = load(RECIPE / 'build_location_donor.py', 'ordinary_final_donor_recipe')
    assert donor.OUT == DONOR and donor.stage.OUT == STAGE
    helper = load(HELPER, 'ordinary_final_method_transplant')
    return donor, donor.old, helper


def target(path):
    out = (ROOT / Path(path)).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-host-\d{2,}', out.name)
    assert out not in (STAGE.resolve(), (M52 / 'recovery-ordinary-wall-sv-host-03').resolve())
    return out


def reviewed_inputs():
    donor, old, helper = modules()
    pins = donor.inputs()  # Original exact chain, all stage artifacts, source checks.
    result, intent = read(DONOR / 'result.json'), read(DONOR / 'intent.json')
    assert result['passed'] is True and result['donor_only'] is True
    assert result['inputs_unchanged'] is True and result['installation_unchanged'] is True
    assert all(result[key] is False for key in ('validated', 'installed', 'air_started'))
    assert intent['inputs'] == pins and intent['commands'] == donor.commands()
    assert len(result['commands']) == 4 and all(c['exit_code'] == 0 and c['reaped'] for c in result['commands'])
    assert result['donor_sha256'] == sha(DONOR / 'donor.swf')
    for name, digest in result['artifacts'].items():
        assert sha(DONOR / name) == digest, name
        pins[str(DONOR / name)] = digest
    for path in (Path(__file__), HELPER, DONOR / 'result.json', DONOR / 'intent.json'):
        pins[str(path.resolve())] = sha(path)
    dependencies = helper.dependencies()
    assert isinstance(dependencies, dict) and dependencies, 'Missing complete transplant dependency inventory'
    for path, digest in dependencies.items():
        assert str(Path(path).resolve()) == path and sha(path) == digest, path
        assert path not in pins or pins[path] == digest, 'Conflicting helper dependency: ' + path
        pins[path] = digest
    pins.update({str(p): h for p, h in PINS.items()})
    assert sha(STAGE / 'grafon-after/scripts/fe/loc/Location.as') == sha(old.BASE / 'after/scripts/fe/loc/Location.as')
    return pins


def commands(out):
    _, old, _ = modules()
    selected = ','.join(old.PATCHED + old.REPRESENTATIVES)
    steps = [
        ('serialize', ['-xml2swf', out / 'retained.xml', out / 'serialized.swf']),
        ('serialized-xml', ['-swf2xml', out / 'serialized.swf', out / 'serialized.xml']),
        ('final-xml', ['-swf2xml', out / 'pfe.swf', out / 'final.xml']),
        ('final-as', ['-selectclass', selected, '-export', 'script', out / 'after', out / 'pfe.swf']),
        ('final-pcode', ['-format', 'script:pcode', '-selectclass', ','.join(old.PATCHED),
                         '-export', 'script', out / 'pcode', out / 'pfe.swf']),
        ('final-classes', ['-dumpAS3', out / 'pfe.swf']),
    ]
    return [dict(name=name, argv=[str(old.JAVA), '-Dfile.encoding=UTF-8', '-Duser.language=en',
        '-Duser.country=US', '-Xmx512m', '-jar', str(old.FFDEC), *map(str, args)]) for name, args in steps]


def copies():
    _, old, _ = modules()
    result = {'before-classes.txt': old.BASE / 'after-classes.txt'}
    for cls in old.PATCHED + old.REPRESENTATIVES:
        rel = cls.replace('.', '/') + '.as'
        result['before/scripts/' + rel] = old.BASE / 'after/scripts' / rel
    for rel in old.SOURCE:
        result['import/' + rel] = old.NATIVE / 'src' / rel
    return result


def verify(out):
    out = target(out)
    meta = read(out / 'prepared.json')
    for path, digest in meta['inputs'].items():
        assert sha(path) == digest, path
    assert meta['kind'] == 'ordinary-wall-sv-method-retained-host'
    assert meta['inputs'] == reviewed_inputs() and meta['stage_sha256'] == STAGE_SHA
    assert meta['commands'] == commands(out)
    expected = {name: sha(path) for name, path in copies().items()}
    assert meta['copied_sources'] == expected
    for name, digest in expected.items():
        assert sha(out / name) == digest, name
    assert all(meta[key] is False for key in ('compiled', 'validated', 'air_started', 'installed'))
    modules()[1].installation()  # Actual current inventory; never historical substitution.
    return meta


def prepare(out):
    out = target(out)
    assert not out.exists(), 'Keep existing final candidate/failure; select a new output'
    frozen = reviewed_inputs()
    _, old, _ = modules()
    before = old.installation()
    out.mkdir()
    save(out / 'prepare-start.json', dict(inputs=frozen, installation_before=before))
    for name, source in copies().items():
        dest = out / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        assert not dest.exists()
        shutil.copyfile(source, dest)
    assert reviewed_inputs() == frozen and old.installation() == before
    save(out / 'prepared.json', dict(kind='ordinary-wall-sv-method-retained-host', inputs=frozen,
        stage_sha256=STAGE_SHA, donor_sha256=sha(DONOR / 'donor.swf'), commands=commands(out),
        copied_sources={name: sha(path) for name, path in copies().items()}, installation_before=before,
        host03_rejected=True, host04_intermediate_only=True, compiled=False, validated=False,
        air_started=False, installed=False, gameplay_qualified=False, performance_qualified=False))
    return verify(out)


def build(out, wait):
    out = target(out)
    meta = verify(out)
    assert not any((out / n).exists() for n in ('build-start.json', 'build.json', 'retained.xml', 'pfe.swf', 'serialized.swf', 'after', 'pcode'))
    _, old, helper = modules()
    before, prepared_hash = old.installation(), sha(out / 'prepared.json')
    save(out / 'build-start.json', dict(prepared_sha256=prepared_hash, installation_before=before))
    result = dict(prepared_sha256=prepared_hash, installation_before=before, commands=[],
        compiled=False, build_checks_passed=False, validated=False, air_started=False, installed=False,
        gameplay_qualified=False, performance_qualified=False, source_semantics_qualified=False,
        host03_rejected=True, host04_intermediate_only=True)
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    failure = None
    try:
        with Registration(owner='RConnect / 普通墙面双方法保留', resource='game',
                purpose='Retain exactly two Location method bodies; no AIR/install', run_dir=out,
                evidence=out / 'build.json', wait=wait) as record:
            def ready(name):
                verify(out)
                assert old.installation() == before, 'Installation changed during final build'
                memory = snapshot()
                save(out / (name + '.memory-before.json'), memory)
                assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before ' + name

            ready('retain')
            result['retain'] = helper.retain(STAGE / 'grafon-only.xml', DONOR / 'donor.xml', out / 'retained.xml')
            assert result['retain']['passed'] is True
            save(out / 'retain.json', result['retain'])
            for command in commands(out):
                name = command['name']
                ready(name)
                item = dict(command, pid=None, exit_code=None, reaped=False)
                result['commands'].append(item)
                process = None
                stdout_path = out / ('after-classes.txt' if name == 'final-classes' else name + '.log')
                stderr_path = out / (name + '.stderr.log')
                with stdout_path.open('x', encoding='utf-8') as stdout, stderr_path.open('x', encoding='utf-8') as stderr:
                    try:
                        record.before_launch('FFDec ' + name)
                        process = subprocess.Popen(command['argv'], cwd=out, stdout=stdout, stderr=stderr,
                            creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid'] = process.pid
                        record.child(process.pid)
                        item['exit_code'] = wait_owned(process, 300, out / (name + '.memory-timeline.json'))
                    finally:
                        if process is not None:
                            if process.poll() is None:
                                process.kill()
                            process.wait()
                            item['reaped'] = process.poll() is not None
                        record.child_stopped()
                assert item['exit_code'] == 0 and item['reaped'], item
                for path in (stdout_path, stderr_path):
                    assert not any(word in old.text(path) for word in ('SEVERE:', 'Unknown preprocessor instruction', 'Exception in thread')), str(path)
                if name == 'serialized-xml':
                    ready('serialized-audit')
                    result['serialized_audit'] = helper.audit(STAGE / 'grafon-only.xml', out / 'serialized.xml', out / 'retained.xml')
                    assert result['serialized_audit']['passed'] is True
                    save(out / 'serialized-audit.json', result['serialized_audit'])
                    ready('splice')
                    result['splice'] = helper.splice(STAGE / 'grafon-only.swf', out / 'serialized.swf', out / 'pfe.swf')
                    assert result['splice']['passed'] is True
                    save(out / 'splice.json', result['splice'])
                    result.update(compiled=True, candidate_sha256=sha(out / 'pfe.swf'))
                if name == 'final-xml':
                    ready('final-method-audit')
                    result['method_audit'] = helper.audit(STAGE / 'grafon-only.xml', out / 'final.xml', out / 'retained.xml')
                    assert result['method_audit']['passed'] is True
                    save(out / 'method-audit.json', result['method_audit'])
            ready('readback-audit')
            result['readback_audit'] = old.audit(out)
            verify(out)
            assert old.installation() == before
            result['build_checks_passed'] = True
            record.outcome = 'passed'
            record.note = 'Exact method retention/resources/readback passed; changed bytecode semantics and native behavior pending'
    except BaseException as exc:
        failure = exc
        result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        try:
            result['installation_after'] = old.installation()
            result['installation_unchanged'] = result['installation_after'] == before
            result['inputs_unchanged'] = reviewed_inputs() == meta['inputs'] and sha(out / 'prepared.json') == prepared_hash
            if not result['installation_unchanged'] or not result['inputs_unchanged']:
                result['build_checks_passed'] = False
                failure = failure or AssertionError('Final input/installation drift')
        except BaseException as exc:
            failure = failure or exc
            result.update(build_checks_passed=False, final_check_error=str(exc))
        result['artifacts'] = {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob('*')) if p.is_file()}
        save(out / 'build.json', result)
    if failure:
        raise failure
    return verify_result(out)


def verify_result(out):
    out = target(out)
    verify(out)
    if not (out / 'build.json').exists():
        return dict(prepared_verified=True, compiled=False, validated=False, installed=False)
    result = read(out / 'build.json')
    assert result['prepared_sha256'] == sha(out / 'prepared.json')
    for name, digest in result['artifacts'].items():
        assert sha(out / name) == digest, name
    assert all(result[k] is True for k in ('compiled', 'build_checks_passed', 'inputs_unchanged', 'installation_unchanged', 'host03_rejected', 'host04_intermediate_only'))
    assert result['installation_before'] == result['installation_after']
    assert len(result['commands']) == 6 and all(x['exit_code'] == 0 and x['reaped'] for x in result['commands'])
    assert [dict(name=x['name'], argv=x['argv']) for x in result['commands']] == commands(out)
    for key, filename in (('retain', 'retain.json'), ('serialized_audit', 'serialized-audit.json'),
                          ('splice', 'splice.json'), ('method_audit', 'method-audit.json'), ('readback_audit', 'readback-audit.json')):
        assert result[key] == read(out / filename)
        assert result[key]['readback_integrity_passed' if key == 'readback_audit' else 'passed'] is True
    assert result['candidate_sha256'] == sha(out / 'pfe.swf')
    assert all(result[k] is False for k in ('validated', 'air_started', 'installed', 'gameplay_qualified', 'performance_qualified', 'source_semantics_qualified'))
    return dict(prepared_verified=True, compiled=True, build_checks_passed=True, validated=False, candidate_sha256=result['candidate_sha256'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT)
    parser.add_argument('--registry-wait', type=float, default=900)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--build', action='store_true')
    mode.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    assert args.registry_wait >= 0
    out = target(args.output)
    if args.prepare:
        prepare(out)
        value = dict(prepared=True, compiled=False, validated=False, air_started=False, installed=False)
    elif args.build:
        value = build(out, args.registry_wait)
    else:
        value = verify_result(out)
    print(json.dumps(value, ensure_ascii=False))


if __name__ == '__main__':
    main()
