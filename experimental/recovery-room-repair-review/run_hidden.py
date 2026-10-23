"""Reuse the exact historical 12-round hidden-room driver with roomfix2/80CF."""
from pathlib import Path
import argparse,json,re,shutil,subprocess,sys,traceback
from prepare import ROOT,M52,GAME,RUNNER,installation,sha,read,save
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
PRODUCT=M52/'recovery-room-production-02'; OLD=M52/'a22-testpack-15-04'
DRIVER=OLD/'build/driver-qualified-hidden'; VERSION='0.2.24-roomfix2'
CANDIDATE='c26b1aa7dccf6e96c4027f551332a2b55d413467b24311426a20c8d341058cc0'
HOST='80cfd8cf3138ee59cbf6eda0a1824a9ec960f413bd95e4b90d41dd0322b4fd3d'
ARTIFACTS={'EffectsDriver.swf':'a2a5c325b87182f02aab51e0dd9808ec46fb367070d4c6f7f0a9bc3488ef0f6f',
 'EffectsHarness.swf':'cfe342dcf55d4554971d2ac1902b8d50c68b831cfc5e9adcf5aed752df5470d5'}
def preflight():
 before=installation();assert before['pfe.swf']==HOST
 pins={str(Path(__file__)):sha(__file__),str(HERE/'prepare.py'):sha(HERE/'prepare.py')}
 assert sha(RUNNER)=='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
 pins[str(RUNNER)]=sha(RUNNER)
 assert sha(PRODUCT/'prepared.json')=='39ed0adf2c4e49abbd796f1daedd264e8b517587c7bda27eea8dbe7a94f59200'
 assert sha(PRODUCT/'compile.json')=='9b5bbfa9853c3d2c6e9ef511fac795108e39e42cc55bd7bbe4aefa7af316b69c'
 prepared=read(PRODUCT/'prepared.json');compiled=read(PRODUCT/'compile.json')
 assert prepared['kind']=='room-repair-overlay' and prepared['version']==VERSION
 assert compiled['compiled'] is True and compiled['candidate_sha256']==CANDIDATE==sha(PRODUCT/'RConnectMod.swf')
 assert all(c['exit_code']==0 for c in compiled['commands'])
 assert compiled['installation_before']==compiled['installation_after']==prepared['installation_before']==before
 assert compiled['sources_unchanged'] is True and compiled['installation_unchanged'] is True
 for name,digest in prepared['source'].items():assert sha(PRODUCT/'src'/name)==digest; pins[str(PRODUCT/'src'/name)]=digest
 for name,digest in prepared['inputs'].items():assert sha(PRODUCT/'tools'/name)==digest; pins[str(PRODUCT/'tools'/name)]=digest
 # Historical proof validates the reused bytes, never impersonates today's installation.
 assert sha(OLD/'prepared.json')=='ec5400b9f2874030dc19d386a706c22babc692344412ee7910714b21f6cfad88'
 assert sha(OLD/'qualified-hidden-result.json')=='707ce3c81dddaaaedefb56b16547a65a0514a3c5221e0f851a0cd3df9792f6fb'
 old=read(OLD/'prepared.json');result=read(OLD/'qualified-hidden-result.json');intent=read(OLD/'qualified-hidden-intent.json')
 for name,digest in {**old['source'],**old['inputs']}.items():assert sha(OLD/name)==digest; pins[str(OLD/name)]=digest
 assert result['entry']=='A22HiddenTimingTestDoc' and result['run']=='73d75eff59' and result['exit']==0
 assert result['installation_changes']=={} and all(result[r]['done'] and result[r]['failed']==0 for r in ('host','join'))
 oldrun=ROOT/'build/cooperation/73d75eff59'
 assert sha(oldrun/'run.json')==result['run_sha256']
 oldnative=read(oldrun/'run.json')
 for role in ('host','join'):
  assert sha(oldrun/(role+'.log'))==result[role]['log_sha256']
  assert oldnative['inputs'][role]['driver']==ARTIFACTS['EffectsDriver.swf']
  assert oldnative['inputs'][role]['harness']==ARTIFACTS['EffectsHarness.swf']
  pins[str(oldrun/(role+'.log'))]=sha(oldrun/(role+'.log'))
 assert read(DRIVER/'driver-input.json')=={'candidate_sha256':old['candidate_sha256'],'entry':'A22HiddenTimingTestDoc'}
 for name,digest in ARTIFACTS.items():assert sha(DRIVER/name)==digest==intent['inputs']['driver'][name];pins[str(DRIVER/name)]=digest
 for p in (PRODUCT/'prepared.json',PRODUCT/'compile.json',PRODUCT/'RConnectMod.swf',OLD/'prepared.json',OLD/'qualified-hidden-result.json',OLD/'qualified-hidden-intent.json',OLD/'qualified-hidden-build.log',DRIVER/'driver-input.json',oldrun/'run.json'):
  pins[str(p)]=sha(p)
 return before,pins
