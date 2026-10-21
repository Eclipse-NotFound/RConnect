"""Derive an explicit-intent wrapper, retaining the reviewed timing checks."""
from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def change(s,a,b):assert s.count(a)==1,a[:100];return s.replace(a,b,1)
def main():
 old=s=(ROOT/'experimental/recovery-first-raster-native/run_native.py').read_text(encoding='utf-8')
 s=change(s,'from native_inputs import audit,host_input,verify_host_intent,verify_driver',
     'from control_inputs import audit,host_input,verify_host_intent,verify_driver,validate_gate_result')
 s=change(s,"    ap.add_argument('--candidate',required=True)","    ap.add_argument('--candidate',required=True)\n    ap.add_argument('--gate-expect',choices=['on','off'],required=True)")
 s=change(s,"choices=['scene','entry-room']","choices=['scene']")
 s=change(s,'    audit(candidate)','    audit(candidate,a.gate_expect)')
 s=change(s,"    save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf')))",
     "    save(binding/'driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(binding/'EffectsDriver.swf')))\n    gate_intent=dict(schema=1,expectSeedTicket=a.gate_expect=='on',candidateSha=digest)\n    save(binding/'seed-gate-intent.json',gate_intent)")
 s=change(s,"scenario=a.scenario,solo=a.solo,diagnostic_only=", "scenario=a.scenario,solo=a.solo,seed_gate_intent=gate_intent,diagnostic_only=")
 # Freeze the actual invoked private runtime too, while preserving the common
 # runtime hash separately in adapter-inputs.json.
 s=s.replace("ROOT/'tools/run_coop_regression.py'","Path(__file__).resolve().parent/'native_runner.py'")
 s=change(s,"    verify_driver(drivers,meta,a.scenario)\n    assert sha(drivers/'prepared.json')==read(out/'intent.json')['driver_manifest']", 
     "    audit(candidate,a.gate_expect)\n    verify_driver(drivers,meta,a.scenario)\n    assert sha(drivers/'prepared.json')==read(out/'intent.json')['driver_manifest']\n    if found:validate_gate_result(result,gate_intent,run,binding)")
 (HERE/'run_native.py').write_text(s,encoding='utf-8',newline='\n')
 (HERE/'wrapper.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='frozen-first-raster/run_native.py',tofile='seed-control/run_native.py')),encoding='utf-8')
 names=['run_native.py','native_runner.py','control_inputs.py','generate.py','generate_adapter.py','prepare.py','prepare_driver.py']
 (HERE/'adapter-inputs.json').write_text(json.dumps(dict(files={n:sha(HERE/n) for n in names},
     common_runtime_sha256=sha(ROOT/'tools/run_coop_regression.py'),common_wrapper_sha256=sha(ROOT/'tools/validation/run_room_travel_timing.py'),
     source_only=True,air_started=False),indent=2)+'\n',encoding='utf-8')
 print('Explicit on/off wrapper prepared; no game run')
if __name__=='__main__':main()
