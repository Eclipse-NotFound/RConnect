"""Read-only AIR process inventory for rejecting overlapping timing runs."""
import ctypes
from ctypes import wintypes as w


class ProcessEntry(ctypes.Structure):
    _fields_=[('size',w.DWORD),('usage',w.DWORD),('pid',w.DWORD),
              ('heap',ctypes.c_size_t),('module',w.DWORD),('threads',w.DWORD),
              ('parent',w.DWORD),('priority',w.LONG),('flags',w.DWORD),('exe',w.WCHAR*260)]


def air_processes():
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.CreateToolhelp32Snapshot.argtypes=[w.DWORD,w.DWORD]
    kernel.CreateToolhelp32Snapshot.restype=w.HANDLE
    kernel.Process32FirstW.argtypes=[w.HANDLE,ctypes.POINTER(ProcessEntry)]
    kernel.Process32FirstW.restype=w.BOOL
    kernel.Process32NextW.argtypes=[w.HANDLE,ctypes.POINTER(ProcessEntry)]
    kernel.Process32NextW.restype=w.BOOL
    kernel.CloseHandle.argtypes=[w.HANDLE];kernel.CloseHandle.restype=w.BOOL
    handle=kernel.CreateToolhelp32Snapshot(2,0)
    if handle==ctypes.c_void_p(-1).value:raise ctypes.WinError(ctypes.get_last_error())
    rows=[]
    try:
        entry=ProcessEntry();entry.size=ctypes.sizeof(entry)
        found=kernel.Process32FirstW(handle,ctypes.byref(entry))
        while found:
            if entry.exe.lower() in ('adl.exe','adl64.exe'):rows.append(dict(pid=entry.pid,exe=entry.exe))
            found=kernel.Process32NextW(handle,ctypes.byref(entry))
        error=ctypes.get_last_error()
        if error!=18:raise ctypes.WinError(error)
    finally:kernel.CloseHandle(handle)
    return rows
