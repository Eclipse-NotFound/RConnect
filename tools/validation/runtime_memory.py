"""Read Windows commit headroom; bound only the child process owned by a test."""
import ctypes
from ctypes import wintypes
import json
import time


class PerformanceInfo(ctypes.Structure):
    _fields_ = [('cb', wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in (
        'commit_total', 'commit_limit', 'commit_peak', 'physical_total', 'physical_available',
        'system_cache', 'kernel_total', 'kernel_paged', 'kernel_nonpaged', 'page_size')]
    _fields_ += [('handles', wintypes.DWORD), ('processes', wintypes.DWORD), ('threads', wintypes.DWORD)]


_psapi = ctypes.WinDLL('psapi', use_last_error=True)
_read = _psapi.GetPerformanceInfo
_read.argtypes = [ctypes.POINTER(PerformanceInfo), wintypes.DWORD]
_read.restype = wintypes.BOOL


def snapshot():
    info = PerformanceInfo()
    info.cb = ctypes.sizeof(info)
    if not _read(ctypes.byref(info), info.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    return dict(utc_ms=int(time.time()*1000),
                free_commit_bytes=(info.commit_limit-info.commit_total)*info.page_size,
                commit_limit_bytes=info.commit_limit*info.page_size,
                physical_available_bytes=info.physical_available*info.page_size)


def wait_owned(process, seconds, output):
    """No other process is inspected or stopped. Pressure never counts as pass."""
    start = time.monotonic()
    rows = []
    reason = None
    overhead = 0.0
    exit_code = None
    try:
        while process.poll() is None:
            at = time.perf_counter()
            row = snapshot()
            overhead += (time.perf_counter()-at)*1000
            rows.append(row)
            if row['free_commit_bytes'] < 512*1024*1024:
                reason = 'system-commit-below-512MiB'
            elif time.monotonic()-start >= seconds:
                reason = 'timeout'
            if reason:
                process.kill()
                process.wait()
                exit_code = 125 if reason.startswith('system-') else 124
                return exit_code
            time.sleep(1)
        exit_code = process.returncode
        return exit_code
    finally:
        output.write_text(json.dumps(dict(pid=process.pid, reason=reason, rows=rows,
            exit_code=exit_code, process_returncode=process.poll(),
            sample_elapsed_ms=overhead, interval_ms=1000, minimum_commit_bytes=512*1024*1024),
            indent=2), encoding='utf-8')

