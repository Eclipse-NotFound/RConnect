"""Run frozen wall-impact drivers, checking the live installation stayed intact."""
import argparse
import json
import re
import subprocess
import sys
from check_coop_bundle import ROOT, M52, sha, inventory, save
from run_security_terminals import installation, test_port

def main():
    ap=argparse.ArgumentParser();ap.add_argument('candidate');ap.add_argument('--suite',required=True)
    ap.add_argument('--label',required=True);ap.add_argument('--control',action='store_true')
    ap.add_argument('--all-mods',action='store_true');ap.add_argument('--registry-wait',type=float,default=300)
    args=ap.parse_args();out=(ROOT/args.candidate).resolve();assert out.parent==M52
    m=json.loads((out/'prepared.json').read_text('utf-8'))
    assert inventory(out/'src')==m['source'] and inventory(out/'tests')==m['tests']
    assert inventory(out/'drivers')==m['drivers'] and sha(out/'RConnectMod.swf')==m['sha256']
    assert args.suite in ['WallBallisticTestDoc','WallEnergyTestDoc','WallMagicTestDoc']
    assert re.fullmatch(r'[a-zA-Z0-9-]+',args.label)
    log=out/(args.label+'.log');result=out/(args.label+'.json');assert not log.exists() and not result.exists()
    binary=(M52/'coop-bundle-04' if args.control else out)/'RConnectMod.swf'
    driver=out/('control' if args.control else 'drivers')/args.suite
    before=installation()
    command=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
             '--candidate',str(binary),'--effects','--effects-driver',str(driver),
             '--private-desktop','--defer-visible','--wait-host-world','--responsive',
             '--seconds','330','--land','begin','--port',str(test_port()),
             '--expected-version','0.2.23-coop-bundle2' if args.control else m['version'],
             '--registry-wait',str(args.registry_wait)]
    if args.all_mods:command.append('--all-mods')
    with log.open('w',encoding='utf-8') as f:p=subprocess.run(command,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
    after=installation();changes={k:dict(before=before.get(k),after=after.get(k)) for k in before.keys()|after.keys() if before.get(k)!=after.get(k)}
    text=log.read_text('utf-8',errors='replace');match=re.search(r'OUTPUT (.+)',text)
    native=None
    # Shared runner prints its artifact folder as a standalone path.
    for line in text.splitlines():
        if 'build\\cooperation\\' in line and line.strip().startswith(str(ROOT)):
            native=line.strip()
    save(result,dict(exit=p.returncode,control=args.control,suite=args.suite,candidate_sha256=sha(binary),
                     driver_sha256=sha(driver/'EffectsDriver.swf'),installation_before=before,
                     installation_changes=changes,native_output=native,all_mods=args.all_mods))
    print(text[-10000:]);print('RECEIPT',result)
    raise SystemExit(p.returncode or bool(changes))

if __name__=='__main__':main()
