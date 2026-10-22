"""Align the two ENTER markers in the completed isolated run."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/m52/recovery-paint-enter-tail-solo-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
result=read(OUT/'result.json');run=ROOT/'build/cooperation'/result['run']
assert result['passed'] and result['profile_valid'] and result['installation_unchanged']
assert not result['performance_qualified'] and result['roles']['host']['checks']==35
assert not result['roles']['host']['errors']
lines=(run/'host.log').read_text(encoding='utf-8-sig').splitlines()
tails=[json.loads(s.split('EARLY PAINT TAIL ',1)[1]) for s in lines if s.startswith('EARLY PAINT TAIL {')]
assert tails==result['paint_profiles']['host']['tail_cpu']['rows']
assert len(tails)==3 and not tails[1]['triggered']
segments=[]
for row in (tails[0],tails[2]):
    assert row['complete'] and row['cleanupComplete'] and not row['errors']
    rb=row['renderBoundary'];marks=rb['marks'];c=row['clocks']
    assert rb['attached'] and rb['available'] and not rb['incomplete']
    assert rb['faults']==rb['overflow']==0 and rb['observed']==len(marks)
    assert [m['phase'] for m in marks]==['high','low','high','low']
    a=row['stageEnterAfterDefault'];b=row['stageEnterTail']
    item=dict(segment=row['segment'],cpu_samples=row['cpu'],
        tail_ms=c['stop']['t']-c['startReturned']['t'],
        after_default=a,enter_tail=b,
        after_default_unavailable=row['stageEnterAfterDefaultUnavailable'],
        enter_tail_unavailable=row['stageEnterTailUnavailable'],
        incomplete=row['stageEnterAfterDefaultIncomplete'] or row['stageEnterTailIncomplete'])
    if a is not None and b is not None and not item['incomplete']:
        assert a['enter']==b['enter']==row['startStage']
        for field in ('t','wall'):
            times=[c['startReturned'][field],a[field],b[field],marks[0][field],marks[-1][field],c['stop'][field]]
            assert times==sorted(times)
            item[field+'_intervals_ms']=[y-x for x,y in zip(times,times[1:])]
    segments.append(item)
inputs=[OUT/'result.json',OUT/'intent.json',run/'host.log',run/'run.json',
    ROOT/'build/m52/recovery-paint-enter-tail-driver-01/prepared.json',
    ROOT/'build/m52/recovery-paint-enter-tail-driver-01/scene/EffectsDriver.swf']
receipt=dict(run=result['run'],checks=35,segments=segments,inputs={str(p):sha(p) for p in inputs},
    source_sha256=sha(Path(__file__)),diagnostic_only=True,performance_qualified=False,
    interval_order=['start to Stage priority -1','priority -1 to lowest Stage ENTER',
        'lowest Stage ENTER to first Stage RENDER','first to last Stage RENDER','last Stage RENDER to next ENTER'],
    scope='Same Stage listener priority boundaries only; not all display objects or all script execution.')
destination=OUT/'enter-alignment.json';assert not destination.exists()
destination.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(run=result['run'],checks=35,segments=segments),ensure_ascii=False))
