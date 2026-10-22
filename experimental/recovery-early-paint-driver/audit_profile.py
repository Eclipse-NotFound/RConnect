"""Read bounded native profiles; never grant performance or deployment qualification."""
from pathlib import Path
import argparse,hashlib,json,math

def audit_profiles(profiles,travels):
    assert len(profiles)==3 and len(travels)==3,'Need every original travel segment'
    assert sorted(p['segment'] for p in profiles)==[0,1,2]
    assert sorted(t['round'] for t in travels)==[0,1,2]
    summaries=[]
    for p in sorted(profiles,key=lambda x:x['segment']):
        segment=p['segment'];travel=next(t for t in travels if t['round']==segment)
        assert travel['rasterEvidence']['paintEvidence']==p,'Profile differs from original travel result'
        assert p['kind']=='ensure-work' and p['reason']=='finish' and p['limit']==32
        assert p['diagnosticOnly'] is True and p['performanceQualified'] is False
        assert p['passed'] is True and p['observationComplete'] is True and p['available'] is True
        assert p['overflow'] is False and p['ownershipPreserved'] is True
        assert all(p[k]==0 for k in ('faults','nativeFaults','bindingConflicts','incompleteCalls'))
        rows=p['rows'];assert len(rows)<=32
        assert p['observedCalls']==len(rows)+p['zeroMsStableResidentSkipped']
        assert p['zeroMsStableResidentSkipped']>=0
        target=sum(r['sameRasterRoom'] is True for r in rows)
        assert target==p['targetRows'] and (not p['rasterRoomBound'] or target>0)
        durations=[];offsets=[]
        for index,r in enumerate(rows,1):
            assert r['segment']==segment and r['sequence']==index and r['phase']=='ensure-work'
            assert r['location']>0
            assert all(r[k] is True for k in ('sameWorld','sameGame','sameRenderer','sameLoc','completed',
                'worldRendererAtStart','worldRendererAtEnd','worldLocAtStart','worldLocAtEnd'))
            for k in ('started','finished','startedWall','finishedWall'):assert math.isfinite(r[k]),k
            duration=r['finished']-r['started'];assert duration>=0 and r['finishedWall']>=r['startedWall']
            assert duration>0 or r['initial'] is True or r['residentAfter']!=r['residentBefore'], 'Unselected zero row leaked into buffer'
            durations.append(duration)
            offsets.extend((r['startedWall']-r['started'],r['finishedWall']-r['finished']))
        assert p['inclusiveTotalMs']==sum(durations)
        assert p['maxMs']==max(durations,default=0)
        assert p['positiveMsCalls']==sum(d>0 for d in durations)
        summaries.append(dict(segment=segment,rows=len(rows),calls=p['observedCalls'],
            zero_ms_stable_resident_skipped=p['zeroMsStableResidentSkipped'],target_rows=target,
            inclusive_ms=sum(durations),max_ms=max(durations,default=0),
            wall_minus_timer_min=min(offsets,default=None),wall_minus_timer_max=max(offsets,default=None),
            target_intervals=[dict(started_wall=r['startedWall'],finished_wall=r['finishedWall'],
                local_ms=r['finished']-r['started']) for r in rows if r['sameRasterRoom']]))
    return dict(valid=True,diagnostic_only=True,performance_qualified=False,segments=summaries)

def audit_log(path):
    data=Path(path).read_bytes();profiles=[];travels=[]
    for line in data.decode('utf-8-sig').splitlines():
        if line.startswith('EARLY PAINT PROFILE '):profiles.append(json.loads(line[20:]))
        if line.startswith('TRAVEL RESULT '):travels.append(json.loads(line[14:]))
    result=audit_profiles(profiles,travels)
    result.update(log=str(path),log_sha256=hashlib.sha256(data).hexdigest())
    return result

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run-dir',type=Path,required=True)
    ap.add_argument('--roles',nargs='+',choices=['host','join'],default=['host','join'])
    ap.add_argument('--output',type=Path)
    args=ap.parse_args()
    result={role:audit_log(args.run_dir/(role+'.log')) for role in args.roles}
    content=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.output:
        assert not args.output.exists(),'Keep prior diagnostic results'
        args.output.write_text(content,encoding='utf-8')
    print(content)
if __name__=='__main__':main()
