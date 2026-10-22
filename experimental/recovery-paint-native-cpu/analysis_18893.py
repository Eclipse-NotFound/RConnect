"""Read the completed run; derive endpoint-bounded process CPU accounting."""
from pathlib import Path
import hashlib,json,statistics
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/m52/recovery-paint-native-cpu-solo-03'
RUN=ROOT/'build/cooperation/18893bfce6'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cpu(r):return (r['user_100ns']+r['kernel_100ns'])/10000
def main():
    paths=[OUT/'result.json',OUT/'rv83-admission.json',RUN/'process-cpu.json',RUN/'run.json',RUN/'host.log']
    result=read(paths[0]);trace=read(paths[2]);manifest=read(paths[3])
    assert result['passed'] and result['installation_unchanged'] and result['profile_valid']
    assert result['roles']['host']['checks']==35 and not result['roles']['host']['errors']
    assert trace['complete'] and len(trace['roles'])==1
    role=trace['roles'][0];rows=role['rows']
    assert role['complete'] and role['query_handle_closed'] and not role['errors'] and not role['truncated']
    assert manifest['pids']==[role['pid']]
    assert len(rows)==1001 and all(x['creation_100ns']==role['creation_100ns'] for x in rows)
    for a,b in zip(rows,rows[1:]):
        assert a['wall_before_ms']<=a['wall_after_ms']<=b['wall_before_ms']
        assert cpu(a)<=cpu(b)
    segments=[]
    for tail in result['paint_profiles']['host']['tail_cpu']['rows']:
        if not tail['triggered']:continue
        assert tail['complete'] and tail['clockOrdered'] and not tail['errors']
        start=tail['clocks']['startReturned']['wall'];end=tail['clocks']['stop']['wall']
        # Widen outside / narrow inside by one millisecond for AS Date granularity.
        before=max((x for x in rows if x['wall_after_ms']<=start-1),key=lambda x:x['wall_after_ms'])
        after=min((x for x in rows if x['wall_before_ms']>=end+1),key=lambda x:x['wall_before_ms'])
        inside=[x for x in rows if x['wall_before_ms']>=start+1 and x['wall_after_ms']<=end-1]
        assert len(inside)>=2
        segments.append(dict(segment=tail['segment'],wall_ms=end-start,
            cpu_ms_inside=cpu(inside[-1])-cpu(inside[0]),cpu_ms_enclosing=cpu(after)-cpu(before),
            before_margin_ms=start-before['wall_after_ms'],after_margin_ms=after['wall_before_ms']-end,
            inside_rows=len(inside),flash_cpu_samples=tail['cpu'],resident=tail['ensure']['residentAfter'],
            start_wall=start,end_wall=end))
    assert len(segments)==2
    evidence=dict(run='18893bfce6',checks=35,segments=segments,rows=len(rows),
        max_query_ms=max(x['read_ns'] for x in rows)/1e6,
        total_query_ms=sum(x['read_ns'] for x in rows)/1e6,
        max_interval_ms=max(x.get('interval_ns',0) for x in rows)/1e6,
        median_interval_ms=statistics.median(x['interval_ns'] for x in rows if 'interval_ns' in x)/1e6,
        inputs={str(p):sha(p) for p in paths},source_sha256=sha(Path(__file__)),
        scope='Whole-process cumulative CPU, all threads; endpoint bracketing, not GPU/main-thread attribution',
        diagnostic_only=True,performance_qualified=False)
    output=OUT/'cpu-alignment.json'
    assert not output.exists(),'Keep the original derived evidence'
    output.write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in evidence.items() if k!='inputs'},ensure_ascii=False))
if __name__=='__main__':main()
