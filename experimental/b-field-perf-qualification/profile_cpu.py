"""Observe one original AB007 --profile run; no process search or extra launch.

The original runner owns launching/registration/cleanup. Its save function is
forwarded exactly once and unchanged; only a read-only receipt reference is
retained because the join PID is not written to disk until the run finishes.
This wrapper is diagnostic, never performance qualification.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import threading
import time
import xml.etree.ElementTree as ET

import qualify as q

FILETIME_UNIX_OFFSET = 116444736000000000
MAX_SAMPLES = 1800
INTERVAL_SECONDS = 1.0
PID_QUERY_ACCESS = 0x1000  # PROCESS_QUERY_LIMITED_INFORMATION; never VM_WRITE/TERMINATE.


def filetime_now():
    return time.time_ns() // 100 + FILETIME_UNIX_OFFSET


def identity(entry, role, workspace, appdata):
    """Verify only the PID explicitly supplied in this run's own receipt."""
    pid = entry.get("pid")
    if type(pid) is not int or pid <= 0:
        raise ValueError("Missing/invalid recorded PID")
    appid = entry.get("appid", "")
    match = re.fullmatch("pfe-modsettings-rconnect-b-ab-" + role + r"-([0-9a-f]{12})", appid)
    if match is None:
        raise ValueError("Recorded appid is not this role's isolated AB test")
    game = (workspace / role).resolve()
    if not game.is_relative_to(workspace.resolve()):
        raise ValueError("Role directory escaped the recorded workspace")
    descriptor = game / "ab-test.xml"
    raw = descriptor.read_bytes()
    hashes = {name.replace("\\", "/").lower(): value for name, value in entry["files"].items()}
    digest = hashlib.sha256(raw).hexdigest()
    if hashes.get("ab-test.xml") != digest:
        raise ValueError("Role descriptor differs from recorded hash")
    doc = ET.fromstring(raw)
    if doc.findtext("{*}id") != appid or doc.findtext("{*}initialWindow/{*}content") != "pfe.swf":
        raise ValueError("Role descriptor identity/entry differs from receipt")
    if Path(entry["storage"]).resolve() != (appdata / appid / "Local Store").resolve():
        raise ValueError("Recorded storage does not match the isolated appid")
    return {"role": role, "pid": pid, "appid": appid, "session": match.group(1),
            "descriptor": str(descriptor), "descriptor_sha256": digest,
            "expected_image": str(game / "adl64.exe")}


def cpu_delta(previous, current, logical_cpus):
    if previous is None:
        return None
    wall_ns = current["monotonic_ns"] - previous["monotonic_ns"]
    kernel = current["kernel_100ns"] - previous["kernel_100ns"]
    user = current["user_100ns"] - previous["user_100ns"]
    if wall_ns <= 0 or kernel < 0 or user < 0:
        raise ValueError("Process sample counters/time moved backwards")
    core_percent = (kernel + user) * 100 / wall_ns * 100
    return {"wall_ms": wall_ns / 1e6, "kernel_ms": kernel / 10000,
            "user_ms": user / 10000, "cpu_core_percent": core_percent,
            "cpu_machine_percent": core_percent / logical_cpus if logical_cpus else None}


class ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
        (name, ctypes.c_size_t) for name in ("PeakWorkingSetSize", "WorkingSetSize",
        "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
        "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage")]


class WindowsQueries:
    """All process handles request query-limited rights only."""
    def __init__(self):
        if os.name != "nt":
            raise RuntimeError("Windows process APIs are required")
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        self.api.OpenProcess.restype = wintypes.HANDLE
        self.api.CloseHandle.argtypes = [wintypes.HANDLE]
        self.api.CloseHandle.restype = wintypes.BOOL
        self.api.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        self.api.GetProcessTimes.restype = wintypes.BOOL
        self.api.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD,
                                                       wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
        self.api.QueryFullProcessImageNameW.restype = wintypes.BOOL
        self.api.K32GetProcessMemoryInfo.argtypes = [wintypes.HANDLE,
            ctypes.POINTER(ProcessMemoryCounters), wintypes.DWORD]
        self.api.K32GetProcessMemoryInfo.restype = wintypes.BOOL

    def open(self, pid):
        handle = self.api.OpenProcess(PID_QUERY_ACCESS, False, pid)
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        return handle

    def close(self, handle):
        self.api.CloseHandle(handle)

    def times(self, handle):
        values = [wintypes.FILETIME() for _ in range(4)]
        if not self.api.GetProcessTimes(handle, *[ctypes.byref(v) for v in values]):
            raise ctypes.WinError(ctypes.get_last_error())
        ticks = [(v.dwHighDateTime << 32) | v.dwLowDateTime for v in values]
        return dict(zip(("creation_100ns", "exit_100ns", "kernel_100ns", "user_100ns"), ticks))

    def image(self, handle):
        buffer = ctypes.create_unicode_buffer(32768)
        size = wintypes.DWORD(len(buffer))
        if not self.api.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)):
            raise ctypes.WinError(ctypes.get_last_error())
        value = buffer.value
        return value[4:] if value.startswith("\\\\?\\") else value

    def memory(self, handle):
        value = ProcessMemoryCounters()
        value.cb = ctypes.sizeof(value)
        if not self.api.K32GetProcessMemoryInfo(handle, ctypes.byref(value), value.cb):
            # Query-limited permissions may not expose memory on every runtime.
            # Never reopen with additional permissions to make a metric appear.
            return {"available": False, "winerror": ctypes.get_last_error()}
        return {"available": True, "working_set_bytes": value.WorkingSetSize,
                "peak_working_set_bytes": value.PeakWorkingSetSize,
                "private_commit_bytes": value.PrivateUsage,
                "pagefile_bytes": value.PagefileUsage, "page_fault_count": value.PageFaultCount}


