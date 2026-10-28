"""Build a narrow overlay on the installed animfix1 source; never deploy."""
from pathlib import Path
import argparse, difflib, hashlib, json, os, shutil, subprocess, sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
GAME = RC.parents[1]
BASE = RC / 'build/m52/a-live-animation-product-04'
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
    assert sha(BASE / 'RConnectMod.swf') == '2c49dfd05d524085ea43fb8ffa537d1a9359febd52fb13d6a19faae6e2563621'
    old = json.loads((BASE / 'prepared.json').read_text('utf8'))
    assert inventory(BASE / 'src') == old['source']
    before = sha(RC / 'release/RConnectMod.swf')
    overlay = inventory(HERE / 'src')
    assert overlay
    shutil.copytree(BASE / 'src', out / 'src')
    diff = ''
    for rel in overlay:
        original = (BASE / 'src' / rel).read_text('utf8').splitlines(True)
        fresh = (HERE / 'src' / rel).read_text('utf8').splitlines(True)
        diff += ''.join(difflib.unified_diff(original, fresh, fromfile='animfix1/' + rel, tofile='stutter-repair/' + rel))
        shutil.copyfile(HERE / 'src' / rel, out / 'src' / rel)
    (out / 'source.diff').write_text(diff, encoding='utf8')
    shutil.copyfile(BASE / 'GameCombatStubs.swc', out / 'GameCombatStubs.swc')
    command = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
               '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
               '-source-path=' + str(out / 'src'), '-external-library-path+=' + str(out / 'GameCombatStubs.swc'),
               '-output=' + str(out / 'RConnectMod.swf'), str(out / 'src/RConnectDoc.as')]
    result = dict(compiled=False, base_sha256=sha(BASE / 'RConnectMod.swf'), overlay=overlay,
                  source=inventory(out / 'src'), command=command, installed_before=before, recipe_sha256=sha(__file__))
    save(out / 'prepared.json', result)
    try:
        with Registration(owner='RConnect / 卡顿修正', purpose='Compile narrow A runtime repair',
                          run_dir=out, evidence=out / 'compile.json', wait=300) as reg:
            proc = None
            try:
                reg.before_launch('Compile isolated candidate; installed files untouched')
                with (out / 'compile.log').open('w', encoding='utf8') as log:
                    proc = subprocess.Popen(command, cwd=out, env=dict(os.environ, AIR_HOME=str(SDK)),
                                            stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                    reg.child(proc.pid)
                    assert proc.wait(timeout=300) == 0, 'Read compile.log'
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
