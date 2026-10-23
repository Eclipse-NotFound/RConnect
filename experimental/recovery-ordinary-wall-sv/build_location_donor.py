"""Generate Location donor against the exact Grafon-only intermediate.

Donor is never a playable candidate: its unrelated E4X methods are discarded.
"""
from pathlib import Path
import importlib.util
import json
import subprocess
import sys
import argparse

if sys.flags.optimize:
    raise RuntimeError('Do not disable input checks')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('wall_method_stage', HERE / 'build_method_stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)
old = stage.old
OUT = old.M52 / 'recovery-ordinary-wall-sv-location-donor-01'


def inputs():
    pins = stage.pins()
    result = old.read(stage.OUT / 'stage-result.json')
    assert result['passed'] and result['compiled'] and not result['validated']
    assert result['inputs_unchanged'] and result['installation_unchanged']
    for name, digest in result['artifacts'].items():
        assert old.sha(stage.OUT / name) == digest, name
        pins[str(stage.OUT / name)] = digest
    pins[str(stage.OUT / 'stage-result.json')] = old.sha(stage.OUT / 'stage-result.json')
    pins[str(Path(__file__).resolve())] = old.sha(__file__)
    return pins


def commands():
    args = [
        ('import', ['-importScript', stage.OUT / 'grafon-only.swf', OUT / 'donor.swf', OUT / 'import']),
        ('xml', ['-swf2xml', OUT / 'donor.swf', OUT / 'donor.xml']),
        ('as', ['-selectclass', 'fe.loc.Location', '-export', 'script', OUT / 'after', OUT / 'donor.swf']),
        ('pcode', ['-format', 'script:pcode', '-selectclass', 'fe.loc.Location', '-export', 'script', OUT / 'pcode', OUT / 'donor.swf']),
    ]
    return [dict(name=name, argv=[str(old.JAVA), '-Dfile.encoding=UTF-8', '-Duser.language=en',
        '-Duser.country=US', '-Xmx512m', '-jar', str(old.FFDEC), *map(str, args)]) for name, args in args]


def build(wait):
    assert not OUT.exists(), 'Keep previous evidence'
    frozen, before = inputs(), old.installation()
    OUT.mkdir()
    source = OUT / 'import/fe/loc/Location.as'
    source.parent.mkdir(parents=True)
    source.write_bytes((old.NATIVE / 'src/fe/loc/Location.as').read_bytes())
    assert old.sha(source) == old.SOURCE['fe/loc/Location.as']
    old.save(OUT / 'intent.json', dict(inputs=frozen, installation_before=before, commands=commands(),
        donor_only=True, installed=False, air_started=False, validated=False))
    sys.path.insert(0, str(old.ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(old.ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    result = dict(commands=[], passed=False, donor_only=True, validated=False, installed=False, air_started=False)
    failure = None
    try:
        with Registration(owner='RConnect / 双方法供体构建', resource='game', purpose='Isolated donor only; no AIR/install',
            run_dir=OUT, evidence=OUT / 'result.json', wait=wait) as record:
            for command in commands():
                assert inputs() == frozen and old.installation() == before
                assert old.sha(source) == old.SOURCE['fe/loc/Location.as']
                memory = snapshot()
                old.save(OUT / (command['name'] + '.memory-before.json'), memory)
                assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before FFDec'
                item = dict(command, pid=None, exit_code=None, reaped=False)
                result['commands'].append(item)
                process = None
                with (OUT / (command['name'] + '.log')).open('x', encoding='utf-8') as stdout, \
                     (OUT / (command['name'] + '.stderr.log')).open('x', encoding='utf-8') as stderr:
                    try:
                        record.before_launch('FFDec ' + command['name'])
                        process = subprocess.Popen(command['argv'], cwd=OUT, stdout=stdout, stderr=stderr,
                            creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid'] = process.pid
                        record.child(process.pid)
                        item['exit_code'] = wait_owned(process, 300, OUT / (command['name'] + '.memory-timeline.json'))
                    finally:
                        if process is not None:
                            if process.poll() is None:
                                process.kill()
                            process.wait()
                            item['reaped'] = process.poll() is not None
                        record.child_stopped()
                assert item['exit_code'] == 0 and item['reaped'], item
                for suffix in ('.log', '.stderr.log'):
                    content = old.text(OUT / (command['name'] + suffix))
                    assert not any(x in content for x in ('SEVERE:', 'Unknown preprocessor instruction', 'Exception in thread')), content[-2000:]
            result.update(passed=True, donor_sha256=old.sha(OUT / 'donor.swf'))
            record.outcome = 'passed'
            record.note = 'Donor generated; only selected method bodies may be retained after audit'
    except BaseException as exc:
        failure = exc
        result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        result['inputs_unchanged'] = inputs() == frozen
        result['installation_unchanged'] = old.installation() == before
        if not result['inputs_unchanged'] or not result['installation_unchanged']:
            result['passed'] = False
            failure = failure or AssertionError('Input or installation drift')
        result['artifacts'] = {p.relative_to(OUT).as_posix(): old.sha(p) for p in sorted(OUT.rglob('*')) if p.is_file()}
        old.save(OUT / 'result.json', result)
    if failure:
        raise failure
    return {k: result[k] for k in ('passed', 'donor_sha256', 'validated', 'installed')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    print(json.dumps(build(args.registry_wait) if args.build else dict(inputs=len(inputs())), ensure_ascii=False))
