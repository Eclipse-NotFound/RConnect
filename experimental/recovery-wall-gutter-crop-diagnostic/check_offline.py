"""Finite observer/codec counterexamples only; never starts JVM or AIR."""
import ast
import base64
import copy
import hashlib
import json
import struct
import zlib
from pathlib import Path
import analyze_diagnostic as a
import generate as g

HERE=Path(__file__).resolve().parent
BASELINE=0xff878881;WRONG=0xff868881
CROP=dict(x=576,y=4396,w=128,h=128)
POINT=(651,4431);INDEX=4555


def compressed(words):
    raw=struct.pack('>'+str(len(words))+'I',*words);wire=zlib.compress(raw)
    return dict(encoding='u32be-zlib-base64',wordCount=len(words),rawBytes=len(raw),compressedBytes=len(wire),
        data=base64.b64encode(wire).decode())


def packed(words):
    raw=struct.pack('>H',len(words))+b''.join(struct.pack('>HI',i,v) for i,v in words)
    return '!W1:'+base64.b64encode(zlib.compress(raw)).decode()


def snap(seq,kind,core_color,gutter_color):
    surfaces=[]
    for order,(x,y) in enumerate(((280,4120),(600,4120),(280,4440),(600,4440))):
        left=max(x,CROP['x']);top=max(y,CROP['y']);right=min(x+400,CROP['x']+128);bottom=min(y+400,CROP['y']+128)
        cut=dict(x=left,y=top,w=right-left,h=bottom-top);words=[BASELINE]*(cut['w']*cut['h'])
        px,py=POINT
        if left<=px<right and top<=py<bottom:
            core=x+40<=px<x+360 and y+40<=py<y+360
            words[(py-top)*cut['w']+px-left]=core_color if core else gutter_color
        surfaces.append(dict(order=order,x=x,y=y,side=320,gutter=40,revision=1,bufferWidth=400,bufferHeight=400,
            cut=cut,**compressed(words)))
    return dict(seq=seq,kind=kind,at=10+seq,wall=1000+seq,frame=2,cost=0,
        hits=[{}]*8 if kind=='native-after-hits' else [],sameFrameHitOrderUnknown=kind=='native-after-hits',surfaces=surfaces)


def pair():
    def diag(snaps,packets):
        return dict(schema=2,diagnosticOnly=True,active=True,crop=CROP.copy(),errors=[],
            rawMessageBeforeProduction=True,socketSendTimeObserved=False,nativeImpactOrderObserved=False,
            snapshots=snaps,packets=packets,maxPackets=96,maxSnapshots=210,maxSurfaces=4,maxWireCells=25,
            maxWireChars=1280640,maxDataChars=6291456,
            encodedChars=sum(len(s['data']) for row in snaps for s in row['surfaces']),
            wireChars=sum(len(c['d']) for p in packets for c in p['cells']))
    # The source core remains baseline but a gutter differs. This is only a
    # synthetic counterexample; the real 7855 run did not observe this point.
    source=diag([snap(0,'baseline',BASELINE,BASELINE),snap(1,'native-after-hits',BASELINE,WRONG)],[])
    cells=[dict(x=16,y=110,v=1,d=packed([(1251,WRONG)])),dict(x=16,y=111,v=3,d=packed([(0,BASELINE)]))]
    packet=dict(seq=0,at=10,wall=1000,frame=2,type='worldstate',cells=cells,afterCells=copy.deepcopy(cells),
        rawUnchanged=True,duplicateCellsUnknown=False,before=1,after=2)
    remote=diag([snap(0,'baseline',BASELINE,BASELINE),snap(1,'wire-before',BASELINE,BASELINE),snap(2,'wire-after',WRONG,WRONG)],[packet])
    def row(is_source,d):
        final=[BASELINE]*16384
        if not is_source:final[INDEX]=WRONG
        return dict(source=is_source,round=2,area=CROP.copy(),target=dict(x=640,y=4460),
            hits=[{}]*8 if is_source else [],finalNative=final,gutterDiagnostic=d)
    return row(True,source),row(False,remote)


