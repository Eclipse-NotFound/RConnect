"""Read only the two completed eight-pause runs; emit no full trace."""
from pathlib import Path
import hashlib,json,re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUNS=[('22','recovery22-native-pause-control-01','b09eac8fb3'),
      ('23','recovery23-native-pause-comparison-01','4582357f26')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text('utf-8-sig'))
def tagged(lines,prefix):return [(i,json.loads(s[len(prefix):])) for i,s in enumerate(lines) if s.startswith(prefix)]

def one(version,outer_name,run_id):
    outer=ROOT/'build/m52'/outer_name;folder=ROOT/'build/cooperation'/run_id
    result,intent,run,inputs=[read(p) for p in [outer/'result.json',outer/'intent.json',folder/'run.json',folder/'input.json']]
    assert result['run']==run_id and result['passed'] and result['exit_code']==0
    lines=(folder/'join.log').read_text('utf-8-sig').splitlines()
    host=(folder/'host.log').read_text('utf-8-sig').splitlines()
    timelines=tagged(lines,'A22 ENEMY TIMELINE ');timings=tagged(lines,'A22 PAUSE TIMING ')
    endings=tagged(lines,'CONTINUITY PAUSE ');pixels=tagged(lines,'A22 SATS PIXELS ')
    assert len(timelines)==len(timings)==len(endings)==len(pixels)==8
    source_frames=[int(s.rsplit('=',1)[1]) for s in host if 'source enemy was moving before pause frames=' in s]
    assert len(source_frames)==8
    poses=[]
    for i,s in enumerate(lines):
        marker='COOP PASS continuity SATS native body phase matches authority source='
        if s.startswith(marker):
            tail=s[len(marker):];source,offset=json.JSONDecoder().raw_decode(tail)
            assert tail[offset:].startswith(' display=')
            display=json.loads(tail[offset+len(' display='):]);poses.append((i,source,display))
    assert len(poses)==8
    rounds=[]
    for n,((tl_line,tl),(pa_line,pa),(end_line,end),(px_line,px),(pose_line,source_pose,display_pose)) in enumerate(zip(timelines,timings,endings,pixels,poses),1):
        trace=tl['trace'];first_index=next(i for i,s in enumerate(trace) if s['paused'])
        first=trace[first_index];endpoint=end['endpoint']
        settled=next(s for s in trace[first_index:] if abs(s['x']-endpoint)<=1)
        render=next((s for s in pa if s['kind']=='render-observed' and s['at']==first['t']),None)
        begin=next((s for s in pa if render is not None and s['frame']==render['frame'] and s['kind']=='enter-begin'),None)
        measured=None
        if begin:
            measured=dict(start_at=begin['at'],end_at=render['at'],frame=render['frame'],elapsed_ms=render['at']-begin['at'],
                view_ms=render['viewMs']-begin['viewMs'],motion_ms=render['motionMs']-begin['motionMs'],
                view_calls=render['viewCalls']-begin['viewCalls'],motion_calls=render['motionCalls']-begin['motionCalls'])
        check=dict(buffer_coverage=len(tl['bufferFrames'])>=8,p90_le_4=tl['p90']<=4,
            confirmed_settle_le_100=0<=tl['settleMs']<=100,body_distinct_ge_8=tl['bodyFrames']>=8,
            no_body_backsteps=tl['bodyBacksteps']==0,
            authority_body_phase=abs(source_pose['blit']['f']-display_pose['blit']['f'])<.01,
            paused_position=abs(end['pausedX']-endpoint)<=1,bitmap_equal=type(px['comparison']) is int and px['comparison']==0,
            bitmap_bounds_equal=px['actual']==px['expected'],resume_jump_le_4=end['resumeJump']<=4)
        assert all(check.values())
        rounds.append(dict(round=n,line_indices=dict(timeline=tl_line,timing=pa_line,ending=end_line,pixels=px_line,pose=pose_line),
            source_moving_frames=source_frames[n-1],trace_count=len(trace),endpoint=endpoint,
            first_paused=dict(index=first_index,**first),first_observed_endpoint=settled,
            observed_pause_to_endpoint_ms=settled['t']-first['t'],initial_visual_gap=abs(first['x']-endpoint),
            preceding_sample_gap_ms=first['t']-trace[first_index-1]['t'] if first_index else None,
            confirmed_endpoint_settle_ms=tl['settleMs'],confirmed_endpoint_initial_gap=tl['initialPauseGap'],
            buffered_frames_count=len(tl['bufferFrames']),buffered_frames_p90=tl['p90'],
            body_distinct=tl['bodyFrames'],body_backsteps=tl['bodyBacksteps'],
            authority_body_f=source_pose['blit']['f'],display_body_f=display_pose['blit']['f'],
            paused_x=end['pausedX'],resume_jump=end['resumeJump'],bitmap_comparison=px['comparison'],
            maximum_trace_gap_ms=max(b['t']-a['t'] for a,b in zip(trace,trace[1:])),
            retained_pause_timing_start=pa[0]['at'],retained_pause_timing_rows=len(pa),
            first_paused_enter_to_render=measured,original_metric_checks=check))
    error_pattern=re.compile(r'\bERROR\b|\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b')
    module_errors={}
    for p in (folder/'module-logs').rglob('*.log'):
        found=[i for i,s in enumerate(p.read_text('utf-8-sig',errors='replace').splitlines()) if error_pattern.search(s)]
        if found:module_errors[p.relative_to(folder).as_posix()]=found
    assert not module_errors
    paths=[outer/'result.json',outer/'intent.json',folder/'run.json',folder/'input.json',folder/'host.log',folder/'join.log']
    return dict(version=version,run=run_id,candidate_sha256=intent['candidate_sha256'],
        driver_sha256=run['inputs']['join']['driver'],driver_manifest=intent['driver_manifest'],
        hashes={str(p.relative_to(ROOT)):sha(p) for p in paths},
        checks={r:dict(passed=result['roles'][r]['checks'],errors=result['roles'][r]['errors'],done=result['roles'][r]['done']) for r in ('host','join')},
        wrapper_passed=result['passed'],installation_fingerprint_count=len(intent['installation']),
        verified_flags={k:result[k] for k in ['installation_unchanged','runner_unchanged','air_inventory_unchanged','exclusive_air_confirmed',
            'process_policy_confirmed','vision_templates_confirmed','vision_templates_unchanged','same_runtime_as_reference']},
        process_policy={r:read(folder/(r+'.process-policy.json')) for r in ('host','join')},
        installation=intent['installation'],runtime_inputs=run['inputs'],
        fixture_ambient_removed=int(next(s.rsplit('=',1)[1] for s in host if s.startswith('CONTINUITY FIXTURE ambient foes removed='))),
        rounds=rounds,performance_qualified=False,attribution_allowed=False,
        comparison_inputs={k:intent[k] for k in ['driver_manifest','wrapper_sha256','runner_sha256','air_inventory_sha256','vision_config_templates','process_policy_expected']})

