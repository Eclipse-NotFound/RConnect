"""Run one exact-byte isolated M51 probe. Never closes an unrelated game."""
import argparse, ast, copy, json, os, re, shutil, subprocess, sys
from pathlib import Path
from validation_baseline import ROOT, GAME, sha, read, verify_protected, verify_runtime_inputs
from run_final_regressions import JAVA

ap=argparse.ArgumentParser();ap.add_argument('snapshot');ap.add_argument('entry');ap.add_argument('--seconds',type=int)
ap.add_argument('--vision-candidate',type=Path,help='Diagnostic probes only: exact RV cache candidate, with its frozen inputs manifest')
ap.add_argument('--game-candidate',type=Path,help='Diagnostic probes only: isolated native Land patch, with exact inputs manifest')
a=ap.parse_args();out=(ROOT/a.snapshot).resolve()
assert out.parent==ROOT/'build/m51'
m=read(out/'source-input.json');baseline=verify_protected(m)
for n,h in {**m['source'],**m['verification']}.items():assert sha(out/n)==h,n
assert sha(out/'RConnectMod.swf')==m['candidate_sha256']
vision_args=[];vision_record=None;runtime_baseline=baseline
if a.vision_candidate:
    assert out.name.startswith('probe-'),'RV overrides cannot qualify as final release evidence'
    p=a.vision_candidate.resolve();rv=GAME/'mods/RealisticVision'
    assert p.name=='RealisticVisionMod.swf' and p.parent.parent==rv/'build' and p.parent.name.startswith('exploration-cache-')
    v=read(p.parent/'inputs.json');assert sha(p)==v['candidate_sha256']
    for n,h in v['source'].items():assert sha(p.parent/n)==h,n
    for n,h in v['protected'].items():assert sha(GAME/n)==h,n
    dest=out/'RealisticVisionCandidate.swf'
    if not dest.exists():shutil.copy2(p,dest)
    assert sha(dest)==v['candidate_sha256']
    vision_args=['--vision-candidate',str(dest)]
    vision_record=dict(path=p.as_posix(),sha256=sha(dest),inputs_sha256=sha(p.parent/'inputs.json'),diagnostic_only=True)
    runtime_baseline=copy.deepcopy(baseline)
    matches=[n for n in runtime_baseline['runtime_modules'] if n.replace('\\','/').lower()=='mods/realisticvision/release/realisticvisionmod.swf']
    assert len(matches)==1
    runtime_baseline['runtime_modules'][matches[0]]=sha(dest)
game_args=[];game_record=None
if a.game_candidate:
    assert out.name.startswith('probe-'),'Game overrides cannot qualify as final release evidence'
    p=a.game_candidate.resolve()
    assert p.name=='pfe.swf' and p.parent.parent==ROOT/'build/m51' and p.parent.name.startswith('map-seed-game-')
    v=read(p.parent/'game-input.json');assert v['diagnostic_only'] and sha(p)==v['candidate_sha256']
    assert v['original_sha256']==baseline['protected']['pfe.swf']
    for n,h in v['sources'].items():assert sha(p.parent/n)==h,n
    assert sha(ROOT/v['script'])==v['script_sha256']
    dest=out/'game-candidate/pfe.swf'
    if not dest.exists():dest.parent.mkdir(exist_ok=False);shutil.copy2(p,dest)
    assert sha(dest)==v['candidate_sha256']
    runtime_baseline=copy.deepcopy(runtime_baseline)
    runtime_baseline['protected']['pfe.swf']=sha(dest)
    runtime_baseline['runtime_assets']['pfe.swf']=sha(dest)
    game_args=['--game-candidate',str(dest)]
    game_record=dict(path=p.as_posix(),sha256=sha(dest),inputs_sha256=sha(p.parent/'game-input.json'),diagnostic_only=True)
driver=out/'build'/(a.entry+'-driver');assert not driver.exists()
with (out/(a.entry+'-build.log')).open('w',encoding='utf-8') as log:
    r=subprocess.run([sys.executable,'-X','utf8',str(out/'tools/build_effects_driver.py'),'--candidate',str(out/'RConnectMod.swf'),
        '--source-root',str(out/'src'),'--java',JAVA,'--output',str(driver),'--entry',a.entry],cwd=out,stdout=log,stderr=subprocess.STDOUT)
if r.returncode:
    print((out/(a.entry+'-build.log')).read_bytes().decode('gb18030',errors='replace')[-6500:]);raise SystemExit(r.returncode)
# The scene and time budget belong to the frozen test inputs, not to a later
# edit of the live planner while another probe is still running.
planner=ast.parse((out/'tools/validation/run_final_regressions.py').read_text(encoding='utf-8-sig'))
checks=next(ast.literal_eval(node.value) for node in planner.body if isinstance(node,ast.Assign)
    and any(isinstance(target,ast.Name) and target.id=='CHECKS' for target in node.targets))
seconds,land,profile=checks.get(a.entry,(300,'rbl',False))
profile_args=[]
if profile:
    assert out.name.startswith('final-') and m.get('profiles'),'Frozen isolated profiles required'
    for role,record in m['profiles'].items():
        p=ROOT/record['path'];assert p.is_relative_to(out/'profiles') and sha(p)==record['sha256']
        profile_args+=['--'+role+'-save-template',str(p)]
    profile_args+=['--connect-after-load']
if a.seconds:seconds=a.seconds
for n in ('tools/run_coop_regression.py','tools/RConnect.Process.ps1','tools/keep_test_responsive.ps1','tools/validation/native_runtime_assets.py'):
    assert sha(ROOT/n)==m['verification'][n],n
command=[sys.executable,'-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(out/'RConnectMod.swf'),
    '--effects-driver',str(driver),'--effects','--all-mods','--responsive','--visible-windows','--seconds',str(seconds),'--expected-version',m['version']]+profile_args+vision_args+game_args
if land:command+=['--land',land]
print('RUN '+a.entry,flush=True)
r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
(out/(a.entry+'-runner.log')).write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
found=re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$',r.stdout,re.M)
record=dict(entry=a.entry,run=found.group(1) if found else None,exit=r.returncode,sha256=m['candidate_sha256'])
if vision_record:record['vision_override']=vision_record
if game_record:record['game_override']=game_record
if record['run']:
    folder=ROOT/'build/cooperation'/record['run'];run=read(folder/'run.json');verify_runtime_inputs(runtime_baseline,run)
    for role in ('host','join'):
        s=(folder/(role+'.log')).read_text(encoding='utf-8-sig')
        record[role]=dict(passed=len(re.findall('^COOP PASS ',s,re.M)),failed=len(re.findall('^COOP FAIL ',s,re.M)),done='COOP EFFECTS DONE' in s)
        storage=__import__('pathlib').Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-coop-'+role+'-'+record['run'])/'Local Store'
        for p in storage.glob('*.png'):shutil.copy2(p,folder/(role+'-'+p.name))
(out/(a.entry+'-result.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
verify_protected(m);print(json.dumps(record))
if r.returncode:print('\n'.join(line for line in r.stdout.splitlines() if 'FAIL ' in line or 'ERROR' in line)[-5500:])
raise SystemExit(r.returncode)
