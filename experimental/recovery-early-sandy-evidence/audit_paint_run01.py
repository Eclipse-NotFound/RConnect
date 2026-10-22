"""Read-only audit of incomplete diagnostic run 84ff2d9da3; no runtime."""
from pathlib import Path
import hashlib,json,re

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
RUN=ROOT/'build/cooperation/84ff2d9da3'
WRAPPER=ROOT/'build/m52/recovery-early-paint-dual-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def payloads(lines,prefix):
    return [(i,json.loads(s[len(prefix):])) for i,s in enumerate(lines,1) if s.startswith(prefix)]

def audit():
    result=json.loads((WRAPPER/'result.json').read_text(encoding='utf-8-sig'))
    assert result['run']=='84ff2d9da3' and not result['passed'] and not result['profile_valid']
    out={'run':result['run'],'passed':False,'profile_valid':False,'performance_qualified':False,
         'installation_unchanged':result['installation_unchanged'],'roles':{}}
    for role in ('host','join'):
        path=RUN/(role+'.log');lines=path.read_text(encoding='utf-8-sig').splitlines()
        assert sha(path)==result['roles'][role]['log_sha256']
        profiles=payloads(lines,'EARLY PAINT PROFILE ');assert len(profiles)==1
        line,profile=profiles[0];first=profile['rows'][0]
        offset=first['startedWall']-first['started']
        assert first['finished']>first['started'] and first['finishedWall']>first['startedWall']
        flags=['completed','sameWorld','sameGame','sameRenderer','sameLoc','sameRasterRoom',
               'worldRendererAtStart','worldRendererAtEnd','worldLocAtStart','worldLocAtEnd']
        assert all(first[k] for k in flags)
        drift=max(abs(row[k+'Wall']-row[k]-offset) for row in profile['rows'] for k in ('started','finished'))
        assert drift<=1 and profile['nativeFaults']==profile['faults']==0 and profile['ownershipPreserved']
        clock=payloads(lines,'TRAVEL CLOCK ')[0][1]
        early={}
        for i,s in enumerate(lines,1):
            m=re.search(r'RConnectEarly: (constructed|ready|activated).*t=(\d+)',s)
            if m:early[m[1]]={'line':i,'local_ms':int(m[2]),'wall_estimate':offset+int(m[2])}
        receives=[dict(line=i,operation=p['op'],start=p['from'],end=p['at'],duration=p['ms'],
                       wall_start_estimate=offset+p['from'],wall_end_estimate=offset+p['at'])
                  for i,p in payloads(lines,'A22 ROOM RECEIVE ') if p.get('barrier')==2]
        gaps=[dict(line=i,start=p['from'],end=p['at'],duration=p['ms'])
              for i,p in payloads(lines,'A22 ROOM FRAME GAP ') if p['from']>=clock['started']]
        row={'log_sha256':sha(path),'checks':result['roles'][role]['checks'],
             'errors':result['roles'][role]['errors'],'completed_travel_rows':len(result['roles'][role]['rows']),
             'paint_profile_line':line,'profile':{k:profile[k] for k in ('observedCalls','positiveMsCalls','targetRows','overflow','observationComplete','faults','nativeFaults','ownershipPreserved','inclusiveTotalMs')},
             'first_ensure':{k:first[k] for k in ('started','finished','startedWall','finishedWall','residentBefore','residentAfter')},
             'first_ensure_identity_flags_valid':True,'wall_offset':offset,'observed_clock_drift_max_ms':drift,
             'request_local_ms':clock['started'],'request_wall_estimate':offset+clock['started'],
             'early_events':early,'receives':receives,'frame_gaps':gaps}
        prefix='RConnectRoomTiming capture ' if role=='host' else 'RConnectRoomTiming restore '
        timing=[p for _,p in payloads(lines,prefix) if p['key'].startswith('random_mane/')]
        assert len(timing)==1;timing=timing[0]
        keys=['units','objects','terrain','total'] if role=='host' else ['role','objects','terrain','units','effects','redraw']
        elapsed=0;deltas={}
        for key in keys:deltas[key]=timing[key]-elapsed;elapsed=timing[key]
        row['checkpoint_cumulative_ms']=timing;row['checkpoint_stage_differences_ms']=deltas
        row['gaps_ms']={
           'request_to_constructed':early['constructed']['local_ms']-clock['started'],
           'ensure_duration':first['finished']-first['started'],
           'ensure_finish_to_activated':early['activated']['local_ms']-first['finished']}
        if role=='host':
            assert profile['overflow'] and not profile['observationComplete'] and profile['observedCalls']==33 and len(profile['rows'])==32
            r=next(x for x in receives if x['operation']=='ready')
            row['gaps_ms'].update(constructed_to_ready_handler=r['start']-early['constructed']['local_ms'],
                ready_handler_to_ensure=first['started']-r['end'],
                first_ensure_finish_to_next_logged_frame=74605-first['finished'],
                next_logged_frame_to_activated=early['activated']['local_ms']-74605)
            evidence=payloads(lines,'SCENE TRAVEL INPUT ')[0][1]['evidence']
            samples=evidence['baseline'];row['baseline_samples']=samples
            row['baseline_ms']=samples[-1]['t']-samples[0]['t']
            assert row['baseline_ms']==1159 and not evidence['pressed'] and not evidence['released']
            row['gaps_ms']['activated_to_baseline_start']=samples[0]['t']-early['activated']['local_ms']
        else:
            assert not profile['overflow'] and profile['observationComplete'] and profile['observedCalls']==4
            travel=result['roles'][role]['rows'][0];ticket=travel['rasterEvidence']['tickets'][0]
            r=next(x for x in receives if x['operation']=='grant')
            row['gaps_ms'].update(constructed_to_grant_handler=r['start']-early['constructed']['local_ms'],
                grant_handler_to_ensure=first['started']-r['end'],
                grant_handler_outside_restore=r['duration']-timing['total'],
                ensure_finish_to_ticket_first_painted_observation=ticket['firstPainted']-first['finished'],
                ensure_finish_to_ready=early['ready']['local_ms']-first['finished'],
                ready_to_activated=early['activated']['local_ms']-early['ready']['local_ms'],
                activated_to_flags_ready=travel['at']-early['activated']['local_ms'])
            row['travel']={k:travel[k] for k in ('elapsed','requestedWall','flagsReadyWall','controlResponseElapsed','inputResponseMs','inputReleaseVerifiedWall','x','y')}
            row['baseline_ms']=travel['inputEvidence']['baselineElapsed']
        out['roles'][role]=row
    h=out['roles']['host']['first_ensure'];j=out['roles']['join']['first_ensure']
    out['first_ensure_overlap_ms']=max(0,min(h['finishedWall'],j['finishedWall'])-max(h['startedWall'],j['startedWall']))
    out['between_first_ensure_intervals_ms']=j['startedWall']-h['finishedWall']
    assert out['first_ensure_overlap_ms']==0 and out['between_first_ensure_intervals_ms']==649
    out['interpretation']=[
      'The two recorded first ensure-work intervals do not overlap. This does not establish non-overlap of all native rendering or other room work.',
      'Host overflow invalidates the complete observation window; previously stored identity-valid first-row timestamps remain local raw evidence.',
      'Host input baseline exceeded the unchanged 1000 ms requirement; no host key-down response was measured. Buffer overflow is not proved to cause this failure.',
      'About two seconds after each first ensure-work completion lie outside that measured method interval. Logs do not identify those costs.',
      'RoomTiming fields are cumulative boundaries; stage costs are differences, not sums of the fields.',
      'No whole-run, full-three-segment, solo-comparison or performance admission is justified.']
    out['inputs']={str(p):sha(p) for p in (WRAPPER/'result.json',RUN/'host.log',RUN/'join.log',
       ROOT/'build/m52/recovery-early-paint-driver-v2-01/tests/PaintTimingBuffer.as',
       ROOT/'build/m52/recovery-early-exit-compile-01/src/rconnect/game/GameBridge.as')}
    return out

if __name__=='__main__':
    out=HERE/'paint-run01-audit.json';assert not out.exists()
    result=audit();out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('run','passed','profile_valid','first_ensure_overlap_ms','between_first_ensure_intervals_ms')},ensure_ascii=False))
