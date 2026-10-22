"""Source and fake-query boundaries only: no native handles, AIR, compiler or registration."""
from pathlib import Path
import ast,hashlib,json
import process_times as cpu
import runtime_adapter as adapter

HERE=Path(__file__).resolve().parent
checks=[]
def require(ok,name):
    assert ok,name
    checks.append(name)
def rejects(call,name):
    try:call()
    except RuntimeError:checks.append(name);return
    raise AssertionError(name)

class FakeQuery:
    pid=123;creation=456
    def __init__(self):self.n=0;self.closed=False;self.bad=False;self.decrease=False;self.fail=False
    def read(self):
        if self.fail:raise RuntimeError('injected read failure')
        self.n+=1
        return (457 if self.bad else self.creation,0,0 if self.decrease else self.n*2,self.n*3)
    def close(self):self.closed=True

def main():
    pins=json.loads((HERE/'handoff.json').read_text(encoding='utf-8'))
    for name,h in pins['files'].items():
        require(hashlib.sha256((HERE/name).read_bytes()).hexdigest()==h,'frozen '+name)
    for path,h in pins['originals'].items():
        require(hashlib.sha256(Path(path).read_bytes()).hexdigest()==h,'borrowed '+Path(path).name)
    for name in ('process_times.py','runtime_adapter.py','run.py','check.py'):
        ast.parse((HERE/name).read_text(encoding='utf-8'));checks.append('syntax '+name)
    old=adapter._tail_runner_source();new=adapter.runner_source()
    restored=new
    for before,after in reversed(adapter.EDITS):
        require(restored.count(after)==1,'unique insertion '+str(len(checks)))
        restored=restored.replace(after,before,1)
    require(restored==old,'four additions reverse to exact frozen runner')
    require(new.index('record.child(proc.pid)')<new.index('cpu_traces.append(start_owned(proc,role))'),'starts after owned child registration')
    require(new.index('cpu_results=stop_all(cpu_traces)')<new.index('        for p in procs:'),'stop before original process cleanup')
    require(new.index('if args.private_desktop:p.close()')<new.index("save_all(output/'process-cpu.json',cpu_results)"),'write after original process handle close')
    require(new.count('assert_installation(args,output)')==1,'original post-registration installation gate retained')
    source=(HERE/'process_times.py').read_text(encoding='utf-8')
    require('DuplicateHandle(current,source,current,ctypes.byref(target),0x1000,False,0)' in source,'exact noninheritable query-only duplicate')
    require(all(token not in source for token in ('OpenProcess(', 'TerminateProcess(', 'CreateProcess', 'EnumProcesses', 'process_iter')),'no process open/enumerate/modify APIs')
    query=FakeQuery();trace=cpu.Trace(query,'fake')
    trace.sample(0,'test');trace.sample(0,'test')
    trace.stop_event.set();trace.loop();result=trace.stop()
    require(result['complete'] and query.closed and len(result['rows'])==3,'normal stop closes query with final endpoint')
    query=FakeQuery();trace=cpu.Trace(query,'fake');query.bad=True
    rejects(lambda:trace.sample(0,'test'),'creation identity mismatch rejected')
    query=FakeQuery();trace=cpu.Trace(query,'fake');trace.sample(0,'test');query.decrease=True
    rejects(lambda:trace.sample(0,'test'),'decreasing cumulative CPU rejected')
    query=FakeQuery();trace=cpu.Trace(query,'fake');original_clock=cpu.time.time_ns
    try:
        clock=iter((200,100));cpu.time.time_ns=lambda:next(clock)
        rejects(lambda:trace.sample(0,'test'),'same-read wall clock reversal rejected')
    finally:cpu.time.time_ns=original_clock
    query=FakeQuery();query.fail=True;trace=cpu.Trace(query,'fake');trace.loop();result=trace.stop()
    require(not result['complete'] and query.closed and bool(result['errors']),'query failure closes and marks incomplete')
    original_limit,original_interval=cpu.MAX_ROWS,cpu.INTERVAL_NS
    try:
        cpu.MAX_ROWS=2;cpu.INTERVAL_NS=1
        query=FakeQuery();trace=cpu.Trace(query,'fake');trace.loop();result=trace.stop()
        require(result['truncated'] and len(result['rows'])==2 and query.closed and not result['complete'],'row budget closes query and refuses completeness')
    finally:cpu.MAX_ROWS, cpu.INTERVAL_NS=original_limit,original_interval
    class BadPath:
        def write_text(self,*args,**kwargs):raise OSError('injected output failure')
    cpu.save_all(BadPath(),[]);checks.append('output failure does not escape cleanup')
    result=dict(passed=True,checks=checks,count=len(checks),native_api_executed=False,air_started=False,performance_qualified=False)
    (HERE/'source-check.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,count=len(checks),native_api_executed=False,air_started=False)))
if __name__=='__main__':main()