class Observer:
    def __init__(self, workspace, result, appdata, api, machine, started_filetime,
                 max_samples=MAX_SAMPLES):
        self.workspace, self.result, self.appdata = workspace, result, appdata
        self.api, self.machine, self.started_filetime = api, machine, started_filetime
        self.max_samples, self.logical_cpus = max_samples, os.cpu_count()
        self.receipt = None
        self.stop_event = threading.Event()
        self.thread = None
        self.handles, self.identities, self.previous = {}, {}, {}
        self.rejected, self.exited, self.errors, self.samples = set(), set(), [], []
        self.session = None
        self.truncated = False

    def warn(self, message):
        if len(self.errors) < 32:
            self.errors.append({"wall_time": time.time(), "message": str(message)})

    def save_wrapper(self, original):
        def observe(path, data, *args, **kwargs):
            answer = original(path, data, *args, **kwargs)
            try:
                if Path(path).resolve() == (self.result / "result.json").resolve():
                    self.receipt = data  # Retain reference, never change or re-save it.
            except Exception as error:
                self.warn("Receipt observation failed: " + str(error))
            return answer
        return observe

    def attach(self, role, entry):
        info = identity(entry, role, self.workspace, self.appdata)
        if self.session is not None and info["session"] != self.session:
            raise ValueError("Recorded roles belong to different test sessions")
        if any(value["pid"] == info["pid"] for value in self.identities.values()):
            raise ValueError("Recorded roles reuse the same PID")
        handle = self.api.open(info["pid"])
        try:
            actual_image = str(Path(self.api.image(handle)).resolve()).casefold()
            expected_image = str(Path(info["expected_image"]).resolve()).casefold()
            if actual_image != expected_image:
                raise ValueError("Recorded PID image is not the expected role's adl64.exe")
            times = self.api.times(handle)
            if times["creation_100ns"] < self.started_filetime - 10000000:
                raise ValueError("Recorded PID predates this wrapper run")
            if times["creation_100ns"] > filetime_now() + 10000000:
                raise ValueError("Recorded PID creation time is in the future")
            info.update(image=actual_image, creation_100ns=times["creation_100ns"])
            self.identities[role], self.handles[role] = info, handle
            self.session = info["session"]
        except Exception:
            self.api.close(handle)
            raise

    def close_role(self, role):
        handle = self.handles.pop(role, None)
        if handle is not None:
            self.api.close(handle)

    def tick(self):
        if len(self.samples) >= self.max_samples:
            self.truncated = True
            return False
        if self.receipt is None:
            return True
        entries = dict(self.receipt.get("roles", {}))
        for role in ("host", "join"):
            entry = dict(entries.get(role, {}))
            if "pid" not in entry or role in self.rejected or role in self.exited:
                continue
            if role not in self.handles:
                try:
                    self.attach(role, entry)
                except Exception as error:
                    self.rejected.add(role)
                    self.warn(role + " identity/query rejected: " + str(error))
            elif entry["pid"] != self.identities[role]["pid"] or entry.get("appid") != self.identities[role]["appid"]:
                self.rejected.add(role)
                self.close_role(role)
                self.warn(role + " recorded PID/appid changed; refusing replacement")
        if not self.identities and not self.rejected:
            return True
        row = {"wall_time": time.time(), "monotonic_ns": time.perf_counter_ns(), "roles": {}}
        try:
            row["machine"] = self.machine()
        except Exception as error:
            self.warn("Machine sample unavailable: " + str(error))
        for role, handle in list(self.handles.items()):
            try:
                value = self.api.times(handle)
                if value["creation_100ns"] != self.identities[role]["creation_100ns"]:
                    raise ValueError("PID creation identity changed")
                value.update(pid=self.identities[role]["pid"], wall_time=time.time(),
                             monotonic_ns=time.perf_counter_ns())
                value["delta"] = cpu_delta(self.previous.get(role), value, self.logical_cpus)
                value["memory"] = self.api.memory(handle) if value["exit_100ns"] == 0 else {"available": False, "exited": True}
                self.previous[role] = value
                row["roles"][role] = value
                if value["exit_100ns"]:
                    self.exited.add(role)
                    self.close_role(role)
            except Exception as error:
                self.warn(role + " process sample ended: " + str(error))
                self.rejected.add(role)
                self.close_role(role)
        self.samples.append(row)
        return True

    def run(self):
        try:
            while not self.stop_event.is_set():
                if not self.tick():
                    break
                self.stop_event.wait(INTERVAL_SECONDS)
        except Exception as error:
            self.warn("Sampler stopped: " + str(error))
        finally:
            for role in list(self.handles):
                self.close_role(role)

    def start(self):
        self.thread = threading.Thread(target=self.run, name="owned-AB007-process-observer", daemon=False)
        self.thread.start()

    def stop(self):
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("workspace", "candidate", "native", "result", "out"):
        parser.add_argument("--" + key, required=True)
    parser.add_argument("--plan", default="experimental/b-field-perf-qualification/field21-plan.json")
    parser.add_argument("--seconds", type=int, default=60, choices=range(10, 91))
    args = parser.parse_args()
    plan = q.read(q.root_path(args.plan))
    q.verify_plan(plan)
    workspace, result, candidate, native, out = [q.root_path(getattr(args, key))
                                               for key in ("workspace", "result", "candidate", "native", "out")]
    for path in (workspace, result, candidate, native):
        q.require(path.is_relative_to(q.ROOT / "build/ab"), "Runtime inputs must remain in build/ab")
    q.require(not result.exists(), "Use a new original-runner result directory")
    q.require(not out.exists() and out.parent.is_dir(), "Use a new sampler output with existing parent")
    q.require(not out.is_relative_to(result), "Keep sampler output separate from the original run archive")
    q.require(any(candidate == q.ROOT / group["build"] and native == q.ROOT / group["native"]
                  for group in plan["groups"].values()), "Mod/native pair does not match the frozen plan")
    runner = q.ROOT / plan["runner"]["path"]
    runner_hash = q.sha(runner)
    q.require(runner_hash == plan["runner"]["sha256"], "Original runner bytes changed")
    api = WindowsQueries()
    sys.path.insert(0, str(runner.parent))
    spec = importlib.util.spec_from_file_location("original_ab007_profile_runner", runner)
    bench = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bench)
    observer = Observer(workspace, result, Path(os.environ["APPDATA"]), api, bench.machine, filetime_now())
    original_save, original_argv = bench.save, sys.argv
    bench.save = observer.save_wrapper(original_save)
    bench_args = [str(runner), "--workspace", args.workspace, "--candidate", args.candidate,
                  "--native", args.native, "--result", args.result, "--seconds", str(args.seconds), "--profile"]
    report = {"schema": "b-owned-process-profile-1", "diagnostic_only": True, "qualified": False,
              "runner": str(runner), "runner_sha256": runner_hash, "runner_args": bench_args,
              "wrapper_sha256": q.sha(__file__), "plan_sha256": q.sha(q.root_path(args.plan)),
              "interval_seconds": INTERVAL_SECONDS, "maximum_samples": MAX_SAMPLES,
              "logical_cpus": observer.logical_cpus, "process_access": PID_QUERY_ACCESS,
              "started_wall_time": time.time(), "receipt_observation": "read_only_live_reference_after_original_save"}
    exit_code = 2
    try:
        observer.start()
        sys.argv = bench_args
        exit_code = bench.main()  # The only invocation; original runner owns both games.
    except BaseException as error:
        report["runner_exception"] = type(error).__name__ + ": " + str(error)
        exit_code = 130 if isinstance(error, KeyboardInterrupt) else 2
    finally:
        sys.argv, bench.save = original_argv, original_save
        observer.stop()
        report.update(finished_wall_time=time.time(), runner_exit_code=exit_code,
                      runner_unchanged=q.sha(runner) == runner_hash, identities=observer.identities,
                      errors=observer.errors, rejected_roles=sorted(observer.rejected),
                      exited_roles=sorted(observer.exited), truncated=observer.truncated,
                      samples=observer.samples,
                      limitations=["Process CPU includes all AIR threads, not just the AS3 main thread",
                                   "Timing values are wall-clock time and include scheduler waits",
                                   "No GPU or end-to-end network latency measurement",
                                   "Memory may be unavailable under query-limited permissions",
                                   "Sampling starts after the original receipt first exists; no claim of full boot coverage"])
        report["process_sample_counts"] = {role: sum(role in row["roles"] for row in observer.samples)
                                           for role in ("host", "join")}
        report["two_roles_sampled"] = all(count >= 2 for count in report["process_sample_counts"].values())
        receipt_file = result / "result.json"
        if receipt_file.exists():
            report["original_receipt_sha256"] = q.sha(receipt_file)
        q.output(out, report)
    print(json.dumps({"sampler_output": str(out), "runner_exit_code": exit_code,
                      "samples": len(observer.samples), "errors": observer.errors,
                      "qualified": False}, ensure_ascii=False))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
