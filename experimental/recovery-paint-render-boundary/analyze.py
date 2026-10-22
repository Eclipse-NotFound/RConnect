"""Recompute the completed RENDER observation; never grants performance approval."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/m52/recovery-paint-render-solo-01'
RUN=ROOT/'build/cooperation/cf820db4d7'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
result=read(OUT/'result.json')
assert result['passed'] and result['profile_valid'] and result['installation_unchanged']
assert result['run']=='cf820db4d7' and result['roles']['host']['checks']==35
assert not result['roles']['host']['errors'] and not result['performance_qualified']
lines=(RUN/'host.log').read_text(encoding='utf-8-sig').splitlines()
tails=[json.loads(s.split('EARLY PAINT TAIL ',1)[1]) for s in lines if s.startswith('EARLY PAINT TAIL {')]
assert tails==result['paint_profiles']['host']['tail_cpu']['rows']
assert len(tails)==3 and not tails[1]['triggered']
segments=[]
for row in (tails[0],tails[2]):
    assert row['complete'] and row['cleanupComplete'] and not row['errors']
    rb=row['renderBoundary'];marks=rb['marks'];clocks=row['clocks']
    assert rb['attached'] and rb['available'] and not rb['incomplete']
    assert rb['faults']==rb['overflow']==0 and rb['observed']==len(marks)==4
    assert [m['phase'] for m in marks]==['high','low','high','low']
    assert all(m['enter']==row['startStage'] for m in marks)
    assert [m['serial'] for m in marks]==list(range(marks[0]['serial'],marks[0]['serial']+4))
    for field in ('t','wall'):
        times=[clocks['startReturned'][field]]+[m[field] for m in marks]+[clocks['stop'][field]]
        assert times==sorted(times)
    segments.append(dict(segment=row['segment'],resident=row['ensure']['residentAfter'],
        tail_ms=clocks['stop']['t']-clocks['startReturned']['t'],
        before_first_stage_render_ms=marks[0]['t']-clocks['startReturned']['t'],
        first_to_last_stage_render_ms=marks[-1]['t']-marks[0]['t'],
        last_stage_render_to_next_enter_ms=clocks['stop']['t']-marks[-1]['t'],
        cpu_samples=row['cpu'],render_marks=len(marks)))
inputs=[OUT/'result.json',OUT/'intent.json',RUN/'run.json',RUN/'host.log',
    ROOT/'build/m52/recovery-paint-render-driver-01/prepared.json',
    ROOT/'build/m52/recovery-paint-render-driver-01/scene/EffectsDriver.swf']
receipt=dict(run=result['run'],checks=35,segments=segments,
    inputs={str(p):sha(p) for p in inputs},source_sha256=sha(Path(__file__)),
    diagnostic_only=True,performance_qualified=False,
    limitation='Stage RENDER markers only; not a full display-list/GPU boundary. No process CPU collected in this run.')
destination=OUT/'render-alignment.json'
assert not destination.exists(),'Preserve the first derived result'
destination.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(run=result['run'],checks=35,segments=segments),ensure_ascii=False))
