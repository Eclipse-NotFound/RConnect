"""Freeze the independently opted-in MSW B bridge, leaving its release intact."""
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
        raise FileExistsError('Use a new MSW build directory')
    out.mkdir(parents=True)
    sources={}
    source=ROOT.parent/'MoreSkills&Weapons'
    for folder in ('src','build/stubs'):
        for path in sorted((source/folder).rglob('*.as')):
            name=path.relative_to(source).as_posix()
            target=out/name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,target)
            sources[name]=sha(target)
    externs=sorted(p.relative_to(out/'build/stubs').with_suffix('').as_posix().replace('/','.') for p in (out/'build/stubs').rglob('*.as'))
    includes=['fe.unit.MSWBlindAccess','fe.inter.MSWLaserSats','fe.weapon.MSWPanicBlade','fe.weapon.MSWDazzlerWeapon','fe.weapon.MSWPointerWeapon','fe.weapon.MSWFlashWeapon','fe.weapon.MSWFlashBullet']
    def compiler(jar):
        return [str(JAVA),'-Xmx512m','-Dsun.io.useCanonCaches=false','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
    commands=[compiler('compc.jar')+['-source-path='+str(out/'build/stubs'),'-include-classes='+','.join(externs),'-output='+str(out/'SmartHost.swc'),'-swf-version=38'],compiler('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'SmartHost.swc'),'-includes='+','.join(includes),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/'MoreSkillsWeaponsMod.swf'),str(out/'src/MoreSkillsWeaponsMod.as')]]
    with (out/'build.log').open('w',encoding='utf-8') as log:
        for cmd in commands:
            subprocess.run(cmd,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
    with (out/'classes.txt').open('w',encoding='utf-8') as log:
        subprocess.run([str(JAVA),'-jar',str(FFDEC),'-dumpAS3',str(out/'MoreSkillsWeaponsMod.swf')],stdout=log,check=True)
    embedded={line.split()[0] for line in (out/'classes.txt').read_text(encoding='utf-8').splitlines() if line.strip()}
    if 'MSWAuthority' not in embedded or embedded.intersection(externs) or not set(includes).issubset(embedded):
        raise ValueError('Invalid MSW class isolation')
    save(out/'build-input.json',dict(experimental_only=True,family='msw-authority-v1',sources=sources,candidate_sha256=sha(out/'MoreSkillsWeaponsMod.swf'),extern_sha256=sha(out/'SmartHost.swc'),compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'lib/compc.jar',SDK/'frameworks/libs/air/airglobal.swc')},commands=commands,script_sha256=sha(__file__),classes_sha256=sha(out/'classes.txt')))
    print('Frozen independent MSW bridge: '+str(out),flush=True)


if __name__=='__main__':
    main()
