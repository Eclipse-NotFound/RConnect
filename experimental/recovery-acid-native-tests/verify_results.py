"""Independent acid Part record checks; no game, receiver or emitter calls."""
import argparse
import json
import math
from pathlib import Path


def finite(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)


def validate(value,expected_source,water):
    errors=[]
    def need(ok,label):
        if not ok:errors.append(label)
    need(value.get('source') is expected_source,'source role')
    need(value.get('id')=='acidgr' and value.get('water') is water,'weapon/water request')
    explosion=value.get('explosion') or {}
    need(explosion.get('water') is water,'actual native explosion water branch')
    proof=value.get('proof') or {};rows=proof.get('rows') or []
    need(0<len(rows)<=256 and proof.get('overflow') is False,'bounded actual acid Part rows')
    need(proof.get('allEnded') is True,'native particle terminal')
    pixel=proof.get('pixel') or {}
    need(finite(pixel.get('pixels')) and pixel['pixels']>0,'actual final-stage ground pixel difference')
    need(finite(proof.get('readbackAt')) and finite(pixel.get('at')) and proof['readbackAt']>=pixel['at'],
         'deferred bitmap readback')
    animated=faded=False
    ids=set()
    for row in rows:
        need(row.get('id') not in ids,'unique local Part identity');ids.add(row.get('id'))
        need(row.get('partClass')=='fe.graph::Part' and row.get('visualClass')=='visualAcid','actual native acid class')
        need(row.get('stable') is True and finite(row.get('x')) and finite(row.get('y')),'stationary finite positions')
        need(finite(row.get('mliv')) and 100<=row['mliv']<=129,'native acid lifespan distribution')
        need(finite(row.get('firstLiv')) and row['firstLiv']>0 and row.get('detached') is True and
             finite(row.get('finalLiv')) and row['finalLiv']<=0,'natural lifetime removal')
        need(finite(row.get('removedFrame')) and finite(row.get('bornFrame')) and
             row['removedFrame']>row['bornFrame'],'later terminal frame')
        need(finite(row.get('removedAt')) and finite(proof.get('readbackAt')) and
             proof['readbackAt']>=row['removedAt'],'readback only after all Part removals')
        animated=animated or row.get('animated') is True
        faded=faded or (finite(row.get('alphaMax')) and finite(row.get('alphaMin')) and
                        row['alphaMax']>=.5 and row['alphaMin']<row['alphaMax'])
        if expected_source:
            s=row.get('surface') or {}
            need(all(finite(s.get(k)) for k in ('ty','x','y','phis','zForm','above')) and
                 s['ty']>1 and (s['phis']>0 or s.get('shelf') is True) and
                 (s['zForm']!=0 or s['above']==0) and finite(row.get('x')) and finite(row.get('y')) and
                 abs(row['x']-s['x'])<=2.01 and abs(row['y']-s['y'])<.01,'actual exposed source surface')
    need(animated and faded,'native animation and alpha changes')
    if expected_source:need(value.get('shots')==1 and value.get('inputReleased',0)>0,'single real throw and release')
    else:need(value.get('unexpected')==0,'no extra native damaging projectile on receiver')
    return errors


def footprint(origin,remote):
    a=origin.get('proof',{}).get('rows',[]);b=remote.get('proof',{}).get('rows',[])
    if not a or len(a)!=len(b):return False,[]
    used=set();matches=[]
    for row in b:
        choices=[(math.hypot(row['x']-p['x'],row['y']-p['y']),i) for i,p in enumerate(a)
                 if i not in used and abs(row['x']-p['x'])<=4 and abs(row['y']-p['y'])<=4]
        if not choices:return False,matches
        _,i=min(choices);used.add(i);matches.append(dict(source=a[i]['id'],remote=row['id'],
                                                       dx=row['x']-a[i]['x'],dy=row['y']-a[i]['y']))
    return True,matches


def analyze(host_log,join_log):
    cases={};errors=[]
    for role,path in [('host',host_log),('join',join_log)]:
        text=path.read_text(encoding='utf-8-sig',errors='replace')
        for line in text.splitlines():
            if line.startswith('COOP FAIL '):errors.append(role+': '+line)
            if not line.startswith('ACID GROUND RESULT '):continue
            record=json.loads(line[len('ACID GROUND RESULT '):]);n=record['round']
            if record.get('role')!=role or n not in range(4) or (role,n) in cases:
                errors.append('invalid/duplicate result '+role+' '+str(n));continue
            cases[(role,n)]=record['value']
            errors += [role+' round='+str(n)+': '+e for e in validate(record['value'],
                        (role=='host')==(n%2==0),n>=2)]
    comparisons=[]
    for n in range(4):
        if ('host',n) not in cases or ('join',n) not in cases:
            errors.append('missing two-sided round '+str(n));continue
        a,b=cases[('host',n)],cases[('join',n)]
        origin,remote=(a,b) if n%2==0 else (b,a)
        try:ok,matches=footprint(origin,remote)
        except (KeyError,TypeError,ValueError):ok,matches=False,[]
        if not ok:errors.append('source/remote actual Part footprint differs round='+str(n))
        comparisons.append(dict(round=n,water=n>=2,passed=ok,matches=matches))
    return dict(passed=not errors,errors=errors,observed_results=len(cases),comparisons=comparisons,
                functional_only=True,performance_qualified=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--host-log',type=Path,required=True)
    p.add_argument('--join-log',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();assert not a.output.exists(),'Preserve previous evidence'
    result=analyze(a.host_log,a.join_log)
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=result['passed'],errors=len(result['errors']))))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
