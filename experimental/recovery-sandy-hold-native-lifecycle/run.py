"""Functional native lifecycle using the already-frozen isolated runner."""
from pathlib import Path
import argparse,json,re,shutil,subprocess,sys
from prepare import ROOT,M52,TRAVEL,verify,read,save,sha
from native_inputs import audit,sandy_input,host_input,verify_host_intent,installation,CANDIDATE,HOST
sys.path.insert(0,str(ROOT/'tools/validation'))
from run_security_terminals import test_port

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--drivers',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--registry-wait',type=int,default=900);a=ap.parse_args()
    drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
    assert drivers.parent==M52.resolve() and out.parent==M52.resolve() and not out.exists()
    meta=verify(drivers);assert meta['compiled'] is True
    rc=audit(CANDIDATE);before=installation();host=host_input(HOST,before);sand=sandy_input('bridge')
    source_manifest=sha(drivers/'prepared.json');out.mkdir();binding=out/'driver';binding.mkdir()
    for name in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(drivers/'lifecycle'/name,binding/name)
    save(binding/'driver-input.json',dict(candidate_sha256=rc['sha256']))
    intent=dict(candidate_sha256=rc['sha256'],host=host,sandy=sand,source_manifest=source_manifest,
        installation=before,driver_sha256=sha(binding/'EffectsDriver.swf'),
        runner_sha256=sha(TRAVEL/'native_runner.py'),function_only=True,performance_qualified=False)
    save(out/'intent.json',intent)
    command=[sys.executable,'-B','-X','utf8',str(TRAVEL/'native_runner.py'),
        '--candidate',str(CANDIDATE/'RConnectMod.swf'),'--game-candidate',str(HOST/'pfe.swf'),
        '--sandy-candidate',sand['candidate'],'--all-mods','--effects','--effects-driver',str(binding),
        '--solo','--land','rbl','--seconds','600','--expected-version',rc['version'],'--port',str(test_port()),
        '--private-desktop','--defer-visible','--wait-host-world','--require-exclusive-air',
        '--registry-wait',str(a.registry_wait)]
    save(out/'command.json',command)
    with (out/'runner.log').open('x',encoding='utf-8') as log:
        process=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace');found=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',raw,re.M)
    after=installation();result=dict(passed=False,exit_code=process.returncode,run=found[1] if found else None,
        installation_unchanged=before==after,function_only=True,performance_qualified=False)
    if found:
        run=ROOT/'build/cooperation'/found[1];manifest=read(run/'run.json');inp=manifest['inputs']['host']
        assert set(manifest['inputs'])=={'host'}
        assert inp['game']==host['candidate_sha256'] and inp['production']==rc['sha256']
        assert inp['driver']==intent['driver_sha256']
        modules={k.replace(chr(92),'/').lower():v for k,v in inp['modules'].items()}
        assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']
        text=(run/'host.log').read_text(encoding='utf-8-sig',errors='replace')
        all_text=text+'\n'+(run/'host.stdout.log').read_text(encoding='utf-8',errors='replace')
        for path in (run/'module-logs/host').glob('*.log'):all_text+='\n'+path.read_text(encoding='utf-8-sig',errors='replace')
        errors=list(dict.fromkeys(line for line in all_text.splitlines() if 'COOP FAIL' in line or 'handoff timed out' in line
            or 'game error dialog' in line or re.search(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line,re.I)))
        rows=[json.loads(line.split('SANDY HOLD RESULT ',1)[1]) for line in text.splitlines() if line.startswith('SANDY HOLD RESULT ')]
        valid=len(rows)==1
        if valid:
            row=rows[0];held=[r for r in row['observations'] if r['label']=='held-frame']
            valid=row['passed'] is True and row['failed']==0 and row['checks']==41 and row['holdFrames']==12
            valid=valid and len(held)==12 and [r['phaseFrame'] for r in held]==list(range(1,13))
            valid=valid and all(r['state']['held'] is True and r['state']['phase']=='idle' for r in held)
            valid=valid and row['cleanup']['final']['held'] is False and row['cleanup']['final']['phase']=='idle'
            valid=valid and row['functionOnly'] is True and row['performanceQualified'] is False
        result.update(errors=errors,rows=rows,done='COOP EFFECTS DONE sandy-native' in text,memory=read(run/'memory-timeline.json'))
        result['passed']=process.returncode==0 and before==after and result['done'] and not errors and valid
    verify(drivers);assert sha(drivers/'prepared.json')==source_manifest
    verify_host_intent(HOST,host,after);assert sandy_input('bridge')==sand
    save(out/'result.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('memory','rows')},ensure_ascii=False))
    if not result['passed']:raise SystemExit(1)
if __name__=='__main__':main()
