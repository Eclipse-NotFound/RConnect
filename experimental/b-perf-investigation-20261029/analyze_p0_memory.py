import collections
import datetime
import re
import statistics
from pathlib import Path

path = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-p0-clean-01-memory.csv'
groups = collections.defaultdict(list)
lines = path.read_text(encoding='utf-8-sig').splitlines()
bad = 0
for line in lines[1:]:
    try:
        left, start_text = line.rsplit(',', 1)
        timestamp, elapsed, pid, numbers = left.split(',', 3)
        parts = numbers.split(',')
        values = []
        position = 0
        while position < len(parts) and len(values) < 2:
            current = parts[position]
            position += 1
            if '.' not in current:
                if position >= len(parts):
                    raise ValueError(numbers)
                current += parts[position]
                position += 1
            values.append(float(current))
        if len(values) != 2:
            raise ValueError(numbers)
        working, private = values
        groups[pid].append((
            datetime.datetime.fromisoformat(timestamp),
            float(working), float(private),
            datetime.datetime.fromisoformat(start_text)))
    except Exception:
        bad += 1
        continue
print('parsed', sum(len(value) for value in groups.values()), 'bad', bad, 'groups', len(groups))
items = [(key, value) for key, value in groups.items() if value]
for pid, rows in sorted(items, key=lambda item: min(x[0] for x in item[1])):
    first = min(x[0] for x in rows)
    last = max(x[0] for x in rows)
    stable = [x for x in rows if (x[0] - first).total_seconds() >= 90]
    if not stable:
        continue
    print(pid, 'samples', len(rows), 'from', first.isoformat(timespec='seconds'),
          'to', last.isoformat(timespec='seconds'), 'dur', round((last-first).total_seconds()),
          'start', rows[0][3].isoformat(timespec='seconds'), 'stable_n', len(stable),
          'work_avg', round(statistics.mean(x[1] for x in stable), 1),
          'priv_avg', round(statistics.mean(x[2] for x in stable), 1),
          'work_max', max(x[1] for x in rows), 'priv_max', max(x[2] for x in rows))
