"""No child process: derivation, AS surface and scalar replay checks only."""
import ast
import json
from pathlib import Path
import re
from prepare import HERE,BASE,PIN,sha,verify,sources,trace
from replay_model import Clock,replay

def main():
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'),str(p))
    manifest=verify();old,new=sources()
    assert sha(BASE/'RemoteMotion.as')==PIN
    assert re.findall(r'public (?:static )?function [^\{]+',old)==re.findall(r'public (?:static )?function [^\{]+',new)
    assert 'else if(!immediateStart && correction>Math.max(100,interval*2))cursor+=correction;' in new
    assert new.index('if(rateHeld())')<new.index('else if(enemyRecovery)')<new.index('else if(actorCalibration())')
    assert new.count('calibrationDebt+=correction;')==1 and new.count('clearCalibration();')==4
    assert not any(x in new for x in ['getTimer','FlightDiagnostics','System.','sourceTime='])
    for suffix,expected in [('Before',old),('After',new)]:
        p=HERE/'components/rconnect/game'/('RemoteMotion'+suffix+'.as')
        assert p.read_text(encoding='utf-8')==re.sub(r'\bRemoteMotion\b','RemoteMotion'+suffix,expected)
    for p in (HERE/'components').rglob('*.as'):
        text=p.read_text(encoding='utf-8')
        assert len(re.findall(r'public (?:final )?class\s+',text))==1,p
        assert not re.search(r'\.(?:case|return|throw|try|catch|new|if|else|for|while)\b',text),p
    best=replay()
    assert best['old_trace_max_abs_error']==0 and best['old_first_eligible_at']==46159
    assert best['new_first_eligible_at']==45956 and best['eligible_gain_ms']==203
    def debt(new):
        m=Clock(new)
        for stamp,now in [(1000,1000),(1100,1040),(1200,1080),(1300,1120)]:m.push(stamp,now)
        return m
    a,b=debt(False),debt(True);start=b.cursor;a.sample(1120);b.sample(1120)
    assert b.cursor>a.cursor and b.cursor-start<=180
    prev_cursor=b.cursor;prev_speed=(b.cursor-start)/120;prev_dt=120
    for i in range(1,21):
        now=1120+i*10;b.push(1300+i*10,now);b.sample(now);speed=(b.cursor-prev_cursor)/10
        assert .9-1e-9<=speed<=1.5+1e-9
        assert abs(speed-prev_speed)<=.003*(10+prev_dt)/2+1e-9,(i,speed,prev_speed)
        prev_cursor=b.cursor;prev_speed=speed;prev_dt=10
    before=b.cursor
    for _ in range(100):b.sample(1320);assert b.cursor==before
    a,b=debt(False),debt(True);a.sample(1120);b.sample(1120)
    for i in range(1,101):
        for m in (a,b):m.push(1300+i*50,1120+i*50);m.sample(1120+i*50)
        if i>80:assert a.cursor==b.cursor
    for jitter in [False,True]:
        a,b=Clock(),Clock(True)
        for m in (a,b):m.push(1000,1000)
        for i in range(1,81):
            stamp=1000+i*(70 if jitter else 50);now=stamp+(30 if jitter else 0)
            for m in (a,b):m.push(stamp,now);m.sample(now)
            assert a.cursor==b.cursor
            for m in (a,b):m.sample(now+15)
            assert a.cursor==b.cursor
    data=trace();assert len(data['rows'])==180
    test=(HERE/'components/ClockCatchupChecks.as').read_text(encoding='utf-8')
    # Two parameterized functions each execute three times; exclude check's
    # declaration and exception-only fail branch from the normal count.
    expected=len(re.findall(r'\bcheck\(',test))-2+2+2
    assert expected==40,expected
    print(json.dumps({'static_passed':True,'scalar_old_trace_error':0,'model_gain_ms':203,
        'component_expected_checks':expected,'AS_executed':False,'JVM':False,'AIR':False}))

if __name__=='__main__':main()
