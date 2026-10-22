"""Additional pure-data rejections; immutable build audit remains untouched."""
from copy import deepcopy
import json
from audit_checks import fixture,travels,empty,HERE
from audit_runtime import audit_profiles,audit_log

def run():
    labels=[]
    value=fixture();assert audit_profiles(value,travels(value))['valid'];labels.append('original complete fixture retained')
    def reject(label,fn):
        data=fixture();fn(data)
        try:audit_profiles(data,travels(data))
        except (AssertionError,KeyError,ValueError):labels.append(label);return
        raise AssertionError('Invalid runtime accounting accepted: '+label)
    reject('important and bucket cannot share first call',lambda p:p[0]['buckets'][0].__setitem__('firstCall',1))
    def shorten(p):
        p[0]['buckets'][0].update(calls=1,positiveMsCalls=1,totalMs=2,maxMs=2,firstCall=2,lastCall=2,
            firstStarted=20,lastFinished=25,firstStartedWall=1020,lastFinishedWall=1025)
        p[0].update(targetCalls=2,observedCalls=2,positiveMsCalls=2,inclusiveTotalMs=7)
    reject('single call cannot underreport complete duration',shorten)
    reject('unbound segment cannot claim target work',lambda p:p[0].__setitem__('rasterRoomBound',False))
    def overlap(p):
        b=p[0]['buckets'][0];b.update(calls=50,positiveMsCalls=50,totalMs=100,firstCall=2,lastCall=51)
        p[0]['buckets'][2]=dict(b,category='other')
        p[0]['targetCalls']=51
    reject('two buckets cannot reserve identical endpoints',overlap)
    def interior(p):
        p[0]['rows'][0]['callIndex']=50
        p[0]['buckets'][0].update(firstCall=1,lastCall=100)
    reject('bucket span cannot consume an important interior call',interior)
    data=fixture()
    for p in data:
        p['buckets'][0].update(calls=1,positiveMsCalls=1,totalMs=5,maxMs=5,firstCall=2,lastCall=2,
            firstStarted=20,lastFinished=25,firstStartedWall=1020,lastFinishedWall=1025)
        p.update(targetCalls=2,observedCalls=2,positiveMsCalls=2,inclusiveTotalMs=10)
    assert audit_profiles(data,travels(data))['valid'];labels.append('complete single-call bucket accepted')
    try:audit_log(HERE.parents[1]/'build/cooperation/84ff2d9da3/host.log')
    except (AssertionError,KeyError,ValueError):labels.append('real partial old FAIL still rejected')
    else:raise AssertionError('Old partial log accepted')
    return dict(passed=len(labels),checks=labels,compiled=False,air_started=False,performance_qualified=False)

if __name__=='__main__':print(json.dumps(run(),ensure_ascii=False))
