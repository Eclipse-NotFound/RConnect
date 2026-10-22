"""Read-only recipe checks plus a local JSON receipt. No Java, AIR or assembly."""
from pathlib import Path
import ast, hashlib, importlib.util, json
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('early_host_recipe',HERE/'prepare_host.py')
host=importlib.util.module_from_spec(spec);spec.loader.exec_module(host)
rows=[]
def check(label,fn,reject=False):
    try:fn()
    except (AssertionError,ValueError,IndexError):
        assert reject,label
    else:assert not reject,label
    rows.append({'label':label,'passed':True})
for name in ('prepare_host.py','prepare_sources.py'):
    check(name+' parses',lambda n=name:ast.parse((HERE/n).read_text(encoding='utf-8')))
for cls in host.PATCHED:
    rel=Path(*cls.split('.')).with_suffix('.as')
    before=host.text(host.BASE/'after/scripts'/rel);expected=host.text(HERE/'host-import'/rel)
    def verify(candidate):host.verify_readback(cls,before,candidate,expected)
    check(cls+' exact source accepted',lambda:verify(expected))
    if cls=='fe.World':
        single='if(Game.rconnectTravelBridge != null)Game.rconnectTravelBridge("cancel-load",this.game,null);'
        bracket='if(Game.rconnectTravelBridge != null){Game.rconnectTravelBridge("cancel-load",this.game,null);}'
        check('FFDec braces on cancel helper accepted',lambda:verify(expected.replace(single,bracket)))
        check('reversed hold condition rejected',lambda:verify(expected.replace('if(!this.rconnectLoadingHold())','if(this.rconnectLoadingHold())',1)),True)
        check('lost deferred native control rejected',lambda:verify(expected.replace('this.gg.controlOn();','',1)),True)
        check('no-ticket changed pause semantics rejected',lambda:verify(expected.replace('if(!this.rconnectLoadingHold())','if(!this.onPause && !this.rconnectLoadingHold())',1)),True)
        check('unrelated native method change rejected',lambda:verify(expected.replace('Snd.step();','Snd.step(); Snd.step();',1)),True)
    else:
        single='if(rconnectTravelBridge != null)rconnectTravelBridge("constructed",this,null);'
        bracket='if(rconnectTravelBridge != null){rconnectTravelBridge("constructed",this,null);}'
        check('FFDec braces on constructed tail accepted',lambda:verify(expected.replace(single,bracket)))
        check('missing construction callback rejected',lambda:verify(expected.replace(single,'')),True)
        check('wrong callback phase rejected',lambda:verify(expected.replace('"constructed"','"announce"',1)),True)
        check('incorrect feature version rejected',lambda:verify(expected.replace('rconnectEarlyTravelVersion:int = 1','rconnectEarlyTravelVersion:int = 2',1)),True)
        timing='World.w.time___metr("Вход в местность");'
        assert expected.count(timing)==1 and expected.count(single)==1
        check('callback moved before final native action rejected',lambda:verify(expected.replace(single,'').replace(timing,single+'\n'+timing)),True)
data={'assertions':rows,'failed':0,'checks':len(rows),'jvm_started':False,'air_started':False,
      'runtime_or_performance_qualification':False,
      'inputs':{p.relative_to(HERE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (HERE/'prepare_host.py',HERE/'prepare_sources.py',Path(__file__),HERE/'host-import/fe/World.as',HERE/'host-import/fe/loc/Game.as')}}
(HERE/'recipe-checks.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':len(rows),'failed':0,'JVM_AIR_started':False}))
