"""Collect one bounded CPU JSON after the existing runner exits; never launch AIR."""
import argparse,hashlib,json,os,re,sys,xml.etree.ElementTree as ET
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def validate(p):
    assert p['schema']==1 and p['diagnosticOnly'] is True and p['performanceQualified'] is False
    assert p['role']=='join' and p['round']==0 and p['allocationClassesExported'] is False
    caps=p['caps'];rows=p['cpuRows'];stacks=p['stacks'];markers=p['markers']
    assert caps==dict(cpu=12000,stacks=512,depth=24,name=192,nativePerDrain=250000,markers=64,windowMs=15000)
    assert len(rows)<=caps['cpu'] and len(stacks)<=caps['stacks'] and len(markers)<=caps['markers']
    for s in stacks:assert isinstance(s,list) and len(s)<=caps['depth'] and all(isinstance(n,str) and len(n)<=caps['name'] for n in s)
    last=-1
    for n,t,k in rows:
        assert isinstance(n,(int,float)) and last<n<p['nativeEntries'] and isinstance(t,(int,float)) and t>=0 and isinstance(k,int) and -1<=k<len(stacks)
        last=n
    last=-1
    for m in markers:
        assert last<=m['nativeOrdinal']<=p['nativeEntries'];last=m['nativeOrdinal']
    names=[m['label'] for m in markers]
    usable=p['started'] and p['fault']=='' and bool(rows) and 'grant-handler-before' in names and 'grant-handler-returned' in names and 'baseline-start' in names and 'capture-stop' in names
    complete=usable and not any(p[x] for x in ('cpuDropped','nativeTruncated','stackTruncated','markerTruncated')) and p['stopReason'] in ('input-failure','round0-input-complete')
    return dict(usable_cpu_capture=bool(usable),complete_diagnostic_window=bool(complete),cpu=len(rows),unique_stacks=len(stacks),stop_reason=p['stopReason'])
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--run',required=True);ap.add_argument('--drivers',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
    run=(ROOT/a.run).resolve();drivers=(ROOT/a.drivers).resolve();out=(ROOT/a.output).resolve()
    assert run.parent==ROOT/'build/cooperation' and re.fullmatch('[0-9a-f]{10}',run.name)
    assert out.parent==M52 and not out.exists() and drivers.parent==M52
    meta=read(drivers/'prepared.json');assert meta['compiled'] and meta['diagnostic_kind']=='round0-join-input-cpu'
    for n,h in meta['files'].items():assert sha(drivers/n)==h,n
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    sys.path.insert(0,str(ROOT/'experimental/recovery-seed-raster-control'))
    from control_inputs import audit,host_input,HOST,validate_gate_result
    sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
    audit(Path(meta['candidate']),meta['seed_gate_expect']);installed=installation()
    assert installed==meta['installation_before'];assert host_input(HOST,installed)==meta['native_host']
    actual=read(run/'run.json');assert sha(run/'input.json')==actual['input_manifest_sha256']
    registry=read(run/'registry-result.json')
    assert actual['sha256']==meta['candidate_sha256'] and set(actual['inputs'])=={'host','join'}
    for role,inp in actual['inputs'].items():
        assert inp['production']==meta['candidate_sha256'] and inp['driver']==sha(drivers/'scene/EffectsDriver.swf') and inp['game']==meta['native_host']['candidate_sha256']
    descriptor=run/'descriptors/join.xml';assert sha(descriptor)==actual['descriptors']['join']
    doc=ET.parse(descriptor).getroot();appid=doc.find('{*}id').text
    assert appid=='pfe-modsettings-rconnect-coop-join-'+run.name
    source=Path(os.environ['APPDATA'])/appid/'Local Store/room-input-cpu-profile.json'
    assert source.is_file() and source.stat().st_size<=8*1024*1024
    raw=source.read_bytes();profile=json.loads(raw);assert profile['applicationId']==appid
    status=validate(profile)
    summary=dict(diagnostic_only=True,performance_qualified=False,run=run.name,registry=registry,
        driver_sha256=sha(drivers/'scene/EffectsDriver.swf'),profile_sha256=hashlib.sha256(raw).hexdigest(),
        **status,passed=False,roles={},installation_unchanged=True)
    for role in ('host','join'):
        text=(run/(role+'.log')).read_text('utf-8-sig')
        summary['roles'][role]=dict(checks=len(re.findall('^COOP PASS ',text,re.M)),
            errors=[s for s in text.splitlines() if s.startswith('COOP FAIL ')],
            rows=[json.loads(s.split('TRAVEL RESULT ',1)[1]) for s in text.splitlines() if s.startswith('TRAVEL RESULT ')])
    # Retain the original three-round/ticket requirements even if input fails.
    validate_gate_result(summary,read(drivers/'scene/seed-gate-intent.json'),run,drivers/'scene')
    summary['cpu_phase_summary']=[]
    marks=profile['markers'];rows=profile['cpuRows'];stacks=profile['stacks']
    for i,m in enumerate(marks[:-1]):
        nxt=marks[i+1];counts={}
        for ordinal,stamp,k in rows:
            if m['nativeOrdinal']<=ordinal<nxt['nativeOrdinal']:counts[k]=counts.get(k,0)+1
        summary['cpu_phase_summary'].append(dict(label=m['label'],next=nxt['label'],from_t=m['t'],to_t=nxt['t'],
            cpu=sum(counts.values()),top=[dict(samples=c,stack=stacks[k] if k>=0 else ['<bounded-stack-overflow>']) for k,c in sorted(counts.items(),key=lambda x:-x[1])[:12]]))
    summary['cpu_outside_marker_intervals']=len(rows)-sum(s['cpu'] for s in summary['cpu_phase_summary'])
    out.mkdir();(out/'join-cpu-profile.json').write_bytes(raw)
    (out/'review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in summary.items() if k not in ('roles','cpu_phase_summary')},ensure_ascii=False))
    print('Original functional failures remain; CPU counts are not callback durations or FPS qualification.')
if __name__=='__main__':main()
