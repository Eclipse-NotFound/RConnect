"""Prove exact v3 source compatibility with the existing v2 observer; no runtime approval."""
import re
from native_inputs import HOST_SOURCE,SOURCE_SHA,driver,sha,read,load

V2_SHA='3bdc70d8c81d7ca2cdda070cb16421e3d7b412bb34a54d6b7d4aae2446e7ad07'
V3_MANIFEST='0c0e6851510ac6e62e1aa62aa0865436bf393468374ba81f99d614028670b9a3'
FIELDS='phase preload initial left top width height started finished startedWall finishedWall residentBefore residentAfter completed sameWorld sameGame sameLoc worldRendererAtStart worldRendererAtEnd worldLocAtStart worldLocAtEnd'.split()
CALL='paintObserver(this,paintWorld,paintGame,paintLoc,{'

def norm(text):return re.sub(r'\s+','',text)
def ensure(text):
    start=text.index('      private function sceneEnsure(')
    end=text.index('      public function sceneTick()',start)
    return text[start:end].rstrip()

def compare(before,after):
    old=ensure(before);new=ensure(after)
    assert before.replace(old,'__ensure__',1)==after.replace(new,'__ensure__',1), 'Only sceneEnsure may differ from v2'
    assert old.split('var paintCompleted:Boolean = false;',1)[0]==new.split('var paintCompleted:Boolean = false;',1)[0], 'Early returns/capture identity/timers changed'
    assert CALL in old and CALL in new,'Callback five-argument order changed'
    old_payload=old.split(CALL,1)[1].split('});',1)[0]
    new_payload=new.split(CALL,1)[1].split('});',1)[0]
    assert norm(old_payload)==norm(new_payload),'Callback field expressions changed'
    assert re.findall(r'^\s*([A-Za-z][A-Za-z0-9]*):',new_payload,re.M)==FIELDS
    old_observer=old.split('         finally\n         {\n',1)[1][:-len('         }\n      }')]
    new_observer=new.split('            paintFailure = paintNativeError;\n         }\n',1)[1].split('         if(paintFailed)',1)[0]
    assert norm(old_observer)==norm(new_observer),'Observer timing/fault/callback logic changed'
    assert 'finally' not in new
    assert new.count('return;')==2
    assert new.count('this.scenePreloadAll();')==new.count('this.sceneEnsureUpcoming(left,top,width,height);')==1
    assert 'var paintFailed:Boolean = false;' in new and 'var paintFailure:*;' in new
    assert 'if(paintFailed)\n         {\n            throw paintFailure;' in new
    return dict(callback_arguments=['this','paintWorld','paintGame','paintLoc','value'],
        fields=FIELDS,callback_field_expressions_identical=True,observer_block_identical=True,
        early_returns_and_capture_identical=True,all_other_source_identical=True,
        only_changed_behavior='explicit saved-original-error propagation instead of finally',
        diagnostic_only=True,runtime_qualified=False,performance_qualified=False)

def verify():
    driver.verify_tools()
    assert sha(HOST_SOURCE/'prepared.json')==V3_MANIFEST
    handoff=read(HOST_SOURCE/'handoff.json')
    for n,h in handoff['files'].items():assert sha(HOST_SOURCE/n)==h,n
    old_path=driver.HOST_V2/'src/fe/graph/Grafon.as'
    new_path=HOST_SOURCE/'src/fe/graph/Grafon.as'
    assert sha(old_path)==V2_SHA and sha(new_path)==SOURCE_SHA
    meta=read(HOST_SOURCE/'prepared.json')
    assert meta['prior_diagnostic_source_sha256']==V2_SHA and meta['prepared_source_sha256']==SOURCE_SHA
    assert meta['contract_changed'] is False and meta['imports_changed'] is False
    recipe=load('paint_native_exact_v3_source_recipe',HOST_SOURCE/'prepare.py')
    assert recipe.transform(recipe.SOURCE.read_bytes())==new_path.read_bytes(), 'Changed exception flow differs from exact reviewed transformation'
    result=compare(old_path.read_text(encoding='utf-8'),new_path.read_text(encoding='utf-8'))
    result.update(driver_host_source_sha256=V2_SHA,actual_host_source_sha256=SOURCE_SHA,
        source_manifest_sha256=V3_MANIFEST,driver_sources_unchanged=True)
    return result
