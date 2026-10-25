"""Prepare one shared, passive loading fixture. Text only; no compiler or AIR."""
from pathlib import Path
import ast, difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/goal-native-loading-probe-driver-01'
ORIGINAL={
 'RoomTravelTimingTestDoc.as':'ebe117b2b391a396eb83c79a616580b07bd7305b601b83acd9ca007e359e592c',
 'NativeLoadingProbe.as':'0bd3c84f3a48487ae9b9e0d651e2a901873913eba737622c2833edbc2cf64b92',
 'A22RoomMetrics.as':'314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)

def sources():
    for n,h in ORIGINAL.items():assert sha(BASE/'tests'/n)==h,n
    text=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf8')
    text=once(text,'                  cls.nativeEnabled=merged();\n                  sceneConfigured=Boolean(cls.nativeEnabled)==merged();break;',
                    '                  sceneConfigured=true;break;')
    text=once(text,'            check(sceneConfigured,"native scene preference was explicitly configured");',
                    '            check(!sceneConfigured && sceneClass==null,"ContinuousScene is explicitly not loaded");')
    text=once(text,'         if(!host && !solo && sceneClass!=null) {\n            mod.session.leave();\n            check(sceneClass.nativeEnabled===merged(),"disconnect preserves the configured same scene preference");',
                    '         if(!host && !solo) {\n            mod.session.leave();\n            check(sceneClass==null,"disconnect preserves ContinuousScene absence");')
    text=once(text,'seed:info.layoutSeed,units:w.loc.units.length,merged:merged(),actualMerged:actual,target:target};',
                    'seed:info.layoutSeed,units:w.loc.units.length,merged:merged(),actualMerged:actual,target:target,\n'
                    '            entranceView:{playerX:Number(w.gg.X),playerY:Number(w.gg.Y),cameraX:Number(w.cam.X),cameraY:Number(w.cam.Y),\n'
                    '               vx:Number(w.cam.vx),vy:Number(w.cam.vy),zoom:Number(w.cam.isZoom),scaleV:Number(w.cam.scaleV),\n'
                    '               stageWidth:mod.stage.stageWidth,stageHeight:mod.stage.stageHeight,\n'
                    '               visualX:Number(w.visual.x),visualY:Number(w.visual.y),visualScaleX:Number(w.visual.scaleX),visualScaleY:Number(w.visual.scaleY)}};')
    probe=(BASE/'tests/NativeLoadingProbe.as').read_text('utf8')
    probe=once(probe,'      private static const LIMIT:int=20000;',
                      '      private var solo:Boolean,expectedUi:Boolean,strictUi:Boolean,productVersion:String;\n      private static const LIMIT:int=20000;')
    probe=once(probe,'         mod=m;began=getTimer();',
                      '         mod=m;began=getTimer();\n'
                      '         productVersion=String(Object(mod).constructor.VERSION);\n'
                      '         solo=mod.config.getValue("autoRole")=="";\n'
                      '         expectedUi=productVersion=="0.2.24-nativeui1";strictUi=expectedUi&&!solo;\n'
                      '         if(!expectedUi && productVersion!="0.2.24-roomfix5")fault("product",productVersion);')
    probe=once(probe,'         var passed:Boolean=true;for each(var c:Object in checks)if(!c.passed)passed=false;',
                      '         // Preserve all 11 original UI assertions as evidence. Only the new UI\n'
                      '         // dual arm requires them; old host and solo cannot claim this contract.\n'
                      '         var uiChecks:Array=checks.concat();\n'
                      '         if(!strictUi) {\n'
                      '            checks=[uiChecks[0],uiChecks[1],uiChecks[2],uiChecks[5],uiChecks[8],uiChecks[9],uiChecks[10]];\n'
                      '            check(renderCount>0&&waitCount>0,"actual native loading observed without claiming the UI bridge");\n'
                      '         }\n'
                      '         var passed:Boolean=true;for each(var c:Object in checks)if(!c.passed)passed=false;')
    probe=once(probe,'            appId:NativeApplication.nativeApplication.applicationID,passed:passed,complete:true,checks:checks,',
                      '            appId:NativeApplication.nativeApplication.applicationID,passed:passed,complete:true,checks:checks,\n'
                      '            productVersion:productVersion,solo:solo,uiContractRequired:strictUi,\n'
                      '            uiContractQualified:strictUi&&passed,uiChecks:uiChecks,')
    return {'RoomTravelTimingTestDoc.as':text,'NativeLoadingProbe.as':probe,
            'A22RoomMetrics.as':(BASE/'tests/A22RoomMetrics.as').read_text('utf8')}

def diff_text():
    return ''.join(''.join(difflib.unified_diff((BASE/'tests'/n).read_text('utf8').splitlines(True),v.splitlines(True),
                   fromfile='original877B/tests/'+n,tofile='only-rconnect/tests/'+n)) for n,v in sources().items())

def verify():
    m=read(HERE/'source-manifest.json')
    assert m['kind']=='only-rconnect-loading-source-v1' and m['source_count']==3
    assert m['original_sources']==ORIGINAL and m['prepare_sha256']==sha(__file__)
    assert m['original_driver_prepared_sha256']==sha(BASE/'prepared.json')=='562bb57f0640eefb4f89fa2799fd52918baec49cdab42c434808a21c36840ca9'
    assert m['source_diff_sha256']==sha(HERE/'source.diff') and (HERE/'source.diff').read_text('utf8')==diff_text()
    for n,v in sources().items():assert (HERE/'tests'/n).read_text('utf8')==v and sha(HERE/'tests'/n)==m['sources'][n],n
    assert (HERE/'tests/A22RoomMetrics.as').read_bytes()==(BASE/'tests/A22RoomMetrics.as').read_bytes()
    assert m['runtime_environment']==actual_installation()
    return m

def actual_installation():
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from run_security_terminals import installation
    result=installation();assert len(result)==22;return result

def main():
    if sys.argv[1:]==['--prepare']:
        (HERE/'tests').mkdir(exist_ok=True)
        for n,v in sources().items():
            with (HERE/'tests'/n).open('x',encoding='utf8',newline='\n') as f:f.write(v)
        with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff_text())
        m=dict(kind='only-rconnect-loading-source-v1',source_count=3,prepare_sha256=sha(__file__),
               original_sources=ORIGINAL,original_driver_prepared_sha256=sha(BASE/'prepared.json'),
               source_diff_sha256=sha(HERE/'source.diff'),sources={n:sha(HERE/'tests'/n) for n in sources()},
               runtime_environment=actual_installation(),travelChecksDual={'host':23,'join':12},travelChecksSolo={'host':11},
               uiChecksDualCandidate=11,observationChecksBaselineOrSolo=8,compiled=False,air_started=False)
        with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,ensure_ascii=False,indent=2);f.write('\n')
    else:assert sys.argv[1:]==['--check']
    verify();print('Only-RConnect source verified; no Java/AIR')
if __name__=='__main__':main()
