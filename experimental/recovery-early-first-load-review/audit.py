"""Read exact old logs and source; no game, compiler or production writes."""
from pathlib import Path
import hashlib,json,re,statistics
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def load(run,role):
    path=ROOT/'build/cooperation'/run/(role+'.log')
    lines=path.read_text(encoding='utf-8-sig').splitlines()
    results=[json.loads(s[14:]) for s in lines if s.startswith('TRAVEL RESULT ')]
    row=next(r for r in results if r['round']==0)
    pairs=[r['wallMs']-r['t'] for name in ('baseline','pressed','released') for r in row['inputEvidence'][name]]
    tickets=row['rasterEvidence']['tickets']
    offset=tickets[0]['wall']-tickets[0]['at'] if tickets else statistics.median(pairs)
    request=row['requestedWall'];events=[];current=-1;captures=[];restores=[]
    def add(kind,t,line,**extra):events.append(dict(kind=kind,local_t=t,after_request_ms=t+offset-request,line=line,**extra))
    for index,s in enumerate(lines,1):
        if s.startswith('TRAVEL CLOCK '):current=json.loads(s[13:])['round']
        if current!=0:continue
        if s.startswith('RConnectEarly:'):
            m=re.search(r'RConnectEarly: (\w+) .* t=(\d+)',s)
            if m:add('early-'+m[1],int(m[2]),index)
        elif s.startswith('RConnectTravel: prepare '):
            add('prepare-send-return',int(re.search(r't=(\d+)',s)[1]),index)
        elif s.startswith('A22 ROOM RECEIVE '):
            r=json.loads(s[17:]);add(r['op']+'-handler-enter',r['from'],index)
            add(r['op']+'-handler-exit',r['at'],index,duration_ms=r['ms'],exit=r['context']['exit'])
        elif s.startswith('A22 ROOM FRAME GAP '):
            r=json.loads(s[19:]);add('frame-gap-start',r['from'],index)
            add('frame-gap-end',r['at'],index,duration_ms=r['ms'],exit_before=r['before']['exit'],exit_after=r['after']['exit'])
        elif s.startswith('RConnectRoomTiming capture '):captures.append(dict(line=index,**json.loads(s[26:])))
        elif s.startswith('RConnectRoomTiming restore '):restores.append(dict(line=index,**json.loads(s[26:])))
    for t in tickets:
        add('ticket-created',t['at'],None)
        add('release-observed',t['firstReleased'],None)
        add('painted-observed',t['firstPainted'],None)
    events.sort(key=lambda x:(x['local_t'],x['kind']))
    checks={k:row[k] for k in ('elapsed','controlResponseElapsed','exitStart','exitEnd','units','x','y','width','height','seed')}
    checks['flags_ready_after_request_ms']=row['flagsReadyWall']-request
    checks['baseline_ms']=row['inputEvidence']['baselineElapsed'];checks['key_response_ms']=row['inputResponseMs']
    return dict(run=run,role=role,log_sha256=sha(path),row=checks,events=events,captures=captures,restores=restores,
        paired_wall_minus_timer_min=min(pairs),paired_wall_minus_timer_max=max(pairs),used_offset=offset,
        actual_raster_duration_known=False,pure_network_latency_known=False)
def main():
    result={'dual_host':load('3b3c31c5f5','host'),'dual_join':load('3b3c31c5f5','join'),'solo':load('925d5f32df','host')}
    sources=[ROOT/'experimental/recovery-early-buildsrc/src/rconnect/core/RoomSync.as',ROOT/'experimental/recovery-early-buildsrc/src/rconnect/core/EarlyTravelGate.as',ROOT/'experimental/recovery-early-buildsrc/src/rconnect/game/GameBridge.as',ROOT/'experimental/recovery-early-buildsrc/src/rconnect/net/TcpLink.as',ROOT/'build/m52/recovery-early-host-01/after/scripts/fe/graph/Grafon.as']
    result['source_hashes']={str(p):sha(p) for p in sources}
    result['performance_qualified']=False
    target=HERE/'evidence.json';assert not target.exists();target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for k in ('dual_host','dual_join','solo'):
        r=result[k];print(k,json.dumps(r['row'],ensure_ascii=False))
        print('events',json.dumps(r['events'],ensure_ascii=False))
        print('capture/restore',json.dumps([r['captures'],r['restores']],ensure_ascii=False))
if __name__=='__main__':main()
