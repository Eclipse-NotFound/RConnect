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
    ap.add_argument('--game-candidate',help='Verified isolated native-travel host directory; never installs it')
    ap.add_argument('--scenario',choices=['timing','scene','entry-room','entry-map'],default='timing')
    ap.add_argument('--solo',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=300)
    a=ap.parse_args()
    candidate=(ROOT/a.candidate).resolve();drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
    assert candidate.parent==M52 and drivers.parent==M52 and out.parent==M52 and not out.exists()
    audit(candidate)
    meta=read(drivers/'prepared.json')
    assert not (a.solo and meta.get('diagnostic_only')), 'First resumed mirror frame profiling requires a peer'
    for n,h in meta['files'].items():assert sha(drivers/n)==h,n
    binary=candidate/'RConnectMod.swf';digest=sha(binary)
    version=re.search(r'VERSION:String\s*=\s*"([^"]+)"',(candidate/'src/RConnectMod.as').read_text(encoding='utf-8')).group(1)
    before=installation()
    host_candidate=None
    host_intent=None
    if a.game_candidate:
        host_candidate=(ROOT/a.game_candidate).resolve()
        assert host_candidate.parent==M52
        host_meta=read(host_candidate/'prepared.json')
        assert host_meta['kind']=='recovery-native-travel-host'
        assert host_meta.get('compiled') is True and host_meta.get('validated') is True
        assert host_meta.get('installed_unchanged') is True and host_meta.get('source_set_unchanged') is True
        assert host_meta['original_sha256']==before['pfe.swf']
        assert host_meta['candidate_sha256']==sha(host_candidate/'pfe.swf')
        assert host_meta['non_code_tags_unchanged'] and host_meta['loader_unchanged']
        assert sha(host_candidate/'native-input.json')==host_meta['native_input_sha256']
        for name,source_digest in host_meta['source_inputs'].items():
            assert sha(host_candidate/'sources'/name)==source_digest,name
        host_intent=dict(directory=str(host_candidate),manifest_sha256=sha(host_candidate/'prepared.json'),
            original_sha256=host_meta['original_sha256'],candidate_sha256=host_meta['candidate_sha256'],
            native_input_sha256=host_meta['native_input_sha256'],sources=host_meta['source_inputs'])
    out.mkdir();binding=out/'driver';binding.mkdir()
    for n in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(drivers/a.scenario/n,binding/n)
    save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf')))
    save(out/'intent.json',dict(candidate=str(candidate),candidate_sha256=digest,driver_manifest=sha(drivers/'prepared.json'),
        scenario=a.scenario,solo=a.solo,diagnostic_only=bool(meta.get('diagnostic_only',False)),installation=before,
        runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),wrapper_sha256=sha(__file__),native_host=host_intent))
    timed=a.scenario in ('timing','scene')
    cmd=[sys.executable,'-B','-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(binary),
        '--effects','--effects-driver',str(binding),'--all-mods','--land','random_mane' if a.scenario=='entry-room' else 'rbl','--seconds','600',
        '--expected-version',version,'--port',str(test_port()),'--private-desktop','--defer-visible','--wait-host-world','--require-exclusive-air']
    cmd+=['--registry-wait',str(a.registry_wait)]
    if host_candidate:cmd+=['--game-candidate',str(host_candidate/'pfe.swf')]
    if a.solo:cmd+=['--solo']
    with (out/'runner.log').open('w',encoding='utf-8') as log:
        process=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
    found=re.search(r'^OUTPUT .*?([0-9a-f]{10})\s*$',raw,re.M)
    after=installation()
    result=dict(exit_code=process.returncode,run=found[1] if found else None,installation_unchanged=before==after,
        diagnostic_only=bool(meta.get('diagnostic_only',False)),passed=False)
    if found:
        run=ROOT/'build/cooperation'/found[1];manifest=read(run/'run.json');result['roles']={}
        for role in (('host',) if a.solo else ('host','join')):
            inp=manifest['inputs'][role]
            expected_host=host_intent['candidate_sha256'] if host_intent else before['pfe.swf']
            assert inp['game']==expected_host and inp['production']==digest
            assert inp['driver']==sha(binding/'EffectsDriver.swf')
            path=run/(role+'.log');text=path.read_text(encoding='utf-8-sig',errors='replace') if path.exists() else ''
            stdout=run/(role+'.stdout.log');all_text=text+'\n'+(stdout.read_text(encoding='utf-8',errors='replace') if stdout.exists() else '')
            module_logs=run/'module-logs'/role
            for module_log in sorted(module_logs.glob('*.log')):
                if module_log.name!='RConnect.log':all_text+='\n'+module_log.read_text(encoding='utf-8',errors='replace')
            errors=[line for line in all_text.splitlines() if 'COOP FAIL' in line
                or 'handoff timed out' in line or 'game error dialog' in line
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
            if result['diagnostic_only']:
                result['roles'][role]['profile']=[json.loads(s.split('A22 ROOM FIRST FRAME TIMING ',1)[1])
                    for s in text.splitlines() if s.startswith('A22 ROOM FIRST FRAME TIMING ')]
                result['roles'][role]['terrain_diff']=[json.loads(s.split('ROOM TERRAIN DIFF ',1)[1])
                    for s in text.splitlines() if s.startswith('ROOM TERRAIN DIFF ')]
                result['roles'][role]['raster_parity']=[json.loads(s.split('ROOM RASTER PARITY ',1)[1])
                    for s in text.splitlines() if s.startswith('ROOM RASTER PARITY ')]
        result['passed']=process.returncode==0 and before==after and all(r['done'] and r['version'] and not r['errors'] and (len(r['rows'])==3 if timed else r['checks']>0) for r in result['roles'].values())
        if result['diagnostic_only']:
            if meta.get('diagnostic_kind')=='raster':
                rows=result['roles'].get('join',{}).get('raster_parity',[])
                result['profile_valid']=len(rows)==2 and all(r.get('valid') and r.get('comparedLayers',0)>0 for r in rows)
            else:
                profiles=result['roles'].get('join',{}).get('profile',[])
                result['profile_valid']=len(profiles)==2 and all(
                    len(p.get('markers',[]))>=8 and p.get('presentation',{}).get('motionCalls',0)>0 for p in profiles)
                if 'tests/RoomTerrainDiff.as' in meta['files']:
                    diffs=result['roles']['join']['terrain_diff']
                    result['profile_valid']=result['profile_valid'] and len(diffs)==2 and all(d.get('valid') for d in diffs)
            result['passed']=result['passed'] and result['profile_valid']
        result['memory']=read(run/'memory-timeline.json')
    if host_candidate:
        assert sha(host_candidate/'prepared.json')==host_intent['manifest_sha256']
        assert sha(host_candidate/'pfe.swf')==host_intent['candidate_sha256']
        assert sha(host_candidate/'native-input.json')==host_intent['native_input_sha256']
        for name,source_digest in host_intent['sources'].items():
            assert sha(host_candidate/'sources'/name)==source_digest,name
        result['native_host']=host_intent
    save(out/'result.json',result)
    # Keep complete phase/input/source evidence on disk, not in every progress
    # item. This only shortens console output; qualification above is unchanged.
    shown={k:v for k,v in result.items() if k not in ('memory','roles','native_host')}
    if 'roles' in result:
        shown['roles']={role:dict(checks=value['checks'],errors=value['errors'],done=value['done'],
            rows=[{key:row.get(key) for key in ('round','target','elapsed','controlResponseElapsed')}
                  for row in value['rows']]) for role,value in result['roles'].items()}
    if host_intent:shown['native_host_sha256']=host_intent['candidate_sha256']
    print(json.dumps(shown,ensure_ascii=False),flush=True)
    if not result['passed']:raise SystemExit(1)


if __name__=='__main__':main()
