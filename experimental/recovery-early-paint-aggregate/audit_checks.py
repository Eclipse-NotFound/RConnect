"""Pure data positives/negatives for the new schema, including the old real FAIL."""
from pathlib import Path
from copy import deepcopy
import hashlib,json
from audit_profile import audit_profiles,audit_log,KIND,CATEGORIES
HERE=Path(__file__).resolve().parent

def empty(category):
    return dict(category=category,calls=0,positiveMsCalls=0,zeroMsCalls=0,totalMs=0,maxMs=0,
       firstStarted=None,lastFinished=None,firstStartedWall=None,lastFinishedWall=None,
       firstCall=None,lastCall=None,roomChanges=0,firstResident=None,lastResident=None,
       residentTransitions=0,preloadCalls=0,allCompleted=True,allIdentitiesMatch=True,
       allClocksValid=True,stableResidentOnly=True)

def fixture():
    profiles=[]
    for segment in range(3):
        row=dict(segment=segment,sequence=1,callIndex=1,phase='ensure-work',category='target',location=1,
            sameRasterRoom=True,started=10,finished=15,startedWall=1010,finishedWall=1015,
            initial=False,preload=False,residentBefore=0,residentAfter=1)
        for k in ('important','clockValid','residentsValid','sameWorld','sameGame','sameRenderer','sameLoc',
                  'completed','worldRendererAtStart','worldRendererAtEnd','worldLocAtStart','worldLocAtEnd'):row[k]=True
        buckets=[empty(c) for c in CATEGORIES]
        buckets[0].update(calls=100,positiveMsCalls=100,totalMs=200,maxMs=2,firstStarted=20,lastFinished=319,
            firstStartedWall=1020,lastFinishedWall=1319,firstCall=2,lastCall=101,firstResident=1,lastResident=1)
        profiles.append(dict(kind=KIND,schema=1,segment=segment,reason='finish',limit=32,bucketLimit=3,
            diagnosticOnly=True,performanceQualified=False,passed=True,observationComplete=True,available=True,
            ownershipPreserved=True,overflow=False,faults=0,nativeFaults=0,bindingConflicts=0,incompleteCalls=0,
            rasterRoomBound=True,targetRows=1,targetCalls=101,observedCalls=101,positiveMsCalls=101,zeroMsCalls=0,
            inclusiveTotalMs=205,maxMs=5,rows=[row],buckets=buckets))
    return profiles

def travels(p):return [dict(round=x['segment'],rasterEvidence=dict(paintEvidence=deepcopy(x))) for x in p]

def run():
    checks=[]
    p=fixture();assert audit_profiles(p,travels(p))['valid'];checks.append('100 stable positive calls plus important work accepted')
    p=fixture()
    for x in p:
        x['buckets'][0].update(positiveMsCalls=0,zeroMsCalls=100,totalMs=0,maxMs=0)
        x.update(positiveMsCalls=1,zeroMsCalls=100,inclusiveTotalMs=5)
    assert audit_profiles(p,travels(p))['valid'];checks.append('all zero stable calls remain counted')
    def reject(label,mutate):
        value=fixture();mutate(value)
        try:audit_profiles(value,travels(value))
        except (AssertionError,KeyError,TypeError,ValueError):checks.append(label);return
        raise AssertionError('Incorrect aggregate accepted: '+label)
    for field,bad in [('kind','ensure-work'),('schema',0),('overflow',True),('nativeFaults',1),('faults',1),
        ('bindingConflicts',1),('incompleteCalls',1),('ownershipPreserved',False),('observationComplete',False),
        ('observedCalls',100),('positiveMsCalls',100),('zeroMsCalls',1),('inclusiveTotalMs',204),('maxMs',4),
        ('targetCalls',100),('targetRows',0),('performanceQualified',True)]:
        reject('reject profile '+field,lambda p,f=field,b=bad:p[0].__setitem__(f,b))
    for field,bad in [('calls',99),('positiveMsCalls',99),('totalMs',1000),('maxMs',0),('allCompleted',False),
        ('allIdentitiesMatch',False),('allClocksValid',False),('stableResidentOnly',False),('roomChanges',1),
        ('lastFinished',19),('lastFinishedWall',1019),('lastCall',1),('firstResident',2)]:
        reject('reject target bucket '+field,lambda p,f=field,b=bad:p[0]['buckets'][0].__setitem__(f,b))
    reject('reject duplicate bucket category',lambda p:p[0]['buckets'][1].__setitem__('category','target'))
    reject('reject missing fixed bucket',lambda p:p[0]['buckets'].pop())
    reject('reject empty bucket nonzero time',lambda p:p[0]['buckets'][1].__setitem__('totalMs',1))
    reject('reject invalid row identity',lambda p:p[0]['rows'][0].__setitem__('sameLoc',False))
    reject('reject invalid row clock',lambda p:p[0]['rows'][0].__setitem__('clockValid',False))
    reject('reject nonfinite row time',lambda p:p[0]['rows'][0].__setitem__('started',float('nan')))
    reject('reject stable call in important list',lambda p:p[0]['rows'][0].__setitem__('residentBefore',1))
    reject('reject target category disagreement',lambda p:p[0]['rows'][0].__setitem__('category','other'))
    reject('reject absent segment',lambda p:p.pop())
    p=fixture();wrong=travels(p);wrong[0]['rasterEvidence']['paintEvidence']['maxMs']=7
    try:audit_profiles(p,wrong)
    except AssertionError:checks.append('reject profile versus original result mismatch')
    else:raise AssertionError('Mismatched original result accepted')
    old=HERE.parents[1]/'build/cooperation/84ff2d9da3/host.log'
    before=hashlib.sha256(old.read_bytes()).hexdigest()
    try:audit_log(old)
    except (AssertionError,KeyError,ValueError):checks.append('real old 84ff2d9da3 partial FAIL remains rejected')
    else:raise AssertionError('Old partial result was reinterpreted as new PASS')
    assert hashlib.sha256(old.read_bytes()).hexdigest()==before
    return dict(passed=len(checks),checks=checks,old_failure_log_sha256=before,
       compiled=False,air_started=False,performance_qualified=False)

if __name__=='__main__':print(json.dumps(run(),ensure_ascii=False))
