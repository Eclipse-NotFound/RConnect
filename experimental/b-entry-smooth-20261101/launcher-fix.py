"""Apply and check the launcher-only compatibility fix; never starts a player."""
from pathlib import Path
import importlib.util
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('entry_release', HERE / 'release.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
d = r.d
initial = r.RC / 'build/ab/b-entry-deploy-20261101-01/deployment.json'
out = r.RC / 'build/ab/b-entry-deploy-20261101-launcher-02'


def main():
    d.require(not out.exists(), 'Launcher transaction already exists; inspect its receipt')
    with d.package_lock():
        old = d.read(initial)
        d.require(old['status'] == 'verified', 'Initial deployment not verified')
        d.verify(r.GAME, old['after'])
        manifest = d.package()
        root = d.root_game_snapshot()
        helper = r.RC / 'tools/launch-b.cmd'
        data = r.batch(HERE / 'launchers/launch-b.cmd')
        manifest['quick_launchers'][r.rel(helper)] = d.digest(data)
        validation = d.read(r.P / 'playable-validation.json')
        validation.update(manual_manifest_sha256=d.digest(d.encode(manifest)),
                          launcher_verification=dict(transaction=d.rel(out),
                                                     mode='check-only; no player started',
                                                     sha256=d.digest(data)))
        contents = {helper: data, r.P / 'manual-input.json': d.encode(manifest),
                    r.P / 'playable-validation.json': d.encode(validation)}
        out.mkdir()
        before = {r.rel(p): d.sha(p) for p in contents}
        for p in contents:
            backup = out / 'before' / r.rel(p)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, backup)
        receipt = dict(status='prepared', created=d.utc(),
                       parent=dict(path=d.rel(initial), sha256=d.sha(initial)),
                       before=before, after={r.rel(p): d.digest(v) for p, v in contents.items()},
                       root_witness=root, script_sha256=d.sha(__file__))
        d.atomic_write(out / 'deployment.json', d.encode(receipt))
        shutil.copy2(__file__, out / 'launcher-fix-executed.py')
        done = []
        try:
            for p, value in contents.items():
                d.atomic_write(p, value, before[r.rel(p)])
                done.append(p)
            check = subprocess.run([os.environ['COMSPEC'], '/d', '/c', str(helper), 'check'],
                                   cwd=r.GAME, capture_output=True, text=True, timeout=30)
            (out / 'launcher-check.txt').write_text(check.stdout + check.stderr, encoding='utf-8')
            d.require(check.returncode == 0 and 'AIR host verified.' in check.stdout,
                      'Launcher check failed: ' + check.stdout + check.stderr)
            d.package()
            d.check_root_game(root)
            d.verify(r.GAME, dict(old['after'], **receipt['after']))
            receipt.update(status='verified', finished=d.utc(), check_exit=check.returncode,
                           check_sha256=d.sha(out / 'launcher-check.txt'))
            d.atomic_write(out / 'deployment.json', d.encode(receipt))
        except Exception as error:
            receipt.update(status='rollback_required', error=str(error))
            d.atomic_write(out / 'deployment.json', d.encode(receipt))
            for p in reversed(done):
                name = r.rel(p)
                d.atomic_write(p, (out / 'before' / name).read_bytes(), receipt['after'][name])
            receipt['status'] = 'rolled_back'
            d.atomic_write(out / 'deployment.json', d.encode(receipt))
            raise
    print(json.dumps(dict(status=receipt['status'], transaction=d.rel(out),
                          launcher_check=receipt['check_exit'])))


if __name__ == '__main__':
    main()
