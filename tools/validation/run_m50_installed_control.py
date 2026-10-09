"""Run the original seven-angle negative control on the current external baseline."""
import argparse,json,re,subprocess,sys
from pathlib import Path
from validation_baseline import ROOT,M50_SHA,sha,read,verify_protected,verify_runtime_inputs

ap=argparse.ArgumentParser();ap.add_argument('--snapshot',type=Path,required=True);a=ap.parse_args()
out=a.snapshot.resolve();assert out.parent==ROOT/'build/m50' and out.name.startswith('final')
m=read(out/'source-input.json');baseline=verify_protected(m)
old=ROOT/'build/m50/red-peer-01';driver=old/'PeerVisualTestDoc-driver'
assert sha(old/'RConnectMod.swf')==sha(ROOT/'release/RConnectMod.swf')==M50_SHA
assert read(driver/'driver-input.json')==dict(candidate_sha256=M50_SHA,entry='PeerVisualTestDoc')
assert not (out/'installed-control-runner.log').exists()
cmd=[sys.executable,'-X','utf8',str(ROOT/'tools/run_coop_regression.py'),'--candidate',str(old/'RConnectMod.swf'),
     '--effects-driver',str(driver),'--effects','--all-mods','--responsive','--seconds','180','--expected-version','0.2.21-dev','--land','rbl']
if m.get('visible_windows') is True:cmd.append('--visible-windows')
r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
(out/'installed-control-runner.log').write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
found=re.search(r'OUTPUT .*?([0-9a-f]{10})\s*$',r.stdout,re.M)
record=dict(exit=r.returncode,run=found[1] if found else None,expected_negative=False)
if found:
    folder=ROOT/'build/cooperation'/found[1];verify_runtime_inputs(baseline,read(folder/'run.json'))
    logs=[(folder/(role+'.log')).read_text(encoding='utf-8-sig') for role in ('host','join')]
    record['fail_count']=sum(s.count('COOP FAIL') for s in logs)
    record['expected_negative']=r.returncode==1 and record['fail_count']==28 and all('COOP EFFECTS DONE' in s for s in logs)
(out/'installed-control-result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
verify_protected(m)
print(json.dumps(record),flush=True)
assert record['expected_negative'], 'Unexpected installed-control outcome; retain logs and investigate'
