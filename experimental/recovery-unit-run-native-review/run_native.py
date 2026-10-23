"""User-seed observation with immutable copied Littlepip saves; shared runner unchanged."""
from pathlib import Path
import argparse,json,re,shutil,subprocess,sys,traceback
from prepare import ROOT,M52,GAME,RUNNER,PINNED,installation,sha,read,save,verify
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--drivers',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--mode',choices=['dual','solo'],default='dual');ap.add_argument('--scenario',choices=['scene','timing'],default='scene')
 ap.add_argument('--product',choices=['aura1'],default='aura1')
 ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
 assert drivers.parent==M52 and out.parent==M52 and not out.exists() and a.registry_wait>=0
 meta=verify(drivers);assert meta['compiled'] is True
 before=installation();binary=GAME/'mods/RConnect/release/RConnectMod.swf';version='0.2.24-aura1';product_inputs={}
 digest=sha(binary)
 out.mkdir();binding=out/'driver';binding.mkdir()
 for n in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(drivers/a.scenario/n,binding/n)
 save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf'),
  source_manifest_sha256=sha(drivers/'prepared.json'),scope='external existing public API; exact installed production bytes'))
 command=[sys.executable,'-B','-X','utf8',str(RUNNER),'--candidate',str(binary),'--effects','--effects-driver',str(binding),
  '--all-mods','--land','rbl','--seconds','600','--expected-version',version,'--private-desktop','--defer-visible',
  '--wait-host-world','--require-exclusive-air','--registry-wait',str(a.registry_wait)]
 if a.mode=='solo':command+=['--solo']
 templates={'host':M52/'littlepip-save-replay-01/host/PFEgame0.sol'}
 if a.mode=='dual':templates['join']=M52/'littlepip-save-replay-01/join/PFEgame0.sol'
 expected={'host':'2c0fe1d16138797b5914a7e1a0adb12e7438c0b0fba88e594490bba30f42c9f4','join':'8e70021accf93b8b920935666f85e6dc06f863ce5b242d04d6c7e2f38ef1bc3d'}
 for role,path in templates.items():
  assert sha(path)==expected[role],role
  command+=['--'+role+'-save-template',str(path)]
 pins={str(p):sha(p) for p in [Path(__file__),HERE/'prepare.py',drivers/'prepared.json',RUNNER,binding/'EffectsDriver.swf',binding/'EffectsHarness.swf']}
 pins.update(product_inputs);pins[str(binary)]=digest
 pins.update({str(path):sha(path) for path in templates.values()})
 save(out/'intent.json',dict(command=command,mode=a.mode,scenario=a.scenario,installation=before,inputs=pins,
  candidate_sha256=digest,product=a.product,expected_version=version,no_host_override=True,no_other_mod_override=True,
  diagnostic_only=True,user_seed=4095208676,stage_before_mission=4,save_templates={role:{'path':str(path),'sha256':sha(path)} for role,path in templates.items()}))
 result=dict(passed=False,air_started=False,mode=a.mode,scenario=a.scenario,product=a.product,performance_qualified=False,installed=False,diagnostic_only=True,observations={})
 try:
  with (out/'runner.log').open('x',encoding='utf-8') as log:p=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  result['exit_code']=p.returncode
  raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
  result['framework_passed']=bool(re.search(r'^RESULT PASS\s*$',raw,re.M)) and not bool(re.search(r'^RESULT FAIL\s*$',raw,re.M))
  matches=re.findall(r'^(?:OUTPUT|QUEUED_OUTPUT) (.+?[0-9a-f]{10})\s*$',raw,re.M)
  assert matches,'No owned run path recorded'
  run=Path(matches[-1]).resolve();assert run.parent==(ROOT/'build/cooperation').resolve()
  result['run']=str(run);result['roles']={}
  if not (run/'run.json').is_file():raise RuntimeError('Runner stopped before complete run.json; see preserved runner.log and owned run')
  native=read(run/'run.json');result.update(air_started=bool(native['pids']),run_sha256=sha(run/'run.json'))
  assert native['sha256']==digest and native['solo']==(a.mode=='solo')
  for role,path in templates.items():
   saved=native['save_templates'][role]
   assert saved['source_sha256']==sha(path) and saved['slot']==9,role
  assert native['private_desktop'] is True and native['defer_visible'] is True
  assert sha(run/'input.json')==native['input_manifest_sha256']
  expected_roles=['host'] if a.mode=='solo' else ['host','join'];assert set(native['inputs'])==set(expected_roles)
  for role in expected_roles:
   values=native['inputs'][role];assert values['game']==before['pfe.swf'] and values['production']==digest
   assert values['driver']==sha(binding/'EffectsDriver.swf') and values['harness']==sha(binding/'EffectsHarness.swf')
   installed={n.lower():h for n,h in before.items()}
   for n,h in values['modules'].items():
    key=n.replace('\\','/').lower()
    if key=='mods/rconnect/release/rconnectmod.swf':assert h==sha(binding/'EffectsHarness.swf')
    else:assert h==installed[key],n
   for n,h in values.get('mod_assets',{}).items():assert h==installed[n.replace('\\','/').lower()],n
   log=run/(role+'.log');text=log.read_text(encoding='utf-8-sig',errors='replace')
   observation_rows=[json.loads(line.split('UNIT RUN OBSERVATION ',1)[1]) for line in text.splitlines() if line.startswith('UNIT RUN OBSERVATION ')]
   observed=[]
   for row in observation_rows:
    name=row['kind'];assert name in ('first-error','generation-returned')
    source=Path(row['path']).resolve()
    expected_store=Path.home()/'AppData/Roaming'/('pfe-modsettings-rconnect-coop-'+role+'-'+run.name)/'Local Store/unit-run-generation'
    assert source==expected_store/(name+'.json')
    content=read(source);assert content['kind']==name and content['applicationId']=='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
    saved=out/(role+'-'+name+'.json');shutil.copyfile(source,saved)
    observed.append(dict(kind=name,source=str(source),sha256=sha(saved),complete=content['complete'],error=content['error'],anomaly_count=content['anomalyCount']))
   result['observations'][role]=observed
   all_text=text+'\n'+(run/(role+'.stdout.log')).read_text(encoding='utf-8-sig',errors='replace')
   for f in (run/'module-logs'/role).glob('*.log'):all_text+='\n'+f.read_text(encoding='utf-8-sig',errors='replace')
   errors=list(dict.fromkeys(line for line in all_text.splitlines() if 'COOP FAIL' in line or 'handoff timed out' in line
    or 'game error dialog' in line or re.search(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line,re.I)))
   rows=[json.loads(line.split('TRAVEL RESULT ',1)[1]) for line in text.splitlines() if line.startswith('TRAVEL RESULT ')]
   result['roles'][role]=dict(rows=rows,errors=errors,done='COOP EFFECTS DONE travel-timing '+role in text,
    version=('v'+version+' initialized') in text,checks=len(re.findall(r'^COOP PASS ',text,re.M)),log_sha256=sha(log))
   if rows:assert [r['round'] for r in rows]==list(range(len(rows))) and len(rows)<=3
  memory=read(run/'memory-timeline.json');assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
  assert memory['minimum_commit_bytes']==512*1024**2
  assert read(run/'memory-before.json')['free_commit_bytes']>=(3 if a.mode=='solo' else 6)*1024**3
  assert not read(run/'air-before.json')
  assert all(not (run/n).exists() for n in ('host','join','frozen')),'Owned runtime copies were not removed'
  result['functional_pass']=bool(p.returncode==0 and result['framework_passed'] and all(v['done'] and v['version'] and not v['errors'] and len(v['rows'])==3 for v in result['roles'].values()))
  result['observation_ready']=all(any(row['kind']=='generation-returned' and row['complete'] for row in result['observations'][role]) for role in expected_roles)
  result['native_error_observed']=any(row['kind']=='first-error' for values in result['observations'].values() for row in values)
  result['passed']=result['functional_pass'] and result['observation_ready'] and not result['native_error_observed']
 except Exception as e:result.update(passed=False,error=str(e),traceback=traceback.format_exc())
 finally:
  try:
   after=installation();assert after==before
   verify(drivers)
   for n,h in pins.items():assert sha(n)==h,n
   result.update(installation_unchanged=True,installation_after=after,inputs_unchanged=True)
  except Exception as e:result.update(passed=False,final_verification_error=str(e))
  save(out/'result.json',result)
 print(json.dumps(dict(passed=result['passed'],output=str(out),run=result.get('run'),error=result.get('error')),ensure_ascii=False))
 return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
