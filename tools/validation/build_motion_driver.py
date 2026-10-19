"""Compile focused external drivers against the frozen gameplay candidate.

Retains exact existing continuity, projectile and density tests. The fast-motion
probe is separate; no production class is linked into the external driver.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
from prepare_motion_transport import ROOT, JAVA, SDK, sha


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    candidate=(ROOT/args.candidate).resolve();out=(ROOT/args.output).resolve()
    assert candidate.parent==out.parent==ROOT/'build/m52' and not out.exists()
    m=json.loads((candidate/'prepared.json').read_text(encoding='utf-8-sig'))
    assert m['compiled'] and sha(candidate/'RConnectMod.swf')==m['candidate_sha256']
    for name,digest in {**m['source'],**m['inputs']}.items():assert sha(candidate/name)==digest,name
    base=ROOT/'build/m52/coop-bundle-drivers-04'
    old=json.loads((base/'prepared.json').read_text(encoding='utf-8-sig'))
    for name,digest in old['files'].items():assert sha(base/name)==digest,name
    out.mkdir();shutil.copytree(base/'tests',out/'tests')
    shutil.copyfile(ROOT/'tests/FastMotionNetworkTestDoc.as',out/'tests/FastMotionNetworkTestDoc.as')
    # Existing driver binaries reference the same public classes. The private
    # Session branch and added HostServer query require no driver ABI change.
    for kind in ['continuity','density','pause-timing','animation']:
        shutil.copytree(base/kind,out/kind)
        (out/kind/'driver-input.json').write_text(json.dumps(dict(
            candidate_sha256=m['candidate_sha256'],entry=json.loads((base/kind/'driver-input.json').read_text())['entry'],
            binary_origin=str((base/kind).relative_to(ROOT)),binary_origin_sha256=sha(base/kind/'EffectsDriver.swf')),
            indent=2),encoding='utf-8')
    declarations=base/'ProductionDeclarations.swc'
    stub=candidate/'build/GameCombatStubs.swc'
    command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air',
             '+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true',
             '-source-path='+str(out/'tests'),'-external-library-path+='+str(declarations),
             '-external-library-path+='+str(stub)]
    fast=out/'fast-motion';fast.mkdir()
    shutil.copyfile(base/'density/EffectsHarness.swf',fast/'EffectsHarness.swf')
    command+=['-output='+str(fast/'EffectsDriver.swf'),str(out/'tests/FastMotionNetworkTestDoc.as')]
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        p=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)))
    (fast/'driver-input.json').write_text(json.dumps(dict(candidate_sha256=m['candidate_sha256'],
        entry='FastMotionNetworkTestDoc',diagnostic_only=True),indent=2),encoding='utf-8')
    record=dict(candidate_sha256=m['candidate_sha256'],source_manifest=sha(candidate/'prepared.json'),
                base_driver_manifest=sha(base/'prepared.json'),external_declarations_sha256=sha(declarations),
                stubs_sha256=sha(stub),recipe_sha256=sha(Path(__file__)),compile_exit=p.returncode,
                files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()})
    (out/'prepared.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps(dict(output=str(out),compile_exit=p.returncode)))
    raise SystemExit(p.returncode)


if __name__=='__main__':main()
