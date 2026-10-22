"""Use the shared runner unchanged except narrowly evidenced negative-test logs.

The scenario deliberately provokes exactly two real localhost IO refusals.
Only those two messages and their complete successful result line can be
excluded from the generic error matcher. All logs remain preserved.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / 'tools/run_coop_regression.py'
ORIGINAL_SHA = '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
COVERAGE = {'virgin','virginLeave','hostNoPeer','hostLeave','joinFailed','failedLeave',
    'failedRetry','loopbackConnected','loopbackClosed','loopbackRetry','occupiedHostFailed','finalLeave'}


def passed_row(row):
    return (row.get('passed') is True and row.get('failed') == 0 and row.get('version') == '0.2.24-offline1'
        and row.get('phase') == 'final-offline' and set(row.get('coverage', {})) == COVERAGE
        and all(v is True for v in row['coverage'].values()) and row.get('loopbackAccepts') == 2
        and row.get('cleanup', {}).get('errors') == [] and row['cleanup'].get('configRestored') is True
        and row['cleanup'].get('sessionReleased') is True)


def expected_lines(text):
    """Empty on any ambiguity; no broad Error/IOError suppression."""
    lines = text.splitlines()
    results = [line for line in lines if line.startswith('OFFLINE LIFECYCLE RESULT ')]
    if len(results) != 1 or 'COOP EFFECTS DONE offline-lifecycle' not in lines:
        return set()
    try:
        row = json.loads(results[0].split('OFFLINE LIFECYCLE RESULT ', 1)[1])
        if not passed_row(row):
            return set()
        observations = [v for v in row['observations'] if v['label'] == 'actual-socket-error']
        if len(observations) != 2 or {v['phase'] for v in observations} != {'join-refused','join-refused-retry'}:
            return set()
        allowed = []
        for event in observations:
            detail = event['detail']
            if detail['kind'] != 'ioError' or detail['attempt'] != event['phase'] or not detail['text'].startswith('Error #2031:'):
                return set()
            allowed.append('RConnectNet: link failed: IOError: ' + detail['text'])
        counts = Counter(lines)
        if any(counts[line] != count for line, count in Counter(allowed).items()):
            return set()
        return set(allowed + results)
    except (ValueError, KeyError, TypeError):
        return set()


def expected_lifecycle_error(path, line):
    if path.name != 'RConnect.log':
        return False
    return line in expected_lines(path.read_text(encoding='utf-8-sig', errors='replace'))


def main():
    raw = ORIGINAL.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == ORIGINAL_SHA
    source = raw.decode('utf-8-sig')
    before = "if re.search(r'\\bERROR\\b|\\b(?:Error\\s*#\\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\\b',line):"
    after = before[:-1] + ' and not expected_lifecycle_error(module_log,line):'
    assert source.count(before) == 1
    modified = source.replace(before, after, 1)
    assert modified.replace(after, before, 1) == source
    # Keep the original __file__ and tools import root; game/storage/cleanup,
    # resource registration, deadlines and memory gates are unchanged.
    sys.path.insert(0, str(ROOT / 'tools'))
    namespace = {'__name__': '__main__', '__file__': str(ORIGINAL),
                 'expected_lifecycle_error': expected_lifecycle_error}
    exec(compile(modified, str(ORIGINAL), 'exec'), namespace)


if __name__ == '__main__':
    main()
