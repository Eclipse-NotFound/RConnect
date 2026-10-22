"""Exact additive observer integration only; no compiler or runtime invocation."""
from pathlib import Path
import hashlib,json,difflib

HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'recovery-early-paint-aggregate'
HELPER=HERE.parent/'recovery-early-paint-tail-sampler-v3'
PINS={
 'FirstRasterSceneProbe.as':'a1e5298292f33aa30dee4f827eb89d39270b1ae181c086ae3ff67b8c83f593e7',
 'PaintTimingBuffer.as':'b8684081e88fccba936ab987710e22bf735ef7daf1297357e791d91b9c8ce56e'}

EDITS={
 'PaintTimingBuffer.as':[
 ('      public function PaintTimingBuffer(type:Object) {cls=type;own=receive;}',
  '''      public var tailObserver:Function;
      public function ownsObserver():Boolean {
         return active && attached && cls!=null && cls.rconnectPaintTimingBridge===own;
      }
      public function PaintTimingBuffer(type:Object) {cls=type;own=receive;}'''),
 ('               left:Number(v.left),top:Number(v.top),width:Number(v.width),height:Number(v.height)});',
  '''               left:Number(v.left),top:Number(v.top),width:Number(v.width),height:Number(v.height)});
            // The aggregate entry above remains the sole native observer. A stable
            // resident call cannot trigger the 0-to-positive tail window.
            if(attached && tailObserver!=null)tailObserver(g,w,gameValue,l,v);''')],
 'FirstRasterSceneProbe.as':[
 ('      private var paintProbe:PaintTimingBuffer;',
  '      private var paintProbe:PaintTimingBuffer;\n      private var tailProbe:PaintTailSampler;'),
 ('         paintProbe=new PaintTimingBuffer(cls);',
  '''         paintProbe=new PaintTimingBuffer(cls);
         // Only the frozen exclusive diagnostic runner may load this driver.
         tailProbe=new PaintTailSampler(new FlashPaintTailSampler(true),
            function():Boolean {return paintProbe.ownsObserver();});
         tailProbe.attach(mod.stage);
         paintProbe.tailObserver=function(g:Object,w:Object,gameValue:Object,l:Object,v:Object):void {
            tailProbe.observe(g,w,gameValue,l,v);
         };'''),
 ('            paintProbe.bind(w,l,g);',
  '            paintProbe.bind(w,l,g);\n            tailProbe.bind(w,l,g);'),
 ('         paintProbe.begin(mod.game.world);',
  '         paintProbe.begin(mod.game.world);\n         tailProbe.begin(mod.game.world);'),
 ('         var result:Object=paintProbe.finish(reason);',
  '''         // Cancel/close while the original aggregate slot is still owned.
         var tail:Object=tailProbe.finish(reason);
         var result:Object=paintProbe.finish(reason);'''),
 ('         if(result!=null)Log.d("EARLY PAINT PROFILE "+JSON.stringify(result));',
  '''         if(result!=null)Log.d("EARLY PAINT PROFILE "+JSON.stringify(result));
         if(tail!=null) {
            var encodeStart:int=getTimer(),encodeStartWall:Number=new Date().time;
            var payload:String=JSON.stringify(tail);
            var encodeEnd:int=getTimer(),encodeEndWall:Number=new Date().time;
            var outputStart:int=getTimer(),outputStartWall:Number=new Date().time;
            Log.d("EARLY PAINT TAIL "+payload);
            var outputEnd:int=getTimer(),outputEndWall:Number=new Date().time;
            // This small timing marker's own output cost is not self-measured.
            Log.d("EARLY PAINT TAIL OUTPUT "+JSON.stringify({segment:tail.segment,
               encodeStart:encodeStart,encodeEnd:encodeEnd,encodeStartWall:encodeStartWall,encodeEndWall:encodeEndWall,
               outputStart:outputStart,outputEnd:outputEnd,outputStartWall:outputStartWall,outputEndWall:outputEndWall,
               encodeMs:encodeEnd-encodeStart,outputMs:outputEnd-outputStart,characters:payload.length,
               diagnosticOnly:true,performanceQualified:false}));
         }'''),
 ('         finishPaint("dispose");',
  '''         finishPaint("dispose");
         paintProbe.tailObserver=null;
         var tailSummary:Object=tailProbe.dispose();
         Log.d("EARLY PAINT TAIL SUMMARY "+JSON.stringify({kind:tailSummary.kind,
            globalFaults:tailSummary.globalFaults,cleanupBlocked:tailSummary.cleanupBlocked,
            segments:tailSummary.rows.length,diagnosticOnly:true,performanceQualified:false,runtimeQualified:false}));''')]
}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def transformed(name):
    path=BASE/'tests'/name
    assert sha(path)==PINS[name],name
    text=path.read_text(encoding='utf-8-sig')
    for old,new in EDITS[name]:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text

def main():
    assert not (HERE/'inputs.json').exists(),'Frozen source must never be regenerated'
    (HERE/'tests').mkdir(exist_ok=True)
    diff=[];origins={}
    for name in PINS:
        text=transformed(name);(HERE/'tests'/name).write_text(text,encoding='utf-8',newline='\n')
        origins[str(BASE/'tests'/name)]=PINS[name]
        diff.extend(difflib.unified_diff((BASE/'tests'/name).read_text(encoding='utf-8-sig').splitlines(True),
                    text.splitlines(True),fromfile='aggregate/'+name,tofile='tail/'+name))
    manifest=json.loads((HELPER/'component-inputs.json').read_text(encoding='utf-8'))
    for name in ('PaintTailSampler.as','FlashPaintTailSampler.as'):
        source=HELPER/'src'/name;assert sha(source)==manifest['source_sha256']['src/'+name]
        (HERE/'tests'/name).write_bytes(source.read_bytes());origins[str(source)]=sha(source)
    (HERE/'observer.patch').write_text(''.join(diff),encoding='utf-8')
    (HERE/'source-origin.json').write_text(json.dumps(dict(originals=origins,
        helper_manifest=str(HELPER/'component-inputs.json'),helper_manifest_sha256=sha(HELPER/'component-inputs.json'),
        source_only=True,compiled=False,performance_qualified=False),indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