def review_role(run,role):
 log=run/(role+'.log');text=log.read_text(encoding='utf-8-sig',errors='replace')
 files=[log,run/(role+'.stdout.log'),*(run/'module-logs'/role).glob('*.log')]
 combined='\n'.join(p.read_text(encoding='utf-8-sig',errors='replace') for p in files)
 errors=list(dict.fromkeys(line for line in combined.splitlines() if 'COOP FAIL' in line or 'handoff timed out' in line or 'game error dialog' in line or re.search(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',line,re.I)))
 labels=(['enabled host follows join into background','host camera/player world pointers remain local','host local player body remains visible after join entry','host settles returned join hit once','host defeated enemy remains dead after round trip'] if role=='host' else ['join enters distinct background Z room through native door','join returns to original foreground through native door','defeated foreground enemy does not respawn alive','surviving foreground enemy keeps authoritative health','reunited join returns to mirrored combat','join native LMG can damage surviving enemy after return'])
 coverage={label:len(re.findall(r'^COOP PASS hidden-room '+re.escape(label),text,re.M)) for label in labels}
 if role=='host':
  for stem in ('host input remains enabled after join entry round ','host moves through native input after follow round ','host body contributes pixels to final scene round '):
   rounds=[int(x) for x in re.findall(r'^COOP PASS hidden-room '+re.escape(stem)+r'(\d+)\s*$',text,re.M)]
   coverage[stem]=rounds
   if rounds!=list(range(12)):errors.append('Incomplete rounds: '+stem)
  controls=[json.loads(l.split('HIDDEN TEST control ',1)[1]) for l in text.splitlines() if l.startswith('HIDDEN TEST control ')]
  if [c['round'] for c in controls]!=list(range(12)) or not all(c['state']['landZ']==1 and c['state']['samePlayer'] and c['pixels']>30 for c in controls):errors.append('Native background identity/pixel observations incomplete')
 if any(coverage[label]!=12 for label in labels):errors.append('Incomplete 12-round native coverage')
 return dict(done='COOP EFFECTS DONE hidden-room '+role in text,version=('v'+VERSION+' initialized') in text,
  passed=len(re.findall(r'^COOP PASS ',text,re.M)),failed=len(re.findall(r'^COOP FAIL ',text,re.M)),errors=errors,coverage=coverage,logs={str(p):sha(p) for p in files})
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path);ap.add_argument('--check',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 before,pins=preflight()
 if a.check:print(json.dumps(dict(preflight=True,candidate=CANDIDATE,host=HOST,driver=ARTIFACTS,air_started=False)));return 0
 assert a.output is not None and a.registry_wait>=0
 out=(ROOT/a.output).resolve();assert out.parent==M52 and not out.exists();out.mkdir();binding=out/'driver';binding.mkdir()
 for name,digest in ARTIFACTS.items():shutil.copyfile(DRIVER/name,binding/name);assert sha(binding/name)==digest
 save(binding/'driver-input.json',dict(candidate_sha256=CANDIDATE,entry='A22HiddenTimingTestDoc',
  reused_historical_driver=True,original_candidate_sha256=read(DRIVER/'driver-input.json')['candidate_sha256'],driver_sha256=ARTIFACTS['EffectsDriver.swf'],source_provenance=str(OLD/'prepared.json')))
 command=[sys.executable,'-B','-X','utf8',str(RUNNER),'--candidate',str(PRODUCT/'RConnectMod.swf'),'--effects','--effects-driver',str(binding),'--all-mods','--land','random_mane','--seconds','600','--expected-version',VERSION,'--private-desktop','--defer-visible','--wait-host-world','--require-exclusive-air','--registry-wait',str(a.registry_wait)]
 save(out/'intent.json',dict(command=command,inputs=pins,installation=before,candidate_sha256=CANDIDATE,host_sha256=HOST,driver=ARTIFACTS,source='historical unchanged 12-round native background-door fixture',recompiled=False,no_game_override=True,no_other_mod_override=True))
 result=dict(passed=False,air_started=False,roles={},performance_qualified=False,installed=False)
 try:
  with (out/'runner.log').open('x',encoding='utf-8') as log:p=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  result['exit_code']=p.returncode;raw=(out/'runner.log').read_text(encoding='utf-8',errors='replace')
  result['framework_passed']=bool(re.search(r'^RESULT PASS\s*$',raw,re.M)) and not bool(re.search(r'^RESULT FAIL\s*$',raw,re.M))
  runs=re.findall(r'^(?:OUTPUT|QUEUED_OUTPUT) (.+?[0-9a-f]{10})\s*$',raw,re.M);assert runs,'No owned run path'
  run=Path(runs[-1]).resolve();assert run.parent==(ROOT/'build/cooperation').resolve();result['run']=str(run)
  native=read(run/'run.json');result['run_sha256']=sha(run/'run.json');result['air_started']=bool(native['pids'])
  assert native['sha256']==CANDIDATE and native['solo'] is False and native['private_desktop'] is True and native['defer_visible'] is True
  assert sha(run/'input.json')==native['input_manifest_sha256'] and set(native['inputs'])=={'host','join'}
  installed={n.replace('\\','/').lower():h for n,h in before.items()}
  for role in ('host','join'):
   v=native['inputs'][role];assert v['game']==HOST and v['production']==CANDIDATE and v['driver']==ARTIFACTS['EffectsDriver.swf'] and v['harness']==ARTIFACTS['EffectsHarness.swf']
   for n,h in v['modules'].items():
    key=n.replace('\\','/').lower();assert h==(ARTIFACTS['EffectsHarness.swf'] if key=='mods/rconnect/release/rconnectmod.swf' else installed[key]),n
   for n,h in v.get('mod_assets',{}).items():assert h==installed[n.replace('\\','/').lower()]
   result['roles'][role]=review_role(run,role)
  memory=read(run/'memory-timeline.json');assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
  assert memory['minimum_commit_bytes']==512*1024**2 and read(run/'memory-before.json')['free_commit_bytes']>=6*1024**3
  assert not read(run/'air-before.json') and all(not (run/n).exists() for n in ('host','join','frozen'))
  result['passed']=bool(p.returncode==0 and result['framework_passed'] and all(v['done'] and v['version'] and v['passed']>0 and v['failed']==0 and not v['errors'] for v in result['roles'].values()))
 except Exception as e:result.update(passed=False,error=str(e),traceback=traceback.format_exc())
 finally:
  try:
   assert installation()==before
   for path,digest in pins.items():assert sha(path)==digest,path
   for name,digest in ARTIFACTS.items():assert sha(binding/name)==digest
   result.update(installation_unchanged=True,inputs_unchanged=True,owned_runtime_copies_removed=bool(result.get('run')) and all(not (Path(result['run'])/n).exists() for n in ('host','join','frozen')))
  except Exception as e:result.update(passed=False,final_verification_error=str(e))
  save(out/'result.json',result)
 print(json.dumps(dict(passed=result['passed'],output=str(out),run=result.get('run'),error=result.get('error')),ensure_ascii=False));return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
