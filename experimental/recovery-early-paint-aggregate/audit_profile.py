"""Strict new aggregate schema; never reinterpret old partial paint profiles."""
from pathlib import Path
import argparse,hashlib,json,math

KIND='ensure-work-aggregate-v1'
CATEGORIES=('target','unbound','other')

def number(value):
    assert isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)
    return value

def integer(value):
    number(value);assert value>=0 and value==int(value)
    return int(value)

def interval(value,first,last,wall_first,wall_last):
    a,b=number(value[first]),number(value[last])
    wa,wb=number(value[wall_first]),number(value[wall_last])
    assert a>=0 and b>=a and wb>=wa
    return b-a,dict(started_wall=wa,finished_wall=wb,local_ms=b-a)

def audit_profiles(profiles,travels):
    assert len(profiles)==len(travels)==3,'Need every original travel segment'
    assert sorted(p['segment'] for p in profiles)==[0,1,2]
    assert sorted(t['round'] for t in travels)==[0,1,2]
    summaries=[]
    for p in sorted(profiles,key=lambda v:v['segment']):
        segment=p['segment'];travel=next(t for t in travels if t['round']==segment)
        assert travel['rasterEvidence']['paintEvidence']==p
        assert p['kind']==KIND and p['schema']==1 and p['reason']=='finish'
        assert p['limit']==32 and p['bucketLimit']==3
        assert p['diagnosticOnly'] is True and p['performanceQualified'] is False
        assert all(p[k] is True for k in ('passed','observationComplete','available','ownershipPreserved'))
        assert p['overflow'] is False
        assert all(p[k]==0 for k in ('faults','nativeFaults','bindingConflicts','incompleteCalls'))
        rows=p['rows'];buckets=p['buckets'];assert len(rows)<=32 and len(buckets)==3
        assert [b['category'] for b in buckets]==list(CATEGORIES)
        calls=integer(p['observedCalls']);positive=zero=0;total=maximum=0
        target_rows=target_calls=0;last_index=0;last_end=last_wall=-1;intervals=[]
        for sequence,row in enumerate(rows,1):
            assert row['segment']==segment and row['sequence']==sequence
            index=integer(row['callIndex']);assert last_index<index<=calls;last_index=index
            assert row['category'] in CATEGORIES and row['sameRasterRoom']==(row['category']=='target')
            assert integer(row['location'])>0 and row['phase']=='ensure-work'
            assert all(row[k] is True for k in ('important','clockValid','residentsValid','sameWorld','sameGame',
                'sameRenderer','sameLoc','completed','worldRendererAtStart','worldRendererAtEnd','worldLocAtStart','worldLocAtEnd'))
            duration,span=interval(row,'started','finished','startedWall','finishedWall')
            assert row['started']>=last_end and row['startedWall']>=last_wall
            last_end=row['finished'];last_wall=row['finishedWall']
            before=integer(row['residentBefore']);after=integer(row['residentAfter'])
            assert isinstance(row['initial'],bool) and isinstance(row['preload'],bool)
            assert row['initial'] or before!=after,'A successful stable call belongs in a fixed bucket'
            positive+=duration>0;zero+=duration==0;total+=duration;maximum=max(maximum,duration)
            if row['sameRasterRoom']:target_rows+=1;intervals.append(span)
        summed_calls=len(rows)
        summaries_buckets=[]
        for b in buckets:
            count=integer(b['calls']);pos=integer(b['positiveMsCalls']);z=integer(b['zeroMsCalls'])
            assert count==pos+z
            milliseconds=number(b['totalMs']);largest=number(b['maxMs'])
            assert milliseconds>=0 and largest>=0 and largest<=milliseconds
            assert all(b[k] is True for k in ('allCompleted','allIdentitiesMatch','allClocksValid','stableResidentOnly'))
            assert integer(b['preloadCalls'])<=count
            assert integer(b['roomChanges'])<=max(0,count-1)
            assert integer(b['residentTransitions'])<=max(0,count-1)
            if b['category']=='target':assert b['roomChanges']==0
            if count:
                span,_=interval(b,'firstStarted','lastFinished','firstStartedWall','lastFinishedWall')
                assert milliseconds<=span,'Summed sequential work cannot exceed bucket time span'
                assert integer(b['firstCall'])<=integer(b['lastCall'])<=calls and b['firstCall']>0
                assert count<=b['lastCall']-b['firstCall']+1
                assert integer(b['firstResident'])>=0 and integer(b['lastResident'])>=0
                if not b['residentTransitions']:assert b['firstResident']==b['lastResident']
                if pos:assert largest>0 and pos<=milliseconds<=pos*largest
                else:assert milliseconds==largest==0
                if count==1:assert b['firstCall']==b['lastCall'] and b['roomChanges']==b['residentTransitions']==0
            else:
                assert milliseconds==largest==b['roomChanges']==b['residentTransitions']==b['preloadCalls']==0
                assert all(b[k] is None for k in ('firstStarted','lastFinished','firstStartedWall','lastFinishedWall',
                    'firstCall','lastCall','firstResident','lastResident'))
            summed_calls+=count;positive+=pos;zero+=z;total+=milliseconds;maximum=max(maximum,largest)
            if b['category']=='target':target_calls+=count
            summaries_buckets.append({k:b[k] for k in ('category','calls','positiveMsCalls','zeroMsCalls','totalMs','maxMs',
                'firstStartedWall','lastFinishedWall','roomChanges','residentTransitions')})
        target_calls+=target_rows
        assert calls==summed_calls==positive+zero
        assert integer(p['positiveMsCalls'])==positive and integer(p['zeroMsCalls'])==zero
        assert number(p['inclusiveTotalMs'])==total and number(p['maxMs'])==maximum
        assert integer(p['targetRows'])==target_rows and integer(p['targetCalls'])==target_calls
        assert isinstance(p['rasterRoomBound'],bool) and (not p['rasterRoomBound'] or target_calls>0)
        summaries.append(dict(segment=segment,important_rows=len(rows),calls=calls,target_calls=target_calls,
            inclusive_ms=total,max_ms=maximum,target_important_intervals=intervals,stable_buckets=summaries_buckets))
    return dict(valid=True,kind=KIND,diagnostic_only=True,performance_qualified=False,segments=summaries)

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
    ap.add_argument('--roles',nargs='+',choices=['host','join'],default=['host','join']);ap.add_argument('--output',type=Path)
    a=ap.parse_args();value={role:audit_log(a.run_dir/(role+'.log')) for role in a.roles}
    content=json.dumps(value,ensure_ascii=False,indent=2)+'\n'
    if a.output:
        assert not a.output.exists(),'Keep previous result unchanged'
        a.output.write_text(content,encoding='utf-8')
    print(content)

if __name__=='__main__':main()
