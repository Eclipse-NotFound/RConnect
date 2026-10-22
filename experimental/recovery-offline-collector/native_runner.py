"""Run the exact shared native runner without altering its error classification."""
from pathlib import Path
import hashlib
import runpy
import sys

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / 'tools/run_coop_regression.py'
ORIGINAL_SHA = '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
COVERAGE = {'virgin', 'null', 'throws', 'falseValue', 'truthyString', 'afterHost'}


def passed_row(row):
    cleanup = row.get('cleanup', {})
    return (row.get('passed') is True and row.get('failed') == 0
        and row.get('version') == '0.2.24-offline1' and row.get('phase') == 'done'
        and row.get('abortReason') == '' and set(row.get('coverage', {})) == COVERAGE
        and all(v is True for v in row['coverage'].values())
        and row.get('collectorExecutionQualified') is True
        and cleanup.get('errors') == []
        and all(cleanup.get(k) is True for k in ('hookRestored', 'configRestored',
            'sessionReleased', 'equipmentRestored')))


if __name__ == '__main__':
    assert hashlib.sha256(ORIGINAL.read_bytes()).hexdigest() == ORIGINAL_SHA
    sys.path.insert(0, str(ROOT / 'tools'))
    runpy.run_path(str(ORIGINAL), run_name='__main__')
