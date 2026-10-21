"""Static checks only. This does not compile or run the 54 AIR assertions."""
from pathlib import Path
import ast
import json
import prepare

HERE=Path(__file__).resolve().parent

def main():
    checks=[]
    def check(ok,label):
        checks.append(dict(passed=bool(ok),label=label))
        assert ok,label
    prepare.verify()
    check(True,'all original, overlay and component fingerprints verified')
    old,new=prepare.expected()
    check(old.count(prepare.OLD)==1 and new.count(prepare.NEW)==1,'one exact block replacement')
    check(new.replace(prepare.NEW,prepare.OLD,1)==old,'reverse patch is exact full original class')
    for label,body in [('Before',old),('After',new)]:
        t=prepare.read(HERE/'components/rconnect/game'/('Pose'+label+'.as'))
        t=t.replace('class Pose'+label,'class UnitPresentation',1)
        t=t.replace('   import fixture.getTimer;\n   import fixture.Trace;','   import flash.utils.getTimer;',1)
        t=t.replace(prepare.ACCESS,'',1).replace(prepare.TRACE,'',1)
        check(t==body,label+' component strips to exact complete production source')
    check(prepare.OLD.count('getTimer()')==prepare.NEW.count('getTimer()')==1,'elapsed clock read preserved')
    for token in ['w.t_prep=','w.t_reload=','if(!paused && gun.queue>0',
                  'if(int(gun.flash)<=1)','w.animate();','telekinesis.weapon(w,s.aura);','melee.apply(u,w,']:
        check(old[old.index(token):]==new[new.index(token):],'unchanged suffix from '+token)
    check('pose.slot==s.slot&&pose.id==s.id&&pose.variant==s.variant&&pose.stream==s.stream' in prepare.NEW,
          'identity predicate preserves all four fields and coercion')
    check(prepare.NEW.index('var elapsed:int=getTimer()')<prepare.NEW.index('if(clockSample!=null'),
          'elapsed read stays before source lookup')
    for p in (HERE/'prepare.py',HERE/'check_offline.py'):ast.parse(p.read_text(encoding='utf-8'))
    check(True,'Python tools parse without importing compiler or AIR runner')
    output=dict(passed=True,checks=checks,expected_runtime_assertions=54,
                runtime_assertions_executed=False,JVM_started=False,AIR_started=False)
    (HERE/'offline-result.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(static_checks=len(checks),failed=0,runtime_assertions_executed=False)))

if __name__=='__main__':main()
