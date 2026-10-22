"""Read same-event native buffer snapshots and exact received wall-cell bytes.

No nearest-color/timing match is used. Source hit order is deliberately unknown
when multiple native contacts were first observed in one frame.
"""
import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path


def decode(data):
    assert isinstance(data,str) and data.startswith('!W1:') and len(data)<=13340
    raw=base64.b64decode(data[4:],validate=True);assert len(raw)<=10000
    inflater=zlib.decompressobj();raw=inflater.decompress(raw,9603)
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail and 2<=len(raw)<=9602
    count=struct.unpack_from('>H',raw)[0];assert count<=1600 and len(raw)==2+6*count
    out={};previous=-1
    for i in range(count):
        index,color=struct.unpack_from('>HI',raw,2+6*i);assert previous<index<1600
        out[index]=color;previous=index
    return out


def point(snapshot,x,y):
    values=[]
    for s in snapshot['surfaces']:
        cut=s['cut'];assert len(s['words'])==cut['w']*cut['h']
        if cut['x']<=x<cut['x']+cut['w'] and cut['y']<=y<cut['y']+cut['h']:
            value=s['words'][(y-cut['y'])*cut['w']+x-cut['x']]
            core=s['x']+s['gutter']<=x<s['x']+s['gutter']+s['side'] and s['y']+s['gutter']<=y<s['y']+s['gutter']+s['side']
            values.append(dict(order=s['order'],x=s['x'],y=s['y'],core=core,revision=s['revision'],argb=f'{value:08x}'))
    assert sum(s['core'] for s in values)==1,'Exactly one real core required'
    return dict(seq=snapshot['seq'],kind=snapshot['kind'],at=snapshot['at'],wall=snapshot['wall'],frame=snapshot['frame'],
        sameFrameHitOrderUnknown=snapshot['sameFrameHitOrderUnknown'],values=values)


def analyze_pair(source,remote):
    a,b=source['gutterDiagnostic'],remote['gutterDiagnostic']
    assert source['source'] is True and remote['source'] is False and source['round']==remote['round']==2
    assert source['area']==remote['area'] and a['cell']==b['cell']
    assert source['area']['w']==source['area']['h']==128 and a['cell']['w']==a['cell']['h']==40
    assert len(source['finalNative'])==len(remote['finalNative'])==128*128
    for d in (a,b):
        assert d['active'] and d['diagnosticOnly'] and d['schema']==1 and not d['errors']
        assert d['rawMessageBeforeProduction'] and d['socketSendTimeObserved'] is False and d['nativeImpactOrderObserved'] is False
        assert 0<len(d['snapshots'])<=210 and len(d['packets'])<=96
        assert [s['seq'] for s in d['snapshots']]==list(range(len(d['snapshots'])))
        assert all(0<len(s['surfaces'])<=4 for s in d['snapshots'])
    hits=[s for s in a['snapshots'] if s['kind']=='native-after-hits']
    assert sum(len(s['hits']) for s in hits)==len(source['hits'])>=8
    assert b['packets'],'No actual transmitted cell captured'
    for packet in b['packets']:
        assert len(packet['cells'])==1 and not packet['multipleCellsUnknown']
        assert packet['rawUnchanged'] and packet['cells']==packet['afterCells'],'Actual message fields mutated during dispatch'
        before=b['snapshots'][packet['before']];after=b['snapshots'][packet['after']]
        assert before['kind']=='wire-before' and after['kind']=='wire-after'
        assert before['frame']==packet['frame']==after['frame'] and before['at']<=after['at']
        assert packet['before']<packet['after'],'Message snapshots are not ordered'
    cell=a['cell'];area=source['area'];diff=[];outside=[]
    for i,(v,w) in enumerate(zip(source['finalNative'],remote['finalNative'])):
        if v==w:continue
        x=area['x']+i%128;y=area['y']+i//128
        item=dict(index=i,x=x,y=y,source=f'{v:08x}',remote=f'{w:08x}')
        (diff if cell['x']<=x<cell['x']+40 and cell['y']<=y<cell['y']+40 else outside).append(item)
    requested={(row['x'],row['y']) for row in diff}
    fixed={(source['target']['x']+15,source['target']['y']+5),(source['target']['x']+14,source['target']['y']+6)}
    targets=fixed|set(sorted(requested-fixed)[:14])
    timelines=[]
    for x,y in sorted(targets):
        index=(y-cell['y'])*40+x-cell['x'];wire=[]
        for packet in b['packets']:
            c=packet['cells'][0];words=decode(c['d'])
            assert c['x']*40==cell['x'] and c['y']*40==cell['y']
            wire.append(dict(seq=packet['seq'],wall=packet['wall'],at=packet['at'],version=c['v'],type=packet['type'],
                raw_d_sha256=hashlib.sha256(c['d'].encode('ascii')).hexdigest(),
                wire_argb=None if index not in words else f'{words[index]:08x}',
                before=point(b['snapshots'][packet['before']],x,y),after=point(b['snapshots'][packet['after']],x,y)))
        timelines.append(dict(x=x,y=y,cell_index=index,source=[point(s,x,y) for s in a['snapshots'] if s['kind'] in ('baseline','native-after-hits')],wire=wire))
    return dict(diagnostic_checks_passed=True,diagnostic_only=True,gameplay_qualified=False,performance_qualified=False,
        actual_final_mismatches=diff,outside_observed_cell=outside,all_final_mismatches_observed=not outside,
        all_mismatch_timelines_expanded=requested.issubset(targets),expanded_points_limit=16,
        mismatch_reproduced=bool(diff),timelines=timelines,
        source_hit_observation_batches=len(hits),source_hits=sum(len(s['hits']) for s in hits),
        multiple_hits_same_frame=any(s['sameFrameHitOrderUnknown'] for s in hits),
        exact_native_paint_enumeration_observed=False,root_cause_automatically_declared=False,
        limitation='Wire is the exact received pre-production message, not a source socket timestamp. Same-frame multiple hits have no inferred native ordering.')


def analyze(directory):
    directory=Path(directory);paths={role:directory/'wall-proof'/role/'round-2-proof.json' for role in ('host','join')}
    sources={role:json.loads(path.read_text(encoding='utf-8-sig')) for role,path in paths.items()}
    result=analyze_pair(sources['host'],sources['join'])
    result['inputs']={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths.values()}
    framework=directory/'result.json';result['framework_sha256']=hashlib.sha256(framework.read_bytes()).hexdigest()
    result['framework_passed']=json.loads(framework.read_text(encoding='utf-8-sig'))['passed']
    result['diagnostic_checks_passed'] &= result['framework_passed']
    return result
