"""Freeze Sandevistan's independently attached B API; never touch its release."""
import argparse
import os
import shutil
import subprocess
from common import ROOT, SDK, JAVA, FFDEC, inside_build, sha, save


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    out = inside_build(ROOT / args.output)
    if out.exists():
        raise FileExistsError('Use a new Sandevistan build directory')
    out.mkdir(parents=True)
    sources = {}
    source = ROOT.parent / 'Sandevistan'
    for folder in ('src', 'build/stubs-high-fps'):
        for path in sorted((source / folder).rglob('*.as')):
            name = path.relative_to(source).as_posix()
            target = out / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            sources[name] = sha(target)
    externs = ['fe.serv.Gov60']
    def compiler(jar):
        return [str(JAVA), '-Xmx512m', '-Dsun.io.useCanonCaches=false', '-jar', str(SDK / 'lib' / jar),
                '+configname=air', '+flexlib=' + str(SDK / 'frameworks')]
    commands = [compiler('compc.jar') + ['-source-path=' + str(out / 'build/stubs-high-fps'),
                '-include-classes=' + ','.join(externs), '-output=' + str(out / 'Gov60Stubs.swc'), '-swf-version=38'],
                compiler('mxmlc.jar') + ['-source-path=' + str(out / 'src'),
                '-external-library-path+=' + str(out / 'Gov60Stubs.swc'), '-swf-version=38',
                '-debug=false', '-optimize=true', '-output=' + str(out / 'SandevistanMod.swf'), str(out / 'src/SandevistanMod.as')]]
    with (out / 'build.log').open('w', encoding='utf-8') as log:
        for command in commands:
            subprocess.run(command, cwd=out, env=dict(os.environ, AIR_HOME=str(SDK)),
                           stdout=log, stderr=subprocess.STDOUT, check=True)
    with (out / 'classes.txt').open('w', encoding='utf-8') as log:
        subprocess.run([str(JAVA), '-jar', str(FFDEC), '-dumpAS3', str(out / 'SandevistanMod.swf')], stdout=log, check=True)
    embedded = {line.split()[0] for line in (out / 'classes.txt').read_text(encoding='utf-8').splitlines() if line.strip()}
    if 'SandyAuthority' not in embedded or embedded.intersection(externs):
        raise ValueError('Invalid Sandevistan class isolation')
    save(out / 'build-input.json', dict(experimental_only=True, family='sandy-authority-v1', sources=sources,
        candidate_sha256=sha(out / 'SandevistanMod.swf'), extern_sha256=sha(out / 'Gov60Stubs.swc'),
        compiler={str(p): sha(p) for p in (JAVA, SDK / 'lib/mxmlc.jar', SDK / 'lib/compc.jar', SDK / 'frameworks/libs/air/airglobal.swc')},
        commands=commands, script_sha256=sha(__file__), classes_sha256=sha(out / 'classes.txt')))
    print('Frozen independent Sandevistan bridge: ' + str(out), flush=True)


if __name__ == '__main__':
    main()
