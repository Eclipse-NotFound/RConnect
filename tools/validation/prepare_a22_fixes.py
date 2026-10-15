"""Freeze small source overrides on the already verified A22/map source tree."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,SDK

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('output')
    ap.add_argument('--version',required=True)
    ap.add_argument('--overrides',action='store_true')
    ap.add_argument('--base',default='build/m52/a22-map-only-02')
    ap.add_argument('--current-native-sha',help='Pin a separately updated installed game without modifying or patching it')
    ap.add_argument('--installed-baseline',action='store_true',help='Use an already deployed A pair as the unchanged native/control baseline')
    args=ap.parse_args()
    base=(ROOT/args.base).resolve()
    assert base.parent==ROOT/'build/m52'
    receipt=json.loads((base/'prepared.json').read_text(encoding='utf-8'))
    out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    assert sha(base/'RConnectMod.swf')==receipt['candidate_sha256']
    if args.current_native_sha:
        assert args.installed_baseline, 'New native baseline requires an installed module baseline'
        assert sha(ROOT.parents[1]/'pfe.swf')==args.current_native_sha
    if args.installed_baseline:
        deployment=json.loads((base/'deployment.json').read_text(encoding='utf-8'))
        assert deployment['status']=='deployed-smoke-passed'
        assert deployment['proof']['candidate_sha256']==receipt['candidate_sha256']==sha(ROOT/'release/RConnectMod.swf')
        proof=deployment['proof']
        assert proof.get('candidate_game_sha256',proof.get('native_sha256'))==receipt['candidate_game_sha256']
        if not args.current_native_sha:assert receipt['candidate_game_sha256']==sha(ROOT.parents[1]/'pfe.swf')
    for n,h in receipt['source'].items():
        assert sha(base/n)==h,n
        put(out/n,(base/n).read_bytes())
    overrides={}
    if args.overrides:
        for p in sorted((ROOT/'experimental/a22-fixes/src').rglob('*.as')):
            n=p.relative_to(ROOT/'experimental/a22-fixes').as_posix()
            overrides[n]=dict(before=sha(out/n) if (out/n).exists() else None,after=sha(p))
            put(out/n,p.read_bytes())
    entry=out/'src/RConnectMod.as'
    source=entry.read_text(encoding='utf-8-sig')
    base_version=receipt['version']
    assert base_version.startswith('0.2.22-') and source.count('"'+base_version+'"')==1
    entry.write_text(source.replace('"'+base_version+'"','"'+args.version+'"'),encoding='utf-8')
    for n,h in receipt['inputs'].items():
        if n.startswith('tools/stubs/'):
            assert sha(base/n)==h,n
            put(out/n,(base/n).read_bytes())
    for p in (ROOT/'tests').rglob('*'):
        if p.is_file():put(out/p.relative_to(ROOT),p.read_bytes())
    for n in ('tools/build_mod.py','tools/build_effects_driver.py'):
        put(out/n,(ROOT/n).read_bytes())
    for n,h in [('control.swf',receipt['control_sha256']),('native/pfe.swf',receipt['candidate_game_sha256'])]:
        if n=='native/pfe.swf' and args.current_native_sha:
            put(out/n,(ROOT.parents[1]/'pfe.swf').read_bytes())
            assert sha(out/n)==args.current_native_sha
            continue
        if args.installed_baseline and n=='control.swf':
            put(out/n,(base/'RConnectMod.swf').read_bytes());continue
        assert sha(base/n)==h,n
        put(out/n,(base/n).read_bytes())
    with (out/'build.log').open('w',encoding='utf-8') as stream:
        subprocess.run([sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),
            '--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')],
            cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,check=True)
    receipt.update(kind='isolated-a22-followup',version=args.version,base_prepared_sha256=sha(base/'prepared.json'),
        candidate_sha256=sha(out/'RConnectMod.swf'),overrides=overrides,script_sha256=sha(Path(__file__)),
        source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')},
        inputs={p.relative_to(out).as_posix():sha(p) for d in ('tools','tests') for p in (out/d).rglob('*') if p.is_file()})
    if args.installed_baseline:
        if args.current_native_sha:
            receipt.update(previous_native_sha256=receipt['candidate_game_sha256'],candidate_game_sha256=args.current_native_sha,
                native_baseline_update='pinned current installation; no native import or deployment')
        receipt.update(original_game_sha256=receipt['candidate_game_sha256'],
            control_sha256=sha(base/'RConnectMod.swf'),control_version=base_version,
            installed_baseline=base.relative_to(ROOT).as_posix(),
            installed_deployment_sha256=sha(base/'deployment.json'),native_unchanged=True)
    if args.current_native_sha:assert sha(ROOT.parents[1]/'pfe.swf')==args.current_native_sha
    (out/'prepared.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:receipt[k] for k in ('kind','version','candidate_sha256','overrides')}))

if __name__=='__main__':main()
