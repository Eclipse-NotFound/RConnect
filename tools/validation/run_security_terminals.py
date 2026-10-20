"""Bounded isolated native pair, with exact inputs and installation protection.

The shared runner freezes all runtime assets, creates fresh characters under
unique AppIDs and removes only its own redundant copies. This wrapper adds the
security-specific source, exception and installation checks; it never deploys.
"""
import argparse
import json
from pathlib import Path
import re
import secrets
import socket
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
        names=[entry+'.swf', 'config.txt', 'config.json']
        if directory.lower()=='continuousscene':names.append('scene.xml')
        for name in names:
            path = GAME/'mods'/directory/'release'/name
            if path.is_file():
                files.add(path)
    return {p.relative_to(GAME).as_posix():sha(p) for p in sorted(files)}


def test_port():
    # Do not hand AIR a recently freed client ephemeral port. This is only a
    # test-runner choice; the installed networking/configuration is unchanged.
    for _ in range(64):
        port=20000+secrets.randbelow(25000)
        with socket.socket() as probe:
            if hasattr(socket,'SO_EXCLUSIVEADDRUSE'):
                probe.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
            try:
                probe.bind(('0.0.0.0',port))
                probe.listen(1)
            except OSError:
                continue
            return port
    raise RuntimeError('No available isolated test port')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for key in ('output', 'candidate', 'native'):
        ap.add_argument('--'+key, type=Path, required=True)
    ap.add_argument('--driver',type=Path)
    ap.add_argument('--smoke',action='store_true',help='Use the normal loader and exact production SWF, without the external test driver')
    ap.add_argument('--seconds', type=int, default=300)
    args = ap.parse_args()
    if args.smoke == (args.driver is not None):ap.error('Choose either --smoke or --driver')
    out, candidate, native = [(ROOT/getattr(args, k)).resolve() for k in ('output','candidate','native')]
    driver=(ROOT/args.driver).resolve() if args.driver else None
    for p in (out, candidate, native)+((driver,) if driver else ()):
        assert p.parent == ROOT/'build/m52'
    assert not out.exists()
    source, patch = [read(p/'prepared.json') for p in (candidate,native)]
    test=read(driver/'driver-input.json') if driver else None
    assert source['kind']=='security-terminals' and source['compiled']
    assert sha(candidate/'RConnectMod.swf')==source['sha256']
    for name, digest in source['source'].items():
        assert sha(candidate/name)==digest, name
    assert sha(native/'pfe.swf')==patch['candidate_sha256']
    assert patch['loader_unchanged'] and patch['non_code_tags_unchanged']
    if test:
        assert source['sha256']==test['candidate_sha256']
        assert sha(driver/'EffectsDriver.swf')==test['driver_sha256']
        assert sha(driver/'tests/SecurityTerminalTestDoc.as')==test['source_sha256']
    assert sha(GAME/'pfe.swf')==patch['original_sha256']
    before = installation()
    version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(candidate/'src/RConnectMod.as').read_text(encoding='utf-8-sig'))[1]
    command = [sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),
        '--candidate',str(candidate/'RConnectMod.swf'),'--game-candidate',str(native/'pfe.swf'),
        '--expected-version',version,
        '--all-mods','--land','random_mane','--seconds',str(args.seconds),'--port',str(test_port())]
    command+=['--smoke'] if args.smoke else ['--effects','--effects-driver',str(driver)]
    out.mkdir()
    intent = dict(command=command, installation_before=before,
        source=sha(candidate/'prepared.json'),native=sha(native/'prepared.json'),driver=test,
        runner=sha(ROOT/'tools/run_coop_regression.py'),wrapper=sha(__file__),
        qualification='normal-loader startup only' if args.smoke else 'functional only; no exclusive performance claim')
    (out/'intent.json').write_text(json.dumps(intent,indent=2),encoding='utf-8')
    with (out/'run.log').open('w',encoding='utf-8') as log:
        result = subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    after = installation()
    output = (out/'run.log').read_text(encoding='utf-8',errors='replace')
    match = re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',output,re.M)
    receipt = dict(exit_code=result.returncode,run=match[1] if match else None,
        installation_changes={n:dict(before=before.get(n),after=after.get(n))
            for n in sorted(set(before)|set(after)) if before.get(n)!=after.get(n)},
        passed=False,gameplay_verified=False,normal_loader=args.smoke,installed=False)
    if match:
        run = ROOT/'build/cooperation'/match[1]
        info = read(run/'run.json')
        for role in ('host','join'):
            if args.smoke:
                assert info['sha256']==source['sha256']
                modules=info['inputs'][role]['modules']
                assert next(v for k,v in modules.items() if k.replace('\\','/').lower()=='mods/rconnect/release/rconnectmod.swf')==source['sha256']
                assert 'driver' not in info['inputs'][role]
            else:
                assert info['inputs'][role]['production']==source['sha256']
                assert info['inputs'][role]['driver']==test['driver_sha256']
            assert info['inputs'][role]['game']==patch['candidate_sha256']
            path = run/(role+'.log')
            lines = path.read_text(encoding='utf-8-sig',errors='replace') if path.is_file() else ''
            bad = [s for s in lines.splitlines() if 'RConnect security:' in s or 'COOP FAIL ' in s
                   or ('obj spawn' in s and 'failed' in s)
                   or re.search(r'\b(?:Error\s*#\d+|ArgumentError|TypeError|ReferenceError|VerifyError|RangeError|SecurityError)\b',s)]
            stdout=run/(role+'.stdout.log')
            native_text=stdout.read_text(encoding='utf-8',errors='replace') if stdout.is_file() else ''
            native_errors=[s for s in native_text.splitlines() if re.search(
                r'\b(?:Error\s*#\d+|ArgumentError|TypeError|ReferenceError|RangeError|VerifyError|SecurityError|out of memory)\b',s,re.I)]
            receipt[role]=dict(passed=len(re.findall(r'^COOP PASS security ',lines,re.M)),
                failures=bad,native_errors=native_errors,done=('tick 200' in lines if args.smoke else 'COOP EFFECTS DONE '+role+' security checks=' in lines),
                version_loaded='v'+version+' initialized' in lines,
                log_sha256=sha(path) if path.is_file() else None,
                stdout_sha256=sha(stdout) if stdout.is_file() else None)
        receipt['passed']=result.returncode==0 and not receipt['installation_changes'] and all(
            receipt[r]['done'] and receipt[r]['version_loaded'] and (args.smoke or receipt[r]['passed']>0)
            and not receipt[r]['failures'] and not receipt[r]['native_errors'] for r in ('host','join'))
        receipt['gameplay_verified']=receipt['passed'] and not args.smoke
    (out/'result.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False))
    raise SystemExit(0 if receipt['passed'] else 1)


if __name__=='__main__':
    main()
