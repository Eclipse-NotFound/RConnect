"""Preserve original failures and full scene audit; append corridor evidence."""
from prepare import load_helper, ROOT, read, sha
base = load_helper('audit.py')


def corridor_rows(out):
    result = read(out / 'result.json')
    rows = {}
    for role in ('host', 'join'):
        log = ROOT / 'build/cooperation' / result['run'] / (role + '.log')
        found = base.prefixed(log.read_text(encoding='utf-8-sig', errors='replace'), 'DENSITY CORRIDOR ')
        assert len(found) == 1, role + ': one actual corridor summary required'
        row = found[0]
        assert row['fixture'] == 'native-open-corridor-v1' and row['role'] == role
        assert row['applied'] and not row['bad'] and row['nativeFlightUnmodified']
        assert len(row['cells']) == 48 * 25
        assert base.adler_utf16(row['cells']) == row['common']['tileHash']
        assert all(n == 0 for n in row['common']['staticLists'].values())
        assert row['common']['backobjs'] == 0
        assert len(row['geometry']) == (12 if role == 'host' else 0)
        assert all(g['ok'] for g in row['geometry'])
        rows[role] = row
    assert rows['host']['common'] == rows['join']['common'], 'Actual native corridor differs across peers'
    return rows


def audit(out, reference=None):
    report = base.audit(out, reference)
    # Never turn a native movement/frame fail green, nor discard the original
    # conservative full prepared-scene comparison because Part/hold varied.
    try:
        rows = corridor_rows(out)
        report['corridor'] = rows
        report['corridor_static_prepared'] = True
        if reference:
            old = corridor_rows(reference)
            report['corridor_static_differences'] = base.differences(
                {r: old[r]['common'] for r in old}, {r: rows[r]['common'] for r in rows})
            report['corridor_static_equal'] = not report['corridor_static_differences']
            if not report['corridor_static_equal']:
                report.update(passed=False, attribution_allowed=False)
        report['geometry_is_not_performance_pass'] = True
    except (AssertionError, KeyError, OSError, ValueError) as error:
        report.update(passed=False, attribution_allowed=False, corridor_error=str(error))
    return report
