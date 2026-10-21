"""Validate bounded gas startup diagnostics; never turn native failure into PASS."""
import argparse
import hashlib
import json
import math
from pathlib import Path

WIDTH=24
CAPACITY=32768

def number(v):return isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def decode(text):
    headers=[];done=[];rows=[];cases={};errors=[]
    for line in text.splitlines():
        try:
            if line.startswith('GAS CLOCK HEADER '):headers.append(json.loads(line[17:]))
            elif line.startswith('GAS CLOCK DONE '):done.append(json.loads(line[15:]))
            elif line.startswith('GAS CLOCK ROWS '):
                block=json.loads(line[15:])
                if block['from']!=len(rows):errors.append('non-contiguous diagnostic block')
                if not 0<len(block['rows'])<=128:errors.append('invalid block size')
                rows.extend(block['rows'])
                if len(rows)>CAPACITY:raise ValueError('numeric buffer exceeds bound')
            elif line.startswith('GAS PULSE RESULT '):
                item=json.loads(line[17:]);key=(item['role'],item['round'])
                if key in cases:errors.append('duplicate native round evidence')
                cases[key]=item['value']
        except (KeyError,TypeError,ValueError) as e:errors.append('malformed diagnostic/evidence: '+str(e))
    return headers,done,rows,cases,errors