def main():
    checks=[]
    def test(label,fn):
        try:fn();checks.append(dict(label=label,passed=True))
        except Exception as e:checks.append(dict(label=label,passed=False,error=repr(e)))
    def exact_strip():
        old=(g.BASE/g.ACTOR).read_text(encoding='utf-8-sig');new,edits=g.apply(old)
        assert new==(HERE/'tests'/g.ACTOR).read_text(encoding='utf-8-sig')
        for before,after in reversed(edits):assert new.count(after)==1;new=new.replace(after,before)
        assert new==old and g.sha(g.BASE/g.ACTOR)==g.ACTOR_SHA and g.sha(HERE/'tests'/g.PROBE)==g.PROBE_SHA
        assert g.sha(HERE/'verify_results.py')=='a3e8d886772d8facada4363331e79b6277c582b316f05c00e360e7edd247e874'
    test('original driver04 stimulus and assertions recovered exactly; original analyzer preserved',exact_strip)
    def hot_paths():
        source=(HERE/'tests/NativeWallColorProbe.as').read_text();hot=source.split('private static function encoded(',1)[0]
        for banned in ('getVector(','.encode(','.setPixel32(','.setVector(','.send(','.receive(','.report(','.checkpoint(','.compress('):
            assert banned not in hot,banned
        assert 'MAX_PACKETS:int=96,MAX_SNAPSHOTS:int=210,MAX_SURFACES:int=4' in hot
        assert 'MAX_WIRE_CELLS:int=25,MAX_WIRE_CHARS:int=1280640,MAX_DATA_CHARS:int=6291456' in hot
        assert 'new Rectangle(target.x-64,target.y-64,128,128)' in hot
        assert 'Endian.BIG_ENDIAN' in source and 'bytes.writeUnsignedInt(value)' in source
        assert 'beforeMessage,false,100000' in hot and 'afterMessage,false,-100000' in hot
        assert 's.bitmap=null' in source and 'if(s.bitmap!=null)' in source
    test('bounded full crop read-only snapshots; uint readback/compression only after both samplers stop',hot_paths)
    def prior_failure():
        root=g.ROOT/'build/m52/recovery18-wall-gutter-native-01/wall-proof'
        x=json.loads((root/'host/round-2-proof.json').read_text());y=json.loads((root/'join/round-2-proof.json').read_text())
        assert x['area']==CROP==y['area']
        assert [i for i in range(16384) if x['finalNative'][i]!=y['finalNative'][i]]==[INDEX]
        assert x['finalNative'][INDEX]==BASELINE and y['finalNative'][INDEX]==WRONG
        assert all(INDEX not in dict(zip(f['native'][::2],f['native'][1::2])) for f in x['frames'])
        assert POINT==(CROP['x']+INDEX%128,CROP['y']+INDEX//128)
    test('new boundary covers actual (651,4431) source-baseline false-positive mark',prior_failure)
    def positive():
        result=a.analyze_pair(*pair());assert result['diagnostic_checks_passed'] and result['all_final_mismatches_observed']
        assert result['all_original_crop_core_pixels_observed'] and result['actual_final_mismatches'][0]['index']==INDEX
        t=next(t for t in result['timelines'] if (t['x'],t['y'])==POINT)
        assert [v['argb'] for v in t['source'][-1]['values'] if v['core']]==['ff878881']
        assert any(v['argb']=='ff868881' for v in t['source'][-1]['values'] if not v['core'])
        assert t['wire'][0]['wire_argb']=='ff868881' and all(v['argb']=='ff868881' for v in t['wire'][0]['after']['values'])
        assert not result['root_cause_automatically_declared'] and not result['gameplay_qualified'] and not result['performance_qualified']
    test('same received packet holds multiple cells; outside-old-cell full causal evidence retained',positive)
    def no_repro():
        x,y=pair();y['finalNative']=x['finalNative'].copy();r=a.analyze_pair(x,y)
        assert not r['mismatch_reproduced'] and not r['root_cause_automatically_declared']
    test('non-reproduction is never root-cause or product qualification',no_repro)
    def codec():
        words=[((i*2654435761)^0x80ff00fe)&0xffffffff for i in range(16384)]
        s=dict(cut=dict(x=0,y=0,w=128,h=128),**compressed(words));assert list(a.uints(s))==words
        assert words[0]!=int.from_bytes(words[0].to_bytes(4,'big'),'little')
        words=[0,0xffffffff,0xff43433c,0xf664625b,0xee595953,0xe64d4d48]
        s=dict(cut=dict(x=0,y=0,w=6,h=1),**compressed(words));assert list(a.uints(s))==words
    test('full16384 exact big-endian uint roundtrip including original opaque/alpha counterexamples',codec)
    def negative(label,mutate):
        def check():
            x,y=pair();mutate(x,y)
            try:a.analyze_pair(x,y)
            except (AssertionError,KeyError,IndexError,ValueError,zlib.error):return
            raise AssertionError('Invalid or incomplete observation accepted')
        test(label,check)
    negative('missing core for any crop pixel rejected',lambda x,y:y['gutterDiagnostic']['snapshots'][1]['surfaces'].pop(1))
    negative('duplicate physical buffer rejected',lambda x,y:y['gutterDiagnostic']['snapshots'][1]['surfaces'].__setitem__(0,copy.deepcopy(y['gutterDiagnostic']['snapshots'][1]['surfaces'][1])))
    negative('actual raw d/version mutation rejected',lambda x,y:y['gutterDiagnostic']['packets'][0]['afterCells'][0].update(v=99))
    negative('different event frame rejected',lambda x,y:y['gutterDiagnostic']['snapshots'][2].update(frame=3))
    negative('missing after callback rejected',lambda x,y:y['gutterDiagnostic']['packets'][0].update(after=-1))
    negative('original crop truncated rejected',lambda x,y:y.update(finalNative=[]))
    negative('snapshot or wire capacity error remains failure',lambda x,y:y['gutterDiagnostic'].update(errors=['capacity exceeded']))
    negative('diagnostic budget cannot be silently raised',lambda x,y:y['gutterDiagnostic'].update(maxDataChars=99999999))
    negative('declared wordcount inconsistent rejected',lambda x,y:y['gutterDiagnostic']['snapshots'][0]['surfaces'][0].update(wordCount=1))
    negative('encoded aggregate accounting inconsistent rejected',lambda x,y:y['gutterDiagnostic'].update(encodedChars=0))
    def geometry_gap(x,y):
        d=y['gutterDiagnostic'];d['snapshots'][1]['surfaces'].pop(1)
        d['encodedChars']=sum(len(s['data']) for r in d['snapshots'] for s in r['surfaces'])
    negative('core coverage gap rejected even with valid aggregate bookkeeping',geometry_gap)
    def duplicate_cell(x,y):
        d=y['gutterDiagnostic'];p=d['packets'][0]
        p['cells'].append(copy.deepcopy(p['cells'][0]));p['afterCells']=copy.deepcopy(p['cells'])
        d['wireChars']=sum(len(c['d']) for row in d['packets'] for c in row['cells'])
    negative('duplicate actual cells rejected despite exact before/after and valid byte count',duplicate_cell)
    def outside_cell(x,y):
        p=y['gutterDiagnostic']['packets'][0];p['cells'][0]['y']=0;p['afterCells']=copy.deepcopy(p['cells'])
    negative('wire cells outside original proof crop rejected',outside_cell)
    def zlib_limits():
        def reject(text,size):
            try:a.inflate(text,93336,70000,size)
            except (AssertionError,ValueError,zlib.error):return
            raise AssertionError('Invalid compressed data accepted')
        valid=zlib.compress(bytes(4))
        reject(base64.b64encode(valid+b'garbage').decode(),4)
        reject(base64.b64encode(zlib.compress(bytes(65540))).decode(),65536)
        reject(base64.b64encode(valid[:-1]).decode(),4)
        reject('invalid!',4)
    test('bounded inflate rejects excess output, trailing bytes, truncation and malformed base64',zlib_limits)
    def syntax():
        for f in HERE.glob('*.py'):ast.parse(f.read_text(encoding='utf-8'))
    test('Python syntax',syntax)
    result=dict(passed=all(c['passed'] for c in checks),count=len(checks),failed=sum(not c['passed'] for c in checks),checks=checks,
        jvm_started=False,air_started=False,production_modified=False,gameplay_qualified=False,performance_qualified=False)
    (HERE/'offline-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False));return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
