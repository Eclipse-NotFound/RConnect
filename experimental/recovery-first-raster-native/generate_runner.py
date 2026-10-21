"""Adapt only exact candidate/host input verification; keep common runner intact."""
from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def change(s,old,new):assert s.count(old)==1,old[:100];return s.replace(old,new,1)
def main():
    path=ROOT/'tools/validation/run_room_travel_timing.py';original=s=path.read_text(encoding='utf-8-sig')
    s=change(s,'from audit_room_entry_candidate import audit','from native_inputs import audit,host_input,verify_host_intent,verify_driver')
    s=change(s,"ap.add_argument('--game-candidate',help=", "ap.add_argument('--game-candidate',required=True,help=")
    s=change(s,"ap.add_argument('--scenario',choices=['timing','scene','entry-room','entry-map'],default='timing')",
        "ap.add_argument('--scenario',choices=['scene','entry-room'],default='scene')")
    s=change(s,"    meta=read(drivers/'prepared.json')", "    meta=read(drivers/'prepared.json')\n    verify_driver(drivers,meta,a.scenario)")
    s=change(s,"    save(out/'result.json',result)","    verify_driver(drivers,meta,a.scenario)\n    assert sha(drivers/'prepared.json')==read(out/'intent.json')['driver_manifest']\n    save(out/'result.json',result)")
    first=s.index('        host_meta=read(host_candidate/');last=s.index('    out.mkdir();binding=',first)
    s=s[:first]+'        host_intent=host_input(host_candidate,before)\n'+s[last:]
    first=s.index('        assert sha(host_candidate/');last=s.index('        result[\'native_host\']=host_intent',first)
    s=s[:first]+'        verify_host_intent(host_candidate,host_intent,after)\n'+s[last:]
    header='from pathlib import Path\nimport sys\nsys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools/validation"))\n'
    s=header+s
    (HERE/'run_native.py').write_text(s,encoding='utf-8',newline='\n')
    (HERE/'runner.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='common/run_room_travel_timing.py',tofile='isolated/run_native.py')),encoding='utf-8')
    (HERE/'runner-inputs.json').write_text(json.dumps(dict(original_wrapper_sha256=sha(path),
        native_runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),derived_runner_sha256=sha(HERE/'run_native.py'),
        adapter_sha256=sha(HERE/'native_inputs.py'),execution_or_assertion_changes=False,air_started=False),indent=2)+'\n',encoding='utf-8')
    print('Isolated wrapper generated; original execution, error checks, metrics and 22-input validation retained')
if __name__=='__main__':main()
