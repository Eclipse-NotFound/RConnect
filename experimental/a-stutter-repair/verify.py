"""Inspect exact compiled definitions and source provenance. No installation writes."""
import argparse, json, re, subprocess
from pathlib import Path
from build import RC, GAME, JAVA, BASE, Registration, inventory, sha, save

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('candidate', type=Path)
    args = ap.parse_args()
    folder = args.candidate.resolve()
    assert folder.is_relative_to(RC / 'build')
    meta = json.loads((folder / 'compile.json').read_text('utf8'))
    assert meta['compiled'] and inventory(folder / 'src') == meta['source']
    assert sha(folder / 'RConnectMod.swf') == meta['candidate_sha256']
    command = [str(JAVA), '-Xmx256m', '-jar', str(GAME / 'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'),
               '-dumpAS3', str(folder / 'RConnectMod.swf')]
    result = dict(passed=False, candidate_sha256=meta['candidate_sha256'], command=command)
    with Registration(owner='RConnect / 卡顿候选检查', purpose='Read compiled class definitions',
                      run_dir=folder, evidence=folder / 'class-audit.json', wait=300) as reg:
        proc = None
        try:
            reg.before_launch('Inspect isolated SWF; no game or deployment')
            with (folder / 'classes.txt').open('w', encoding='utf8') as log:
                proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
                reg.child(proc.pid)
                assert proc.wait(timeout=180) == 0
            actual = {m.group(1) for m in re.finditer(r'^([\w.]+)\s+\d+\s*$',
                      (folder / 'classes.txt').read_text('utf8', errors='replace'), re.M)}
            expected = {str(Path(n).with_suffix('')).replace('\\', '.').replace('/', '.') for n in meta['source']}
            assert actual == expected, (sorted(actual - expected), sorted(expected - actual))
            # The product intentionally contains existing fe.* access bridges.
            # Exact source membership above rejects embedded extern stubs;
            # rejecting the entire namespace would also reject valid bridges.
            assert not actual.intersection({'fe.World', 'fe.unit.Unit', 'fe.unit.UnitPlayer',
                                            'fe.weapon.Weapon', 'fe.weapon.Bullet', 'fe.loc.Location'})
            changed = [n for n, h in meta['source'].items() if h != sha(BASE / 'src' / n)]
            assert set(changed) == {'RConnectMod.as', 'rconnect/game/UnitPresentation.as', 'rconnect/game/ProjectileVisuals.as'}
            result.update(passed=True, classes=len(actual), changed=changed)
            reg.outcome = 'passed'
            reg.note = 'Exactly 3 source changes; no native stubs or test classes'
        finally:
            if proc is not None:
                if proc.poll() is None: proc.kill()
                proc.wait()
                reg.child_stopped()
            save(folder / 'class-audit.json', result)
    print(json.dumps(result))

if __name__ == '__main__': main()
