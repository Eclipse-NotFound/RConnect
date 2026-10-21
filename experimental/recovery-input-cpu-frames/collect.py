"""Collect bounded per-frame CPU evidence after the existing runner; never launches AIR."""
import argparse,hashlib,json,math,os,re,sys,xml.etree.ElementTree as ET
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
CAPS=dict(windows=6,cpu=12000,stacks=512,depth=24,name=192,nativePerWindow=250000,markers=64,frames=256,windowMs=15000)

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def integer(n):return isinstance(n,int) and not isinstance(n,bool)
def finite(n):return isinstance(n,(int,float)) and not isinstance(n,bool) and math.isfinite(n)

def validate(p):
    assert p['schema']==2 and p['diagnosticOnly'] is True and p['performanceQualified'] is False
    assert p['role']=='join' and p['round']==0 and p['allocationClassesExported'] is False and p['samplerCallbackUsed'] is False
    assert p['caps']==CAPS and p['countsAreNotDurations'] is True
    windows=p['windows'];frames=p['frames'];markers=p['markers']
    assert p['selectedWindows']==len(windows)<=CAPS['windows'] and len(frames)<=CAPS['frames'] and len(markers)<=CAPS['markers']
    for key in ('observedFrames','selectedWindows','skippedFrames','unrecordedFrames','duplicateRenders','markerDropped','cpuKept','stacksKept'):
        assert integer(p[key]) and p[key]>=0,key
    assert p['observedFrames']==len(frames)+p['unrecordedFrames']
    assert p['skippedFrames']==p['observedFrames']-p['selectedWindows']
    total_cpu=total_stacks=duplicates=0;valid_ids=[];last_frame=p['grantFrame'];last_end=p['armAt']
    for i,w in enumerate(windows):
        assert w['id']==i and integer(w['frame']) and w['frame']>last_frame
        assert finite(w['startAt']) and finite(w['endAt']) and last_end<=w['startAt']<=w['endAt']
        last_frame=w['frame'];last_end=w['endAt']
        assert isinstance(w['valid'],bool) and isinstance(w['invalidReasons'],list)
        assert len(w['invalidReasons'])==len(set(w['invalidReasons'])) and all(isinstance(x,str) and 0<len(x)<=80 for x in w['invalidReasons'])
        for k in ('startNative','endNative','lastNative','nativeScanned','cpuDropped','duplicateRenders','beginCostMs','closeCostMs','scanCostMs'):
            assert finite(w[k]) and w[k]>=0,(i,k)
        assert w['nativeScanned']<=CAPS['nativePerWindow']
        assert w['closeReason'] in ('render','missing-render','stop-before-render','start-failed')
        assert isinstance(w['nativeScanComplete'],bool) and isinstance(w['nativeTruncated'],bool) and isinstance(w['stackTruncated'],bool)
        rows=w['cpuRows'];stacks=w['stacks'];duplicates+=w['duplicateRenders']
        if not w['valid']:
            assert w['invalidReasons'] and rows==[] and stacks==[], 'Invalid windows must not supply CPU stacks'
            continue
        assert w['closeReason']=='render' and w['invalidReasons']==[]
        assert w['endAt']-w['startAt']<=CAPS['windowMs']
        assert w['nativeScanComplete'] and w['nativeScanned']==w['endNative']<=CAPS['nativePerWindow']
        assert w['endNative']>=max(w['startNative'],w['lastNative'])
        assert not w['nativeTruncated'] and not w['stackTruncated'] and w['cpuDropped']==0 and rows
        assert len(rows)<=CAPS['cpu'] and len(stacks)<=CAPS['stacks']
        for stack in stacks:
            assert isinstance(stack,list) and len(stack)<=CAPS['depth']
            assert all(isinstance(n,str) and len(n.encode('utf-16-le'))//2<=CAPS['name'] for n in stack)
        last=-1
        for ordinal,stamp,k in rows:
            assert integer(ordinal) and last<ordinal<w['endNative'] and finite(stamp) and stamp>=0
            assert integer(k) and 0<=k<len(stacks);last=ordinal
        valid_ids.append(i);total_cpu+=len(rows);total_stacks+=len(stacks)
    assert total_cpu==p['cpuKept']<=CAPS['cpu'] and total_stacks==p['stacksKept']<=CAPS['stacks']
    assert duplicates==p['duplicateRenders']
    last_frame=p['grantFrame'];selected_rows=[]
    for f in frames:
        assert integer(f['frame']) and f['frame']>last_frame;last_frame=f['frame']
        assert isinstance(f['selected'],bool) and finite(f['t'])
        if f['selected']:
            i=f['window'];assert integer(i) and 0<=i<len(windows)
            assert f['reason']=='selected-first-six' and f['frame']==windows[i]['frame'];selected_rows.append(i)
        else:assert f['window']==-1 and f['reason']=='selection-cap'
    assert selected_rows==list(range(len(windows))), 'Every selected window must have exactly one frame row'
    marker_counts={};last_t=-1
    for mark in markers:
        assert finite(mark['t']) and mark['t']>=last_t;last_t=mark['t']
        assert isinstance(mark['label'],str) and len(mark['label'])<=80
        i=mark['window'];count=mark['nativeCount'];assert integer(i)
        if i==-1:assert count==-1
        else:
            assert 0<=i<len(windows) and finite(count) and count>=0 and mark['frame']==windows[i]['frame']
            if windows[i]['valid']:
                assert marker_counts.get(i,windows[i]['startNative'])<=count<=windows[i]['endNative']
                marker_counts[i]=count
    assert p['stopReason'] in ('input-failure','round0-input-complete','fixture-finish','diagnostic-window-cap')
    if p['armed']:
        assert finite(p['armAt']) and p['armAt']>=0 and p['stopAt']>=p['armAt']
        assert markers and markers[0]['label']=='grant-handler-returned'
    else:assert windows==[] and frames==[] and total_cpu==0
    usable=p['armed'] and bool(valid_ids)
    complete=usable and len(windows)==CAPS['windows'] and len(valid_ids)==len(windows)
    complete=complete and not p['unrecordedFrames'] and not p['markerDropped'] and p['stopReason'] in ('input-failure','round0-input-complete')
    return dict(usable_cpu_capture=bool(usable),complete_selected_frame_capture=bool(complete),
        valid_windows=valid_ids,invalid_windows=[dict(id=w['id'],frame=w['frame'],reasons=w['invalidReasons']) for w in windows if not w['valid']],
        selected_windows=len(windows),cpu=total_cpu,unique_stacks=total_stacks,stop_reason=p['stopReason'],
        skipped_frames=p['skippedFrames'],unrecorded_frames=p['unrecordedFrames'])

def summaries(profile):
    out=[]
    for w in profile['windows']:
        row={k:w[k] for k in ('id','frame','startAt','endAt','valid','invalidReasons','closeReason','scanCostMs','closeCostMs','contextStart','contextEnd')}
        row['cpu']=len(w['cpuRows']);row['top']=[]
        if w['valid']:
            counts={}
            for ordinal,stamp,k in w['cpuRows']:counts[k]=counts.get(k,0)+1
            row['top']=[dict(samples=n,stack=w['stacks'][k]) for k,n in sorted(counts.items(),key=lambda x:-x[1])[:12]]
        out.append(row)
    return out

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run',required=True);ap.add_argument('--drivers',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
    run=(ROOT/a.run).resolve();drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
    assert run.parent==ROOT/'build/cooperation' and re.fullmatch('[0-9a-f]{10}',run.name)
    assert out.parent==M52 and not out.exists() and drivers.parent==M52
    meta=read(drivers/'prepared.json');assert meta['compiled'] and meta['diagnostic_kind']=='round0-join-input-cpu-frames'
    for n,h in meta['files'].items():assert sha(drivers/n)==h,n
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    sys.path.insert(0,str(ROOT/'experimental/recovery-seed-raster-control'))
    from control_inputs import audit,host_input,HOST,validate_gate_result
    sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
    audit(Path(meta['candidate']),meta['seed_gate_expect']);installed=installation()
    assert len(installed)==22 and installed==meta['installation_before'] and host_input(HOST,installed)==meta['native_host']
    actual=read(run/'run.json');assert sha(run/'input.json')==actual['input_manifest_sha256']
    registry=read(run/'registry-result.json')
    assert actual['sha256']==meta['candidate_sha256'] and set(actual['inputs'])=={'host','join'}
    for role,inp in actual['inputs'].items():
        assert inp['production']==meta['candidate_sha256'] and inp['driver']==sha(drivers/'scene/EffectsDriver.swf') and inp['game']==meta['native_host']['candidate_sha256']
        assert inp['harness']==sha(drivers/'scene/EffectsHarness.swf')
    descriptor=run/'descriptors/join.xml';assert sha(descriptor)==actual['descriptors']['join']
    appid=ET.parse(descriptor).getroot().find('{*}id').text
    assert appid=='pfe-modsettings-rconnect-coop-join-'+run.name
    source=Path(os.environ['APPDATA'])/appid/'Local Store/room-input-cpu-frames.json'
    assert source.is_file() and source.stat().st_size<=16*1024*1024
    raw=source.read_bytes();profile=json.loads(raw);assert profile['applicationId']==appid
    # Keep invalid captures and their reason; never derive stacks from rejected data.
    validation_errors=[]
    try:status=validate(profile)
    except (AssertionError,KeyError,TypeError,ValueError) as error:
        validation_errors=[str(error) or type(error).__name__]
        status=dict(usable_cpu_capture=False,complete_selected_frame_capture=False)
    summary=dict(diagnostic_only=True,performance_qualified=False,run=run.name,registry=registry,
        driver_sha256=sha(drivers/'scene/EffectsDriver.swf'),profile_sha256=hashlib.sha256(raw).hexdigest(),
        **status,validation_errors=validation_errors,passed=False,roles={},installation_unchanged=True)
    for role in ('host','join'):
        text=(run/(role+'.log')).read_text('utf-8-sig')
        summary['roles'][role]=dict(checks=len(re.findall('^COOP PASS ',text,re.M)),
            errors=[s for s in text.splitlines() if s.startswith('COOP FAIL ')],
            rows=[json.loads(s.split('TRAVEL RESULT ',1)[1]) for s in text.splitlines() if s.startswith('TRAVEL RESULT ')])
    validate_gate_result(summary,read(drivers/'scene/seed-gate-intent.json'),run,drivers/'scene')
    summary['cpu_window_summary']=[] if validation_errors else summaries(profile)
    assert installation()==installed
    out.mkdir();(out/'join-cpu-frames.json').write_bytes(raw)
    (out/'review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in summary.items() if k not in ('roles','cpu_window_summary')},ensure_ascii=False))
    print('Original functional failures remain. Unselected/invalid windows have no inferred stacks; diagnostic timing is not qualification.')

if __name__=='__main__':main()
