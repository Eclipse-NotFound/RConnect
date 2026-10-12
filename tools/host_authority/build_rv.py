"""Freeze the separate RV B lease and default fallback; never changes release."""
import argparse
import os
import shutil
import subprocess
from common import ROOT, SDK, JAVA, FFDEC, inside_build, sha, save


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--output',required=True)
    args=ap.parse_args()
    out=inside_build(ROOT/args.output)
    if out.exists():
        raise FileExistsError('Use a new RV build directory')
    out.mkdir(parents=True)
    sources={}
    source=ROOT.parent/'RealisticVision'
    for folder in ('src','build/stubs','tests/authority'):
        for path in sorted((source/folder).rglob('*.as')):
            name=path.relative_to(source).as_posix()
            target=out/name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,target)
            sources[name]=sha(target)
    externs=sorted(p.relative_to(out/'build/stubs').with_suffix('').as_posix().replace('/','.') for p in (out/'build/stubs').rglob('*.as'))
    def compiler(jar):
        return [str(JAVA),'-Xmx512m','-Dsun.io.useCanonCaches=false','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
    commands=[compiler('compc.jar')+['-source-path='+str(out/'build/stubs'),'-include-classes='+','.join(externs),'-output='+str(out/'GameStubs.swc'),'-swf-version=38']]
    for entry,output in [('src/RealisticVisionMod.as','RealisticVisionMod.swf'),('tests/authority/AuthorityViewChecks.as','AuthorityViewChecks.swf')]:
        commands.append(compiler('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'GameStubs.swc'),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/output),str(out/entry)])
    with (out/'build.log').open('w',encoding='utf-8') as log:
        for cmd in commands:
            subprocess.run(cmd,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
    with (out/'classes.txt').open('w',encoding='utf-8') as log:
        subprocess.run([str(JAVA),'-jar',str(FFDEC),'-dumpAS3',str(out/'RealisticVisionMod.swf')],stdout=log,check=True)
    classes=(out/'classes.txt').read_text(encoding='utf-8')
    if any(line.strip().startswith('fe.') for line in classes.splitlines()) or 'RVAuthorityView' not in classes:
        raise ValueError('Invalid RV class isolation')
    save(out/'build-input.json',dict(experimental_only=True,family='rv-authority-v1',sources=sources,candidate_sha256=sha(out/'RealisticVisionMod.swf'),tests_sha256=sha(out/'AuthorityViewChecks.swf'),extern_sha256=sha(out/'GameStubs.swc'),compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'lib/compc.jar',SDK/'frameworks/libs/air/airglobal.swc')},commands=commands,script_sha256=sha(__file__),classes_sha256=sha(out/'classes.txt')))
    print('Frozen independent RV bridge: '+str(out),flush=True)


if __name__=='__main__':
    main()
