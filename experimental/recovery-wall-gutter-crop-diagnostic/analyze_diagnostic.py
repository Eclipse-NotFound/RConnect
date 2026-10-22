"""Exact bounded uint decompression of the original 128x128 proof crop.

Only diagnostic completeness is qualified. Original product assertions/results
and ambiguous same-frame native ordering remain unchanged.
"""
from array import array
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib

MAX_PACKETS=96;MAX_SNAPSHOTS=210;MAX_SURFACES=4
MAX_WIRE_CELLS=25;MAX_WIRE_CHARS=1280640;MAX_DATA_CHARS=6291456


def inflate(text,maximum_text,maximum_compressed,expected):
    assert isinstance(text,str) and 0<len(text)<=maximum_text
    compressed=base64.b64decode(text,validate=True)
    assert base64.b64encode(compressed).decode('ascii')==text,'Noncanonical base64'
    assert 0<len(compressed)<=maximum_compressed
    inflater=zlib.decompressobj();raw=inflater.decompress(compressed,expected+1)
    assert len(raw)==expected and inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
    return raw,len(compressed)


def decode(data):
    assert isinstance(data,str) and data.startswith('!W1:') and len(data)<=13340
    text=data[4:];compressed=base64.b64decode(text,validate=True)
    assert base64.b64encode(compressed).decode('ascii')==text and len(compressed)<=10000
    inflater=zlib.decompressobj();raw=inflater.decompress(compressed,9603)
    assert inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail and 2<=len(raw)<=9602
    count=struct.unpack_from('>H',raw)[0];assert count<=1600 and len(raw)==2+6*count
    out={};previous=-1
    for i in range(count):
        index,color=struct.unpack_from('>HI',raw,2+6*i);assert previous<index<1600
        out[index]=color;previous=index
    return out


def uints(surface):
    cut=surface['cut'];count=cut['w']*cut['h']
    assert all(isinstance(cut[k],int) for k in ('x','y','w','h'))
    assert 0<cut['w']<=128 and 0<cut['h']<=128
    assert surface['encoding']=='u32be-zlib-base64' and surface['wordCount']==count and surface['rawBytes']==count*4
    raw,compressed=inflate(surface['data'],93336,70000,count*4)
    assert compressed==surface['compressedBytes']
    values=array('I');values.frombytes(raw);assert values.itemsize==4
    if sys.byteorder=='little':values.byteswap()
    return values


def intersects(c,crop):
    return c['x']*40<crop['x']+crop['w'] and c['x']*40+40>crop['x'] and c['y']*40<crop['y']+crop['h'] and c['y']*40+40>crop['y']


def unpack(d,crop):
    assert d['schema']==2 and d['active'] and d['diagnosticOnly'] and d['crop']==crop and not d['errors']
    assert d['rawMessageBeforeProduction'] and d['socketSendTimeObserved'] is False and d['nativeImpactOrderObserved'] is False
    assert (d['maxPackets'],d['maxSnapshots'],d['maxSurfaces'],d['maxWireCells'],d['maxWireChars'],d['maxDataChars'])==(
        MAX_PACKETS,MAX_SNAPSHOTS,MAX_SURFACES,MAX_WIRE_CELLS,MAX_WIRE_CHARS,MAX_DATA_CHARS)
    assert 0<len(d['snapshots'])<=MAX_SNAPSHOTS and len(d['packets'])<=MAX_PACKETS
    assert [s['seq'] for s in d['snapshots']]==list(range(len(d['snapshots'])))
    chars=sum(len(s['data']) for row in d['snapshots'] for s in row['surfaces'])
    assert chars==d['encodedChars'] and chars<=MAX_DATA_CHARS
    wire_chars=sum(len(c['d']) for p in d['packets'] for c in p['cells'])
    assert wire_chars==d['wireChars'] and wire_chars<=MAX_WIRE_CHARS
    snapshots=[]
    for row in d['snapshots']:
        assert 0<len(row['surfaces'])<=MAX_SURFACES
        surfaces=[];seen=set();coverage=bytearray(128*128)
        for s in row['surfaces']:
            cut=s['cut'];key=(s['x'],s['y']);assert key not in seen;seen.add(key)
            assert all(isinstance(s[k],int) for k in ('x','y','side','gutter','bufferWidth','bufferHeight'))
            assert s['side']>0 and s['gutter']>=0 and s['bufferWidth']==s['bufferHeight']==s['side']+2*s['gutter']
            left=max(crop['x'],s['x']);top=max(crop['y'],s['y'])
            right=min(crop['x']+128,s['x']+s['bufferWidth']);bottom=min(crop['y']+128,s['y']+s['bufferHeight'])
            assert cut==dict(x=left,y=top,w=right-left,h=bottom-top),'Exact real-buffer/crop intersection required'
            surfaces.append(dict(s,words=uints(s)))
            cx=s['x']+s['gutter'];cy=s['y']+s['gutter']
            for y in range(max(cy,crop['y']),min(cy+s['side'],crop['y']+128)):
                for x in range(max(cx,crop['x']),min(cx+s['side'],crop['x']+128)):
                    i=(y-crop['y'])*128+x-crop['x'];coverage[i]+=1
        assert all(n==1 for n in coverage),'Every original proof pixel requires exactly one observed actual core'
        snapshots.append(dict(row,surfaces=surfaces))
    for packet in d['packets']:
        cells=packet['cells'];assert 0<len(cells)<=MAX_WIRE_CELLS and not packet['duplicateCellsUnknown']
        assert packet['rawUnchanged'] and cells==packet['afterCells'],'Actual received d/v changed during dispatch'
        assert len({(c['x'],c['y']) for c in cells})==len(cells),'Duplicate actual wire cells'
        for c in cells:
            assert isinstance(c['x'],int) and isinstance(c['y'],int) and intersects(c,crop)
            decode(c['d'])
        before=packet['before'];after=packet['after'];assert 0<=before<after<len(snapshots)
        a=snapshots[before];b=snapshots[after]
        assert a['kind']=='wire-before' and b['kind']=='wire-after'
        assert a['frame']==packet['frame']==b['frame'] and a['at']<=b['at']
    return snapshots


