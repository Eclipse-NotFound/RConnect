"""Analyze bounded timing08 records without replacing native flight verdicts."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

PREFIX='FLIGHT TIMING08 '
METHODS={1:'join-message',2:'host-message',3:'session-timer',10:'perception',11:'mirror-mask',12:'mirror-frame',13:'final-view'}


def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def parse(text):
    header=None;done=None;rows=[]
    for line in text.splitlines():
        if not line.startswith(PREFIX):continue
        tag,raw=line[len(PREFIX):].split(' ',1);value=json.loads(raw)
        if tag=='HEADER':
            assert header is None,'Duplicate header';header=value
        elif tag=='ROWS':
            assert header is not None and done is None and value['from']==len(rows),'Discontinuous export'
            rows.extend(value['rows'])
        elif tag=='DONE':
            assert done is None,'Duplicate done';done=value
        else:raise AssertionError('Unknown timing row '+tag)
    assert header is not None and done is not None,'Missing export boundary'
    assert header['schema']==8 and header['width']==24 and header['capacity']==32768
    assert header['numericBytes']==6291456 and header['payloads']==0 and header['codecDiagnostics'] is False
    assert header['rows']==done['rows']==len(rows) and len(rows)<=32768
    assert all(isinstance(r,list) and len(r)==24 and all(v is None or type(v) in (int,float) for v in r) for r in rows)
    assert all(r[0] in range(1,11) and type(r[1]) in (int,float) for r in rows)
    assert all(a[1]<=b[1] for a,b in zip(rows,rows[1:])),'Non-monotonic row time'
    return header,rows,done


def union_ms(spans,begin,end):
    pieces=sorted((max(begin,a),min(end,b)) for a,b in spans if b>begin and a<end)
    total=0;last=begin
    for a,b in pieces:
        a=max(a,last)
        if b>a:total+=b-a
        last=max(last,b)
    return total


def summarize(header,rows,done,role):
    failures=[]
    if header['role']!=role:failures.append('role mismatch')
    for key in ['diagnosticOnly','complete']:
        if header.get(key) is not True or done.get(key) is not True:failures.append(key)
    if header.get('performanceQualified') is not False or done.get('performanceQualified') is not False:failures.append('qualification')
    for key in ['dropped','hookErrors','memoryErrors']:
        if header.get(key)!=0:failures.append(key)
    for key in ['identityOverflow','occupied']:
        if header.get(key) is not False:failures.append(key)
    cases=sorted({int(r[7]) for r in rows if r[0]==10 and r[6]==1})
    if cases!=list(range(8)) or done.get('round')!=7:failures.append('eight scenarios missing')
    method_counts=Counter(int(r[6]) for r in rows if r[0]==6)
    for method in [1 if role=='join' else 2,3,10,11,12,13]:
        if method_counts[method]==0:failures.append('missing method '+str(method))
    if not any(r[0]==3 for r in rows) or not any(r[0]==4 for r in rows):failures.append('no receive/display cursor')
    per_case=[]
    for case in range(8):
        current=[r for r in rows if r[4]==case]
        bounds=[r for r in current if r[0]==9]
        for phase in [1,2,3,4]:
            if not any(r[6]==phase for r in bounds):failures.append('missing boundary '+str((case,phase)))
        renders=[r for r in bounds if r[6]==4]
        spans=[r for r in current if r[0]==6]
        windows=[]
        for a,b in zip(renders,renders[1:]):
            if b[1]-a[1]<=50:continue
            starts=[r[1] for r in bounds if r[2]==b[2] and r[6]==1 and a[1]<=r[1]<=b[1]]
            lasts=[r[1] for r in bounds if r[2]==b[2] and r[6]==2 and a[1]<=r[1]<=b[1]]
            overlap=[r for r in spans if r[9]>a[1] and r[8]<b[1]]
            windows.append({'start':a[1],'end':b[1],'gap_ms':b[1]-a[1],'from_frame':a[2],'to_frame':b[2],
                            'enter_first':starts[:1],'enter_last':lasts[-1:],
                            'observed_span_union_ms':union_ms([(r[8],r[9]) for r in overlap],a[1],b[1]),
                            'spans':[{'method':METHODS.get(int(r[6]),str(r[6])),'type':r[7],'start':r[8],'end':r[9],'cost':r[10]} for r in overlap]})
        costs={METHODS.get(k,str(k)):{'calls':sum(r[6]==k for r in spans),
                'sum_ms':sum(r[10] for r in spans if r[6]==k),'max_ms':max([r[10] for r in spans if r[6]==k] or [0])} for k in sorted(method_counts)}
        marks=[{'code':r[7],'at':r[1],'frame':r[2],'render':r[5]} for r in current if r[0]==10 and r[6]==2]
        receives=[r for r in current if r[0]==3];display=[r for r in current if r[0]==4]
        per_case.append({'round':case,'rows':len(current),'marks':marks,'methods':costs,
                         'render_gap_windows':sorted(windows,key=lambda r:r['gap_ms'],reverse=True)[:12],
                         'first_receive':receives[0] if receives else None,
                         'first_position_write':next((r for r in display if r[9]==4),None),
                         'display_reasons':dict(Counter(int(r[9]) for r in display))})
    exits=[r for r in rows if r[0]==7]
    if not exits:failures.append('no EXIT_FRAME observations')
    if any(r[8]!=r[9] for r in exits):failures.append('unbalanced EXIT_FRAME callbacks')
    return {'complete':not failures,'failures':failures,'header':header,'done':done,'kind_counts':dict(Counter(int(r[0]) for r in rows)),
            'exit_max_broadcasts_between_enters':max([r[8] for r in exits] or [0]),
            'memory_samples':[{'at':r[1],'round':r[4],'total':r[6],'free':r[7],'private':r[8]} for r in rows if r[0]==8],
            'cases':per_case,'timing_not_cpu_accounting':True}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host-log',type=Path,required=True);p.add_argument('--join-log',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    result={'kind':'recovery-flight-timing08','diagnostic_only':True,'performance_qualified':False,
            'diagnostic_complete':False,'inputs':{},'roles':{}}
    for role,path in [('host',args.host_log),('join',args.join_log)]:
        result['inputs'][str(path)]=digest(path)
        try:result['roles'][role]=summarize(*parse(path.read_text(encoding='utf-8-sig')),role)
        except Exception as e:result['roles'][role]={'complete':False,'error':str(e)}
    result['diagnostic_complete']=all(x['complete'] for x in result['roles'].values())
    result['inputs'][str(Path(__file__).resolve())]=digest(Path(__file__))
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'diagnostic_complete':result['diagnostic_complete'],'performance_qualified':False}))
    return 0 if result['diagnostic_complete'] else 1


if __name__=='__main__':raise SystemExit(main())
