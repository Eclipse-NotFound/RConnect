"""Pure source and data audit. No compilation, AIR, or frozen result mutations."""
from pathlib import Path
import ast,json
import baseline,prepare,component_static,audit_checks
from binding import HERE,ROOT,PROBE_SHA,sha,read,verify_tools

def main():
    checks=[]
    def check(ok,label):assert ok,label;checks.append(label)
    baseline.verify_tools();base,old=baseline.original.verify_original_driver()
    check(sha(HERE/'tests/FirstRasterSceneProbe.as')==PROBE_SHA,'exact prior probe reused without edits')
    for name in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as'):
        check(sha(base/'tests'/name)==old['files']['tests/'+name],'original scenario and assertion source '+name)
    adapted=prepare.source();reverted=adapted
    for before,after in reversed(prepare.EDITS):
        check(reverted.count(after)==1,'exact build recipe edit '+before)
        reverted=reverted.replace(after,before,1)
    check(reverted==prepare.SOURCE.read_text(encoding='utf-8-sig'),'compiler memory registry and error behavior fully reused')
    ast.parse(adapted)
    for path in HERE.glob('*.py'):ast.parse(path.read_text(encoding='utf-8-sig'),filename=str(path))
    check(True,'all new Python and adapted recipe parse')
    component=ROOT/'build/m52/recovery-early-paint-aggregate-component-01'
    if (component/'receipt.json').exists():
        receipt=read(component/'receipt.json')
        check(receipt.get('source_unchanged') is True and receipt.get('installation_unchanged') is True,
              'actual component receipt retained source and installation checks')
    component_static.main()
    data=audit_checks.run()
    check(data['passed']>35,'strict aggregate schema positive and negative audits')
    if (HERE/'inputs.json').exists():verify_tools();check(True,'frozen aggregate source inputs remain exact')
    print(json.dumps(dict(source_passed=len(checks),checks=checks,audit=data,
        source_frozen=(HERE/'inputs.json').exists(),compiled=False,air_started=False,performance_qualified=False),ensure_ascii=False))

if __name__=='__main__':main()
