"""Add external paint observation around the exact original probe; no game build."""
from pathlib import Path
import difflib,hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-early-sandy-scene-driver-01'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return path.read_text(encoding='utf-8-sig')
def main():
    source=BASE/'tests/FirstRasterSceneProbe.as'
    assert sha(source)=='785e63b0c315941a81fccb5fc17832a10543fe83545435905ef9ff6ce7f7c789'
    before=read(source);after=before
    edits=[
      ('   import flash.utils.getTimer;', '   import flash.utils.getTimer;\n   import rconnect.core.Log;'),
      ('      private var startPermit:Object,heldSeen:Boolean=false;',
       '      private var startPermit:Object,heldSeen:Boolean=false;\n      private var paintProbe:PaintTimingBuffer;'),
      ('         mod=value;cls=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");',
       '         mod=value;cls=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");\n         paintProbe=new PaintTimingBuffer(cls);'),
      ('            var ticket:Object=original(w,l,g);',
       '            var ticket:Object=original(w,l,g);\n            paintProbe.bind(w,l,g);'),
      ('         active=true;expected=required;tickets=new Dictionary();rows=[];heldSeen=false;startPermit=query();',
       '         active=true;expected=required;tickets=new Dictionary();rows=[];heldSeen=false;startPermit=query();\n         paintProbe.begin(mod.game.world);'),
      ('         return {passed:ok,expected:expected,expectedEarly:SceneRasterBuildConfig.EXPECT_EARLY,',
       '         var paintEvidence:Object=finishPaint("finish");\n         return {passed:ok,expected:expected,expectedEarly:SceneRasterBuildConfig.EXPECT_EARLY,paintEvidence:paintEvidence,'),
      ('      public function dispose():void {',
       '      private function finishPaint(reason:String):Object {\n         var result:Object=paintProbe.finish(reason);\n         if(result!=null)Log.d("EARLY PAINT PROFILE "+JSON.stringify(result));\n         return result;\n      }\n      public function dispose():void {\n         finishPaint("dispose");'),
    ]
    for old,new in edits:
        assert after.count(old)==1,old
        after=after.replace(old,new)
    out=HERE/'tests/FirstRasterSceneProbe.as'
    assert not out.exists(),'Do not overwrite generated source'
    out.write_text(after,encoding='utf-8')
    (HERE/'probe.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='original/FirstRasterSceneProbe.as',tofile='paint/FirstRasterSceneProbe.as')),encoding='utf-8')
    (HERE/'probe-edits.json').write_text(json.dumps(edits,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(out)
if __name__=='__main__':main()
