"""Sampled native gas correspondence: private playback cursor remains unobserved."""
import argparse
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path

def finite(v):return type(v) in (int,float) and math.isfinite(v)
def pose_match(a,b):
    if not all(finite(a.get(k)) and finite(b.get(k)) and abs(a[k]-b[k])<=t
               for k,t in [('x',.1),('y',.1),('r',.1),('sx',.001),('sy',.001),('a',.01)]):return False
    ca,cb=a.get('c'),b.get('c')
    return (a.get('f')==b.get('f') and a.get('visible',a.get('v'))==b.get('visible',b.get('v'))
        and isinstance(ca,list) and isinstance(cb,list) and len(ca)==len(cb)==8
        and all(finite(x) and finite(y) and abs(x-y)<=.01 for x,y in zip(ca,cb)))
def intervals(values):
    values=sorted(v for v in values if finite(v))
    return [values[n]-values[n-1] for n in range(1,len(values))]
def increasing(rows,key):
    return bool(rows) and all(finite(r.get(key)) for r in rows) and all(rows[n][key]>rows[n-1][key] for n in range(1,len(rows)))
def unique_rows(rows,key):return len({r.get(key) for r in rows})==len(rows)
def observation_valid(sample):
    return (finite(sample.get('at')) and finite(sample.get('observedAt'))
        and sample['observedAt']>=sample['at'] and type(sample.get('revision')) is int
        and sample['revision']>=0 and type(sample.get('frame')) is int
        and sample.get('sampleId')==str(sample['frame'])+':'+str(sample['revision']))

