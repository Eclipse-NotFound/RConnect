"""Build the six-class first-raster overlay on exact roomfix5; never deploy."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import types

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-room-production-05'
VERSION = '0.2.24-roomload1'
BASE_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
BASE_PREPARED = 'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58'
BASE_COMPILE = '68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = ROOT.parent/'Sandevistan/build/tools/flexsdk'
sys.path.insert(0, str(ROOT/'tools/validation'))
from run_security_terminals import installation
from runtime_memory import snapshot, wait_owned
sys.path.insert(0, str(ROOT.parent/'ModLoader/tools'))
from test_registry import Registration


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_check():
    assert sha(BASE/'prepared.json') == BASE_PREPARED
    assert sha(BASE/'compile.json') == BASE_COMPILE
    meta, result = read(BASE/'prepared.json'), read(BASE/'compile.json')
    assert meta['version'] == '0.2.24-roomfix5'
    assert sha(BASE/'RConnectMod.swf') == result['candidate_sha256'] == BASE_SHA
    assert result['compiled'] and result['installation_unchanged'] and result['sources_unchanged']
    assert result['installation_before'] == result['installation_after'] == meta['installation_before']
    assert len(result['commands']) == 2 and all(c['exit_code'] == 0 for c in result['commands'])
    assert inventory(BASE/'src') == meta['source'] and inventory(BASE/'tools') == meta['inputs']
    generator = load(HERE/'prepare_sources.py', 'current_first_raster_source')
    argv = sys.argv
    try:
        sys.argv = [str(HERE/'prepare_sources.py'), '--check']
        generator.main()
    finally:
        sys.argv = argv
    overlay = read(HERE/'manifest.json')
    assert len(overlay['sources']) == 6
    source = dict(meta['source'])
    source.update(overlay['sources'])
    entry = (BASE/'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomfix5') == 1
    entry = entry.replace(b'0.2.24-roomfix5', VERSION.encode('ascii'))
    source['RConnectMod.as'] = hashlib.sha256(entry).hexdigest()
    changed = {name for name, value in source.items() if meta['source'].get(name) != value}
    assert changed == set(overlay['sources']) | {'RConnectMod.as'}
    assert set(source) - set(meta['source']) == {'rconnect/core/EarlyTravelGate.as'}
    return dict(source=source, inputs=meta['inputs']), entry


def recipe_inputs():
    paths = [Path(__file__), HERE/'prepare_sources.py', HERE/'manifest.json', HERE/'source.diff',
             BASE/'prepared.json', BASE/'compile.json', BASE/'RConnectMod.swf', JAVA,
             SDK/'lib/compc.jar', SDK/'lib/mxmlc.jar',
             ROOT/'tools/validation/run_security_terminals.py',
             ROOT/'tools/validation/prepare_security_terminals.py',
             ROOT/'tools/validation/runtime_memory.py', ROOT.parent/'ModLoader/tools/test_registry.py']
    return {str(path): sha(path) for path in paths}


def verify(folder):
    """Read-only artifact verification; current installation is reported separately."""
    folder = Path(folder).resolve()
    assert folder.parent == ROOT/'build/m52'
    expected, _ = source_check()
    meta = read(folder/'prepared.json')
    assert meta['kind'] == 'room-first-raster-current-product' and meta['version'] == VERSION
    assert meta['base_sha256'] == BASE_SHA and meta['reviewed_inputs'] == recipe_inputs()
    assert meta['source'] == expected['source'] == inventory(folder/'src')
    assert meta['inputs'] == expected['inputs'] == inventory(folder/'tools')
    if (folder/'compile.json').exists():
        result = read(folder/'compile.json')
        assert result['compiled'] and result['sources_unchanged'] and result['inputs_unchanged']
        assert result['installation_unchanged'] and not result.get('validation_error')
        assert result['installation_before'] == result['installation_after'] == meta['installation_before']
        assert len(result['commands']) == 2 and all(c['exit_code'] == 0 and c['reaped'] for c in result['commands'])
        assert sha(folder/'RConnectMod.swf') == result['candidate_sha256']
    return meta


def build(output, registry_wait):
    out = (ROOT/output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    expected, entry = source_check()
    pins, before = recipe_inputs(), installation()
    assert len(before) == 22 and before['mods/Rconnect/release/RConnectMod.swf'] == BASE_SHA
    shutil.copytree(BASE/'src', out/'src')
    shutil.copytree(BASE/'tools', out/'tools')
    for rel in read(HERE/'manifest.json')['sources']:
        dest = out/'src'/rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE/'src'/rel, dest)
    (out/'src/RConnectMod.as').write_bytes(entry)
    assert inventory(out/'src') == expected['source'] and inventory(out/'tools') == expected['inputs']
    meta = dict(kind='room-first-raster-current-product', version=VERSION, base_sha256=BASE_SHA,
                source=expected['source'], inputs=expected['inputs'], reviewed_inputs=pins,
                installation_before=before, runtimeValidated=False, performanceQualified=False)
    save(out/'prepared.json', meta)
    result = dict(compiled=False, commands=[], installation_before=before, air_started=False,
                  installed=False, runtimeValidated=False, performanceQualified=False)
    try:
        with Registration(owner='RConnect / 首绘延后候选', purpose=VERSION+' isolated compile',
                          run_dir=out, evidence=out/'compile.json', wait=registry_wait) as reg:
            assert installation() == before and recipe_inputs() == pins
            compiler = load(out/'tools/build_mod.py', 'current_first_raster_compiler')
            with (out/'compile.log').open('x', encoding='utf-8') as log:
                def owned(command, env=None, check=False):
                    assert len(result['commands']) < 2 and command[0] == str(JAVA) and '-Xmx384m' in command
                    assert snapshot()['free_commit_bytes'] >= 1024**3
                    assert Path(command[command.index('-jar')+1]).resolve() in (
                        (SDK/'lib/compc.jar').resolve(), (SDK/'lib/mxmlc.jar').resolve())
                    reg.before_launch('isolated first-raster compiler')
                    row = dict(command=command, pid=None, exit_code=None, reaped=False)
                    result['commands'].append(row)
                    process = subprocess.Popen(command, cwd=out, env=env, stdout=log,
                        stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                    try:
                        reg.child(process.pid)
                        row['pid'] = process.pid
                        code = wait_owned(process, 300, out/('memory-'+str(len(result['commands']))+'.json'))
                        row['exit_code'] = code
                    finally:
                        if process.poll() is None:
                            process.kill()
                        process.wait()
                        row['reaped'] = True
                        reg.child_stopped()
                    if check and code:
                        raise subprocess.CalledProcessError(code, command)
                    return subprocess.CompletedProcess(command, code)
                # Only this imported compiler sees the supervised subprocess adapter.
                compiler.subprocess = types.SimpleNamespace(run=owned)
                argv = sys.argv
                try:
                    sys.argv = [str(out/'tools/build_mod.py'), '--java', str(JAVA),
                        '--amxmlc', str(SDK/'bin/amxmlc.bat'), '--output', str(out/'RConnectMod.swf')]
                    compiler.main()
                finally:
                    sys.argv = argv
            assert len(result['commands']) == 2 and all(c['exit_code'] == 0 for c in result['commands'])
            assert installation() == before and recipe_inputs() == pins
            assert inventory(out/'src') == expected['source'] and inventory(out/'tools') == expected['inputs']
            result.update(compiled=True, candidate_sha256=sha(out/'RConnectMod.swf'))
            reg.outcome = 'passed'
            reg.note = 'Isolated compilation only; no native or performance qualification'
    except BaseException as error:
        result['error'] = type(error).__name__+': '+str(error)
        raise
    finally:
        result.update(installation_unchanged=False, sources_unchanged=False, inputs_unchanged=False)
        try:
            result['installation_after'] = installation()
            result['installation_unchanged'] = result['installation_after'] == before
            result['sources_unchanged'] = inventory(out/'src') == expected['source']
            result['inputs_unchanged'] = inventory(out/'tools') == expected['inputs'] and recipe_inputs() == pins
        except BaseException as validation_error:
            result['validation_error'] = type(validation_error).__name__+': '+str(validation_error)
        save(out/'compile.json', result)
    verify(out)
    print(json.dumps(dict(output=str(out), candidate_sha256=result['candidate_sha256'],
                         compiled=True, runtimeValidated=False, performanceQualified=False)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--build', metavar='OUTPUT')
    mode.add_argument('--verify', metavar='OUTPUT')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    if args.check:
        expected, _ = source_check()
        print(json.dumps(dict(source_check_passed=True, version=VERSION, source_count=len(expected['source']),
            new_class='EarlyTravelGate', recipe_sha256=sha(__file__), compiled=False, air_started=False)))
    elif args.verify:
        verify(ROOT/args.verify)
        print(json.dumps(dict(verified=True, runtimeValidated=False, performanceQualified=False)))
    else:
        build(args.build, args.registry_wait)


if __name__ == '__main__':
    main()
