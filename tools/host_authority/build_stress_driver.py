"""Compile an external test stimulus against B's public probe seam; no B SWF changes."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path
from common import ROOT, JAVA, SDK, FFDEC, inside_build, save, sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.output);source=Path(__file__).parent/'stress_driver'
    if out.exists():raise FileExistsError('Every driver build is preserved separately')
    out.mkdir(parents=True);sources={}
    for folder in ('src','stubs'):
        for path in sorted((source/folder).rglob('*.as')):
            name=path.relative_to(source).as_posix();dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,dest);sources[name]=sha(dest)
    identity=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest()
    stamp=out/'src/StressDriverInfo.as';stamp.write_text(stamp.read_text().replace('__SOURCE_HASH__',identity),encoding='utf-8')
    sources['src/StressDriverInfo.as']=sha(stamp)
    env=dict(os.environ,AIR_HOME=str(SDK))
    def compiler(jar):return [str(JAVA),'-Xmx512m','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
    classes=','.join(p.relative_to(out/'stubs').with_suffix('').as_posix().replace('/','.') for p in sorted((out/'stubs').rglob('*.as')))
    commands=[compiler('compc.jar')+['-source-path='+str(out/'stubs'),'-include-classes='+classes,'-output='+str(out/'ProbeExterns.swc'),'-swf-version=38']]
    files={}
    for entry in ('RConnectStressDriverMod','ContinuousStressDoc'):
        commands.append(compiler('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'ProbeExterns.swc'),
            '-output='+str(out/(entry+'.swf')),'-swf-version=38','-debug=false','-optimize=true',str(out/'src'/(entry+'.as'))])
    with (out/'build.log').open('x',encoding='utf-8') as log:
        for cmd in commands:subprocess.run(cmd,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    for entry in ('RConnectStressDriverMod','ContinuousStressDoc'):
        artifact=out/(entry+'.swf');files[artifact.name]=sha(artifact)
        with (out/(entry+'.classes.txt')).open('x',encoding='utf-8') as log:
            subprocess.run([str(JAVA),'-jar',str(FFDEC),'-dumpAS3',str(artifact)],stdout=log,check=True)
        names=(out/(entry+'.classes.txt')).read_text()
        if any('authority.'+name in names for name in ('Probe','NativeAccess','HostSession','ClientReplica')):
            raise ValueError('External driver embedded a frozen B class')
    save(out/'build-input.json',dict(experimental_only=True,family='rconnect-external-stress-driver-v1',source_id=identity,
        sources=sources,files=files,commands=commands,script_sha256=sha(__file__),extern_sha256=sha(out/'ProbeExterns.swc')))
    print(dict(built=str(out),source_id=identity,files=files),flush=True)


if __name__=='__main__':main()
