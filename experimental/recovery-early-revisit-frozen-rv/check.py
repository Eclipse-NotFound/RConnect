"""Read-only identity checks; no compiler/AIR/install writes."""
import ast,json
from pathlib import Path
from native_inputs import HERE,verify_tools,verify_original_driver,sandy_input,audit,host_input,CANDIDATE,HOST,installation
from baseline import assert_current,RV_KEY,RV_OLD,RV_NEW,frozen_vision
def main():
    verify_tools();checks=[]
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'));checks.append('syntax '+p.name)
    path,meta=verify_original_driver();checks.append('exact compiled original driver and every input')
    current=installation();old=meta['installation_before'];assert_current(current,old);checks.append('only pinned RV install transition')
    changed=[]
    row=dict(current);row[RV_KEY]=RV_OLD;changed.append(row)
    row=dict(current);row[RV_KEY]='0'*64;changed.append(row)
    row=dict(current);row['pfe.swf']='0'*64;changed.append(row)
    row=dict(current);row.pop('pfe.swf');changed.append(row)
    row=dict(current);row['extra']='0'*64;changed.append(row)
    for i,row in enumerate(changed):
        try:assert_current(row,old)
        except AssertionError:checks.append('reject changed installation '+str(i))
        else:raise AssertionError('Unpinned install accepted')
    sandy_input('bridge');checks.append('exact Sand003 receipt source tools and original installation')
    frozen_vision();checks.append('exact old RV bytes and deployment receipt')
    audit(CANDIDATE);checks.append('exact RC frozen sources tools binary')
    host_input(HOST,current);checks.append('complete host readback with sole explicit RV transition')
    prep=(HERE/'prepare.py').read_text(encoding='utf-8');assert 'subprocess.run(' not in prep
    assert 'verify_original_driver();sandy_input' in prep;checks.append('no obsolete original preparer invoked')
    assert 'PROBE/\'tests/FirstRasterSceneProbe.as\'' in prep;checks.append('unchanged prior diagnostic observer reused')
    run=(HERE/'run_native.py').read_text(encoding='utf-8')
    assert "cmd+=['--vision-candidate',str(rv)]" in run
    assert "modules[RV_KEY.lower()]==RV_OLD and inp['vision']==RV_OLD" in run
    assert 'before[RV_KEY]==after[RV_KEY]==RV_NEW' in run;checks.append('actual run modules and installed RV both verified')
    assert "result['early_performance_qualified']=False" in run;checks.append('no performance qualification')
    print(json.dumps({'passed':checks,'count':len(checks),'compiled':False,'air_started':False},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
