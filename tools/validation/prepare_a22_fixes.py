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
    ap.add_argument('--installed-baseline',action='store_true',help='Use an already deployed map-only pair as the unchanged native/control baseline')
    args=ap.parse_args()
    base=(ROOT/args.base).resolve()
    assert base.parent==ROOT/'build/m52'
    receipt=json.loads((base/'prepared.json').read_text(encoding='utf-8'))
    out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    assert sha(base/'RConnectMod.swf')==receipt['candidate_sha256']
    if args.installed_baseline:
        deployment=json.loads((base/'deployment.json').read_text(encoding='utf-8'))
        assert deployment['status']=='deployed-smoke-passed'
        assert deployment['proof']['candidate_sha256']==receipt['candidate_sha256']==sha(ROOT/'release/RConnectMod.swf')
        assert deployment['proof']['candidate_game_sha256']==receipt['candidate_game_sha256']==sha(ROOT.parents[1]/'pfe.swf')
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
    assert source.count('"0.2.22-map1"')==1
    entry.write_text(source.replace('"0.2.22-map1"','"'+args.version+'"'),encoding='utf-8')
    for directory in ('tools/stubs','tests'):
        for p in (ROOT/directory).rglob('*'):
            if p.is_file():put(out/p.relative_to(ROOT),p.read_bytes())
    for n in ('tools/build_mod.py','tools/build_effects_driver.py'):
        put(out/n,(ROOT/n).read_bytes())
    for n,h in [('control.swf',receipt['control_sha256']),('native/pfe.swf',receipt['candidate_game_sha256'])]:
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
        receipt.update(original_game_sha256=receipt['candidate_game_sha256'],
            control_sha256=sha(base/'RConnectMod.swf'),control_version='0.2.22-map1',
            installed_baseline=base.relative_to(ROOT).as_posix(),
            installed_deployment_sha256=sha(base/'deployment.json'),native_unchanged=True)
    (out/'prepared.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:receipt[k] for k in ('kind','version','candidate_sha256','overrides')}))

if __name__=='__main__':main()
