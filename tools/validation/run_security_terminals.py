"""Bounded isolated native pair, with exact inputs and installation protection.

The shared runner freezes all runtime assets, creates fresh characters under
unique AppIDs and removes only its own redundant copies. This wrapper adds the
security-specific source, exception and installation checks; it never deploys.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
from prepare_security_terminals import ROOT, sha

GAME = ROOT.parents[1]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def installation():
    files = {GAME/'pfe.swf', GAME/'mods/loader-manifest.txt'}
    for line in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('#') or '|' not in line:
            continue
        directory, entry = line.split('|')[:2]
        for name in (entry+'.swf', 'config.txt', 'config.json'):
            path = GAME/'mods'/directory/'release'/name
            if path.is_file():
                files.add(path)
    return {p.relative_to(GAME).as_posix():sha(p) for p in sorted(files)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for key in ('output', 'candidate', 'native', 'driver'):
        ap.add_argument('--'+key, type=Path, required=True)
    ap.add_argument('--seconds', type=int, default=240)
    args = ap.parse_args()
    out, candidate, native, driver = [(ROOT/getattr(args, k)).resolve() for k in ('output','candidate','native','driver')]
    for p in (out, candidate, native, driver):
        assert p.parent == ROOT/'build/m52'
    assert not out.exists()
    source, patch, test = [read(p/n) for p,n in ((candidate,'prepared.json'),(native,'prepared.json'),(driver,'driver-input.json'))]
    assert source['kind']=='security-terminals' and source['compiled']
    assert sha(candidate/'RConnectMod.swf')==source['sha256']==test['candidate_sha256']
    for name, digest in source['source'].items():
        assert sha(candidate/name)==digest, name
    assert sha(native/'pfe.swf')==patch['candidate_sha256']
    assert patch['loader_unchanged'] and patch['non_code_tags_unchanged']
    assert sha(driver/'EffectsDriver.swf')==test['driver_sha256']
    assert sha(driver/'tests/SecurityTerminalTestDoc.as')==test['source_sha256']
    assert sha(GAME/'pfe.swf')==patch['original_sha256']
    before = installation()
    command = [sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
        '--candidate',str(candidate/'RConnectMod.swf'),'--game-candidate',str(native/'pfe.swf'),
        '--effects','--effects-driver',str(driver),'--expected-version','0.2.22-fix39-security1',
        '--all-mods','--land','random_mane','--seconds',str(args.seconds)]
    out.mkdir()
    intent = dict(command=command, installation_before=before,
        source=sha(candidate/'prepared.json'),native=sha(native/'prepared.json'),driver=test,
        runner=sha(ROOT/'tools/run_coop_regression.py'),wrapper=sha(__file__),
        qualification='functional only; no exclusive performance claim')
    (out/'intent.json').write_text(json.dumps(intent,indent=2),encoding='utf-8')
    with (out/'run.log').open('w',encoding='utf-8') as log:
        result = subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    after = installation()
    output = (out/'run.log').read_text(encoding='utf-8',errors='replace')
    match = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',output,re.M)
    receipt = dict(exit_code=result.returncode,run=match[1] if match else None,
        installation_changes={n:dict(before=before.get(n),after=after.get(n))
            for n in sorted(set(before)|set(after)) if before.get(n)!=after.get(n)},
        passed=False,gameplay_verified=False,installed=False)
    if match:
        run = ROOT/'build/cooperation'/match[1]
        info = read(run/'run.json')
        for role in ('host','join'):
            assert info['inputs'][role]['production']==source['sha256']
            assert info['inputs'][role]['game']==patch['candidate_sha256']
            assert info['inputs'][role]['driver']==test['driver_sha256']
            path = run/(role+'.log')
            lines = path.read_text(encoding='utf-8-sig',errors='replace') if path.is_file() else ''
            bad = [s for s in lines.splitlines() if 'RConnect security:' in s or 'COOP FAIL ' in s
                   or re.search(r'\b(?:TypeError|ReferenceError|VerifyError|RangeError|SecurityError)\b',s)]
            receipt[role]=dict(passed=len(re.findall(r'^COOP PASS security ',lines,re.M)),
                failures=bad,done='COOP EFFECTS DONE '+role+' security checks=' in lines,
                log_sha256=sha(path) if path.is_file() else None)
        receipt['passed']=result.returncode==0 and not receipt['installation_changes'] and all(
            receipt[r]['done'] and receipt[r]['passed']>0 and not receipt[r]['failures'] for r in ('host','join'))
        receipt['gameplay_verified']=receipt['passed']
    (out/'result.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False))
    raise SystemExit(0 if receipt['passed'] else 1)


if __name__=='__main__':
    main()