def validate(value,source,requested):
    errors=[]
    def need(ok,label):
        if not ok:errors.append(label)
    need(value.get('source') is source and value.get('id')=='gasgr' and value.get('requested')==requested,'trial identity')
    p=value.get('proof') or {};native=p.get('nativeRows') or [];visual=p.get('visualRows') or [];wire=p.get('wireRows') or []
    need(p.get('observationSchema')=='first-time-final-pose-capture-revision-v2','exact observation schema')
    need(p.get('overflow') is False and p.get('allEnded') is True,'bounded complete evidence')
    need(p.get('clockObservation')=='source-frame-bounds-only' and p.get('playbackCursorObserved') is False,'honest source-clock observation boundary')
    need(finite(p.get('quietMs')) and p['quietMs']>=500 and finite(p.get('lastActivity'))
        and p.get('readbackAt',0)-p['lastActivity']==p['quietMs'],'500ms after last removal/new gas packet, not merely birth')
    need(0<len(visual)<=96 and unique_rows(visual,'id'),'actual unique displayed gas identities')
    pixel=p.get('pixel') or {};need(pixel.get('pixels',0)>0,'stage pixel difference')
    need(finite(p.get('readbackAt')) and finite(pixel.get('at')) and p['readbackAt']>=pixel['at'],'deferred pixel readback')
    for row in visual:
        samples=row.get('samples') or []
        need(row.get('cls')=='visualGas' and 0<len(samples)<=128 and increasing(samples,'at') and increasing(samples,'frame'),'ordered gas artwork observations')
        need(row.get('reappeared') is not True,'removed display never reappears during quiet observation')
        need(row.get('endAt',0)>row.get('bornAt',0) and p.get('readbackAt',0)>=row.get('endAt',math.inf),'ended before readback')
        need(p.get('lastActivity',0)>=row.get('endAt',math.inf),'quiet horizon includes last display removal')
        need(samples and samples[0]['at']==row.get('bornAt') and samples[-1]['at']<row.get('endAt',0),'display birth/end bracket all recorded poses')
        need(all(observation_valid(s) and s['observedAt']<row.get('endAt',0) for s in samples),'actual final observation remains inside lifetime')
        captures=row.get('captures') or []
        need(len(captures)<=1 and unique_rows(captures,'sampleId'),'bounded immutable capture revisions')
        for capture in captures:
            peers=[s for s in samples if s['frame']==capture.get('frame') and s['at']==capture.get('at')]
            need(observation_valid(capture) and len(peers)==1
                and capture['observedAt']<=peers[0]['observedAt'] and capture['revision']<=peers[0]['revision']
                and (capture['revision']!=peers[0]['revision'] or pose_match(capture,peers[0])),
                'capture revision belongs to its actual frame and precedes final observation')
        need(row.get('alphaMax',0)>=row.get('alphaMin',1),'native alpha range')
    pixel_rows=[r for r in visual if r.get('id')==pixel.get('visual')]
    pixel_samples=[s for r in pixel_rows for s in r.get('captures',[]) if s.get('frame')==pixel.get('frame')
        and s.get('at')==pixel.get('sampleAt') and s.get('sampleId')==pixel.get('sampleId')
        and s.get('observedAt')==pixel.get('observedAt')]
    need(len(pixel_rows)==len(pixel_samples)==1 and pose_match(pixel_samples[0],pixel.get('pose') or {})
         and pose_match(pixel.get('pose') or {},pixel.get('afterPose') or {})
         and pixel.get('at',0)>=pixel_samples[0]['observedAt'],'pixel metadata binds one immutable actual object/frame/revision/pose')
    need(sum(len(r.get('captures') or []) for r in visual)==1,'exactly one captured object observation per trial')
    if source:
        need(value.get('shots')==requested and value.get('inputReleased',0)>0,'actual G count and release')
        gates=value.get('throwGates') or []
        need(len(gates)==max(0,requested-1),'one native release-readiness gate per repeated G')
        shots=value.get('shotRows') or []
        for i,gate in enumerate(gates):
            need(gate.get('afterShot')==i+1 and gate.get('tAuto')==0 and gate.get('attackPos') is True
                and gate.get('tAttack',1)<=0 and gate.get('tReload',1)<=0
                and finite(gate.get('frame')) and finite(gate.get('afterFrame')) and gate['frame']>gate['afterFrame']
                and len(shots)>i+1 and shots[i]['born']<gate.get('at',0)<=shots[i+1]['born'],
                'repeated G follows actual native latch expiry after prior projectile birth')
        need(requested==1 or value.get('overlap') is True,'two live native projectiles overlap')
        need(0<len(native)==len(visual) and unique_rows(native,'id') and unique_rows(native,'visual') and not wire,'source actual Part-to-visual identity map')
        for row in native:
            need(row.get('partClass')=='fe.graph::Part' and row.get('cls')=='visualGas' and row.get('reappeared') is not True,'native source identity')
            need(row.get('endAt',0)>row.get('bornAt',0) and row.get('finalLiv',math.inf)<=0,'native source lifetime expiry')
            linked=[r for r in visual if r.get('id')==row.get('visual')]
            first=linked[0]['samples'][0] if len(linked)==1 and linked[0].get('samples') else {}
            need(len(linked)==1 and all(finite(row.get(k)) and finite(first.get(k)) and abs(row[k]-first[k])<=.1 for k in ('x','y'))
                and row.get('bornFrame')==first.get('frame'),'Part reference links its own first displayed position/frame')
            need(all(finite(row.get(k)) for k in ('bornLo','bornHi','endLo','endHi')) and
                row['bornLo']<=row['bornHi']<=row['bornAt'] and row['endLo']<=row['endHi']<=row['endAt'],'native source frame-time brackets')
        need(len(value.get('shotRows',[]))==requested,'actual bullet identity records')
        for row in value.get('shotRows',[]):need(row.get('end',0)>=row.get('exploded',0)>row.get('born',0),'real native detonation then removal')
    else:
        need(not native and value.get('unexpected')==0,'no native Part/projectile replay loop')
        need(len(wire)==len(visual)>0 and unique_rows(wire,'key'),'unique wire and display counts')
        for row in wire:
            need(row.get('end',0)>0 and row.get('strictEnd') is True and increasing(row.get('frames') or [],'at'),'true ordered source trajectory and terminal in wire')
            need(row.get('outOfOrder') is not True and row.get('endChanged') is not True,'wire history/end cannot change backwards')
            need(finite(row.get('endReceivedAt')) and finite(row.get('endReceivedWall')) and
                 row['endReceivedAt']>=row.get('firstAt',math.inf) and p.get('lastActivity',0)>=row['endReceivedAt'],'actual terminal receipt time')
    return errors

def source_match(native,visual,wire):
    """All source observations align with actual source-stamped wire frames."""
    samples=visual['samples'];frames=wire['frames']
    if len(samples)!=len(frames) or not samples:return False
    if not increasing(samples,'at') or not increasing(frames,'at'):return False
    if not all(finite(native.get(k)) and abs(native[k]-samples[0][k])<=.1 for k in ('x','y')):return False
    if native.get('bornFrame')!=samples[0].get('frame'):return False
    if not (native['endLo']<=wire['end']<=native['endHi']):return False
    if not all(s['sourceLo']<=f['at']<=s['sourceHi'] and pose_match(s,f) for s,f in zip(samples,frames)):return False
    return all(sum(c['sourceLo']<=f['at']<=c['sourceHi'] and pose_match(c,f) for f in frames)==1
               for c in visual.get('captures',[]))

