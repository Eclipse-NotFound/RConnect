"""Bounded read-only review of completed c463d3510f; no simulation or qualification."""
from pathlib import Path
import hashlib,json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
FOLDER=ROOT/'build/cooperation/c463d3510f'
OUTER=ROOT/'build/m52/recovery-drop-observer-native-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text('utf-8-sig'))

def role_summary(role):
    path=FOLDER/(role+'.log');lines=path.read_text('utf-8-sig').splitlines()
    indexed=[(i,json.loads(s.split('DROP RENDER OBSERVER ',1)[1])) for i,s in enumerate(lines) if 'DROP RENDER OBSERVER ' in s]
    assert len(indexed)==1
    line,doc=indexed[0];rows=doc['rows']
    assert doc['complete'] and not doc['fault'] and not doc['overflow']
    render=[(i,x) for i,x in enumerate(rows) if x['kind']=='render']
    wire=[(i,x) for i,x in enumerate(rows) if x['kind']=='loot']
    enters=[(i,x) for i,x in enumerate(rows) if x['kind']=='enter']
    assert all(x['sameVisual'] and x['attached'] and x['visible'] and x['alpha']==1 for _,x in render)
    def largest(predicate):
        pairs=[(b['at']-a['at'],i,a,j,b) for (i,a),(j,b) in zip(render,render[1:]) if predicate(a,b)]
        span,i,a,j,b=max(pairs,key=lambda r:r[0])
        return dict(ms=span,raw_indices=[i,j],start=a,end=b,
            inside=[dict(raw_index=n,**r) for n,r in enumerate(rows) if a['at']<r['at']<b['at']])
    frames={};extra=[]
    for index,row in render:
        if row['frame'] in frames:
            first_index,first=frames[row['frame']]
            extra.append(dict(index=index,first_index=first_index,dt=row['at']-first['at'],
                changed_visual=(first['x'],first['y'])!=(row['x'],row['y']),
                changed_logical=(first['logicalX'],first['logicalY'])!=(row['logicalX'],row['logicalY'])))
        else:frames[row['frame']]=(index,row)
    air=[x for _,x in render if not x['stay']]
    land=next(x for _,x in render if x['stay'])
    cross_frame_air_repeats=[dict(start=a['at'],end=b['at']) for (_,a),(_,b) in zip(render,render[1:])
        if not a['stay'] and not b['stay'] and a['frame']!=b['frame'] and (a['x'],a['y'])==(b['x'],b['y'])]
    wire_summary=None
    if wire:
        wl=[x for _,x in wire]
        first_stay=next(x for x in wl if x['stay'])
        assert len(set(x['key'] for x in wl))==1
        wire_summary=dict(count=len(wl),air_count=sum(not x['stay'] for x in wl),stay_count=sum(x['stay'] for x in wl),
            key=wl[0]['key'],first_at=wl[0]['at'],last_at=wl[-1]['at'],
            arrival_gaps_ms=[b['at']-a['at'] for a,b in zip(wl,wl[1:])],
            source_sample_gaps_ms=[b['sampleTime']-a['sampleTime'] for a,b in zip(wl,wl[1:])],
            maximum_air_to_air_arrival_gap_ms=max(b['at']-a['at'] for a,b in zip(wl,wl[1:]) if not a['stay'] and not b['stay']),
            first_stay_packet=first_stay,first_local_stay_render=land,
            first_stay_packet_to_local_stay_ms=land['at']-first_stay['at'],
            arrival_to_next_render_ms=[min(x['at'] for _,x in render if x['at']>=r['at'])-r['at'] for r in wl])
    return dict(role=role,log_sha256=sha(path),observer_log_line_index=line,
        diagnostic_complete=doc['complete'],start=doc['start'],deadline=doc['deadline'],closed_at=doc['closedObservedAt'],export_at=doc['exportAt'],
        total_rows=len(rows),render_count=len(render),enter_count=len(enters),wire_count=len(wire),
        air_render_records=len(air),air_game_frames=len(set(x['frame'] for x in air)),
        first_landed_render=land,largest_air_to_air_gap=largest(lambda a,b:not a['stay'] and not b['stay']),
        largest_gap_touching_air=largest(lambda a,b:not a['stay'] or not b['stay']),
        largest_landed_gap=largest(lambda a,b:a['stay'] and b['stay']),
        extra_same_frame_renders=len(extra),extra_renders_with_new_visual=sum(x['changed_visual'] for x in extra),
        extra_renders_with_new_logical=sum(x['changed_logical'] for x in extra),maximum_extra_render_delta_ms=max(x['dt'] for x in extra),
        cross_frame_air_equal_positions=cross_frame_air_repeats,wire=wire_summary)

def main():
    result=read(OUTER/'result.json');run=read(FOLDER/'run.json')
    assert result['run']=='c463d3510f' and result['passed']
    classes=['rconnect/game/GameBridge.as','rconnect/game/RemoteMotion.as','rconnect/game/UnitPresentation.as','rconnect/game/RemoteLoot.as']
    same={name:sha(ROOT/'build/m52/recovery-23/src'/name) for name in classes}
    assert all(sha(ROOT/'build/m52/recovery-22/src'/name)==digest for name,digest in same.items())
    out=dict(run=result['run'],candidate_sha256=run['inputs']['join']['production'],driver_sha256=run['inputs']['join']['driver'],
        native_functional_pass=result['passed'],checks={r:result['roles'][r]['checks'] for r in ('host','join')},
        input_checks={k:result[k] for k in ['installation_unchanged','exclusive_air_confirmed','process_policy_confirmed','vision_templates_confirmed']},
        hashes={str(p.relative_to(ROOT)):sha(p) for p in [OUTER/'result.json',OUTER/'observer-summary.json',FOLDER/'run.json',FOLDER/'input.json']},
        equal_22_23_motion_classes=same,roles={r:role_summary(r) for r in ('host','join')},
        old_160ms_air_gap_reproduced=False,smoothness_qualified=False,fps_qualification=False,
        conclusions_limited_to_this_window=True)
    (HERE/'summary.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'run':out['run'],'native_functional_pass':out['native_functional_pass'],
        'air_max_render_gap_ms':{r:v['largest_air_to_air_gap']['ms'] for r,v in out['roles'].items()},
        'extra_new_positions':{r:v['extra_renders_with_new_visual'] for r,v in out['roles'].items()},
        'smoothness_qualified':False}))
if __name__=='__main__':main()
