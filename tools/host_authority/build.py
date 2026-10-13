"""Compile only the B source root with its own frozen extern SWC."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from common import ROOT, EXPERIMENT, JAVA, SDK, FFDEC, inside_build, sha, save


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', required=True)
    ap.add_argument('--source-root', help='Explicit isolated diagnostic source copy below build/ab')
    ap.add_argument('--optimized', action='store_true', help='Use production compiler settings; preserve the exact commands in the build manifest')
    args = ap.parse_args()
    source_root = inside_build(ROOT/args.source_root) if args.source_root else EXPERIMENT
    out = inside_build(ROOT/args.output)
    if out.is_relative_to(source_root) or not (source_root/'src/RConnectDoc.as').is_file():
        raise ValueError('Use a complete source root and a separate build output')
    if out.exists():
        raise FileExistsError('Every compilation gets a fresh directory')
    for tool in (JAVA, SDK/'lib/mxmlc.jar', SDK/'lib/compc.jar', FFDEC):
        if not tool.is_file():
            raise FileNotFoundError(tool)
    out.mkdir(parents=True)
    sources = {}
    for folder in ('src', 'stubs'):
        for path in sorted((source_root/folder).rglob('*.as')):
            name = path.relative_to(source_root).as_posix()
            dest = out/name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
            sources[name] = sha(dest)
    source_id = hashlib.sha256(json.dumps(sources, sort_keys=True).encode('utf-8')).hexdigest()
    stamp = out/'src/authority/BuildInfo.as'
    template = stamp.read_text(encoding='utf-8')
    if template.count('__SOURCE_HASH__') != 1:
        raise RuntimeError('Build stamp template changed')
    stamp.write_text(template.replace('__SOURCE_HASH__', source_id), encoding='utf-8')
    native_capability = re.search(r'NATIVE:String="([^"]+)"', template).group(1)
    sources['src/authority/BuildInfo.as'] = sha(stamp)
    externs = sorted(p.relative_to(out/'stubs').with_suffix('').as_posix().replace('/', '.') for p in (out/'stubs').rglob('*.as'))
    env = dict(os.environ, AIR_HOME=str(SDK))
    def compiler(jar):
        return [str(JAVA), '-Xmx512m', '-Dsun.io.useCanonCaches=false', '-jar', str(SDK/'lib'/jar),
            '+configname=air', '+flexlib='+str(SDK/'frameworks')]
    commands = [compiler('compc.jar')+['-source-path='+str(out/'stubs'),
        '-include-classes='+','.join(externs), '-output='+str(out/'NativeExterns.swc'), '-swf-version=38'],
        compiler('mxmlc.jar')+['-source-path='+str(out/'src'),
        '-external-library-path+='+str(out/'NativeExterns.swc'), '-output='+str(out/'RConnectMod.swf'),
        '-swf-version=38', '-debug='+str(not args.optimized).lower(), '-optimize='+str(args.optimized).lower(),
        '-warnings=true', str(out/'src/RConnectDoc.as')]]
    with (out/'build.log').open('w', encoding='utf-8') as log:
        for cmd in commands:
            subprocess.run(cmd, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    with (out/'classes.txt').open('w', encoding='utf-8') as log:
        subprocess.run([str(JAVA), '-jar', str(FFDEC), '-dumpAS3', str(out/'RConnectMod.swf')], stdout=log, check=True)
    classes = (out/'classes.txt').read_text(encoding='utf-8')
    embedded = {line.split()[0] for line in classes.splitlines() if line.strip()}
    if 'RConnectMod' not in embedded or embedded.intersection(externs):
        raise RuntimeError('Entry missing or native extern classes embedded')
    save(out/'build-input.json', dict(experimental_only=True, family='host-authority-b', optimized=args.optimized, source_id=source_id, native_capability=native_capability, sources=sources,
        source_root=str(source_root.relative_to(ROOT)),
        candidate_sha256=sha(out/'RConnectMod.swf'), extern_sha256=sha(out/'NativeExterns.swc'),
        compiler={str(p):sha(p) for p in (JAVA, SDK/'lib/mxmlc.jar', SDK/'lib/compc.jar', SDK/'frameworks/libs/air/airglobal.swc')},
        commands=commands, script_sha256=sha(__file__), classes_sha256=sha(out/'classes.txt')))
    print('B build: '+str(out/'RConnectMod.swf'), flush=True)


if __name__ == '__main__':
    main()
