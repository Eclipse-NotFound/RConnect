"""Replay actual received melee histories. No invented source frames or AIR/JVM."""
from pathlib import Path
import copy
import hashlib
import json
import math

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1]/'build/cooperation/b49865e3c1/logs/join/stutter-result.json'

def suffix(packet, cache):
    history = packet['melee']
    frames = history['frames']
    stamp = packet['stamp']
    if stamp != cache.get('stamp'):
        cache['from'] = cache.get('to')
        cache['stamp'] = stamp
    first = 0
    cutoff = cache.get('from')
    if cutoff is not None:
        while first+1 < len(frames) and frames[first+1]['at'] <= cutoff:
            first += 1
    cache['to'] = frames[-1]['at']
    return dict(history, frames=frames[first:])

def blend(a, b, t):
    if a is None or b is None:
        return a
    p = dict(a)
    p['x'] = a['x']+(b['x']-a['x'])*t
    p['y'] = a['y']+(b['y']-a['y'])*t
    angle = b['r']-a['r']
    while angle > math.pi:
        angle -= math.pi*2
    while angle < -math.pi:
        angle += math.pi*2
    p['r'] = a['r']+angle*t
    return p

def sample(history, time):
    frames = history['frames']
    a = b = frames[0]
    for point in frames:
        if point['at'] > time:
            b = point
            break
        a = b = point
    span = b['at']-a['at']
    t = max(0, min(1, (time-a['at'])/span)) if span > 0 else 0
    return dict(weapon=blend(a['weapon'], b['weapon'], t),
                trail=blend(a['trail'], b['trail'], t), bodyAlpha=a['bodyAlpha'])

def cases(records, interval=0, include_full=True):
    previous = None
    selected = []
    for packet in records:
        if packet['stream'] == 'units':
            if include_full:
                selected.append(packet)
        elif previous is None or packet['stamp'] == previous or packet['stamp']-previous >= interval:
            selected.append(packet)
            previous = packet['stamp']
    return selected

def replay(records):
    cache = {}
    last_stamp = preceding = None
    previous_full = None
    checks = mismatches = original_count = suffix_count = 0
    original_json = suffix_json = stale = same_stamp = same_stamp_updates = 0
    mismatched = []
    for packet in records:
        history = packet['melee']
        before = json.dumps(history, sort_keys=True, separators=(',', ':'))
        candidate = suffix(packet, cache) if packet['stream'] == 'enemyMotion' else history
        if packet['stream'] == 'enemyMotion':
            original_count += len(history['frames'])
            suffix_count += len(candidate['frames'])
            original_json += len(before)
            suffix_json += len(json.dumps(candidate, sort_keys=True, separators=(',', ':')))
        stamp = packet['stamp']
        if last_stamp is not None and stamp < last_stamp:
            stale += 1
            continue
        if stamp == last_stamp:
            same_stamp += 1
            if previous_full != history:
                same_stamp_updates += 1
        else:
            preceding = last_stamp
        # The first sample has no older pose to interpolate from. Its before-
        # first behavior must also match; subsequent b histories cover [a,b].
        start = preceding if preceding is not None else history['frames'][0]['at']-100
        for cursor in [start+i*.5 for i in range(int((stamp-start)*2)+1)]:
            checks += 1
            if sample(history, cursor) != sample(candidate, cursor):
                mismatches += 1
                if len(mismatched) < 5:
                    mismatched.append({'source_stamp':stamp,'cursor':cursor,'stream':packet['stream'],
                                       'suffix_first':candidate['frames'][0]['at'],'cache':dict(cache)})
        assert json.dumps(history, sort_keys=True, separators=(',', ':')) == before
        previous_full = history
        last_stamp = stamp
    return {'packets':len(records),'cursor_checks_half_ms':checks,'mismatches':mismatches,
            'first_mismatches':mismatched,'same_source_stamp_packets':same_stamp,
            'same_stamp_history_updates':same_stamp_updates,'stale_ignored':stale,
            'fast_original_frame_instances':original_count,'fast_suffix_frame_instances':suffix_count,
            'fast_original_json_chars_proxy':original_json,'fast_suffix_json_chars_proxy':suffix_json,
            'boundary':'JSON character count is offline volume proxy; actual TCP uses the binary codec.'}

def main():
    data = json.loads(SOURCE.read_text(encoding='utf-8-sig'))
    results = {}
    for ident in ('weaponpose_club','weaponpose_laser'):
        records = [p for p in data['wire'] if p['id']==ident and p.get('meleeCount',0)>0]
        results[ident] = {
            'actual_full_fast_interleaved':replay(cases(records)),
            'actual_fast_only':replay(cases(records,include_full=False)),
            'actual_frames_sent_133ms':replay(cases(records,133)),
            'actual_frames_sent_250ms':replay(cases(records,250))}
    result = {'source':str(SOURCE),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'scope':'Actual b49865e3c1 histories; slower-send cases retain actual frames but decimate sends, not a new runtime benchmark.',
              'results':results}
    output=HERE/'analysis/melee-suffix-equivalence.json'
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
