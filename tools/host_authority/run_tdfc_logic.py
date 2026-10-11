"""Run frozen TDFC AS3 checks in a fresh AIR application without the game or saves."""
import argparse
import os
import shutil
import subprocess
import uuid
from pathlib import Path
from common import ROOT, inside_build, read, save, sha, verify_files, verify_baseline


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',required=True)
    ap.add_argument('--baseline',required=True)
    ap.add_argument('--output',required=True)
    args=ap.parse_args()
    candidate, baseline, out=[inside_build(ROOT/p) for p in (args.candidate,args.baseline,args.output)]
    build=read(candidate/'build-input.json');verify_files(candidate,build['sources']);verify_baseline(baseline)
    if sha(candidate/'LogicTests.swf')!=build['tests_sha256']:
        raise ValueError('Frozen test bytes changed')
    if out.exists():raise FileExistsError('Fresh test directory required')
    out.mkdir(parents=True);(out/'out').mkdir()
    shutil.copy2(candidate/'LogicTests.swf',out/'LogicTests.swf')
    shutil.copy2(__file__,out/'run_tdfc_logic.py')
    appid='pfe-modsettings-tdfc-logic-'+uuid.uuid4().hex[:12]
    if (Path(os.environ['APPDATA'])/appid).exists():raise FileExistsError('Fresh AIR storage required')
    desc=out/'logic.xml'
    desc.write_text('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
        '<id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>TDFC authority contract checks</filename>'
        '<initialWindow><content>LogicTests.swf</content><visible>false</visible><width>1000</width><height>650</height></initialWindow></application>',encoding='utf-8')
    game=baseline/'game'
    cmd=[str(game/'adl64.exe'),'-runtime',str(game/'runtimes/air/win64'),str(desc)]
    receipt=dict(appid=appid,command=cmd,build_manifest_sha256=sha(candidate/'build-input.json'),
        baseline_manifest_sha256=sha(baseline/'baseline.json'),swf_sha256=sha(out/'LogicTests.swf'),descriptor_sha256=sha(desc))
    with (out/'stdout.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        receipt['pid']=process.pid
        try:process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            process.terminate();process.wait(timeout=10);receipt['timeout']=True
    result=out/'out/logic-result.txt'
    lines=result.read_text(encoding='utf-8').splitlines() if result.is_file() else []
    receipt.update(exit_code=process.returncode,passed=sum(s.startswith('PASS ') for s in lines),
        failed=[s for s in lines if s.startswith(('FAIL ','ERROR '))],complete='RESULT failures=0' in lines,
        owned_process_exited=process.poll() is not None,swf_unchanged=sha(out/'LogicTests.swf')==receipt['swf_sha256'])
    save(out/'run.json',receipt)
    ok=receipt['complete'] and not receipt['failed'] and process.returncode==0 and receipt['swf_unchanged']
    print(dict(path=str(out),ok=ok,passed=receipt['passed'],failed=receipt['failed']),flush=True)
    raise SystemExit(0 if ok else 1)


if __name__=='__main__':main()
