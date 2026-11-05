import csv
import collections
import datetime
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'build' / 'ab'
for name in ('b-p0-mem-loading-01-memory.csv', 'b-p13-mem-loading-01-memory.csv'):
    groups = collections.defaultdict(list)
    with (ROOT / name).open(encoding='utf-8-sig', newline='') as stream:
        for row in csv.DictReader(stream):
            groups[row['pid']].append((
                datetime.datetime.fromisoformat(row['timestamp']),
                float(row['workingMB']), float(row['privateMB']),
                datetime.datetime.fromisoformat(row['startTime'])))
    print('###', name)
    items = [(key, value) for key, value in groups.items() if len(value) >= 4]
    for pid, rows in sorted(items, key=lambda item: min(x[0] for x in item[1])):
        first = min(x[0] for x in rows)
        stable = [x for x in rows if (x[0] - first).total_seconds() >= 45]
        if not stable:
            continue
        print(pid, 'n', len(rows), 'stable_n', len(stable),
              'work_avg', round(statistics.mean(x[1] for x in stable), 1),
              'priv_avg', round(statistics.mean(x[2] for x in stable), 1),
              'work_max', max(x[1] for x in rows),
              'priv_max', max(x[2] for x in rows),
              'start', rows[0][3].isoformat(timespec='seconds'))
