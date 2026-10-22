"""Only add observer start/stop/save to the frozen native runner; no SWF rebuild."""
from pathlib import Path
import hashlib,json,sys,difflib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
TAIL=HERE.parent/'recovery-early-paint-tail-native'
sys.path.insert(0,str(TAIL));sys.path.insert(0,str(HERE))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def verify_inputs():
    pins=json.loads((HERE/'handoff.json').read_text(encoding='utf-8'))
    for n,h in pins['files'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    from native_inputs import verify_tools
    return verify_tools()
_source=TAIL/'runtime_adapter.py'
assert sha(_source)=='3f47f608a975faa3e023fd93bf3413d2a1b8fb6aae5577dcd15a08911137ba5e'
_text=_source.read_text(encoding='utf-8-sig')
_entry="if __name__=='__main__':main()\n"
assert _text.endswith(_entry)
exec(compile(_text[:-len(_entry)],str(_source),'exec'),globals())
_tail_runner_source=runner_source
_tail_main=main
EDITS=(
 ("    procs=[]; stdout_files=[]; artifacts=[]; inputs={}",
  "    procs=[]; stdout_files=[]; artifacts=[]; inputs={}\n    from process_times import start_owned,stop_all,save_all\n    cpu_traces=[]"),
 ("            record.child(proc.pid)",
  "            record.child(proc.pid)\n            cpu_traces.append(start_owned(proc,role))"),
 ("    finally:\n        for p in procs:",
  "    finally:\n        cpu_results=stop_all(cpu_traces)\n        for p in procs:"),
 ("        record.child_stopped()\n        (output/'memory-timeline.json')",
  "        record.child_stopped()\n        save_all(output/'process-cpu.json',cpu_results)\n        (output/'memory-timeline.json')"))
def runner_source():
    text=_tail_runner_source()
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text
def main():verify_inputs();_tail_main()
if __name__=='__main__':main()
