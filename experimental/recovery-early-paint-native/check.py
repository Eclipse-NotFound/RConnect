"""Static, non-launching verification of exact wrapper adaptation and fail-closed gates."""
import ast,json
from native_inputs import HERE,EXIT,M52,REVIEW,REJECTED_REVIEW,HOST_SOURCE,QUALIFICATION_FIELDS,verify_tools,qualified_review,read,sha
from adapt import SOURCE,EDITS,source
from source_compat import verify as verify_compat,compare,driver

def main():
    checks=[]
    def check(value,label):assert value,label;checks.append(label)
    adapted=source();rebuilt=adapted
    for old,new in reversed(EDITS):
        check(rebuilt.count(new)==1,'one exact observer change '+old.strip()[:45])
        rebuilt=rebuilt.replace(new,old,1)
    check(rebuilt==SOURCE.read_text(encoding='utf-8-sig'),'entire original runtime and error/input audit preserved')
    ast.parse(adapted)
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
    check(True,'all new and adapted Python sources parse')
    check("result['profile_valid']=False" in adapted and 'paint_audit_log(run/' in adapted,'invalid native profiles fail result')
    check("result['performance_qualified']=False" in adapted,'no performance qualification')
    check('--require-exclusive-air' in adapted and '--private-desktop' in adapted,'original exclusive owned runtime preserved')
    check("cmd+=['--vision-candidate',str(rv)]" in adapted,'exact old RV injection preserved')
    check("assert before[RV_KEY]==after[RV_KEY]==RV_NEW" in adapted,'installed RV transition still audited')
    check("'exception_cfg_passed'" in (HERE/'native_inputs.py').read_text(encoding='utf-8'),'native exception CFG required')
    check(len(QUALIFICATION_FIELDS)==7,'all seven review flags required')
    rejected=read(REJECTED_REVIEW)
    check(rejected['exception_cfg_passed'] is False and rejected['validated'] is False,'actual host02 receipt is rejected')
    refused=False
    try:qualified_review(rejected)
    except AssertionError:refused=True
    check(refused,'actual host02 rejection cannot qualify final runtime')
    contract=verify_compat()
    check(len(contract['fields'])==21 and len(contract['callback_arguments'])==5,'exact v2/v3 21-field five-argument observer compatibility')
    compiled_driver=M52/'recovery-early-paint-driver-v2-01'
    driver.verify_driver(compiled_driver,read(compiled_driver/'prepared.json'),'scene')
    check(True,'existing compiled v2 driver passes its original exact admission unchanged')
    before=(driver.HOST_V2/'src/fe/graph/Grafon.as').read_text(encoding='utf-8')
    after=(HOST_SOURCE/'src/fe/graph/Grafon.as').read_text(encoding='utf-8')
    mutations={
        'callback order':after.replace('paintObserver(this,paintWorld,paintGame,paintLoc,{','paintObserver(this,paintGame,paintWorld,paintLoc,{',1),
        'field value':after.replace('completed:paintCompleted','completed:true',1),
        'native duplicate':after.replace('this.scenePreloadAll();','this.scenePreloadAll();this.scenePreloadAll();',1),
        'capture timer':after.replace('paintStarted = int(getTimer());','paintStarted = 0;',1),
        'observer timer':after.replace('var paintFinished:int = int(getTimer());','var paintFinished:int = 0;',1)}
    for name,bad in mutations.items():
        refused=False
        try:compare(before,bad)
        except AssertionError:refused=True
        check(refused,'compatibility rejects '+name)
    if not (HERE/'inputs.json').exists():
        rejected=False
        try:verify_tools()
        except AssertionError as e:rejected='not frozen' in str(e)
        check(rejected,'unfrozen runtime entry refuses before launch')
    else:
        verify_tools();check(True,'complete frozen inputs remain exact')
    print(json.dumps(dict(passed=len(checks),checks=checks,compiled=False,air_started=False,
                         review_exists=REVIEW.exists(),existing_driver_sha256=sha(compiled_driver/'scene/EffectsDriver.swf'),
                         performance_qualified=False),ensure_ascii=False))

if __name__=='__main__':main()
