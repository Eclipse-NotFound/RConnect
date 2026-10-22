"""World-coordinate native mark and displayed-front comparison; no AIR."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

CASES = [('lmg', 'host', 1), ('lmg', 'join', 1), ('plamg', 'host', 8), ('plamg', 'join', 8)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def delta(before, after):
    assert len(before) == len(after) == 128 * 128
    return {i: n for i, n in enumerate(after) if n != before[i]}


def pairs(words):
    assert isinstance(words, list) and len(words) % 2 == 0
    out = {}
    last = -1
    for i, value in zip(words[::2], words[1::2]):
        assert isinstance(i, int) and last < i < 128 * 128, 'Unsorted/duplicate/invalid world-crop pixel'
        assert isinstance(value, int) and 0 <= value <= 0xffffffff
        out[i] = value
        last = i
    return out


def png_words(path):
    with Image.open(path) as image:
        assert image.size == (128, 128) and image.format == 'PNG'
        return [(a << 24) | (r << 16) | (g << 8) | b for r, g, b, a in image.convert('RGBA').getdata()]


def first_frame(row, channel, expected, complete=False):
    last_at = -1
    first = None
    for frame in row['frames']:
        assert frame['at'] >= last_at and row['start'] <= frame['at'] <= row['end']
        last_at = frame['at']
        actual = pairs(frame[channel])
        matches = actual == expected if complete else any(actual.get(i) == v for i, v in expected.items())
        if complete and first is not None:
            assert matches, 'Persistent mark disappears/changes after complete presentation'
        if matches and first is None:first=frame['wall']
    return first


def compare(source, remote):
    """Strict native final pixels; visual front evidence is separate from Part."""
    assert source['source'] is True and remote['source'] is False
    assert source['round'] == remote['round']
    weapon, role, count = CASES[source['round']]
    assert source['role'] == role and remote['role'] != role and source['weapon'] == remote['weapon'] == weapon
    assert source['area'] == remote['area'] and source['target'] == remote['target']
    target = source['target']
    assert target['x'] > 1920 or target['y'] > 1000
    assert source['baseline'] == remote['baseline'], 'Native pre-shot world pixels differ'
    assert source['baselineDisplay'] == remote['baselineDisplay'], 'Displayed-front baseline differs; not a qualified comparison'
    assert source['shots'] >= count and len(source['hits']) >= count
    assert source['attackAttempts'] >= source['attackAccepted'] > 0, 'No accepted native attack attempt'
    assert source['firstAttack']['accepted'] is True, 'First native attempt was rejected; fixture was not ready'
    for hit in source['hits']:
        assert hit['x'] > 1920 or hit['y'] > 1000, 'Actual collision did not cross old limit'
        assert abs(hit['x'] - target['x']) <= 64 and abs(hit['y'] - target['y']) <= 64, 'Hit missed target crop'
    expected = pairs(source['nativeOracle'])
    assert len(expected) >= 5, 'No substantive native persistent mark'
    assert expected == delta(source['baseline'], source['finalNative']), 'Non-native or unobserved final changes entered source oracle'
    native_actual = delta(remote['baseline'], remote['finalNative'])
    visual_expected = delta(source['baselineDisplay'], source['finalDisplay'])
    assert visual_expected, 'Native mark did not alter real displayed front layer'
    visual_actual = delta(remote['baselineDisplay'], remote['finalDisplay'])
    native_first = first_frame(remote, 'native', expected)
    display_first = first_frame(remote, 'display', visual_expected)
    native_all = first_frame(remote, 'native', expected, True)
    display_all = first_frame(remote, 'display', visual_expected, True)
    assert source['sourceFirst'] >= source['startWall'] > 0
    for row in (source, remote):
        assert 2 <= len(row['frames']) <= 480 and row['end'] - row['start'] >= 10000
        assert row['surfaces'] and row['finalSurfaces']
        assert all(x['scratchDifferent'] and x['staged'] for x in row['surfaces'] + row['finalSurfaces'])
        assert all(x['width'] == x['side'] + 2*x['gutter'] and x['height'] == x['width'] for x in row['surfaces'])
    return dict(round=source['round'], weapon=weapon, source=role, target=target,
        native_equal=expected == native_actual, display_equal=visual_expected == visual_actual,
        native_expected=len(expected), native_wrong=sum(native_actual.get(i) != v for i, v in expected.items()),
        native_extra=sum(i not in expected for i in native_actual), display_expected=len(visual_expected),
        source_native_observed_wall=source['sourceFirst'], remote_native_first_wall=native_first,
        source_native_interval_before_wall=source.get('sourceFirstBefore'),
        remote_display_first_wall=display_first, remote_native_complete_wall=native_all,
        remote_display_complete_wall=display_all,
        native_first_delay_ms=None if native_first is None else native_first-source['sourceFirst'],
        display_first_delay_ms=None if display_first is None else display_first-source['sourceFirst'],
        capture_max_ms={source['role']:source['maxCaptureMs'],remote['role']:remote['maxCaptureMs']},
        maximum_observation_gap_ms={row['role']:max(b['wall']-a['wall'] for a,b in zip(row['frames'],row['frames'][1:])) for row in (source,remote)},
        functional_pass=expected == native_actual and visual_expected == visual_actual
            and None not in (native_first, display_first, native_all, display_all),
        performance_qualified=False)


def analyze(root, logs):
    result = dict(passed=False, functional_only=True, performance_qualified=False, rows=[], errors=[], artifacts={})
    data = {}
    for role in ('host', 'join'):
        text = Path(logs[role]).read_text(encoding='utf-8-sig', errors='replace')
        proof_rows = [json.loads(line.split('LARGE WALL PROOF ', 1)[1]) for line in text.splitlines() if line.startswith('LARGE WALL PROOF ')]
        try:
            assert len(proof_rows) == 4 and sorted(p['round'] for p in proof_rows) == list(range(4)), 'Missing or duplicate proof log'
            for n in range(4):
                file = root / role / f'round-{n}-proof.json'
                row = read(file); receipt = next(p for p in proof_rows if p['round'] == n)
                assert row['role'] == receipt['role'] == role and row['round'] == n
                assert row['target'] == receipt['target'] and row['shots'] == receipt['shots']
                assert row['source'] == receipt['source'] and len(row['hits']) == receipt['hits']
                for name in ('attackAttempts', 'attackAccepted', 'firstAttack', 'firstRejected'):
                    assert row[name] == receipt[name], 'Attack diagnostics differ from proof log: ' + name
                assert len(row['frames']) == receipt['samples'] and len(row['nativeOracle'])//2 == receipt['nativePixels']
                assert row['sourceFirst'] == receipt['sourceFirst'] and file.stat().st_size == receipt['bytes']
                result['artifacts'][str(file.relative_to(root))] = sha(file)
                assert len(receipt['files']) == 4
                for suffix, field in [('before-native','baseline'),('after-native','finalNative'),
                                      ('before-display','baselineDisplay'),('after-display','finalDisplay')]:
                    png = root / role / f'round-{n}-{suffix}.png'
                    matching = [p for p in receipt['files'] if p['name'] == png.name]
                    assert len(matching) == 1 and matching[0]['bytes'] == png.stat().st_size
                    assert matching[0]['width'] == matching[0]['height'] == 128
                    assert png_words(png) == row[field], 'PNG does not contain corresponding real crop: ' + png.name
                    result['artifacts'][str(png.relative_to(root))] = sha(png)
                data[role, n] = row
        except (AssertionError, KeyError, OSError, ValueError) as error:
            result['errors'].append(role + ': ' + str(error))
    for n, (_, role, _) in enumerate(CASES):
        try:
            row = compare(data[role,n], data['join' if role=='host' else 'host',n]);result['rows'].append(row)
            if not row['functional_pass']:result['errors'].append(f'case {n}: persistent native/display pixels did not arrive exactly')
        except (AssertionError, KeyError, ValueError) as error:result['errors'].append(f'case {n}: {error}')
    result['passed'] = len(result['rows']) == 4 and not result['errors']
    return result


if __name__ == '__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--run',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args();assert not a.output.exists();r=analyze(a.proof,{role:a.run/(role+'.log') for role in ('host','join')})
    a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');raise SystemExit(0 if r['passed'] else 1)
