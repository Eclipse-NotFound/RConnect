"""Compile a separate driver against an already-built production SWF.

The temporary SWC is an external declaration index, never linked into the driver.
No game or production code is patched. Used only in isolated regression copies.
"""
import argparse
import os
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--java',required=True)
    ap.add_argument('--sdk',type=Path,default=Path(r'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk'))
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--entry',default='EffectsTerrainTestDoc',choices=['EffectsTerrainTestDoc','TurretTestDoc','PresentationTestDoc','RoomCooperationTestDoc','CoopTestDoc','SatsTestDoc','CombatStateTestDoc','CombatNetworkTestDoc'])
    args=ap.parse_args()
    out=args.output.resolve()
    if not out.is_relative_to(ROOT/'build'): ap.error('Output must be inside this mod build directory')
    out.mkdir(parents=True,exist_ok=True)
    classes=[]
    for src in sorted((ROOT/'src').rglob('*.as')):
        relative=src.relative_to(ROOT/'src').with_suffix('')
        parts=list(relative.parts)
        classes.append('.'.join(parts))
    external=out/'ProductionDeclarations.swc'
    compiler=[args.java,'-Xmx384m','-jar',str(args.sdk/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(args.sdk/'frameworks'),'-swf-version=38','-debug=false','-optimize=true']
    env=dict(os.environ,AIR_HOME=str(args.sdk))
    declarations=list(compiler);declarations[3]=str(args.sdk/'lib/compc.jar')
    subprocess.run(declarations+['-source-path='+str(ROOT/'src'),'-external-library-path+='+str(ROOT/'build/GameCombatStubs.swc'),
        '-include-classes='+','.join(classes),'-output='+str(external)],check=True,env=env)
    subprocess.run(compiler+['-source-path='+str(ROOT/'tests'),'-external-library-path+='+str(external),
        '-external-library-path+='+str(ROOT/'build/GameCombatStubs.swc'),'-output='+str(out/'EffectsDriver.swf'),
        str(ROOT/'tests'/(args.entry+'.as'))],check=True,env=env)
    subprocess.run(compiler+['-source-path='+str(ROOT/'tests/harness'),'-output='+str(out/'EffectsHarness.swf'),
        str(ROOT/'tests/harness/RConnectDoc.as')],check=True,env=env)
    (out/'driver-input.json').write_text(json.dumps({'candidate_sha256':hashlib.sha256(args.candidate.read_bytes()).hexdigest(),'entry':args.entry},indent=2))

if __name__=='__main__': main()
