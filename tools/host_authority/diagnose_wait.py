"""Read Windows wait chains for threads of one explicitly supplied test PID.

No process suspension, injection, termination, settings or user store writes.
"""
import argparse
import ctypes as c
import json
import subprocess
from ctypes import wintypes as w


class Lock(c.Structure):
    _fields_ = [('name', w.WCHAR * 128), ('timeout', c.c_longlong), ('alertable', w.BOOL)]


class Thread(c.Structure):
    _fields_ = [('pid', w.DWORD), ('tid', w.DWORD), ('wait_ms', w.DWORD), ('switches', w.DWORD)]


class Detail(c.Union):
    _fields_ = [('lock', Lock), ('thread', Thread)]


class Node(c.Structure):
    _fields_ = [('kind', c.c_int), ('status', c.c_int), ('detail', Detail)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('pid', type=int)
    args = p.parse_args()
    cmd = f'Get-CimInstance Win32_Process -Filter "ProcessId={args.pid}" | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress'
    proc = json.loads(subprocess.check_output(['powershell', '-NoProfile', '-Command', cmd], text=True))
    if 'RConnect\\build\\ab\\' not in proc['CommandLine'] or 'authority-test.xml' not in proc['CommandLine']:
        raise ValueError('Not an explicitly isolated B test process')
    tids = json.loads(subprocess.check_output(['powershell', '-NoProfile', '-Command', f'@((Get-Process -Id {args.pid}).Threads.Id) | ConvertTo-Json -Compress'], text=True))
    api = c.WinDLL('advapi32', use_last_error=True)
    api.OpenThreadWaitChainSession.argtypes = [w.DWORD, c.c_void_p]
    api.OpenThreadWaitChainSession.restype = w.HANDLE
    api.GetThreadWaitChain.argtypes = [w.HANDLE, c.c_size_t, w.DWORD, w.DWORD, c.POINTER(w.DWORD), c.POINTER(Node), c.POINTER(w.BOOL)]
    api.GetThreadWaitChain.restype = w.BOOL
    api.CloseThreadWaitChainSession.argtypes = [w.HANDLE]
    handle = api.OpenThreadWaitChainSession(0, None)
    if not handle:
        raise c.WinError(c.get_last_error())
    result = {'process': proc, 'threads': []}
    try:
        for tid in tids:
            count, cycle, nodes = w.DWORD(16), w.BOOL(), (Node * 16)()
            ok = api.GetThreadWaitChain(handle, 0, 0, tid, c.byref(count), nodes, c.byref(cycle))
            row = dict(tid=tid, ok=bool(ok), cycle=bool(cycle.value), nodes=[])
            if ok:
                for n in nodes[:count.value]:
                    data = dict(kind=n.kind, status=n.status)
                    if n.kind == 8:
                        data.update(pid=n.detail.thread.pid, tid=n.detail.thread.tid, wait_ms=n.detail.thread.wait_ms)
                    else:
                        data.update(name=n.detail.lock.name)
                    row['nodes'].append(data)
            else:
                row['error'] = c.get_last_error()
            result['threads'].append(row)
    finally:
        api.CloseThreadWaitChainSession(handle)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
