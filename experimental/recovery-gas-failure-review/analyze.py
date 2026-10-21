"""Read-only extraction for gas run 4733dbf4b4; never changes its verdict."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOD = HERE.parents[1]
RUN = MOD / 'build/cooperation/4733dbf4b4'
RESULT = MOD / 'build/m52/recovery-gas-native-01'
VERIFIER = MOD / 'experimental/recovery-gas-native-tests/verify_results.py'
spec = importlib.util.spec_from_file_location('gas_verifier_readonly', VERIFIER)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
cases, _ = v.read_cases(RUN / 'host.log', RUN / 'join.log')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(VERIFIER) == '476bb819ffaa83293e54c7b0850275da8580a0451de68a46087fac3a9b0b0f20'

def ordered_candidates(display, wires):
    """Classify poses separately from metadata/end. Does not grant a pass."""
    out = []
    for wire in wires:
        indices = []
        cursor = 0
        for sample in display['samples']:
            match = next((i for i in range(cursor, len(wire['frames']))
                          if v.pose_match(sample, wire['frames'][i])), None)
            if match is None:
                break
            indices.append(match)
            cursor = match
        else:
            out.append((wire, indices))
    return out

output = {'run': '4733dbf4b4', 'read_only_review': True,
          'original_native_pass': False, 'original_analysis_pass': False,
          'performance_qualified': False, 'rounds': [], 'metadata': [], 'inputs': {}}
for (role, n), value in cases.items():
    p = value['proof']
    pixel = p['pixel']
    samples = [s for r in p['visualRows'] if r['id'] == pixel['visual']
               for s in r['samples'] if s['frame'] == pixel['frame']]
    output['metadata'].append(dict(role=role, round=n,
        birth_mismatches=[dict(id=r['id'], born=r['bornAt'], first=r['samples'][0]['at'],
                              same_frame=r['bornFrame'] == r['samples'][0]['frame'])
                          for r in p['visualRows'] if r['bornAt'] != r['samples'][0]['at']],
        pixel_sample_at=pixel['sampleAt'],
        same_frame_final_at=[s['at'] for s in samples],
        same_frame_pose_equal=len(samples) == 1 and v.pose_match(samples[0], pixel['pose']),
        draw_ms=pixel['drawMs']))

for n in (0, 1):
    origin = cases[('host' if n == 0 else 'join', n)]['proof']
    remote = cases[('join' if n == 0 else 'host', n)]['proof']
    records = []
    for native in origin['nativeRows']:
        source_visual = next(r for r in origin['visualRows'] if r['id'] == native['visual'])
        wires = [w for w in remote['wireRows'] if v.source_match(native, source_visual, w)]
        assert len(wires) == 1
        wire = wires[0]
        displays = [(r, indices) for r in remote['visualRows']
                    for w, indices in ordered_candidates(r, remote['wireRows']) if w is wire]
        assert len(displays) == 1
        display, indices = displays[0]
        tail_equal = v.pose_match(display['samples'][-1], wire['frames'][-1])
        records.append(dict(source_id=native['id'], wire=wire['key'], display_id=display['id'],
            source_to_receive_ms=wire['firstWall'] - native['bornWall'],
            receive_to_display_ms=display['bornWall'] - wire['firstWall'],
            source_lifetime_ms=native['endAt'] - native['bornAt'],
            observed_display_lifetime_ms=display['endAt'] - display['bornAt'],
            ordered_pose_match_unique=True, source_to_wire_exact_history_unique=True,
            source_samples=len(wire['frames']), display_samples=len(display['samples']),
            first_source_index=indices[0], last_source_index=indices[-1],
            final_source_pose_observed=tail_equal,
            last_source_frame_to_end_ms=wire['end'] - wire['frames'][-1]['at'],
            last_display_to_removed_ms=display['endAt'] - display['samples'][-1]['at'],
            terminal_received_to_removed_ms=display['endWall'] - wire['endReceivedWall'],
            source_final_alpha=wire['frames'][-1]['a'], display_final_alpha=display['samples'][-1]['a'],
            max_display_sample_gap_ms=max(b['at']-a['at'] for a,b in zip(display['samples'],display['samples'][1:]))))
    output['rounds'].append(dict(round=n, source='host' if n == 0 else 'join', records=records))

paths = [RESULT/'result.json', RESULT/'intent.json', RESULT/'gas-verification.json',
         RUN/'host.log', RUN/'join.log', VERIFIER,
         MOD/'build/m52/recovery-gas-driver-01/tests/GasPulseNativeTestDoc.as',
         MOD/'build/m52/recovery-gas-driver-01/tests/GasPulseProbe.as',
         MOD/'build/m52/recovery-gas-driver-01/drivers/GasPulseNativeTestDoc/EffectsDriver.swf',
         MOD/'build/m52/recovery-13/RConnectMod.swf']
for name in ['EnergyImpactVisuals', 'ProjectileFrameStream', 'RemoteMotion', 'GameBridge']:
    paths.append(MOD/f'build/m52/recovery-13/src/rconnect/game/{name}.as')
for p in paths:
    if p.is_file(): output['inputs'][str(p.relative_to(MOD)).replace('\\','/')] = sha(p)
(HERE/'summary.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'rounds': len(output['rounds']), 'records': sum(len(r['records']) for r in output['rounds']),
                  'birth_mismatches': sum(len(r['birth_mismatches']) for r in output['metadata']),
                  'pixel_same_frame_poses_equal': [r['same_frame_pose_equal'] for r in output['metadata']],
                  'original_verdict_retained': 'FAIL'}, ensure_ascii=False))