def display_match(visual,wire):
    """Repeated/skipped source samples are allowed; backwards/invented poses aren't.
    Final observed artwork and native terminal receipt are both mandatory."""
    samples=visual['samples'];frames=wire['frames'];chosen=[];index=0
    if not samples or not frames:return None
    if not increasing(samples,'at') or not increasing(samples,'frame') or not increasing(frames,'at'):return None
    if samples[0]['at']!=visual.get('bornAt') or samples[-1]['at']>=visual.get('endAt',0):return None
    for sample in samples:
        found=next((i for i in range(index,len(frames)) if pose_match(sample,frames[i])),None)
        if found is None:return None
        chosen.append(found);index=found
    if not pose_match(samples[-1],frames[-1]):return None
    if visual['endAt']<wire['endReceivedAt'] or visual['endWall']<wire['endReceivedWall']:return None
    for capture in visual.get('captures',[]):
        slots=[i for i,s in enumerate(samples) if s['frame']==capture.get('frame') and s['at']==capture.get('at')]
        if len(slots)!=1:return None
        slot=slots[0];lo=chosen[slot-1] if slot else 0;hi=chosen[slot]
        if not any(pose_match(capture,frames[i]) for i in range(lo,hi+1)):return None
    return chosen

def compare(origin,remote):
    a=origin['proof'];b=remote['proof'];errors=[];matches=[]
    if not a['nativeRows'] or len(a['nativeRows'])!=len(b['wireRows']) or len(a['nativeRows'])!=len(b['visualRows']):
        errors.append('actual source/wire/visual count mismatch')
    native_by_wire={};display_by_wire={}
    for n in a['nativeRows']:
        linked=[v for v in a['visualRows'] if v['id']==n.get('visual')]
        choices=[w for w in b['wireRows'] if len(linked)==1 and source_match(n,linked[0],w)]
        if len(choices)!=1:
            errors.append('source Part has missing/ambiguous complete wire history id='+str(n['id']));continue
        key=choices[0]['key']
        if key in native_by_wire:errors.append('two source Parts claim one wire identity '+key)
        native_by_wire[key]=n
    for v in b['visualRows']:
        choices=[(w,display_match(v,w)) for w in b['wireRows']]
        choices=[(w,indices) for w,indices in choices if indices is not None]
        if len(choices)!=1:
            errors.append('display has missing/ambiguous ordered trajectory, missing final source pose, or premature terminal id='+str(v['id']));continue
        w,indices=choices[0];key=w['key']
        if key in display_by_wire:errors.append('two displays claim one wire identity '+key)
        display_by_wire[key]=v;n=native_by_wire.get(key)
        if n is None:continue
        matches.append(dict(sourcePart=n['id'],sourceVisual=n['visual'],wire=key,remoteVisual=v['id'],
            sourceFrameCount=len(w['frames']),displaySampleCount=len(v['samples']),displayedDistinctSourceSamples=len(set(indices)),
            receiveToDisplayMs=v['bornWall']-w['firstWall'],sourceNativeEndBounds=[n['endLo'],n['endHi']],wireNativeEnd=w['end'],
            terminalReceiveWall=w['endReceivedWall'],displayEndWall=v['endWall'],
            terminalReceiptToRemovalMs=v['endWall']-w['endReceivedWall']))
    expected={w['key'] for w in b['wireRows']}
    if set(native_by_wire)!=expected or set(display_by_wire)!=expected:errors.append('incomplete unique source-to-wire-to-display bijection')
    return errors,matches

def read_cases(host_log,join_log):
    cases={};errors=[]
    for role,path in [('host',host_log),('join',join_log)]:
        for line in path.read_text(encoding='utf-8-sig',errors='replace').splitlines():
            if line.startswith('COOP FAIL '):errors.append(role+': '+line)
            if not line.startswith('GAS PULSE RESULT '):continue
            try:
                r=json.loads(line[len('GAS PULSE RESULT '):]);n=r['round']
                if r.get('role')!=role or n not in range(4) or (role,n) in cases:raise ValueError('invalid/duplicate round')
                cases[(role,n)]=r['value']
            except (KeyError,TypeError,ValueError) as e:errors.append(role+': malformed evidence '+str(e))
    return cases,errors

