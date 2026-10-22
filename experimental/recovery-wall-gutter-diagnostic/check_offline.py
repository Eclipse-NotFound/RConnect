"""Source stripping and finite raw-wire diagnostic counterexamples; no AIR/JVM."""
import ast
import base64
import copy
import json
import struct
import zlib
from pathlib import Path
import analyze_diagnostic as a
import generate as g

HERE=Path(__file__).resolve().parent


def packed(values):
    raw=struct.pack('>H',len(values))+b''.join(struct.pack('>HI',i,c) for i,c in values)
    return '!W1:'+base64.b64encode(zlib.compress(raw)).decode()


def pair():
    baseline=0xff75746c;source=0xff2c2c28;wire=0xff2d2c28
    def snap(seq,kind,color,core=None):
        surfaces=[]
        for order,(x,y) in enumerate(((280,4120),(600,4120),(280,4440),(600,4440))):
            words=[baseline]*1600;words[1015]=core if core is not None and order==1 else color
            surfaces.append(dict(order=order,x=x,y=y,side=320,gutter=40,revision=1,
                cut=dict(x=640,y=4440,w=40,h=40),words=words))
        return dict(seq=seq,kind=kind,at=10+seq,wall=1000+seq,frame=2,
            hits=[{}]*8 if kind=='native-after-hits' else [],sameFrameHitOrderUnknown=kind=='native-after-hits',surfaces=surfaces)
    common=dict(schema=1,diagnosticOnly=True,active=True,cell=dict(x=640,y=4440,w=40,h=40),
        errors=[],rawMessageBeforeProduction=True,socketSendTimeObserved=False,nativeImpactOrderObserved=False)
    sa=copy.deepcopy(common);sa.update(snapshots=[snap(0,'baseline',baseline),snap(1,'native-after-hits',wire,source)],packets=[])
    rb=copy.deepcopy(common);cells=[dict(x=16,y=111,v=1,d=packed([(1015,wire)]))]
    rb.update(snapshots=[snap(0,'baseline',baseline),snap(1,'wire-before',baseline),snap(2,'wire-after',wire)],
        packets=[dict(seq=0,at=10,wall=1000,frame=2,type='worldstate',cells=cells,afterCells=copy.deepcopy(cells),
            rawUnchanged=True,multipleCellsUnknown=False,before=1,after=2)])
    def row(is_source,diag,color):
        final=[baseline]*(128*128);final[8911]=color
        return dict(source=is_source,round=2,area=dict(x=576,y=4396,w=128,h=128),target=dict(x=640,y=4460),
            hits=[{}]*8 if is_source else [],finalNative=final,gutterDiagnostic=diag)
    return row(True,sa,source),row(False,rb,wire)


