"""Query-only CPU accounting for the exact HiddenProcess just created by our runner."""
import ctypes
from ctypes import wintypes as w
import json,threading,time

INTERVAL_NS=50_000_000
MAX_ROWS=20000

def ticks(value):return (int(value.dwHighDateTime)<<32)|int(value.dwLowDateTime)

class NativeQuery:
    def __init__(self,process):
        from air_test_process import HiddenProcess
        if not isinstance(process,HiddenProcess) or not process._process:
            raise TypeError('Only the existing owned HiddenProcess handle is accepted')
        self.pid=int(process.pid);self.handle=None
        self.k=ctypes.WinDLL('kernel32',use_last_error=True)
        self.k.GetCurrentProcess.restype=w.HANDLE
        self.k.GetProcessId.argtypes=[w.HANDLE];self.k.GetProcessId.restype=w.DWORD
        self.k.GetProcessTimes.argtypes=[w.HANDLE]+[ctypes.POINTER(w.FILETIME)]*4
        self.k.GetProcessTimes.restype=w.BOOL
        self.k.DuplicateHandle.argtypes=[w.HANDLE,w.HANDLE,w.HANDLE,ctypes.POINTER(w.HANDLE),w.DWORD,w.BOOL,w.DWORD]
        self.k.DuplicateHandle.restype=w.BOOL
        self.k.CloseHandle.argtypes=[w.HANDLE];self.k.CloseHandle.restype=w.BOOL
        source=process._process
        if self.k.GetProcessId(source)!=self.pid:raise RuntimeError('Owned handle PID mismatch')
        creation,_,_,_=self._read(source);self.creation=creation
        target=w.HANDLE();current=self.k.GetCurrentProcess()
        if not self.k.DuplicateHandle(current,source,current,ctypes.byref(target),0x1000,False,0):
            raise ctypes.WinError(ctypes.get_last_error())
        self.handle=target
        try:
            if self.k.GetProcessId(target)!=self.pid or self._read(target)[0]!=creation:
                raise RuntimeError('Query-only duplicate identity mismatch')
        except BaseException:
            self.close();raise
    def _read(self,handle):
        values=[w.FILETIME() for _ in range(4)]
        if not self.k.GetProcessTimes(handle,*[ctypes.byref(v) for v in values]):
            raise ctypes.WinError(ctypes.get_last_error())
        return tuple(ticks(v) for v in values)  # creation, exit, kernel, user; 100ns
    def read(self):return self._read(self.handle)
    def close(self):
        if self.handle is not None:
            if not self.k.CloseHandle(self.handle):raise ctypes.WinError(ctypes.get_last_error())
            self.handle=None

class Trace:
    def __init__(self,query,role):
        self.query=query;self.role=role;self.rows=[];self.errors=[];self.truncated=False;self.closed=False
        self.stop_event=threading.Event();self.thread=None;self.join_timeout=False
        self.started_wall_ms=time.time_ns()/1_000_000
    def sample(self,due,phase):
        before=time.perf_counter_ns();wall_before=time.time_ns()
        creation,exit_at,kernel,user=self.query.read()
        wall_after=time.time_ns();after=time.perf_counter_ns()
        if wall_after<wall_before:raise RuntimeError('Wall clock moved backwards during read; alignment invalid')
        row=dict(phase=phase,mono_before_ns=before,mono_after_ns=after,
            wall_before_ms=wall_before/1_000_000,wall_after_ms=wall_after/1_000_000,
            read_ns=after-before,late_ns=max(0,before-due),creation_100ns=str(creation),
            exit_100ns=str(exit_at),kernel_100ns=kernel,user_100ns=user)
        if creation!=self.query.creation:raise RuntimeError('Creation identity changed')
        if self.rows:
            previous=self.rows[-1]
            row['interval_ns']=before-previous['mono_before_ns']
            if kernel<previous['kernel_100ns'] or user<previous['user_100ns']:
                raise RuntimeError('Cumulative CPU counter decreased')
            if wall_before/1_000_000<previous['wall_after_ms']:
                raise RuntimeError('Wall clock moved backwards; alignment invalid')
        self.rows.append(row)
    def loop(self):
        due=time.perf_counter_ns()
        try:
            while not self.stop_event.is_set():
                if len(self.rows)>=MAX_ROWS:self.truncated=True;break
                self.sample(due,'interval')
                due+=INTERVAL_NS
                now=time.perf_counter_ns()
                if due<=now:due=now+INTERVAL_NS  # No catch-up bursts after a delay.
                self.stop_event.wait(max(0,(due-time.perf_counter_ns())/1e9))
            if self.stop_event.is_set() and len(self.rows)<MAX_ROWS:
                self.sample(time.perf_counter_ns(),'stop-before-process-cleanup')
        except BaseException as error:self.errors.append(type(error).__name__+': '+str(error)[:512])
        finally:
            try:self.query.close();self.closed=True
            except BaseException as error:self.errors.append('CloseHandle: '+str(error)[:512])
    def start(self):
        self.thread=threading.Thread(target=self.loop,name='owned-process-cpu-'+self.role,daemon=True)
        try:self.thread.start()
        except BaseException:
            self.query.close();self.closed=True;raise
    def stop(self):
        self.stop_event.set()
        if self.thread is not None:self.thread.join(timeout=2)
        self.join_timeout=self.thread is not None and self.thread.is_alive()
        # A stuck query thread owns its handle until its finally executes. Never
        # close underneath it. Original cleanup follows after at most 2s per trace.
        return dict(role=self.role,pid=self.query.pid,creation_100ns=str(self.query.creation),
            handle_access=0x1000,interval_ms=50,row_limit=MAX_ROWS,
            complete=not self.join_timeout and self.closed and not self.errors and not self.truncated and len(self.rows)>=2,
            query_handle_closed=self.closed,join_timeout=self.join_timeout,truncated=self.truncated,
            errors=list(self.errors),rows=[] if self.join_timeout else list(self.rows),
            started_wall_ms=self.started_wall_ms,stopped_wall_ms=time.time_ns()/1_000_000,
            diagnostic_only=True,performance_qualified=False,
            scope='Entire owned process, all threads; not main-thread/GPU time; counter endpoints have sampling uncertainty')

def start_owned(process,role):
    query=NativeQuery(process);trace=Trace(query,role);trace.start();return trace

def stop_all(traces):
    results=[]
    for trace in traces:
        try:results.append(trace.stop())
        except BaseException as error:
            results.append(dict(role=trace.role,complete=False,error=str(error)[:512],diagnostic_only=True,performance_qualified=False))
    return results

def save_all(path,results):
    # Called only after original kill/wait/close. I/O failure never blocks cleanup.
    try:
        path.write_text(json.dumps(dict(kind='owned-native-process-cpu',diagnostic_only=True,
            performance_qualified=False,complete=bool(results) and all(r['complete'] for r in results),roles=results),indent=2)+'\n',encoding='utf-8')
    except BaseException as error:
        try:print('PROCESS CPU DIAGNOSTIC WRITE FAILED: '+str(error),flush=True)
        except BaseException:pass
