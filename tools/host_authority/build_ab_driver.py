"""Freeze and compile the common A/B test fixture; never rebuild either candidate."""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path
from common import ROOT, JAVA, SDK, FFDEC, inside_build, save, sha

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    out.mkdir(parents=True)
    shutil.copytree(Path(__file__).parent/'ab_driver',out/'src')
    shutil.copytree(Path(__file__).parent/'stress_driver/stubs',out/'stubs')
    sources={p.relative_to(out).as_posix():sha(p) for part in ('src','stubs') for p in sorted((out/part).rglob('*.as'))}
    identity=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest()
    def cmd(jar):return [str(JAVA),'-Xmx512m','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
    externs=','.join(p.relative_to(out/'stubs').with_suffix('').as_posix().replace('/','.') for p in sorted((out/'stubs').rglob('*.as')))
    commands=[cmd('compc.jar')+['-source-path='+str(out/'stubs'),'-include-classes='+externs,'-output='+str(out/'Externs.swc'),'-swf-version=38']]
    entries=('ABBenchMod','ABPayloadA','ABPayloadB')
    for entry in entries:commands.append(cmd('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'Externs.swc'),'-output='+str(out/(entry+'.swf')),'-swf-version=38','-debug=false','-optimize=true',str(out/'src'/(entry+'.as'))])
    with (out/'build.log').open('x',encoding='utf-8') as log:
        for command in commands:subprocess.run(command,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
    files={}
    for entry in entries:
        p=out/(entry+'.swf');files[p.name]=sha(p)
        with (out/(entry+'.classes.txt')).open('x',encoding='utf-8') as log:subprocess.run([str(JAVA),'-jar',str(FFDEC),'-dumpAS3',str(p)],stdout=log,check=True)
        names=(out/(entry+'.classes.txt')).read_text()
        if 'authority.Probe' in names or 'rconnect.game.GameBridge' in names:raise ValueError('Production code embedded')
    save(out/'build-input.json',dict(family='rconnect-ab-bench-v1',source_id=identity,sources=sources,files=files,commands=commands,script_sha256=sha(__file__)))
    print(json.dumps(dict(output=str(out),source=identity)))
if __name__=='__main__':main()
