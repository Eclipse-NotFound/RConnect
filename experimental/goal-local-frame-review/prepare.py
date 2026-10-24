"""Prepare only diagnostic AS text; never compile or launch a game."""
from pathlib import Path
import difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=HERE.parent/'goal-three-issues-native'
OLD=HERE.parent/'recovery-after-render-sampler/tests/SustainedDensityTestDoc.as'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def replace(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
def derived():
    assert sha(BASE/'tests/NativeMotionProbe.as')=='4ca25c80d0ebeda696f02ef842b56ea691fdf6dd8c78736e5c18e65b2712a394'
    assert sha(BASE/'tests/NativeJumpNetworkTestDoc.as')=='69c45eb85e1f7a77c4ca16dabbfd1cc82aee0cc60823ffc02722eb9bdabc3349'
    assert sha(OLD)=='d8a0cc014ace80377fe042b056efa4da5cdfd2e90ec700ff0ba27092126c5b06'
    s=(BASE/'tests/NativeMotionProbe.as').read_text('utf8')
    s=replace(s,'   import flash.events.Event;', '''   import flash.events.Event;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;''')
    s=replace(s,'      private static const LIMIT:int=4096;', '''      private static const LIMIT:int=4096;
      // Diagnostic phase is private to this observer, not the game's phase.
      private var phase:String="boot",densityProbe:int=0;
      private var diagSampling:Boolean=false,diagNumber:int=0,diagAt:int=0,diagAfter:int=0;
      private var diagRows:Array=[],diagRecord:Object,diagCounts:Object,diagDroppedRows:int=0;
      private var cpuReports:Array=[],cpuExported:Boolean=false;''')
    s=replace(s,'         target=o;key=targetKey;frame=0;frameAt=getTimer();lastRender=-1;', '''         if(name!="native-jump" || round!=0 || cpuReports.length!=0)throw new Error("CPU fixture requires one native-jump window");
         phase="load";
         target=o;key=targetKey;frame=0;frameAt=getTimer();lastRender=-1;''')
    s=replace(s,'         mod.stage.addEventListener(Event.RENDER,onRender,false,-40000);', '''         mod.stage.addEventListener(Event.RENDER,onRender,false,-40000);
         mod.stage.addEventListener(Event.ENTER_FRAME,diagBegin,false,1000000);
         mod.stage.addEventListener(Event.ENTER_FRAME,diagAfterFrame,false,-1000000);
         mod.stage.addEventListener(Event.RENDER,diagEnd,false,-1000000);''')
    s=replace(s,'         if(finalRender)captureRender();', '''         if(finalRender)captureRender();
         diagClose(getTimer(),"finish");phase="done";
         mod.stage.removeEventListener(Event.ENTER_FRAME,diagBegin);
         mod.stage.removeEventListener(Event.ENTER_FRAME,diagAfterFrame);
         mod.stage.removeEventListener(Event.RENDER,diagEnd);
         cpuReports.push({role:host?"host":"join",schema:1,
            scope:"stage-render-tail-to-next-stage-enter-entry",counts:diagCounts,
            droppedRows:diagDroppedRows,frames:diagRows,diagnosticOnly:true,
            kind:nameForCpu(),samplerStopped:!diagSampling,measurementReason:reason,
            measurementStartedAt:live.startedAt,measurementEndedAt:getTimer()});''')
    # Root-authorized sole collector change: six time-distributed selections.
    old=OLD.read_text('utf8')
    methods=old[old.index('      /** Original +1000000 stage ENTER callback.'):old.index('      public function SustainedDensityTestDoc(')]
    methods=replace(methods,'''         var selected:Boolean=(densityProbe==0 || densityProbe==1 || densityProbe==5 || densityProbe==6)
            && diagNumber%5==1 && diagNumber<30 && int(diagCounts[densityProbe])<6;''',
      '''         var selected:Boolean=int(diagCounts[densityProbe])<6
            && rendered-int(live.startedAt)>=1000+2500*int(diagCounts[densityProbe]);''')
    s=replace(s,'      public function close():void {',methods+'''      private function nameForCpu():String {return live==null?"missing":String(live.kind);}
      private function saveCpu():void {
         if(cpuExported)return;cpuExported=true;
         var stream:FileStream=new FileStream();
         try {
            stream.open(File.applicationStorageDirectory.resolvePath("native-jump-cpu.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify({kind:"ordinary-native-jump-cpu-v1",
               applicationId:NativeApplication.nativeApplication.applicationID,
               role:host?"host":"join",diagnosticOnly:true,performanceQualified:false,
               smoothnessQualified:false,samplerStopped:!diagSampling,profiles:cpuReports}));
         } finally {stream.close();}
      }
      public function close():void {''')
    s=replace(s,'         pending=[];','         pending=[];\n         saveCpu();')
    return {'NativeMotionProbe.as':s,'NativeJumpNetworkTestDoc.as':(BASE/'tests/NativeJumpNetworkTestDoc.as').read_text('utf8')}
def check():
    sources=derived()
    for name,s in sources.items(): assert (HERE/'tests'/name).read_text('utf8')==s,name
    m=json.loads((HERE/'source-manifest.json').read_text('utf8'))
    assert m['sources']=={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))}
    assert m['prepare_sha256']==sha(__file__) and m['diff_sha256']==sha(HERE/'source.diff')
    assert all(sha(p)==h for p,h in m['original'].items())
    return m
def main():
    if sys.argv[1:]==['--check']:
        check();print('Source-only check passed; no Java/AIR');return
    assert sys.argv[1:]==[]
    sources=derived();(HERE/'tests').mkdir(exist_ok=True);diff=''
    for name,s in sources.items():
        old=(BASE/'tests'/name).read_text('utf8')
        with (HERE/'tests'/name).open('x',encoding='utf8',newline='\n') as f:f.write(s)
        diff+=''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='current-native/'+name,tofile='cpu-only/'+name))
    (HERE/'source.diff').write_text(diff,encoding='utf8',newline='\n')
    originals=[BASE/'tests'/n for n in sources]+[OLD]
    m=dict(kind='ordinary-native-jump-cpu-v1',prepare_sha256=sha(__file__),
      diff_sha256=sha(HERE/'source.diff'),original={str(p):sha(p) for p in originals},
      sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))},
      compiled=False,air_started=False,performanceQualified=False)
    (HERE/'source-manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf8')
    check()
if __name__=='__main__':main()
