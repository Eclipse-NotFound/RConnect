"""Static source contracts and explicit Python counterexamples; no AS/AIR execution."""
import ast
import copy
import json
import re
from prepare import HERE,BASE,MANIFEST,sha,read,save,check_source,load_helper

def main():
    labels=[]
    def require(ok,label):
        assert ok,label
        labels.append(label)
    check_source();require(True,'exact corridor02 delta and unchanged timed stimulus/thresholds')
    load_helper('run.py');load_helper('audit.py')
    require(True,'unchanged runner and audit imports resolve against this adapter')
    src=(HERE/'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8')
    helper=(HERE/'tests/DensityWeaponPreparation.as').read_text(encoding='utf-8')
    require('import rconnect.core.Log;' in helper,'actual existing external Log declaration is used')
    configure=helper.split('public static function configure(',1)[1].split('public static function identity(',1)[0]
    values={k:int(v) for k,v in re.findall(r'gun\.(\w+)=(\d+);',configure)}
    require(values==dict(hold=10000,damage=1,destroy=0,damageExpl=0,precision=0,deviation=0,critCh=0),
        'shared explicit constants exactly equal old host setup')
    require(src.count('DensityWeaponPreparation.configure(')==1 and helper.count('configure(u.currentWeapon)')==1,
        'only host creation and once-only mirror preparation write parameters')
    require('!arenaCleaned && DensityWeaponPreparation.modelsMatch(objects,arenaExpected)' in src and
            'prepareMirrors(objects,arenaExpected);arenaCleaned=true;' in src,'preparation completes once before cleaned guard closes')
    require('weapon:DensityWeaponPreparation.identity(u)' in src and 'DensityWeaponPreparation.bound(objects)' in src,
        'ready/commit share complete weapon identity and local reference check')
    fields=re.search(r'\["id","variant"[^\]]+\]',helper).group()
    require('"hold"' in fields and '"speed"' in fields and 'row.cls=getQualifiedClassName(gun)' in helper,
        'complete original weapon parameter row plus actual class')
    require('record.weapon!==u.currentWeapon' in helper and 'gun.owner===u' in helper and 'u.childObjs.indexOf(gun)>=0' in helper,
        'same-id replacement and detached/foreign owner are checked')
    readonly=helper.split('public static function bound(',1)[1]
    require(not re.search(r'\b(?:gun|u|record)\.\w+\s*=(?!=)',readonly),'bound check cannot repair values')
    require(helper.index('Log.d("DENSITY WEAPON PREP')<helper.index('configure(u.currentWeapon)'),
        'actual native parameter log precedes any mirror correction')
    require('productParameterSyncVerified:false' in helper,'fixture declares product parameter sync unverified')
    # Behavioral models below are explicit Python counterexamples, not execution
    # of compiled AS. Tie fields/constants/identity guards to source above.
    expected=dict(id='p308c',variant=0,damage=1,destroy=0,damageExpl=0,precision=0,
                  deviation=0,critCh=0,speed=250,hold=10000,cls='fe.weapon::Weapon')
    native=dict(expected,hold=12,damage=26,destroy=10,precision=400,deviation=5,critCh=.2)
    def ready(gun,wanted,bound_gun,owner_ok=True,child_ok=True):
        return gun is bound_gun and owner_ok and child_ok and gun==wanted
    initial=copy.deepcopy(native)
    require(not ready(native,expected,native),'same id but native parameters/hold do not pass readiness')
    require(native==initial,'read-only initial comparison does not repair product fields')
    for key,value in values.items():native[key]=value
    require(ready(native,expected,native),'once-prepared existing object passes full parameter comparison')
    hold_only=dict(expected,hold=0)
    require(not ready(hold_only,expected,hold_only),'hold alone differing with same id/class is rejected')
    replacement=copy.deepcopy(native)
    require(not ready(replacement,expected,native),'same fields new weapon object after preparation is rejected')
    require(not ready(native,expected,native,owner_ok=False),'wrong real owner is rejected')
    require(not ready(native,expected,native,child_ok=False),'missing real child link is rejected')
    native['hold']=9999;unchanged=copy.deepcopy(native)
    require(not ready(native,expected,native) and native==unchanged,'post-preparation drift fails without maintenance reset')
    bad_class=dict(expected,cls='fixture::FakeGun')
    require(not ready(bad_class,expected,bad_class),'same id but wrong real weapon class is rejected')
    for path in HERE.glob('*.py'):ast.parse(path.read_text(encoding='utf-8'))
    require(True,'Python adapters parse')
    for path in (HERE/'tests').rglob('*.as'):
        code=re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '',path.read_text(encoding='utf-8-sig'),flags=re.S)
        stack=[]
        for c in code:
            if c in '({[':stack.append(c)
            elif c in ')}]':assert stack and stack.pop()=={')':'(',']':'[','}':'{'}[c],path
        assert not stack,path
    require(True,'AS source delimiters balanced (not compiler qualification)')
    output=dict(kind='static-contracts-and-python-counterexamples',passed=len(labels),failed=0,labels=labels,
        compiled=False,air_started=False,production_sync_verified=False,native_ready_verified=False,
        source_corridor_manifest=MANIFEST,files={p.relative_to(HERE).as_posix():sha(p)
        for p in sorted(HERE.rglob('*')) if p.is_file() and p.name not in ('static-check.json','handoff.json')})
    save(HERE/'static-check.json',output)
    print(json.dumps({k:output[k] for k in ['passed','failed','compiled','air_started','native_ready_verified']}))

if __name__=='__main__':main()