def inspect(text,role):
    headers,done,rows,cases,errors=decode(text)
    result=dict(role=role,complete=False,errors=errors,rows=len(rows),clocks=[],gas=[],diagnostic_only=True,
                performance_qualified=False)
    if len(headers)!=1 or len(done)!=1:
        errors.append('expected exactly one HEADER and DONE');return result
    h,d=headers[0],done[0];result['header']=h;result['done']=d
    required={'schema':13,'role':role,'width':WIDTH,'capacity':CAPACITY,'numericBytes':6*1024*1024,
        'dropped':0,'occupied':False,'firstRoundComplete':True,'hookErrors':0,'identityOverflow':False,
        'lateBindings':0,'complete':True,'diagnosticOnly':True,'performanceQualified':False}
    for k,v in required.items():
        if h.get(k)!=v:errors.append('HEADER '+k+' differs from '+str(v))
    if not isinstance(h.get('clocks'),int) or not 1<=h['clocks']<=2:errors.append('invalid actor clock count')
    if h.get('rows')!=len(rows) or d.get('rows')!=len(rows) or d.get('complete') is not True:
        errors.append('export counts/completeness mismatch')
    for k in ('hookCalls','hookCostMs','hookMaxMs','frameCalls','frameCostMs','frameMaxMs'):
        if not number(h.get(k)) or h[k]<0:errors.append('missing/nonfinite overhead '+k)
    if not number(d.get('exportMs')) or d['exportMs']<0:errors.append('missing export overhead')
    if d.get('diagnosticOnly') is not True or d.get('performanceQualified') is not False:
        errors.append('invalid diagnostic qualification')
    if any(not isinstance(r,list) or len(r)!=WIDTH or any(v is not None and not number(v) for v in r) for r in rows):
        errors.append('invalid numeric row');return result
    if any(not number(r[1]) or r[0] not in (1,2,3,9,10) for r in rows):
        errors.append('invalid row kind/time');return result
    if any(a[1]>b[1] for a,b in zip(rows,rows[1:])):errors.append('record clock moved backwards')
    start=[i for i,r in enumerate(rows) if r[0]==10 and r[6]==0]
    stop=[i for i,r in enumerate(rows) if r[0]==10 and r[6]==1]
    if start!=[0] or stop!=[len(rows)-1] or rows[-1][7]!=1:
        errors.append('missing startup/first-round cutoff or rows after stop')
    cutoff=rows[-1][1] if rows else None
    first=cases.get((role,0))
    if first is None:errors.append('missing original first-round result')
    elif number(cutoff) and number(first.get('proof',{}).get('readbackAt')):
        if cutoff>first['proof']['readbackAt']:errors.append('diagnostic continued past first-round readback')
    else:errors.append('missing first-round cutoff anchor')
    bound={};events={};gases=[]
    for i,r in enumerate(rows):
        kind=r[0];a=r[6:]
        if kind==2:
            cid=int(a[0])
            if cid not in (1,2):errors.append('clock id outside bound')
            if a[10]==1:
                if cid in bound:errors.append('duplicate fresh actor binding')
                if a[11] is not None or a[12] is not None:errors.append('fresh bind already has source history')
                bound[cid]=(i,r)
            elif cid not in bound:errors.append('identity update precedes binding')
        elif kind in (1,3):
            cid=int(a[0])
            if cid not in bound:errors.append('motion/gas precedes first binding')
            if kind==1:events.setdefault(cid,[]).append(r)
            else:gases.append(r)
    if len(bound)!=h.get('clocks'):errors.append('binding count differs from header')
    for cid,(index,binding) in sorted(bound.items()):
        stream=events.get(cid,[]);push=[];samples=[];settles=[];reset=[];stack=[];last_sample=None;intervals=[]
        for r in stream:
            a=r[6:];op=int(a[1])
            if op in (1,6):stack.append((op,r))
            elif op in (2,7):
                if not stack or stack[-1][0]!=(1 if op==2 else 6):errors.append('unbalanced push/settle records');continue
                before=stack.pop()[1]
                if op==2:
                    push.append(dict(at=before[1],stamp=before[11],beforeOffset=before[10],afterOffset=r[10],
                        beforeCursor=before[9],afterCursor=r[9],beforeLatest=before[20],afterLatest=r[20],
                        debt=r[17],countBefore=before[14],countAfter=r[14]))
                else:settles.append(dict(at=r[1],beforeCursor=before[9],afterCursor=r[9]))
            elif op==3:reset.append(dict(at=r[1],stamp=a[5],cursor=a[3],offset=a[4]))
            elif op==4:
                if last_sample is not None:errors.append('overlapping sample records')
                last_sample=r
            elif op==5:
                if last_sample is None:errors.append('sample end without update start')
                else:samples.append(r);last_sample=None
            elif op not in (8,9):errors.append('unknown motion operation')
        if stack or last_sample is not None:errors.append('incomplete clock operation')
        if not push or stream[0][7]!=1:errors.append('first observed clock operation is not pushTimed')
        if not reset:errors.append('missing initial clock reset')
        if not samples:errors.append('missing real actor sample')
        for a,b in zip(samples,samples[1:]):intervals.append(b[8]-a[8])
        values=lambda n:[r[n] for r in samples if number(r[n])]
        result['clocks'].append(dict(id=cid,peer=binding[7],firstBindingAt=binding[1],firstPush=push[0] if push else None,
            lastPush=push[-1] if push else None,pushes=len(push),samples=len(samples),reset=reset,settle=settles,
            maximumDebt=max(values(17),default=None),maximumCalibrationRate=max(values(18),default=None),
            maximumSampleGap=max(intervals,default=None),branches=sorted({int(r[21]) for r in samples}),
            minimumAcceptedOffset=min((p['afterOffset'] for p in push if number(p['afterOffset'])),default=None),
            legacyClears=sum(r[7]==9 for r in stream)))
    if role=='join':
        if [int(r[7]) for r in gases]!=[1,2,4,3]:errors.append('first observed gas needs receive/show/strictEnd/remove, exactly once each')
        elif len({(r[6],r[8]) for r in gases})!=1:errors.append('gas identity differs between event markers')
        else:
            received,shown,terminal,removed=gases
            wire=first.get('proof',{}).get('wireRows',[]) if first else []
            matches=[w for w in wire if str(w.get('key','')).rsplit(':',1)[-1]==str(int(received[8]))
                and w.get('frames') and w['frames'][0].get('at')==received[13]]
            if len(matches)!=1:errors.append('first gas does not uniquely match round0 wire identity and source birth')
            result['gas']=dict(clock=received[6],id=received[8],wireKey=matches[0]['key'] if len(matches)==1 else None,
                receiptMarkerMinusWireObserverMs=received[1]-matches[0]['firstAt'] if len(matches)==1 else None,
                receiveAt=received[1],showAt=shown[1],removeAt=removed[1],receiveToShow=shown[1]-received[1],
                showToRemove=removed[1]-shown[1],sourceFirst=received[13],sourceLastAtRemove=removed[14],
                sourceEndAtRemove=removed[15],cursorAtReceive=received[11],cursorAtShow=shown[11],
                cursorAtRemove=removed[11],sampleTimeAtShow=shown[10],stageAtShow=shown[17],
                strictEndAt=terminal[1],actualTimeAtStrictEnd=terminal[10],endAtStrictEnd=terminal[15],
                lastReceivedPoseAtStrictEnd=terminal[14],lastShownPoseAtStrictEnd=terminal[19],
                sourceMinusReceiveCursor=received[13]-received[11] if number(received[13]) and number(received[11]) else None)
            if shown[16]!=1 or shown[17]!=1:errors.append('gas first shown is not a stage display')
            if not number(terminal[10]) or not number(terminal[15]) or terminal[10]<terminal[15]:
                errors.append('strictEnd event lacks actual decision clock/end')
    elif gases:
        errors.append('unexpected remote gas before end of host-source round0; diagnostic binding ambiguous')
    boundaries={str(k):[r for r in rows if r[0]==9 and r[6]==k] for k in (1,2,3)}
    result['frameBoundaries']={k:dict(count=len(v),maxInterval=max((b[1]-a[1] for a,b in zip(v,v[1:])),default=None))
                               for k,v in boundaries.items()}
    if any(not v for v in boundaries.values()):errors.append('incomplete frame boundary evidence')
    result['complete']=not errors
    return result

def analyze(host_log,join_log):
    roles={role:inspect(path.read_text(encoding='utf-8-sig'),role) for role,path in [('host',host_log),('join',join_log)]}
    return dict(diagnostic_complete=all(r['complete'] for r in roles.values()),roles=roles,
        diagnostic_only=True,performance_qualified=False,native_qualified=False,
        log_sha256={'host':sha(host_log),'join':sha(join_log)},
        boundary='Scalar first-round evidence only. Native/PNG assertions remain an independent verdict; no performance qualification.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--host-log',type=Path,required=True);p.add_argument('--join-log',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    value=analyze(a.host_log,a.join_log);a.output.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if value['diagnostic_complete'] else 1)
