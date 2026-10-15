"""Run only frozen, isolated RV comparison SWFs; retain every result."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('candidate', type=Path)
    args = ap.parse_args()
    out = (ROOT/args.candidate).resolve()
    assert out.parent == ROOT/'build/m52'
    m = json.loads((out/'prepared.json').read_text(encoding='utf-8'))
    for name, value in {**m['source'],**m['inputs']}.items():
        assert sha(out/name) == value, name
    assert sha(out/'RealisticVisionMod.swf') == m['candidate_sha256']
    installation = GAME/'mods/RealisticVision/release/RealisticVisionMod.swf'
    before = sha(installation)
    for entry in ('WallComparisonChecks','BoundaryChecks'):
        folder = out/'checks'
        assert sha(folder/(entry+'.swf')) == m['tests'][entry+'.swf']
        result_path = folder/(entry+'-result.json')
        assert not result_path.exists(), 'Keep prior evidence; prepare a new candidate for another run'
        app_id = 'pfe-modsettings-rv-wall-compare-'+uuid.uuid4().hex
        desc = folder/(entry+'.xml')
        desc.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+app_id+
            '</id><versionNumber>1.0</versionNumber><filename>RVWallChecks</filename><initialWindow><content>'+entry+
            '.swf</content><visible>false</visible><width>400</width><height>320</height><renderMode>cpu</renderMode>'+
            '</initialWindow></application>',encoding='utf-8')
        log_path = folder/(entry+'.log')
        try:
            with log_path.open('w',encoding='utf-8') as log:
                process = subprocess.Popen([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],
                    cwd=folder,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    code = process.wait(timeout=150)
                except subprocess.TimeoutExpired:
                    process.kill();process.wait();code=124
            evidence = Path(os.environ['APPDATA'])/app_id/'Local Store/evidence'
            if evidence.exists():
                shutil.copytree(evidence,folder/(entry+'-images'))
            log = log_path.read_text(encoding='utf-8',errors='replace')
            result = dict(entry=entry,exit=code,app_id=app_id,pid=process.pid,
                passed=len(re.findall(r'^PASS ',log,re.M)),failed=len(re.findall(r'^FAIL ',log,re.M)),
                complete='COMPLETE' in log,log_sha256=sha(log_path),swf_sha256=m['tests'][entry+'.swf'],
                candidate_sha256=m['candidate_sha256'],prepared_sha256=sha(out/'prepared.json'),
                installation_unchanged=before==sha(installation))
            result_path.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
            print(json.dumps(result,ensure_ascii=False),flush=True)
            for line in log.splitlines():
                if line.startswith('FAIL ') or 'Error' in line:
                    print(line,flush=True)
            if code or result['failed'] or not result['complete'] or not result['installation_unchanged']:
                raise SystemExit(1)
        finally:
            desc.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
