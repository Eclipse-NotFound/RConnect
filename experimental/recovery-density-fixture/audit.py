"""Read-only native scene comparison. Never reclassifies original failed checks."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from prepare import ROOT, M52, read, sha, save


def normalize(value):
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [normalize(v) for v in value]
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def canonical(value):
    return json.dumps(normalize(value), ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def adler_utf16(value):
    data = canonical(value).encode('utf-16-le')
    a, b = 1, 0
    for i in range(0, len(data), 2):
        a = (a + data[i] + 256 * data[i+1]) % 65521
        b = (b + a) % 65521
    return format((b << 16) | a, 'x')


def prefixed(text, prefix):
    return [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]


def scene(out):
    result = read(out / 'result.json')
    assert result.get('run'), 'No native run; no scene evidence'
    folder = ROOT / 'build/cooperation' / result['run']
    roles, errors = {}, []
    for role in ('host', 'join'):
        text = (folder / (role + '.log')).read_text(encoding='utf-8-sig', errors='replace')
        rows, inputs = prefixed(text, 'DENSITY FIXTURE '), prefixed(text, 'DENSITY INPUTS ')
        assert len(rows) == len(inputs) == 1, role + ': expected exactly one frozen preparation summary'
        row, inp = rows[0], inputs[0]
        assert row['schema'] == 1 and row['role'] == role
        cells = []
        for cell in inp['cells']:
            item = {k: v for k, v in cell.items() if k != 'visi'}
            for key, value in item.items():
                if isinstance(value, dict) and 'referenceClass' in value:
                    item[key] = dict(value)
                    item[key]['cls'] = item[key].pop('referenceClass')
            cells.append(item)
        prepared = row['prepared']
        assert adler_utf16(cells) == prepared['tileHash'], role + ': tile summary does not match actual map input'
        tile_sha = hashlib.sha256(canonical(cells).encode('utf-8')).hexdigest()
        actors = prepared['actors']
        counts, guns = {}, {}
        for actor in actors:
            counts[actor['cls']] = counts.get(actor['cls'], 0) + 1
            if actor['weapon']:
                gun = actor['weapon']['id']
                guns[gun] = guns.get(gun, 0) + 1
        assert counts == {'fe.unit::UnitZombie': 1, 'fe.unit::UnitBat': 40, 'fe.unit::UnitSlaver': 39}, (role, counts)
        assert guns.get('lmg') == 12 and guns.get('p308c') == 27, (role, guns)
        assert len(set(row['keys'])) == 80
        assert abs(prepared['player']['X'] - 161.8) < .001 and prepared['player']['Y'] == 960
        assert prepared['player']['storona'] == 1 and prepared['camera']['camera']['isZoom'] == 2
        checks = ['density fixed 80 native bodies, weapon roster, player spawn and peer position verified',
                  'density actual camera/player/roster stable before timing']
        checks += ['density both actual spawn/direction/camera/80-body rosters agree'] if role == 'host' else [
            'density commit still matches actual roster/spawn/camera']
        for check in checks:
            assert 'COOP PASS network-state ' + check in text, (role, check)
        for p in sorted((folder / 'module-logs' / role).glob('*.log')):
            module = p.read_text(encoding='utf-8-sig', errors='replace')
            for line in module.splitlines():
                if re.search(r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory|ERROR)\b', line, re.I):
                    errors.append({'role': role, 'log': p.name, 'line': line[:700]})
        comparable = dict(prepared)
        comparable['tile_sha256'] = tile_sha
        comparable.pop('tileHashAlgorithm', None)
        comparable.pop('tileHash', None)
        roles[role] = dict(prepared=comparable, raw_spawn=row['rawSpawn'], removed=row['removed'],
            diagnostic=row['diagnostic'], enemy_types=counts, weapons=guns, tile_sha256=tile_sha,
            summary_sha256=hashlib.sha256(canonical(row).encode('utf-8')).hexdigest(),
            log_sha256=sha(folder / (role + '.log')),
            windows=len(re.findall(r'^COOP METRIC network-state ', text, re.M)) if role == 'join' else None,
            totals=prefixed(text, 'DENSITY TRAJECTORY TOTALS '))
    assert roles['host']['tile_sha256'] == roles['join']['tile_sha256'], 'Both instances have different native map tiles'
    return result, roles, errors


def differences(left, right, prefix=''):
    out = []
    if isinstance(left, dict) and isinstance(right, dict):
        for key in sorted(set(left) | set(right)):
            path = prefix + '/' + key
            if key not in left or key not in right:
                out.append(path + ': missing field')
            else:
                out.extend(differences(left[key], right[key], path))
    elif isinstance(left, list) and isinstance(right, list):
        if len(left) != len(right):
            out.append(prefix + ': lengths ' + str(len(left)) + ' / ' + str(len(right)))
        for i, (a, b) in enumerate(zip(left, right)):
            out.extend(differences(a, b, prefix + '/' + str(i)))
    elif left != right:
        out.append(prefix + ': ' + repr(left)[:100] + ' / ' + repr(right)[:100])
    return out


def audit(out, reference=None):
    report = dict(original_result_sha256=sha(out / 'result.json'), performance_qualified=False,
                  original_failures_preserved=True, input_comparable=False, attribution_allowed=False, passed=False)
    try:
        result, roles, errors = scene(out)
        report.update(roles=roles, module_errors=errors, native_passed=result['passed'],
                      diagnostic_only=any(r['diagnostic'] for r in roles.values()))
        valid = result.get('installation_unchanged') and result.get('runner_unchanged') and result.get('air_inventory_unchanged') \
            and result.get('exclusive_air_confirmed') and result.get('same_runtime_as_reference') and not errors
        assert roles['join']['windows'] == 7, 'All seven original measured windows are required'
        if reference:
            previous, old_roles, old_errors = scene(reference)
            mismatches = []
            for role in ('host', 'join'):
                mismatches += differences(old_roles[role]['prepared'], roles[role]['prepared'], '/' + role)
            same_driver = read(out / 'intent.json')['driver_manifest'] == read(reference / 'intent.json')['driver_manifest']
            same_runtime = result.get('runtime_signature') == previous.get('runtime_signature')
            report.update(reference=str(reference), reference_result_sha256=sha(reference / 'result.json'),
                differences=mismatches[:80], difference_count=len(mismatches), same_driver=same_driver,
                same_runtime=same_runtime,
                raw_spawn_differences={r: differences(old_roles[r]['raw_spawn'], roles[r]['raw_spawn']) for r in roles})
            report['input_comparable'] = not mismatches and same_driver and same_runtime and not old_errors
            report['attribution_allowed'] = bool(valid and report['input_comparable'] and not report['diagnostic_only']
                and not any(r['diagnostic'] for r in old_roles.values()) and old_roles['join']['windows'] == 7
                and previous.get('installation_unchanged') and previous.get('exclusive_air_confirmed'))
        else:
            report['baseline_only'] = True
        report['passed'] = bool(valid and result['passed'] and (reference is None or report['input_comparable']))
    except (AssertionError, KeyError, OSError, ValueError) as error:
        report['error'] = str(error)
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--reference', type=Path)
    a = p.parse_args()
    out = (ROOT / a.output).resolve()
    ref = (ROOT / a.reference).resolve() if a.reference else None
    assert out.parent == M52.resolve() and (ref is None or ref.parent == M52.resolve())
    target = out / 'fixture-audit.json'
    assert not target.exists(), 'Do not rewrite existing evidence'
    report = audit(out, ref)
    save(target, report)
    print(json.dumps({k: v for k, v in report.items() if k != 'roles'}, ensure_ascii=False))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
