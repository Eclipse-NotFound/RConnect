"""Freeze a small overlay of an exact existing RC product, then compile in isolation.

Only the two explicitly admitted bases are accepted. No game/SWF deployment,
test threshold changes, or historical installation substitution occurs here.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import types

if sys.flags.optimize:
    raise RuntimeError('Validation requires ordinary Python')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
BASES = {
    'recovery-ordinary-wall-sv-production-01': 'c6a3b1136bde63c32d23c4e555dfc240f3a573384d19c4fe9636a4138193496d',
    'recovery-offline-production-01': 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee',
}
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = ROOT.parent / 'Sandevistan/build/tools/flexsdk'
sys.path.insert(0, str(ROOT / 'tools/validation'))
from run_security_terminals import installation
from runtime_memory import snapshot, wait_owned
sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
from test_registry import Registration


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}


def deps():
    paths = [Path(__file__), JAVA, SDK / 'lib/mxmlc.jar', SDK / 'lib/compc.jar',
             SDK / 'frameworks/air-config.xml', SDK / 'frameworks/flex-config.xml',
             SDK / 'frameworks/libs/air/airglobal.swc',
             ROOT / 'tools/validation/runtime_memory.py', ROOT / 'tools/validation/run_security_terminals.py',
             ROOT / 'tools/validation/prepare_security_terminals.py',
             ROOT.parent / 'ModLoader/tools/test_registry.py']
    return {str(p): sha(p) for p in paths}


def target(path):
    out = (ROOT / path).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-[a-z0-9-]+-\d{2,}', out.name)
    return out


def base_check(base):
    assert base.parent == M52.resolve() and base.name in BASES
    assert sha(base / 'RConnectMod.swf') == BASES[base.name]
    meta, result = read(base / 'prepared.json'), read(base / 'compile.json')
    assert result['compiled'] is True and result['compile_exit'] == 0
    assert result['candidate_sha256'] == BASES[base.name]
    assert result['prepared_sha256'] == sha(base / 'prepared.json')
    assert {'src/' + k: v for k, v in inventory(base / 'src').items()} == meta['source']
    assert {'tools/' + k: v for k, v in inventory(base / 'tools').items()} == meta['inputs']
    assert sha(base / 'tools/build_mod.py') == 'b386f55f5e19886ec70905794d9a2237d29ee413fabe5229aefb158249832fa6'
    return meta


def prepare(args, out):
    base = (ROOT / args.base).resolve()
    overlay = (ROOT / args.overlay).resolve()
    assert overlay.is_relative_to(ROOT / 'experimental') and overlay.is_dir()
    original = base_check(base)
    changes = inventory(overlay)
    assert 0 < len(changes) <= 6 and all(k.endswith('.as') for k in changes)
    assert all('src/' + k in original['source'] for k in changes), 'Only existing source classes may be replaced'
    assert re.fullmatch(r'0\.2\.24-[a-z0-9]+', args.version)
    actual = installation()
    assert len(actual) == 22 and actual['mods/Rconnect/release/RConnectMod.swf'] == BASES['recovery-offline-production-01']
    expected = dict(original['installation_before'])
    expected['mods/Rconnect/release/RConnectMod.swf'] = BASES['recovery-offline-production-01']
    assert actual == expected, 'Only the recorded RC baseline update is allowed'
    assert not out.exists()
    out.mkdir()
    diffs = []
    for folder in ('src', 'tools'):
        for rel in inventory(base / folder):
            old = (base / folder / rel).read_bytes()
            data = (overlay / rel).read_bytes() if folder == 'src' and rel in changes else old
            if folder == 'src' and rel == 'RConnectMod.as':
                text = data.decode('utf-8-sig')
                text, count = re.subn(r'(public static const VERSION:String\s*=\s*")[^"]+(";)',
                                     lambda m: m[1] + args.version + m[2], text)
                assert count == 1
                data = text.encode('utf-8')
            path = out / folder / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if data != old:
                diffs.extend(difflib.unified_diff(old.decode('utf-8-sig').replace('\r\n', '\n').splitlines(True),
                    data.decode('utf-8-sig').replace('\r\n', '\n').splitlines(True), fromfile='base/' + folder + '/' + rel,
                    tofile='candidate/' + folder + '/' + rel))
    (out / 'source.diff').write_text(''.join(diffs), encoding='utf-8', newline='\n')
    meta = dict(kind='isolated-existing-product-overlay', base=str(base), base_sha256=BASES[base.name],
                base_manifest_sha256=sha(base / 'prepared.json'), base_compile_sha256=sha(base / 'compile.json'),
                overlay=str(overlay), overlay_inputs=changes, version=args.version,
                source=inventory(out / 'src'), inputs=inventory(out / 'tools'),
                patch_sha256=sha(out / 'source.diff'), installation_before=actual, dependencies=deps(),
                diagnostic_only=args.diagnostic, compiled=False, air_started=False, installed=False)
    save(out / 'prepared.json', meta)
    verify(out)


def verify(out):
    meta = read(out / 'prepared.json')
    base = Path(meta['base'])
    base_check(base)
    assert sha(base / 'prepared.json') == meta['base_manifest_sha256']
    assert sha(base / 'compile.json') == meta['base_compile_sha256']
    assert BASES[base.name] == meta['base_sha256']
    assert inventory(Path(meta['overlay'])) == meta['overlay_inputs']
    assert inventory(out / 'src') == meta['source'] and inventory(out / 'tools') == meta['inputs']
    assert sha(out / 'source.diff') == meta['patch_sha256']
    assert deps() == meta['dependencies'] and installation() == meta['installation_before']
    if (out / 'compile.json').exists():
        result = read(out / 'compile.json')
        assert result['compiled'] and result['compile_exit'] == 0
        assert result['candidate_sha256'] == sha(out / 'RConnectMod.swf')
        assert result['prepared_sha256'] == sha(out / 'prepared.json')
        assert result['installation_before'] == result['installation_after'] == meta['installation_before']
        assert result['sources_unchanged'] and result['installation_unchanged']
        for rel, digest in result['artifacts'].items():
            assert sha(out / rel) == digest
    return meta


def build(out, wait):
    meta = verify(out)
    assert not any((out / n).exists() for n in ('compile.json', 'compile.log', 'RConnectMod.swf', 'compile-start.json'))
    result = dict(compiled=False, compile_exit=None, commands=[], diagnostic_only=meta['diagnostic_only'],
                  prepared_sha256=sha(out / 'prepared.json'), installation_before=installation(),
                  air_started=False, installed=False, gameplay_qualified=False, performance_qualified=False)
    save(out / 'compile-start.json', result)
    error = None
    try:
        with Registration(owner='RConnect / 隔离小范围覆盖', resource='game', purpose=meta['version'] + ' compile only',
                          run_dir=out, evidence=out / 'compile.json', wait=wait) as record:
            verify(out)
            assert snapshot()['free_commit_bytes'] >= 1024 ** 3
            path = out / 'tools/build_mod.py'
            spec = importlib.util.spec_from_file_location('isolated_original_compiler', path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            with (out / 'compile.log').open('x', encoding='utf-8') as log:
                def owned(command, env=None, check=False):
                    index = len(result['commands'])
                    assert index < 2
                    expected = SDK / ('lib/compc.jar' if index == 0 else 'lib/mxmlc.jar')
                    assert command[0] == str(JAVA) and '-Xmx384m' in command
                    assert Path(command[command.index('-jar') + 1]).resolve() == expected.resolve()
                    assert snapshot()['free_commit_bytes'] >= 1024 ** 3
                    row = dict(command=command, pid=None, exit_code=None, reaped=False)
                    result['commands'].append(row)
                    process = None
                    log.write(json.dumps(command) + '\n')
                    log.flush()
                    try:
                        record.before_launch(expected.name)
                        process = subprocess.Popen(command, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT,
                                                   creationflags=subprocess.CREATE_NO_WINDOW)
                        row['pid'] = process.pid
                        record.child(process.pid)
                        code = wait_owned(process, 300, out / ('compile-memory-' + str(index + 1) + '.json'))
                        row['exit_code'] = code
                    finally:
                        if process is not None:
                            if process.poll() is None:
                                process.kill()
                            process.wait()
                            row['reaped'] = process.poll() is not None
                        record.child_stopped()
                    if check and code:
                        raise subprocess.CalledProcessError(code, command)
                    return subprocess.CompletedProcess(command, code)
                module.subprocess = types.SimpleNamespace(run=owned)
                previous = sys.argv
                try:
                    sys.argv = [str(path), '--java', str(JAVA), '--amxmlc', str(SDK / 'bin/amxmlc.bat'),
                                '--output', str(out / 'RConnectMod.swf')]
                    module.main()
                finally:
                    sys.argv = previous
            assert len(result['commands']) == 2 and all(c['exit_code'] == 0 and c['reaped'] for c in result['commands'])
            verify(out)
            result.update(compiled=True, compile_exit=0, candidate_sha256=sha(out / 'RConnectMod.swf'))
            record.outcome = 'passed'
            record.note = 'Isolated compile only; no AIR, gameplay, performance or deployment qualification'
    except BaseException as exc:
        error = exc
        result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        result['installation_after'] = installation()
        result['installation_unchanged'] = result['installation_after'] == result['installation_before']
        result['sources_unchanged'] = inventory(out / 'src') == meta['source'] and inventory(out / 'tools') == meta['inputs']
        result['artifacts'] = {n: sha(out / n) for n in ('RConnectMod.swf', 'build/GameCombatStubs.swc', 'compile.log',
                              'compile-memory-1.json', 'compile-memory-2.json') if (out / n).exists()}
        if not result['installation_unchanged'] or not result['sources_unchanged']:
            result['compiled'] = False
        save(out / 'compile.json', result)
    if error:
        raise error
    verify(out)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path)
    parser.add_argument('--overlay', type=Path)
    parser.add_argument('--version')
    parser.add_argument('--diagnostic', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--build', action='store_true')
    mode.add_argument('--verify', action='store_true')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    out = target(args.output)
    assert args.registry_wait >= 0
    if args.verify:
        verify(out)
    else:
        if not out.exists():
            assert args.base and args.overlay and args.version
            prepare(args, out)
        if args.build:
            build(out, args.registry_wait)
    result = read(out / 'compile.json') if (out / 'compile.json').exists() else read(out / 'prepared.json')
    print(json.dumps(dict(output=str(out), compiled=result['compiled'], candidate_sha256=result.get('candidate_sha256'),
                         air_started=False, installed=False)))


if __name__ == '__main__':
    main()
