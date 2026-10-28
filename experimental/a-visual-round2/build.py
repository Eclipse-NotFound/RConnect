"""Build a narrow overlay on the installed animfix2 source; never deploy."""
from pathlib import Path
import argparse, difflib, hashlib, json, os, shutil, subprocess, sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
GAME = RC.parents[1]
BASE = RC / 'build/m52/a-stutter-repair-02'
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from test_registry import Registration
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = GAME / 'mods/Sandevistan/build/tools/flexsdk'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def inventory(p): return {f.relative_to(p).as_posix(): sha(f) for f in sorted(p.rglob('*')) if f.is_file()}
def save(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf8')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve()
    assert out.is_relative_to(RC / 'build') and not out.exists()
    assert sha(BASE / 'RConnectMod.swf') == 'f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb'
    old = json.loads((BASE / 'prepared.json').read_text('utf8'))
    assert inventory(BASE / 'src') == old['source']
    before = sha(RC / 'release/RConnectMod.swf')
    overlay = inventory(HERE / 'src')
    assert overlay
    shutil.copytree(BASE / 'src', out / 'src')
    diff = ''
    for rel in overlay:
        previous = BASE / 'src' / rel
        original = previous.read_text('utf8').splitlines(True) if previous.exists() else []
        fresh = (HERE / 'src' / rel).read_text('utf8').splitlines(True)
        diff += ''.join(difflib.unified_diff(original, fresh, fromfile='animfix2/' + rel, tofile='stutter-repair/' + rel))
        (out / 'src' / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE / 'src' / rel, out / 'src' / rel)
    (out / 'source.diff').write_text(diff, encoding='utf8')
    stub_command = None
    if (HERE / 'stubs').exists():
        shutil.copytree(HERE / 'stubs', out / 'stubs')
        names = [p.relative_to(out / 'stubs').with_suffix('').as_posix().replace('/', '.') for p in sorted((out / 'stubs').rglob('*.as'))]
        stub_command = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/compc.jar'), '+configname=air',
                        '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38',
                        '-source-path=' + str(out / 'stubs'), '-include-classes=' + ','.join(names),
                        '-output=' + str(out / 'GameCombatStubs.swc')]
    else:
        shutil.copyfile(BASE / 'GameCombatStubs.swc', out / 'GameCombatStubs.swc')
    command = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
               '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
               '-source-path=' + str(out / 'src'), '-external-library-path+=' + str(out / 'GameCombatStubs.swc'),
               '-output=' + str(out / 'RConnectMod.swf'), str(out / 'src/RConnectDoc.as')]
    result = dict(compiled=False, base_sha256=sha(BASE / 'RConnectMod.swf'), overlay=overlay,
                  source=inventory(out / 'src'), stubs=inventory(out / 'stubs') if stub_command else {},
                  command=command, stub_command=stub_command, installed_before=before, recipe_sha256=sha(__file__))
    save(out / 'prepared.json', result)
    try:
        with Registration(owner='RConnect / 六项视觉修复', purpose='Compile narrow A runtime repair',
                          run_dir=out, evidence=out / 'compile.json', wait=300) as reg:
            proc = None
            try:
                reg.before_launch('Compile isolated candidate; installed files untouched')
                with (out / 'compile.log').open('w', encoding='utf8') as log:
                    for invocation in ([stub_command] if stub_command else []) + [command]:
                        proc = subprocess.Popen(invocation, cwd=out, env=dict(os.environ, AIR_HOME=str(SDK)),
                                                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                        reg.child(proc.pid)
                        assert proc.wait(timeout=300) == 0, 'Read compile.log'
                        reg.child_stopped()
            finally:
                if proc is not None:
                    if proc.poll() is None: proc.kill()
                    proc.wait()
                    reg.child_stopped()
            assert inventory(out / 'src') == result['source'] and inventory(HERE / 'src') == overlay
            result.update(compiled=True, candidate_sha256=sha(out / 'RConnectMod.swf'))
            reg.outcome = 'passed'
            reg.note = 'Compilation only; behavior and timing remain unverified'
    finally:
        result['installed_after'] = sha(RC / 'release/RConnectMod.swf')
        result['installation_unchanged'] = before == result['installed_after']
        save(out / 'compile.json', result)
    print(json.dumps({k: result[k] for k in ('compiled', 'candidate_sha256', 'installation_unchanged')}))

if __name__ == '__main__': main()
