"""Reproducible A build. Requires Python 3.9+, Java 11+ and Flex with AIR SDK.

Only writes to --output (default build/a-release). Never installs the result.
Native declarations are external-only and must not be packaged as runtime code.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
from generate_locales import generate
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(path):return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*.as'))}
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--sdk',type=Path,required=True)
    ap.add_argument('--java',default='java');ap.add_argument('--output',type=Path,default=ROOT/'build/a-release')
    args=ap.parse_args();sdk=args.sdk.resolve();out=args.output.resolve()
    assert not out.exists(),'Use a new output directory; existing results are preserved.'
    assert not out.is_relative_to(ROOT/'release'),'Build a candidate, not the installed file.'
    coverage=generate(check=True);out.mkdir(parents=True)
    source=inventory(ROOT/'src');stubs=inventory(ROOT/'tools/stubs')
    names=[Path(rel).with_suffix('').as_posix().replace('/','.') for rel in stubs]
    common=[args.java,'-Xmx384m','-jar']
    flags=['+configname=air','+flexlib='+str(sdk/'frameworks'),'-swf-version=38']
    commands=[common+[str(sdk/'lib/compc.jar')]+flags+['-source-path='+str(ROOT/'tools/stubs'),'-include-classes='+','.join(names),'-output='+str(out/'GameCombatStubs.swc')],
              common+[str(sdk/'lib/mxmlc.jar')]+flags+['-debug=false','-optimize=true','-source-path='+str(ROOT/'src'),'-external-library-path+='+str(out/'GameCombatStubs.swc'),'-output='+str(out/'RConnectMod.swf'),str(ROOT/'src/RConnectDoc.as')]]
    with (out/'compile.log').open('w',encoding='utf8') as log:
        for command in commands:
            subprocess.run(command,cwd=out,env=dict(os.environ,AIR_HOME=str(sdk)),stdout=log,stderr=subprocess.STDOUT,check=True)
    assert inventory(ROOT/'src')==source and inventory(ROOT/'tools/stubs')==stubs,'Inputs changed during build'
    result=dict(source=source,stubs=stubs,localization=coverage,swf_sha256=sha(out/'RConnectMod.swf'))
    (out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(compiled=True,sha256=result['swf_sha256'],localization=coverage)))
if __name__=='__main__':main()
