"""Run one existing isolated test while recording only its owned AIR processes.

This is diagnostic observation, not a launcher/cleanup replacement. The existing
runner continues to own its game copies, original inputs and process lifetime.
"""
import argparse
import ctypes
import json
from pathlib import Path
import re
import subprocess
import sys
import time

import psutil

ROOT = Path(__file__).resolve().parents[2]


class MemoryStatus(ctypes.Structure):
    _fields_ = [('length', ctypes.c_ulong), ('load', ctypes.c_ulong)] + [
        (n, ctypes.c_ulonglong) for n in ('total_phys', 'available_phys', 'total_commit',
        'available_commit', 'total_virtual', 'available_virtual', 'extended_virtual')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True)
    parser.add_argument('--bundle', required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    out = (ROOT/args.candidate).resolve()
    assert out.parent == ROOT/'build/m52' and re.fullmatch('[A-Za-z0-9_-]+', args.label)
    manifest = json.loads((out/'prepared.json').read_text(encoding='utf-8'))
    records = out/(args.label+'-memory.jsonl')
    assert not records.exists()
    command = [sys.executable, '-B', '-X', 'utf8', str(ROOT/'tools/validation/run_a22_map_refresh.py'),
        'candidate', '--candidate', str(out), '--bundle', args.bundle, '--label', args.label,
        '--entry', 'A22EnemyTimelineTestDoc', '--land', 'random_mane', '--seconds', '240',
        '--expected-version', manifest['version']]
    process = subprocess.Popen(command, cwd=ROOT)
    run_log = out/(args.label+'-run.log')
    tracked = {}
    with records.open('x', encoding='utf-8') as stream:
        while process.poll() is None:
            if run_log.is_file():
                for line in run_log.read_text(encoding='utf-8', errors='replace').splitlines():
                    if not line.startswith('{"role":'):
                        continue
                    row = json.loads(line)
                    if row['pid'] not in tracked:
                        tracked[row['pid']] = dict(role=row['role'], appid=row['appid'])
            memory = MemoryStatus()
            memory.length = ctypes.sizeof(memory)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(memory))
            sample = dict(at=time.time(), available_phys=memory.available_phys,
                          available_commit=memory.available_commit, owned=[])
            for pid, identity in tracked.items():
                try:
                    owned = psutil.Process(pid)
                    if 'adl64' not in owned.name().lower():
                        continue
                    info = owned.memory_info()._asdict()
                    sample['owned'].append(dict(pid=pid, role=identity['role'], memory=info))
                except psutil.Error:
                    pass
            stream.write(json.dumps(sample)+'\n')
            stream.flush()
            time.sleep(.25)
    raise SystemExit(process.wait())


if __name__ == '__main__':
    main()