def main():
    checks=[]
    def test(label,fn):
        try:fn();checks.append(dict(label=label,passed=True))
        except Exception as e:checks.append(dict(label=label,passed=False,error=repr(e)))
    def exact_strip():
        old=(g.BASE/g.ACTOR).read_text(encoding='utf-8-sig');new,edits=g.apply(old)
        assert new==(HERE/'tests'/g.ACTOR).read_text(encoding='utf-8-sig')
        for before,after in reversed(edits):assert new.count(after)==1;new=new.replace(after,before)
        assert new==old and g.sha(g.BASE/g.ACTOR)==g.ACTOR_SHA
        assert g.sha(HERE/'tests'/g.PROBE)==g.PROBE_SHA
    test('all eight observation insertions strip to exact driver04 stimulus/assertions',exact_strip)
    def bounded():
        s=(HERE/'tests/NativeWallColorProbe.as').read_text()
        hot=s.split('public function exportEvidence()',1)[0]
        for forbidden in ('getVector(','.encode(','.setPixel32(','.setVector(','.send(','.receive(','.report(','.checkpoint('):assert forbidden not in hot,forbidden
        assert 'MAX_PACKETS:int=96,MAX_SNAPSHOTS:int=210,MAX_SURFACES:int=4' in s
        assert 'beforeMessage,false,100000' in s and 'afterMessage,false,-100000' in s
        assert 'pending[e]=row' in s and 'row:Object=pending[e]' in s and 'row.afterCells=selectedCells(e.data)' in s
        assert 'sameFrameHitOrderUnknown:hits!=null&&hits.length>1' in s
    test('passive bounded same-event snapshots; no hot decode/readback/network mutation',bounded)
    def current_evidence():
        p=g.ROOT/'build/m52/recovery18-wall-surfaces-native-01/wall-proof'
        x=json.loads((p/'host/round-2-proof.json').read_text());y=json.loads((p/'join/round-2-proof.json').read_text())
        bad=[i for i in range(16384) if x['finalNative'][i]!=y['finalNative'][i]]
        assert bad==[8911,9038] and x['area']==dict(x=576,y=4396,w=128,h=128)
    test('diagnostic cell actually covers both remaining 18 opaque differences',current_evidence)
    def positive():
        r=a.analyze_pair(*pair());assert r['diagnostic_checks_passed'] and r['mismatch_reproduced']
        assert r['multiple_hits_same_frame'] and not r['root_cause_automatically_declared']
        assert r['actual_final_mismatches'][0]['source']=='ff2c2c28'
        t=next(t for t in r['timelines'] if t['x']==655)
        assert t['wire'][0]['wire_argb']=='ff2d2c28'
        assert [v['argb'] for v in t['source'][-1]['values'] if v['core']]==['ff2c2c28']
        assert not r['gameplay_qualified'] and not r['performance_qualified']
    test('real-message colors remain separate from core/gutter observations and ambiguous hit order',positive)
    def no_repro():
        x,y=pair();y['finalNative']=x['finalNative'].copy();r=a.analyze_pair(x,y)
        assert not r['mismatch_reproduced'] and not r['root_cause_automatically_declared']
    test('non-reproduction never becomes an automatic root-cause claim',no_repro)
    def negative(label,mutate):
        def check():
            x,y=pair();mutate(x,y)
            try:a.analyze_pair(x,y)
            except (AssertionError,KeyError,IndexError,ValueError):return
            raise AssertionError('Invalid diagnostic accepted')
        test(label,check)
    negative('raw d/version mutation rejected',lambda x,y:y['gutterDiagnostic']['packets'][0]['afterCells'][0].update(v=2))
    negative('different event frame binding rejected',lambda x,y:y['gutterDiagnostic']['snapshots'][2].update(frame=3))
    negative('missing after callback rejected',lambda x,y:y['gutterDiagnostic']['packets'][0].update(after=-1))
    negative('truncated final comparison rejected',lambda x,y:y.update(finalNative=[]))
    negative('capacity or observation error remains failure',lambda x,y:y['gutterDiagnostic'].update(errors=['capacity exceeded']))
    negative('duplicate selected cells cannot yield causal certainty',lambda x,y:y['gutterDiagnostic']['packets'][0].update(multipleCellsUnknown=True))
    def decoder():
        assert a.decode(packed([(0,0),(337,0xff43433c),(1599,0xffffffff)]))=={0:0,337:0xff43433c,1599:0xffffffff}
        for data in (packed([(337,1),(337,2)]),packed([(1600,1)]),'!W1:invalid!'):
            try:a.decode(data)
            except (AssertionError,ValueError):continue
            raise AssertionError('Malformed sparse payload accepted')
    test('exact big-endian sparse codec; duplicate/offset/base64 negatives',decoder)
    def syntax():
        for f in HERE.glob('*.py'):ast.parse(f.read_text(encoding='utf-8'))
    test('Python source syntax',syntax)
    result=dict(passed=all(c['passed'] for c in checks),count=len(checks),failed=sum(not c['passed'] for c in checks),
        checks=checks,jvm_started=False,air_started=False,gameplay_qualified=False,performance_qualified=False)
    (HERE/'offline-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False));return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