def analyze(host_log,join_log):
    cases,errors=read_cases(host_log,join_log);comparisons=[]
    for (role,n),v in cases.items():
        try:errors += [role+' round='+str(n)+': '+e for e in validate(v,(role=='host')==(n%2==0),1 if n<2 else 2)]
        except (KeyError,TypeError,ValueError,IndexError):errors.append(role+' malformed trajectory evidence')
    for n in range(4):
        if ('host',n) not in cases or ('join',n) not in cases:errors.append('missing two-sided round '+str(n));continue
        a,b=cases[('host',n)],cases[('join',n)];origin,remote=(a,b) if n%2==0 else (b,a)
        try:bad,matches=compare(origin,remote)
        except (KeyError,TypeError,ValueError,IndexError):bad,matches=['malformed correspondence evidence'],[]
        errors += ['round='+str(n)+': '+e for e in bad]
        comparisons.append(dict(round=n,passed=not bad,matches=matches,
            sourceBirthIntervalsMs=intervals([r.get('bornAt') for r in origin.get('proof',{}).get('nativeRows',[])]),
            displayBirthIntervalsMs=intervals([r.get('bornAt') for r in remote.get('proof',{}).get('visualRows',[])])))
    return dict(passed=not errors,errors=errors,observed_results=len(cases),comparisons=comparisons,
        functional_only=True,sampledTrajectoryQualified=not errors,fullLifecycleQualified=False,
        cursorAlignmentQualified=False,cursorAlignment='unknown: production RemoteMotion is private and unobserved',
        terminalPolicy=dict(finalSourcePose='required; omission is FAIL',exactCursorRemoval='unknown; private cursor not observed'),
        performance_qualified=False)

def verify_pair(logged,proof_bytes,with_bytes,without_bytes):
    """Bind persisted JSON to log; independently recompute actual PNG pixel count."""
    from PIL import Image
    proof=json.loads(proof_bytes.decode('utf-8-sig'));errors=[]
    if proof!=logged:errors.append('saved proof differs from exact logged proof')
    with Image.open(BytesIO(with_bytes)) as left,Image.open(BytesIO(without_bytes)) as right:
        if left.format!='PNG' or right.format!='PNG':errors.append('artifact is not PNG')
        pixel=logged['pixel'];bounds=pixel['bounds'];expected=(math.ceil(bounds['w']),math.ceil(bounds['h']))
        if left.size!=right.size or left.size!=expected:errors.append('PNG dimensions differ from captured bounds')
        if left.width*left.height>150000 or right.width*right.height>150000:raise ValueError('oversized PNG')
        difference=sum(a!=b for a,b in zip(left.convert('RGBA').getdata(),right.convert('RGBA').getdata()))
        if difference<=0 or difference!=pixel['pixels']:errors.append('actual PNG pixel difference does not equal logged count')
    return errors,dict(pixelDifference=difference,with_sha256=hashlib.sha256(with_bytes).hexdigest(),without_sha256=hashlib.sha256(without_bytes).hexdigest(),proof_sha256=hashlib.sha256(proof_bytes).hexdigest())

def verify_artifacts(host_log,join_log,folder):
    cases,errors=read_cases(host_log,join_log);rows=[]
    for role in ('host','join'):
        for n in range(4):
            try:
                paths=[folder/role/('round-'+str(n)+'-'+suffix) for suffix in ('proof.json','with.png','without.png')]
                if any(not p.is_file() or p.stat().st_size>1024*1024 for p in paths):raise ValueError('missing/oversized saved artifact')
                bad,row=verify_pair(cases[(role,n)]['proof'],*(p.read_bytes() for p in paths))
                errors += [role+' round='+str(n)+': '+e for e in bad];rows.append(dict(role=role,round=n,passed=not bad,**row))
            except (OSError,KeyError,TypeError,ValueError) as e:errors.append(role+' round='+str(n)+': '+str(e))
    return dict(passed=not errors,errors=errors,rows=rows)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--host-log',type=Path,required=True);p.add_argument('--join-log',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();assert not a.output.exists();result=analyze(a.host_log,a.join_log)
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if result['passed'] else 1)
