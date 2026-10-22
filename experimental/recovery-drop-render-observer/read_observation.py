"""Read completed logs only; summarize bounded callback records without qualifying performance."""
from pathlib import Path
import argparse, hashlib, json

MARK='DROP RENDER OBSERVER '
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def summarize(path):
    text=path.read_text('utf-8-sig',errors='replace')
    lines=[(i,line.split(MARK,1)[1]) for i,line in enumerate(text.splitlines()) if MARK in line]
    assert len(lines)==1,'Expected one bounded export: '+str(path)
    index,raw=lines[0];doc=json.loads(raw);rows=doc['rows']
    assert doc['schema']==1 and doc['round']==0 and doc['maximum']==256 and doc['durationMs']==2000
    assert doc['diagnostic_only'] is True and doc['performance_qualified'] is False
    assert isinstance(rows,list) and len(rows)<=256
    assert all(r['kind'] in ('render','enter','loot') and type(r['at']) is int and type(r['frame']) is int for r in rows)
    assert all(a['at']<=b['at'] and a['frame']<=b['frame'] for a,b in zip(rows,rows[1:]))
    if doc['start']>=0:
        assert doc['deadline']-doc['start']==2000
        assert all(doc['start']<=r['at']<doc['deadline'] for r in rows)
    else:assert not rows
    if doc['complete']:
        assert doc['reason']=='elapsed' and doc['closedObservedAt']>=doc['deadline']
        assert doc['overflow']==0 and not doc['fault'] and doc['wireKeyChanges']==doc['visualChanges']==0
    by_kind={kind:[r for r in rows if r['kind']==kind] for kind in ('render','enter','loot')}
    render=by_kind['render'];enter=by_kind['enter'];wire=by_kind['loot']
    def gaps(series):
        result=[]
        for a,b in zip(series,series[1:]):
            result.append(dict(ms=b['at']-a['at'],startAt=a['at'],endAt=b['at'],
                startFrame=a['frame'],endFrame=b['frame'],sameGameFrame=a['frame']==b['frame'],
                enterInside=sum(a['at']<x['at']<b['at'] for x in enter),
                lootInside=sum(a['at']<x['at']<b['at'] for x in wire)))
        return sorted(result,key=lambda r:r['ms'],reverse=True)[:5]
    held_start=None;longest=dict(ms=0,startAt=None,endAt=None,frames=None)
    for a,b in zip(render,render[1:]):
        unchanged=(a['attached'] and b['attached'] and a['sameVisual'] and b['sameVisual']
            and a['x']==b['x'] and a['y']==b['y'])
        if unchanged:
            if held_start is None:held_start=a
            span=b['at']-held_start['at']
            if span>longest['ms']:longest=dict(ms=span,startAt=held_start['at'],endAt=b['at'],
                frames=b['frame']-held_start['frame'],bothEndpointsStay=held_start['stay'] and b['stay'])
        else:held_start=None
    return dict(log=str(path),sha256=sha(path),line_index=index,role=doc['role'],
        diagnostic_complete=doc['complete'],status={k:doc[k] for k in ('start','deadline','closedObservedAt','exportAt',
            'reason','overflow','fault','wireKey','wireKeyChanges','visualChanges')},
        rows=len(rows),counts={k:len(v) for k,v in by_kind.items()},
        duplicate_game_frame_render_visits=sum(r['alreadyDeduped'] for r in render),
        largest_render_gaps=gaps(render),largest_enter_gaps=gaps(enter),
        first_render_at=render[0]['at'] if render else None,last_render_at=render[-1]['at'] if render else None,
        last_render_to_deadline_ms=doc['deadline']-render[-1]['at'] if render else None,
        longest_equal_display_span=longest,
        native_functional_pass=None,smoothness_qualified=False,
        caveat='Callback timestamps only; per-role clocks are not aligned; no CPU/pixel or network-only latency claim.')

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
    assert a.run.is_dir() and not a.output.exists(),'Use completed evidence and a new summary file'
    result={role:summarize(a.run/(role+'.log')) for role in ('host','join')}
    assert result['host']['role']=='host' and result['join']['role']=='join'
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({r:{k:v[k] for k in ('diagnostic_complete','rows','counts','duplicate_game_frame_render_visits','smoothness_qualified')}
        for r,v in result.items()},ensure_ascii=False))
if __name__=='__main__':main()
