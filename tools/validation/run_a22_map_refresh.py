"""Fresh current-installation controls for the isolated A22 map-only pair."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from native_runtime_assets import native_runtime_files

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def save(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mode', choices=['freeze','control','candidate'])
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--candidate', required=True)
    ap.add_argument('--entry', default='NativeMapGenerationTestDoc')
    ap.add_argument('--label')
    ap.add_argument('--land')
    ap.add_argument('--seconds',type=int,default=600)
    ap.add_argument('--expected-version')
    ap.add_argument('--frozen-runtime',action='store_true',help='Test an already frozen combination even when other developers changed the installation; still record and protect the installation observed at this run')
    ap.add_argument('--msw-candidate',type=Path)
    args = ap.parse_args()
    out, bundle = [(ROOT/p).resolve() for p in (args.candidate,args.bundle)]
    assert out.parent == bundle.parent == ROOT/'build/m52'
    m = read(out/'prepared.json')
    if args.mode == 'freeze':
        assert not bundle.exists()
        assert sha(GAME/'pfe.swf') == m['original_game_sha256']
        files = set(native_runtime_files(GAME)) | {GAME/'adl64.exe', GAME/'mods/loader-manifest.txt'}
        files.update(p for p in (GAME/'runtimes/air/win64').rglob('*') if p.is_file())
        for row in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
            if row.startswith('#') or '|' not in row: continue
            directory,entry = row.split('|')[:2]
            files.update(p for n in (entry+'.swf','config.txt','config.json') if (p:=GAME/'mods'/directory/'release'/n).is_file())
        hashes = {p.relative_to(GAME).as_posix():sha(p) for p in sorted(files)}
        assert shutil.disk_usage(ROOT).free > sum(p.stat().st_size for p in files)*4
        bundle.mkdir()
        for name,digest in hashes.items():
            target=bundle/'game'/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(GAME/name,target)
            assert sha(target)==digest and sha(GAME/name)==digest
        for name,digest in hashes.items(): assert sha(GAME/name)==digest, name
        save(bundle/'inputs.json',dict(files=hashes,diagnostic_only=True,installation_modified=False))
        print('Frozen runtime files:',len(hashes));return
    frozen=read(bundle/'inputs.json')
    installation_before={name:sha(GAME/name) if (GAME/name).is_file() else None for name in frozen['files']}
    runtime_difference={n:dict(runtime=h,installed=installation_before[n]) for n,h in frozen['files'].items() if installation_before[n]!=h}
    for name,digest in frozen['files'].items():
        assert sha(bundle/'game'/name)==digest, name
        if not args.frozen_runtime: assert installation_before[name]==digest, 'Installation changed before run: '+name
    for name,digest in {**m['source'],**m['inputs']}.items(): assert sha(out/name)==digest,name
    control=args.mode=='control'
    binary=out/('control.swf' if control else 'RConnectMod.swf')
    assert sha(binary)==m['control_sha256' if control else 'candidate_sha256']
    assert sha(out/'native/pfe.swf')==m['candidate_game_sha256']
    label=args.label or args.mode+'-'+args.entry
    assert re.fullmatch(r'[A-Za-z0-9_-]+',label)
    result=out/(label+'-result.json');log=out/(label+'-run.log')
    assert not result.exists() and not log.exists()
    if args.entry=='NativeMapGenerationTestDoc': driver=out/'build'/('driver-'+args.mode)
    else:
        driver=out/'build'/('driver-'+label)
        assert not driver.exists()
        with (out/(label+'-build.log')).open('w',encoding='utf-8') as stream:
            subprocess.run([sys.executable,'-B','-X','utf8',str(out/'tools/build_effects_driver.py'),
                '--candidate',str(binary),'--source-root',str(out/'src'),'--java',str(JAVA),'--sdk',str(SDK),
                '--entry',args.entry,'--output',str(driver)],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,check=True)
    command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
        '--candidate',str(binary),'--game-root',str(bundle/'game'),'--effects-driver',str(driver),
        '--effects','--all-mods','--visible-windows','--seconds',str(args.seconds),
        '--land',args.land or ('rbl' if args.entry=='NativeMapGenerationTestDoc' else 'random_mane'),
        '--expected-version',args.expected_version or ('0.2.22-dev' if control else '0.2.22-map1')]
    if not control: command+=['--game-candidate',str(out/'native/pfe.swf')]
    msw_hash=None
    if args.msw_candidate:
        msw=args.msw_candidate.resolve()
        assert msw.parent.parent==ROOT/'build/m52' and msw.name=='MoreSkillsWeaponsMod.swf'
        msw_manifest=read(msw.parent/'prepared.json')
        for name,digest in msw_manifest['source'].items():assert sha(msw.parent/name)==digest,name
        msw_hash=sha(msw);assert msw_hash==msw_manifest['candidate_sha256']
        command+=['--msw-candidate',str(msw)]
    inputs=dict(prepared=sha(out/'prepared.json'),runtime=sha(bundle/'inputs.json'),
        runner=sha(ROOT/'tools/run_coop_regression.py'),script=sha(__file__),msw=msw_hash,
        driver={p.name:sha(p) for p in driver.glob('*.swf')})
    save(out/(label+'-intent.json'),dict(command=command,inputs=inputs,installation_before=installation_before,
        runtime_matches_installation=not runtime_difference,runtime_difference=runtime_difference))
    print('RUN',label,flush=True)
    with log.open('w',encoding='utf-8') as stream:
        proc=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
    output=log.read_text(encoding='utf-8',errors='replace')
    match=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',output,re.M)
    receipt=dict(entry=args.entry,control=control,exit=proc.returncode,inputs=inputs,run=match[1] if match else None,
        runtime_matches_installation=not runtime_difference,runtime_difference=runtime_difference,
        installation_changes={n:dict(before=h,after=sha(GAME/n) if (GAME/n).is_file() else None) for n,h in installation_before.items()
            if (sha(GAME/n) if (GAME/n).is_file() else None)!=h})
    if match:
        folder=ROOT/'build/cooperation'/match[1]
        actual=read(folder/'run.json')
        receipt['run_sha256']=sha(folder/'run.json')
        expected=m['original_game_sha256' if control else 'candidate_game_sha256']
        for role in ('host','join'):
            assert actual['inputs'][role]['game']==expected
            assert actual['inputs'][role]['production']==sha(binary)
            for name,digest in actual['inputs'][role]['modules'].items():
                name=name.replace('\\','/')
                if name.lower().startswith('mods/rconnect/'):continue
                if msw_hash and name.lower()=='mods/moreskills&weapons/release/moreskillsweaponsmod.swf':
                    assert digest==msw_hash;continue
                assert digest==frozen['files'][name],name
            lines=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
            receipt[role]=dict(passed=len(re.findall(r'^COOP PASS ',lines,re.M)),failed=len(re.findall(r'^COOP FAIL ',lines,re.M)),
                done='COOP EFFECTS DONE' in lines,log_sha256=sha(folder/(role+'.log')))
    save(result,receipt)
    print(json.dumps(receipt,ensure_ascii=False))
    print('\n'.join(s for s in output.splitlines() if 'COOP FAIL ' in s or 'RESULT ' in s)[-5000:])
    raise SystemExit(proc.returncode or int(bool(receipt['installation_changes'])))

if __name__=='__main__': main()
