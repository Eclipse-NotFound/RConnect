"""Freeze the paired-driver coordination repair without copying the game again."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import ROOT, GAME, JAVA, SDK, sha, read, save, verify_files, Registration, available_gib


def main():
    workspace = ROOT/'build/ab/startup-repair-20261025-01'
    out = workspace/'driver-pair2'
    out.mkdir()
    old = read(workspace/'prepared.json')
    source = out/'BStartupDriverMod.as'
    shutil.copy2(Path(__file__).with_name('BStartupDriverMod.as'), source)
    artifact = out/'BStartupDriverMod.swf'
    command = [str(JAVA), '-Xmx512m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
               '+flexlib='+str(SDK/'frameworks'), '-source-path='+str(out), '-swf-version=38',
               '-debug=true', '-optimize=true', '-output='+str(artifact), str(source)]
    with Registration(owner='RConnect B / 启动修复', purpose='配对驱动协调修正编译', run_dir=out, evidence=out/'build.json') as reg:
        if available_gib()<1: raise RuntimeError('Compiler needs 1 GiB available')
        verify_files(workspace/'game', {k:v for k,v in old['files'].items()
            if k.lower() not in {'mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt'}})
        with (out/'build.log').open('x', encoding='utf-8') as log:
            subprocess.run(command, env=dict(os.environ, AIR_HOME=str(SDK)), stdout=log, stderr=subprocess.STDOUT, check=True)
        # Preserve the first driver and preparation. Existing results keep their exact hashes.
        key='mods/BStartupDriver/release/BStartupDriverMod.swf'
        destination=workspace/'game'/key
        shutil.copy2(destination, workspace/'BStartupDriver-original.swf')
        shutil.copy2(artifact, destination)
        updated=json.loads(json.dumps(old))
        updated['files'][key]=sha(artifact)
        updated['driver']=sha(source)
        updated['compiler_command']=command
        updated['previous_preparation_sha256']=sha(workspace/'prepared.json')
        updated['pair_coordination_fix']='Host records its own unchanged 25-tick check before joiner leaves.'
        save(workspace/'prepared-pair2.json', updated)
        save(out/'build.json',dict(command=command,source_sha256=sha(source),artifact_sha256=sha(artifact),
             preparation_sha256=sha(workspace/'prepared-pair2.json'),script_sha256=sha(__file__)))
        reg.outcome='passed';reg.note='Only external test-driver coordination changed; product unchanged'
    print(json.dumps(read(out/'build.json'),ensure_ascii=False))


if __name__=='__main__': main()
