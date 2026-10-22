"""Add strict call-accounting checks after the exact frozen aggregate audit."""
from pathlib import Path
import hashlib,importlib.util,json

HERE=Path(__file__).resolve().parent
PRIOR=HERE/'audit_profile.py'
PRIOR_SHA='779a2128172034242c89ee3c2c41ff3c785c8ec3aefa1cd37810ff957653538a'
assert hashlib.sha256(PRIOR.read_bytes()).hexdigest()==PRIOR_SHA
spec=importlib.util.spec_from_file_location('frozen_aggregate_source_profile_audit',PRIOR)
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)

def capacity(ranges,reserved):
    """At most three ranges and 38 reserved points; never enumerate all calls."""
    merged=[]
    for lo,hi in sorted(ranges):
        if merged and lo<=merged[-1][1]+1:merged[-1][1]=max(merged[-1][1],hi)
        else:merged.append([lo,hi])
    return sum(hi-lo+1 for lo,hi in merged)-sum(any(lo<=point<=hi for lo,hi in merged) for point in reserved)

def accounting(profile):
    important={row['callIndex'] for row in profile['rows']}
    reserved=set(important);nonempty=[]
    for bucket in profile['buckets']:
        count=bucket['calls']
        if not count:continue
        endpoints={bucket['firstCall'],bucket['lastCall']}
        assert not endpoints & reserved,'A call cannot be both important and bucketed, or belong to two buckets'
        reserved.update(endpoints)
        if count==1:
            duration=bucket['lastFinished']-bucket['firstStarted']
            assert bucket['totalMs']==bucket['maxMs']==duration,'Single-call bucket must retain the complete call duration'
        nonempty.append((bucket['firstCall'],bucket['lastCall'],count-len(endpoints)))
    # Three fixed buckets have only seven subsets. Checking their union capacity
    # excludes impossible double counting even when bucket spans overlap.
    for mask in range(1,1<<len(nonempty)):
        chosen=[value for index,value in enumerate(nonempty) if mask & (1<<index)]
        assert sum(value[2] for value in chosen)<=capacity([(v[0],v[1]) for v in chosen],reserved), \
            'Stable bucket counts exceed their unclaimed call-index capacity'
    if not profile['rasterRoomBound']:
        assert profile['targetCalls']==profile['targetRows']==0,'An unbound segment cannot claim target work'
        assert all(row['category']=='unbound' for row in profile['rows'])
        assert all(bucket['calls']==0 for bucket in profile['buckets'] if bucket['category']!='unbound')

def audit_profiles(profiles,travels):
    result=prior.audit_profiles(profiles,travels)
    for profile in profiles:accounting(profile)
    return result

def audit_log(path):
    data=Path(path).read_bytes();profiles=[];travels=[]
    for line in data.decode('utf-8-sig').splitlines():
        if line.startswith('EARLY PAINT PROFILE '):profiles.append(json.loads(line[20:]))
        if line.startswith('TRAVEL RESULT '):travels.append(json.loads(line[14:]))
    result=audit_profiles(profiles,travels)
    result.update(log=str(path),log_sha256=hashlib.sha256(data).hexdigest())
    return result