def point(snapshot,x,y):
    values=[]
    for s in snapshot['surfaces']:
        cut=s['cut']
        if cut['x']<=x<cut['x']+cut['w'] and cut['y']<=y<cut['y']+cut['h']:
            color=s['words'][(y-cut['y'])*cut['w']+x-cut['x']]
            core=s['x']+s['gutter']<=x<s['x']+s['gutter']+s['side'] and s['y']+s['gutter']<=y<s['y']+s['gutter']+s['side']
            values.append(dict(order=s['order'],x=s['x'],y=s['y'],core=core,revision=s['revision'],argb=f'{color:08x}'))
    assert sum(s['core'] for s in values)==1
    return dict(seq=snapshot['seq'],kind=snapshot['kind'],at=snapshot['at'],wall=snapshot['wall'],frame=snapshot['frame'],
        sameFrameHitOrderUnknown=snapshot['sameFrameHitOrderUnknown'],values=values)


def analyze_pair(source,remote):
    assert source['source'] is True and remote['source'] is False and source['round']==remote['round']==2
    crop=source['area'];assert crop==remote['area'] and crop['w']==crop['h']==128
    assert len(source['finalNative'])==len(remote['finalNative'])==16384
    a,b=source['gutterDiagnostic'],remote['gutterDiagnostic']
    sa,sb=unpack(a,crop),unpack(b,crop)
    hits=[s for s in sa if s['kind']=='native-after-hits']
    assert sum(len(s['hits']) for s in hits)==len(source['hits'])>=8 and b['packets']
    diff=[]
    for i,(v,w) in enumerate(zip(source['finalNative'],remote['finalNative'])):
        if v!=w:diff.append(dict(index=i,x=crop['x']+i%128,y=crop['y']+i//128,source=f'{v:08x}',remote=f'{w:08x}'))
    fixed={(source['target']['x']+15,source['target']['y']+5),(source['target']['x']+14,source['target']['y']+6)}
    requested={(r['x'],r['y']) for r in diff};targets=fixed|set(sorted(requested-fixed)[:14])
    decoded={c['d']:decode(c['d']) for p in b['packets'] for c in p['cells']};timelines=[]
    for x,y in sorted(targets):
        tx=x//40;ty=y//40;index=(y%40)*40+x%40;wire=[]
        for p in b['packets']:
            c=next((c for c in p['cells'] if (c['x'],c['y'])==(tx,ty)),None)
            color=None if c is None else decoded[c['d']].get(index)
            wire.append(dict(seq=p['seq'],wall=p['wall'],at=p['at'],type=p['type'],cell_present=c is not None,
                version=None if c is None else c['v'],wire_argb=None if color is None else f'{color:08x}',
                raw_d_sha256=None if c is None else hashlib.sha256(c['d'].encode('ascii')).hexdigest(),
                before=point(sb[p['before']],x,y),after=point(sb[p['after']],x,y)))
        timelines.append(dict(x=x,y=y,cell=[tx,ty],cell_index=index,
            source=[point(s,x,y) for s in sa if s['kind'] in ('baseline','native-after-hits')],wire=wire))
    return dict(diagnostic_checks_passed=True,diagnostic_only=True,gameplay_qualified=False,performance_qualified=False,
        actual_final_mismatches=diff,all_final_mismatches_observed=True,all_original_crop_core_pixels_observed=True,
        all_mismatch_timelines_expanded=requested.issubset(targets),expanded_points_limit=16,
        mismatch_reproduced=bool(diff),timelines=timelines,source_hit_observation_batches=len(hits),
        source_hits=sum(len(s['hits']) for s in hits),multiple_hits_same_frame=any(s['sameFrameHitOrderUnknown'] for s in hits),
        exact_native_paint_enumeration_observed=False,root_cause_automatically_declared=False,
        limitation='Full original crop, not the whole decal or map. Exact received pre-production messages, not source send times. Same-frame hit and callback order remain unknown.')


def analyze(directory):
    directory=Path(directory);paths={role:directory/'wall-proof'/role/'round-2-proof.json' for role in ('host','join')}
    assert all(path.stat().st_size<=32*1024**2 for path in paths.values()),'Original 32MiB evidence limit retained'
    rows={role:json.loads(path.read_text(encoding='utf-8-sig')) for role,path in paths.items()}
    result=analyze_pair(rows['host'],rows['join'])
    result['inputs']={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths.values()}
    framework=directory/'result.json';result['framework_sha256']=hashlib.sha256(framework.read_bytes()).hexdigest()
    result['framework_passed']=json.loads(framework.read_text(encoding='utf-8-sig'))['passed']
    result['diagnostic_checks_passed'] &= result['framework_passed']
    return result
