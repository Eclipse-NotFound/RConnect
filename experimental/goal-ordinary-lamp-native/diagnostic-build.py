"""Compile only the four-source lamp diagnostic driver; never start AIR.

--check is read-only. --build creates a new bounded output (default driver-01).
verify(output) requires a real successful one-command receipt, not preparation.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, shutil, subprocess, sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
SOURCE = HERE / 'diagnostic-src'
BASE = M52 / 'goal-native-loading-probe-driver-01'
SDK = GAME / 'mods/Sandevistan/build/tools/flexsdk'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
KIND = 'ordinary-lamp-raster-diagnostic-driver-v1'
DEPENDENCIES = {
    'ProductionDeclarations.swc': '598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7',
    'GameCombatStubs.swc': '8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a',
    'timing/EffectsHarness.swf': 'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086',
}
PINS = {
    SOURCE / 'prepare.py': '75aab9f80b8977ce6eeb9ec4040214f1d828f673673c645fd4d3e1d5e4950ca2',
    SOURCE / 'source-manifest.json': '5e92b51563e349b621ed0f5e0da0180993030410e3ddd5a65911b0b1365524d4',
    BASE / 'prepared.json': '562bb57f0640eefb4f89fa2799fd52918baec49cdab42c434808a21c36840ca9',
    BASE / 'compile.json': '02f8efa0c92a6ee964de0e0c87b360387dedf73c1d03e04b61461bc393875045',
    ROOT / 'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT / 'tools/validation/run_security_terminals.py': '4e4ad73dd0f8df69db5c0c11f6c2c1c94c96fb1235dbaa1aad18caaf9877b9cb',
    ROOT / 'tools/validation/prepare_security_terminals.py': '5d156d663f616baf793b03ca183388951a10375a5d11e561e81c2b81ab7e13b5',
    GAME / 'mods/ModLoader/tools/test_registry.py': '8b35a6d6ca1dd94cfd5cba9a42979ebd14d9ae65497688fa859d084425922049',
}

class NotReady(RuntimeError):
    pass

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text('utf-8-sig'))
def save(p, value):
    with Path(p).open('x', encoding='utf8') as f:
        json.dump(value, f, ensure_ascii=False, indent=2); f.write('\n')
def load(p, name):
    spec = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
def installation():
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from run_security_terminals import installation as actual
    current = actual(); assert len(current) == 22; return current
def inventory(folder):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}
def command(out):
    return [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'),
            '+configname=air', '+flexlib=' + str(SDK / 'frameworks'),
            '-swf-version=38', '-debug=false', '-optimize=true',
            '-source-path=' + str(out / 'tests'),
            '-external-library-path+=' + str(out / 'ProductionDeclarations.swc'),
            '-external-library-path+=' + str(out / 'GameCombatStubs.swc'),
            '-output=' + str(out / 'timing/EffectsDriver.swf'),
            str(out / 'tests/RoomTravelTimingTestDoc.as')]
def inputs():
    for path, digest in PINS.items(): assert sha(path) == digest, str(path)
    proof = load(SOURCE / 'prepare.py', 'ordinary_lamp_diagnostic_source').verify()
    assert proof['source_count'] == 4 and proof['originalTravelChecks'] == 35 and proof['originalUiChecksPerRole'] == 11
    assert proof['additionalChecksPerRole'] == 8 and proof['hook_count'] == 4
    old, original = read(BASE / 'compile.json'), read(BASE / 'prepared.json')
    assert old['compiled'] and old['inputs_unchanged'] and old['error'] is None and old['validation_error'] is None
    assert old['prepared_sha256'] == sha(BASE / 'prepared.json') and len(old['commands']) == 1
    assert old['commands'][0]['command'] == command(BASE) and old['commands'][0]['exit_code'] == 0 and old['commands'][0]['reaped']
    paths = list(PINS) + [Path(__file__), SOURCE / 'README.md', SOURCE / 'source.diff']
    paths += [SOURCE / 'tests' / name for name in proof['sources']]
    paths += [BASE / 'tests' / name for name in proof['original_sources']]
    for name, digest in DEPENDENCIES.items():
        assert sha(BASE / name) == original['files'][name] == digest, name
        paths.append(BASE / name)
    for path in (JAVA, SDK / 'lib/mxmlc.jar', SDK / 'frameworks/air-config.xml', SDK / 'frameworks/libs/air/airglobal.swc'):
        assert sha(path) == original['inputs'][str(path)], str(path)
        paths.append(path)
    sources = inventory(SOURCE / 'tests')
    assert sources == proof['sources'] and len(sources) == 4
    return {str(p.resolve()): sha(p) for p in sorted(set(paths))}, proof, sources
def output_path(path):
    out = (ROOT / path).resolve()
    assert out.parent == M52 and out.name.startswith('goal-ordinary-lamp-diagnostic-driver-')
    return out
def copies(out, expected):
    for name, digest in expected.items(): assert sha(out / name) == digest, name
def verify(output):
    out = output_path(Path(output))
    if not (out / 'compile.json').is_file(): raise NotReady('Actual compile.json is required: ' + str(out))
    pins, proof, sources = inputs(); p, r = read(out / 'prepared.json'), read(out / 'compile.json')
    assert p['kind'] == r['kind'] == KIND and p['inputs'] == pins and p['source_proof'] == proof
    assert r['compiled'] and r['inputs_unchanged'] and r['error'] is None and r['validation_error'] is None
    assert r['prepared_sha256'] == sha(out / 'prepared.json')
    assert p['installation_before'] == r['installation_before'] == r['installation_after'] == installation()
    assert inventory(out / 'tests') == sources
    expected = {'tests/' + name: digest for name, digest in sources.items()}; expected.update(DEPENDENCIES)
    assert p['files'] == expected; copies(out, expected)
    assert len(r['commands']) == 1
    row = r['commands'][0]
    assert row['command'] == command(out) and row['exit_code'] == 0 and row['reaped'] is True
    assert type(row['pid']) is int and row['pid'] > 0
    assert set(r['artifacts']) == {'timing/EffectsDriver.swf', 'timing/EffectsHarness.swf'}
    copies(out, r['artifacts'])
    assert r['artifacts']['timing/EffectsHarness.swf'] == DEPENDENCIES['timing/EffectsHarness.swf']
    assert r['compile_log_sha256'] == sha(out / 'compile.log') and r['memory_sha256'] == sha(out / 'compile-memory.json')
    memory = read(out / 'compile-memory.json')
    assert memory['pid'] == row['pid'] and memory['reason'] is None
    assert memory['exit_code'] == memory['process_returncode'] == 0 and memory['minimum_commit_bytes'] == 512 * 1024**2
    assert p['start_minimum_commit_bytes'] == r['start_minimum_commit_bytes'] == 1024**3
    assert row['launch_memory']['free_commit_bytes'] >= 1024**3
    for meta in (p, r):
        assert meta['air_started'] is False and meta['installed'] is False and meta['runtime_tested'] is False
        assert meta['diagnosticOnly'] is True and meta['performanceQualified'] is False
    return dict(verified=True, artifacts=r['artifacts'], inputs=pins, source_proof=proof,
                prepared_sha256=sha(out / 'prepared.json'), compile_sha256=sha(out / 'compile.json'),
                build_environment=r['installation_before'], diagnosticOnly=True, performanceQualified=False)
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true'); mode.add_argument('--build', action='store_true'); mode.add_argument('--verify', type=Path)
    ap.add_argument('--output', type=Path, default=M52 / 'goal-ordinary-lamp-diagnostic-driver-01')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    if args.verify: print(json.dumps(verify(args.verify), ensure_ascii=False)); return
    pins, proof, sources = inputs(); before = installation()
    if args.check:
        print(json.dumps(dict(source_checked=True, source_count=len(sources), current_environment=before, compiled=False, air_started=False))); return
    out = output_path(args.output); assert not out.exists()
    (out / 'tests').mkdir(parents=True); (out / 'timing').mkdir()
    for name in sources: shutil.copyfile(SOURCE / 'tests' / name, out / 'tests' / name)
    for name in DEPENDENCIES: shutil.copyfile(BASE / name, out / name)
    files = inventory(out)
    assert inputs()[0] == pins and installation() == before; copies(out, files)
    flags = dict(air_started=False, installed=False, runtime_tested=False, diagnosticOnly=True, performanceQualified=False, start_minimum_commit_bytes=1024**3)
    save(out / 'prepared.json', dict(kind=KIND, inputs=pins, files=files, source_proof=proof, installation_before=before, compiled=False, **flags))
    prepared_sha = sha(out / 'prepared.json')
    sys.path.insert(0, str(ROOT / 'tools/validation')); from runtime_memory import snapshot, wait_owned
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools')); from test_registry import Registration
    rows, success, error = [], False, None
    try:
        with Registration(owner='RConnect / 普通灯具图像诊断', resource='game', purpose='Compile one lamp image driver; no AIR',
                          run_dir=out, evidence=out / 'compile.json', wait=args.registry_wait) as record:
            process = None; row = dict(command=command(out), pid=None, exit_code=None, reaped=False); rows.append(row)
            try:
                assert inputs()[0] == pins and installation() == before; copies(out, files)
                row['launch_memory'] = snapshot()
                assert row['launch_memory']['free_commit_bytes'] >= 1024**3, 'Compilation requires 1 GiB commit headroom'
                record.before_launch('single ordinary lamp diagnostic compiler')
                with (out / 'compile.log').open('x', encoding='utf8') as log:
                    process = subprocess.Popen(row['command'], cwd=out, stdout=log, stderr=subprocess.STDOUT,
                                              env=dict(os.environ, AIR_HOME=str(SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
                    row['pid'] = process.pid; record.child(process.pid)
                    row['exit_code'] = wait_owned(process, 300, out / 'compile-memory.json')
                    assert row['exit_code'] == 0 and (out / 'timing/EffectsDriver.swf').is_file(), 'Diagnostic compilation failed'
            finally:
                try:
                    if process is not None:
                        if process.poll() is None: process.kill()
                        process.wait(); row['reaped'] = process.poll() is not None
                finally: record.child_stopped()
            assert inputs()[0] == pins and installation() == before; copies(out, files)
            success = True; record.outcome = 'passed'; record.note = 'One diagnostic driver compiled; no AIR or performance qualification'
    except BaseException as exc:
        error = repr(exc); raise
    finally:
        unchanged, after, validation_error, artifacts = False, None, None, {}
        try:
            after = installation(); unchanged = inputs()[0] == pins and after == before
            copies(out, files); assert unchanged and sha(out / 'prepared.json') == prepared_sha
            artifacts = {n: sha(out / n) for n in ('timing/EffectsDriver.swf', 'timing/EffectsHarness.swf') if (out / n).is_file()}
        except BaseException as exc: validation_error = repr(exc)
        save(out / 'compile.json', dict(kind=KIND, compiled=success and error is None and validation_error is None,
             commands=rows, error=error, validation_error=validation_error, inputs_unchanged=unchanged,
             prepared_sha256=prepared_sha, installation_before=before, installation_after=after, artifacts=artifacts,
             compile_log_sha256=sha(out / 'compile.log') if (out / 'compile.log').is_file() else None,
             memory_sha256=sha(out / 'compile-memory.json') if (out / 'compile-memory.json').is_file() else None, **flags))
        if validation_error is not None and error is None: raise RuntimeError(validation_error)
    print(json.dumps(verify(out), ensure_ascii=False))

if __name__ == '__main__':
    try: main()
    except (FileNotFoundError, NotReady) as exc:
        print(json.dumps(dict(ready=False, status='not-ready', error=str(exc)), ensure_ascii=False)); raise SystemExit(2)
