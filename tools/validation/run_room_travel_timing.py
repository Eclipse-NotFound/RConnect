"""Run identical external native travel checks against pinned A binaries."""
import argparse
import json
import re
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, read, save, sha
from run_security_terminals import installation, test_port
from audit_room_entry_candidate import audit


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--candidate',required=True)
    ap.add_argument('--drivers',required=True)
    ap.add_argument('--output',required=True)
    ap.add_argument('--scenario',choices=['timing','scene','entry-room','entry-map'],default='timing')
    ap.add_argument('--solo',action='store_true')
    a=ap.parse_args()
    candidate=(ROOT/a.candidate).resolve();drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
    assert candidate.parent==M52 and drivers.parent==M52 and out.parent==M52 and not out.exists()
    audit(candidate)
    meta=read(drivers/'prepared.json')
    for n,h in meta['files'].items():assert sha(drivers/n)==h,n
    binary=candidate/'RConnectMod.swf';digest=sha(binary)
    version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(candidate/'src/RConnectMod.as').read_text(encoding='utf-8')).group(1)
    before=installation();out.mkdir();binding=out/'driver';binding.mkdir()
    for n in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(drivers/a.scenario/n,binding/n)
    save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf')))
    save(out/'intent.json',dict(candidate=str(candidate),candidate_sha256=digest,driver_manifest=sha(drivers/'prepared.json'),
        scenario=a.scenario,solo=a.solo,installation=before,runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),wrapper_sha256=sha(__file__)))
    timed=a.scenario in ('timing','scene')
    cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(binary),
        '--effects','--effects-driver',str(binding),'--all-mods','--land','random_mane' if a.scenario=='entry-room' else 'rbl','--seconds','600',
        '--expected-version',version,'--port',str(test_port()),'--private-desktop','--defer-visible','--wait-host-world','--require-exclusive-air']
    if a.solo:cmd+=['--solo']
    with (out/'runner.log').open('w',encoding='utf-8') as log:
        process=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
    found=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',raw,re.M)
    after=installation()
    result=dict(exit_code=process.returncode,run=found[1] if found else None,installation_unchanged=before==after,passed=False)
    if found:
        run=ROOT/'build/cooperation'/found[1];manifest=read(run/'run.json');result['roles']={}
        for role in (('host',) if a.solo else ('host','join')):
            inp=manifest['inputs'][role]
            assert inp['game']==before['pfe.swf'] and inp['production']==digest
            assert inp['driver']==sha(binding/'EffectsDriver.swf')
            path=run/(role+'.log');text=path.read_text(encoding='utf-8-sig',errors='replace') if path.exists() else ''
            stdout=run/(role+'.stdout.log');all_text=text+'\n'+(stdout.read_text(encoding='utf-8',errors='replace') if stdout.exists() else '')
            module_logs=run/'module-logs'/role
            for module_log in sorted(module_logs.glob('*.log')):
                if module_log.name!='RConnect.log':all_text+='\n'+module_log.read_text(encoding='utf-8',errors='replace')
            errors=[line for line in all_text.splitlines() if 'COOP FAIL' in line
                or ('obj spawn' in line and 'failed' in line)
                or ('RConnect' in line and (' failed:' in line or ' ERROR' in line))
                or re.search(r'\bERROR\b',line)
                or re.search(r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line,re.I)]
            scene_log=module_logs/'ContinuousScene.log'
            scene_text=scene_log.read_text(encoding='utf-8',errors='replace') if scene_log.exists() else ''
            if '[ContinuousScene] registered ' not in scene_text:errors.append('ContinuousScene initialization was not confirmed')
            scene_asset='mods/ContinuousScene/release/scene.xml'
            if inp.get('mod_assets',{}).get(scene_asset)!=before.get(scene_asset):errors.append('ContinuousScene scene asset differs or is missing')
            errors=list(dict.fromkeys(errors))
            rows=[json.loads(s.split('TRAVEL RESULT ',1)[1]) for s in text.splitlines() if s.startswith('TRAVEL RESULT ')]
            result['roles'][role]=dict(checks=len(re.findall(r'^COOP PASS ',text,re.M)),errors=errors,
                done='COOP EFFECTS DONE' in text,version='v'+version+' initialized' in text,rows=rows,log_sha256=sha(path) if path.exists() else None)
        result['passed']=process.returncode==0 and before==after and all(r['done'] and r['version'] and not r['errors'] and (len(r['rows'])==3 if timed else r['checks']>0) for r in result['roles'].values())
        result['memory']=read(run/'memory-timeline.json')
    save(out/'result.json',result)
    print(json.dumps({k:v for k,v in result.items() if k!='memory'},ensure_ascii=False),flush=True)
    if not result['passed']:raise SystemExit(1)


if __name__=='__main__':main()
