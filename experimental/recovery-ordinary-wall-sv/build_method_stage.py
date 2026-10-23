"""Prepare the Grafon-only intermediate for narrow Location method retention.

No game execution or installation. The original host03 remains rejected.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

if sys.flags.optimize:
    raise RuntimeError('Input assertions must remain enabled')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ordinary_host03_recipe', HERE / 'build_host_v2.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
OUT = old.M52 / 'recovery-ordinary-wall-sv-host-04'
DONOR = old.M52 / 'recovery-ordinary-wall-sv-host-03'
DONOR_SHA = 'a2ffea6a401046e2124c324bd1d3950cef37d6929a4cf620a8b26851673d88f7'


def pins():
    value = old.reviewed_inputs()
    old.verify(DONOR)
    failed = old.read(DONOR / 'build.json')
    assert failed['compiled'] and not failed['build_checks_passed'] and not failed['validated']
    assert old.sha(DONOR / 'pfe.swf') == failed['candidate_sha256'] == DONOR_SHA
    for name, digest in failed['artifacts'].items():
        assert old.sha(DONOR / name) == digest, name
    value.update({str(Path(__file__).resolve()): old.sha(__file__),
                  str(DONOR / 'build.json'): old.sha(DONOR / 'build.json'),
                  str(DONOR / 'pfe.swf'): DONOR_SHA})
    return value


def commands():
    args = [
        ('acc-xml', ['-swf2xml', old.BASE / 'pfe.swf', OUT / 'acc.xml']),
        ('donor03-xml', ['-swf2xml', DONOR / 'pfe.swf', OUT / 'donor03.xml']),
        ('grafon-import', ['-importScript', old.BASE / 'pfe.swf', OUT / 'grafon-only.swf', OUT / 'import']),
        ('grafon-xml', ['-swf2xml', OUT / 'grafon-only.swf', OUT / 'grafon-only.xml']),
        ('grafon-as', ['-selectclass', ','.join(old.PATCHED + old.REPRESENTATIVES),
                       '-export', 'script', OUT / 'grafon-after', OUT / 'grafon-only.swf']),
    ]
    return [dict(name=name, argv=[str(old.JAVA), '-Dfile.encoding=UTF-8', '-Duser.language=en',
        '-Duser.country=US', '-Xmx512m', '-jar', str(old.FFDEC), *map(str, args)]) for name, args in args]


def run(wait):
    assert not OUT.exists(), 'Preserve previous stage evidence'
    inputs, installation = pins(), old.installation()
    OUT.mkdir()
    target = OUT / 'import/fe/graph/Grafon.as'
    target.parent.mkdir(parents=True)
    target.write_bytes((old.NATIVE / 'src/fe/graph/Grafon.as').read_bytes())
    assert old.sha(target) == old.SOURCE['fe/graph/Grafon.as']
    old.save(OUT / 'stage-intent.json', dict(inputs=inputs, installation_before=installation,
        commands=commands(), purpose='Grafon-only intermediate; rejected host03 is only a method donor',
        installed=False, validated=False, air_started=False))
    sys.path.insert(0, str(old.ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(old.ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    result = dict(commands=[], passed=False, compiled=False, validated=False, installed=False, air_started=False)
    failure = None
    try:
        with Registration(owner='RConnect / 普通墙面最小方法准备', resource='game',
            purpose='Grafon-only intermediate/XML export; no AIR/install', run_dir=OUT,
            evidence=OUT / 'stage-result.json', wait=wait) as record:
            for command in commands():
                assert pins() == inputs and old.installation() == installation
                assert old.sha(target) == old.SOURCE['fe/graph/Grafon.as']
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
                if command['name'] == 'grafon-import':
                    result.update(compiled=True, intermediate_sha256=old.sha(OUT / 'grafon-only.swf'))
            assert (OUT / 'grafon-after/scripts/fe/loc/Location.as').read_bytes() == (DONOR / 'before/scripts/fe/loc/Location.as').read_bytes(), 'Unmodified Location source changed'
            result['passed'] = True
            record.outcome = 'passed'
            record.note = 'Intermediate only; retained methods, bytecode audit and runtime qualification remain'
    except BaseException as exc:
        failure = exc
        result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        result['inputs_unchanged'] = pins() == inputs
        result['installation_unchanged'] = old.installation() == installation
        if not result['inputs_unchanged'] or not result['installation_unchanged']:
            result['passed'] = False
            failure = failure or AssertionError('Input or installation drift')
        result['artifacts'] = {p.relative_to(OUT).as_posix(): old.sha(p) for p in sorted(OUT.rglob('*')) if p.is_file()}
        old.save(OUT / 'stage-result.json', result)
    if failure:
        raise failure
    return {k: result[k] for k in ('passed', 'compiled', 'intermediate_sha256', 'validated', 'installed')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    print(json.dumps(run(args.registry_wait) if args.build else dict(inputs=len(pins()), commands=commands()), ensure_ascii=False))
