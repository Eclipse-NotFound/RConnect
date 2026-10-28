"""Bind the existing functional fixture to exact installed field8; optionally rebuild its driver.

No new game copy and no reads/writes of live player saves. Run by the root agent
only after its observer sources are final. Every output preparation is new.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/host_authority/field2_driver'))
from run import Registration, JAVA, SDK, HERE, available_gib, inside_build, read, sha, save, verify_files

BASE = 'd1a83ed5e38da1b80786b32e39e1375794586614420e1731ee5cbc9380813ed5'
NATIVE = 'eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063'
MANUAL = 'ab7a72c103a5bfdc97f526bbac87f07b2239263fb1a9af64424b17a474571c5c'
MUTABLE = {'pfe.swf', 'mods/rconnect/release/rconnectmod.swf', 'mods/rconnect/release/config.txt'}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def helpers(folder):
    return sorted(set(p for pattern in ('B*Cases.as', 'B*Checks.as', 'B*Inputs.as', 'B*Trace.as') for p in folder.glob(pattern)))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--workspace', default='build/ab/b-field2-runtime-01')
    p.add_argument('--preparation', default='prepared-v19.json')
    p.add_argument('--out', required=True, help='New prepared-*.json basename in the existing workspace')
    p.add_argument('--refresh-driver', action='store_true')
    a = p.parse_args()
    for value in (a.preparation, a.out):
        require(Path(value).name == value and value.startswith('prepared-') and value.endswith('.json'), 'Preparation must be a prepared-*.json basename')
    workspace = inside_build(ROOT / a.workspace)
    target = workspace / a.out
    require(not target.exists(), 'Preparation already exists; never overwrite evidence')
    playable = ROOT / 'build/ab/b3-playable-190'
    prior_path = ROOT / 'build/ab/b-field-deploy-20261028-01/before/manual-input.json'
    with Registration(owner='RConnect B / loading fixture', purpose='Bind exact loading fixture' + (' and refresh external observers' if a.refresh_driver else ''), run_dir=workspace, evidence=target, wait=900) as reg:
        require(not target.exists(), 'Preparation appeared concurrently')
        old = read(workspace / a.preparation)
        manual = read(playable / 'manual-input.json')
        require(sha(playable / 'manual-input.json') == MANUAL, 'Installed field8 manifest changed')
        require(manual['candidate_sha256'] == BASE and sha(playable / 'game/pfe.swf') == NATIVE, 'Installed tuple is not exact field8/native021')
        verify_files(playable / 'game', manual['files'])
        # Accept the frozen field22 ancestor, or a previous new field8-bound
        # preparation. Never relabel an unrelated original package.
        if old['manual_manifest'] == MANUAL:
            prior = manual
            ancestry_manual = playable / 'manual-input.json'
        else:
            prior = read(prior_path)
            require(old['manual_manifest'] == sha(prior_path), 'Unknown preparation lineage')
            ancestry_manual = prior_path
        require(old['original_files'] == prior['files'], 'Ancestor inventory differs')
        require(prior['config'] == manual['config'], 'Configuration changed outside this preparation')
        require(set(prior['files']) == set(manual['files']), 'Installed file inventory changed')
        changed = {k.lower() for k in prior['files'] if prior['files'][k] != manual['files'][k]}
        require(changed <= {'mods/rconnect/release/rconnectmod.swf'}, 'Unexpected dependency/native change')
        game = workspace / 'game'
        verify_files(game, {k: v for k, v in old['files'].items() if k.lower() not in MUTABLE})
        frozen_source = Path(old['compiler_command'][-1])
        require(sha(frozen_source) == old['driver'], 'Frozen driver changed')
        verify_files(frozen_source.parent, old['helpers'])
        for role, seed in old['seeds'].items():
            require(sha(workspace / (role + '-save0.sol')) == seed['sha256'], 'Frozen save changed')
        updated = json.loads(json.dumps(old))
        ancestry = dict(preparation=a.preparation, sha256=sha(workspace / a.preparation),
                        prior_manual=str(ancestry_manual), prior_manual_sha256=sha(ancestry_manual),
                        reason='Exact installed field8 binding; frozen copied saves and dependencies retained',
                        preparer_sha256=sha(Path(__file__)))
        if a.refresh_driver:
            require(available_gib() >= 1, 'Compiler requires 1 GiB free memory')
            folder = workspace / ('driver-' + Path(a.out).stem)
            require(not folder.exists(), 'Frozen driver folder already exists')
            folder.mkdir()
            source = folder / 'BStartupDriverMod.as'
            shutil.copy2(HERE / source.name, source)
            for helper in helpers(HERE):
                shutil.copy2(helper, folder / helper.name)
            frozen_swf = folder / 'BStartupDriverMod.swf'
            command = [str(JAVA), '-Xmx512m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
                       '+flexlib=' + str(SDK / 'frameworks'), '-source-path=' + str(folder),
                       '-swf-version=38', '-debug=true', '-optimize=true', '-output=' + str(frozen_swf), str(source)]
            with (folder / 'build.log').open('x', encoding='utf-8') as log:
                reg.before_launch('loading external observer compiler')
                process = subprocess.Popen(command, env=dict(os.environ, AIR_HOME=str(SDK)), stdout=log, stderr=subprocess.STDOUT)
                reg.child(process.pid)
                try:
                    require(process.wait() == 0, 'Observer compilation failed; frozen input/log retained')
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait()
                    reg.child_stopped()
            require(frozen_swf.is_file(), 'Compiler did not create the external observer')
            verify_files(game, {k: v for k, v in old['files'].items() if k.lower() not in MUTABLE})
            shutil.copy2(frozen_swf, game / 'mods/BStartupDriver/release/BStartupDriverMod.swf')
            updated.update(compiler_command=command, driver=sha(source), helpers={x.name: sha(x) for x in helpers(folder)})
        else:
            require((frozen_source.parent / 'BStartupDriverMod.swf').is_file(), 'Deployment needs the original frozen driver SWF')
        for name in manual['files']:
            if name.lower() in ('pfe.swf', 'mods/rconnect/release/rconnectmod.swf'):
                shutil.copy2(playable / 'game' / name, game / name)
        save(game / 'mods/Rconnect/release/config.txt', dict(manual['config'], role='', autoGame=False, probe=False))
        replaced = MUTABLE | {'mods/bstartupdriver/release/bstartupdrivermod.swf'}
        for name in updated['files']:
            if name.lower() in replaced:
                updated['files'][name] = sha(game / name)
        updated.update(manual_manifest=MANUAL, original_files=manual['files'], ancestry=ancestry)
        verify_files(game, updated['files'])
        save(target, updated)
        reg.outcome = 'passed'
    print(json.dumps(dict(preparation=str(target), sha256=sha(target), refreshed_driver=a.refresh_driver), ensure_ascii=False))


if __name__ == '__main__':
    main()