def main():
    a,b=[one(*args) for args in RUNS]
    equal_inputs=a['comparison_inputs']==b['comparison_inputs']
    runtime_equal=all({k:v for k,v in a['runtime_inputs'][r].items() if k!='production'}==
                      {k:v for k,v in b['runtime_inputs'][r].items() if k!='production'} for r in ('host','join'))
    assert equal_inputs and runtime_equal and a['installation']==b['installation']
    for d in [a,b]:del d['runtime_inputs'];del d['installation']
    legacy=ROOT/'build/m52/recovery22-formal-pause-timing-01/result.json';old=read(legacy)
    out=dict(runs=[a,b],equal_declared_inputs=equal_inputs,equal_runtime_except_production=runtime_equal,
        equal_installation=True,single_sequential_pair=True,strict_dynamic_scene_identity=False,
        native_functional_pass=True,smoothness_qualified=False,global_performance_benefit_proven=False,
        legacy=dict(run=old['run'],wrapper_passed=old['passed'],result_sha256=sha(legacy),
            note='Unowned NativeTestGun fixture; FirearmAttachments #1009 preserved, cause not established.'),
        limitations=['First-paused rows are game-frame-deduplicated RENDER observations, not keydown time.',
            'Confirmed endpoint is a separate test message; not the first worldstate arrival.',
            'pauseTiming retains only the latest 220 rows; missing onset frames are not reconstructed.',
            'No host flush duration probe or per-broadcast trace; joining frame spans cannot identify host capture cost.',
            'All declarations and runtime inputs match except candidate; process scheduling and dynamic preparation differ.'])
    (HERE/'summary.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'native_functional_pass':True,'equal_runtime_except_production':True,
        'observed_pause_to_endpoint':{d['version']:[r['observed_pause_to_endpoint_ms'] for r in d['rounds']] for d in [a,b]},
        'performance_qualified':False},ensure_ascii=False))
if __name__=='__main__':main()
