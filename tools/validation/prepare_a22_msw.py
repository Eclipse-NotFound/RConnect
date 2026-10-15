"""Build the optional A22 smart-target contract from installed MSW source only."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,SDK
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');ap.add_argument('--version');args=ap.parse_args()
    out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    original=ROOT.parent/'MoreSkills&Weapons'
    frozen=original/'build/out/flashbang'
    manifest=json.loads((frozen/'source-manifest.json').read_text(encoding='utf-8-sig'))
    source=frozen/'final-source/src';sources={}
    installation=json.loads((frozen/'installation.json').read_text(encoding='utf-8-sig'))
    assert installation['status']=='installed-hash-verified'
    assert sha(original/'release/MoreSkillsWeaponsMod.swf')==installation['sha256'].lower()
    for row in manifest:
        p=source/row['path'];assert sha(p)==row['sha256'],p
    assert {r['path'] for r in manifest}=={p.relative_to(source).as_posix() for p in source.rglob('*.as')}
    out.mkdir();shutil.copytree(source,out/'src')
    for p in (out/'src').rglob('*'):
        if p.is_file():sources[p.relative_to(out).as_posix()]=sha(p)
    overrides={}
    for p in (ROOT/'experimental/a22-fixes/msw-src').rglob('*.as'):
        n=p.relative_to(ROOT/'experimental/a22-fixes/msw-src').as_posix()
        overrides[n]={'before':sha(out/'src'/n),'after':sha(p)};shutil.copy2(p,out/'src'/n)
    if args.version:
        entry=out/'src/MoreSkillsWeaponsMod.as';text=entry.read_text(encoding='utf-8-sig')
        assert args.version.startswith('1.16.0-flashbang-') and text.count('"1.16.0-flashbang"')==1
        entry.write_text(text.replace('"1.16.0-flashbang"','"'+args.version+'"'),encoding='utf-8')
        overrides['MoreSkillsWeaponsMod.as']={'before':sources['src/MoreSkillsWeaponsMod.as'],'after':sha(entry)}
    shutil.copytree(original/'build/stubs',out/'stubs')
    externs=sorted(p.relative_to(out/'stubs').with_suffix('').as_posix().replace('/','.') for p in (out/'stubs').rglob('*.as'))
    includes=['fe.unit.MSWBlindAccess','fe.inter.MSWLaserSats','fe.weapon.MSWPanicBlade','fe.weapon.MSWDazzlerWeapon','fe.weapon.MSWPointerWeapon','fe.weapon.MSWFlashWeapon','fe.weapon.MSWFlashBullet']
    def compiler(jar):return [str(JAVA),'-Xmx384m','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
    commands=[compiler('compc.jar')+['-source-path='+str(out/'stubs'),'-include-classes='+','.join(externs),'-output='+str(out/'SmartHost.swc'),'-swf-version=38'],
        compiler('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'SmartHost.swc'),'-includes='+','.join(includes),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/'MoreSkillsWeaponsMod.swf'),str(out/'src/MoreSkillsWeaponsMod.as')]]
    with (out/'build.log').open('w',encoding='utf-8') as log:
        for cmd in commands:subprocess.run(cmd,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
    receipt=dict(experimental_only=True,contract='rconnectSmartTargetAllowed-v1',installed_source_manifest=sha(frozen/'source-manifest.json'),
        version=args.version or installation['version'],original_sha256=installation['sha256'].lower(),
        installed_receipt_sha256=sha(frozen/'installation.json'),
        baseline=sources,overrides=overrides,source={p.relative_to(out).as_posix():sha(p) for folder in ['src','stubs'] for p in (out/folder).rglob('*') if p.is_file()},
        candidate_sha256=sha(out/'MoreSkillsWeaponsMod.swf'),commands=commands,script_sha256=sha(Path(__file__)))
    (out/'prepared.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8');print(receipt['candidate_sha256'])
if __name__=='__main__':main()
