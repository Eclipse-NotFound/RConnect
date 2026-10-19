"""External native security test driver; production candidate bytes stay exact."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from prepare_security_terminals import ROOT,sha
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,SDK

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output',type=Path);ap.add_argument('--candidate',required=True,type=Path);args=ap.parse_args()
    out=(ROOT/args.output).resolve();candidate=(ROOT/args.candidate).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists();assert candidate.parent==ROOT/'build/m52'
    out.mkdir();source=candidate/'src';tests=out/'tests';shutil.copytree(ROOT/'tests/security-terminals',tests)
    classes=['.'.join(p.relative_to(source).with_suffix('').parts) for p in sorted(source.rglob('*.as'))]
    stub=candidate/'build/GameCombatStubs.swc';external=out/'ProductionDeclarations.swc'
    base=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/compc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=true']
    commands=[base+['-source-path='+str(source),'-external-library-path+='+str(stub),'-include-classes='+','.join(classes),'-output='+str(external)]]
    compile=base.copy();compile[3]=str(SDK/'lib/mxmlc.jar')
    commands.append(compile+['-source-path='+str(tests),'-external-library-path+='+str(external),'-external-library-path+='+str(stub),'-output='+str(out/'EffectsDriver.swf'),str(tests/'SecurityTerminalTestDoc.as')])
    commands.append(compile+['-source-path='+str(ROOT/'tests/harness'),'-output='+str(out/'EffectsHarness.swf'),str(ROOT/'tests/harness/RConnectDoc.as')])
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        for cmd in commands:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    result=dict(candidate_sha256=sha(candidate/'RConnectMod.swf'),entry='SecurityTerminalTestDoc',driver_sha256=sha(out/'EffectsDriver.swf'),source_sha256=sha(tests/'SecurityTerminalTestDoc.as'))
    (out/'driver-input.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':main()
