"""Freeze and compile the authorized TDFC bridge; never writes its release."""
import argparse
import os
import shutil
import subprocess
from pathlib import Path
from common import ROOT, SDK, JAVA, FFDEC, inside_build, sha, save


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    out = inside_build(ROOT/args.output)
    if out.exists():
        raise FileExistsError('Use a new frozen TDFC build directory')
    out.mkdir(parents=True)
    sources = {}
    for folder in ('src', 'tests'):
        for path in sorted((ROOT.parent/'TDFC'/folder).rglob('*')):
            if not path.is_file():
                continue
            name = path.relative_to(ROOT.parent/'TDFC').as_posix()
            target = out/name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            sources[name] = sha(target)
    commands = []
    env = dict(os.environ, AIR_HOME=str(SDK))
    for entry, output in [('src/TDFCMod.as','TDFCMod.swf'), ('tests/LogicTests.as','LogicTests.swf')]:
        cmd = [str(JAVA), '-Xmx512m', '-Dsun.io.useCanonCaches=false', '-jar', str(SDK/'lib/mxmlc.jar'),
               '+configname=air', '+flexlib='+str(SDK/'frameworks'),
               '-source-path='+str(out/'src'), '-source-path+='+str(out/'tests'),
               '-swf-version=38', '-debug=true', '-optimize=false',
               '-output='+str(out/output), str(out/entry)]
        commands.append(cmd)
        with (out/(output+'.build.log')).open('w', encoding='utf-8') as log:
            subprocess.run(cmd, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (out/'classes.txt').open('w', encoding='utf-8') as log:
        subprocess.run([str(JAVA),'-jar',str(FFDEC),'-dumpAS3',str(out/'TDFCMod.swf')],stdout=log,check=True)
    classes=(out/'classes.txt').read_text(encoding='utf-8')
    if any(line.strip().startswith('fe.') for line in classes.splitlines()) or 'TDFCMod' not in classes:
        raise ValueError('Invalid TDFC class isolation')
    save(out/'build-input.json', dict(experimental_only=True, family='tdfc-authority-v1',sources=sources,
        candidate_sha256=sha(out/'TDFCMod.swf'), tests_sha256=sha(out/'LogicTests.swf'),
        compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'frameworks/libs/air/airglobal.swc')},
        commands=commands,script_sha256=sha(__file__),classes_sha256=sha(out/'classes.txt')))
    print('Frozen TDFC bridge and logic checks: '+str(out),flush=True)


if __name__=='__main__':
    main()
