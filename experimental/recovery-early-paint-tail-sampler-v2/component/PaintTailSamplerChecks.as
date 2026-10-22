package {
   import flash.events.Event;
   import flash.events.EventDispatcher;

   /** Small injected-adapter component. It never imports/calls flash.sampler,
    * never loads a game and never changes a production observer slot.
    * run() is executable AS3 test source; it has NOT been compiled/run here. */
   public final class PaintTailSamplerChecks {
      private static var checks:int,failures:Array,assertions:Array;
      private static function check(ok:Boolean,label:String):void {
         checks++;assertions.push({passed:ok,label:label});if(!ok)failures.push(label);
      }
      private static function fixture():Object {
         var api:FakePaintTailApi=new FakePaintTailApi(),stage:EventDispatcher=new EventDispatcher();
         var room:Object={},g:Object={loc:room},w:Object={game:{},grafon:g,loc:room},ownership:Object={valid:true};
         var p:PaintTailSampler=new PaintTailSampler(api,function():Boolean{return ownership.valid;});
         p.attach(stage);p.begin(w);p.bind(w,room,g);
         return {api:api,stage:stage,room:room,g:g,w:w,p:p,ownership:ownership};
      }
      private static function metadata(f:Object):Object {
         return {phase:"ensure-work",completed:true,residentBefore:0,residentAfter:35,
            initial:false,preload:false,started:1,finished:f.api.t-10,startedWall:10001,
            finishedWall:10000+f.api.t-10,sameWorld:true,sameGame:true,sameLoc:true,
            worldRendererAtStart:true,worldRendererAtEnd:true,worldLocAtStart:true,worldLocAtEnd:true};
      }
      private static function trigger(f:Object,v:Object=null):void {
         f.p.observe(f.g,f.w,f.w.game,f.room,v==null?metadata(f):v);
      }
      private static function next(f:Object):void {f.api.t+=2000;f.stage.dispatchEvent(new Event(Event.ENTER_FRAME));}
      private static function cpu(name:String="work",depth:int=1):Object {
         var frames:Array=[];for(var i:int=0;i<depth;i++)frames.push({name:name,file:"fake.as",line:i});
         return {kind:0,frames:frames};
      }
      public static function run():Object {
         checks=0;failures=[];assertions=[];
         var f:Object=fixture(),v:Object=metadata(f),row:Object,result:Object,i:int;
         v.completed=false;trigger(f,v);check(f.api.starts==0,"failed ensure never starts");
         v=metadata(f);v.residentBefore=1;trigger(f,v);check(f.api.starts==0,"resident-positive call never starts");
         v=metadata(f);f.p.observe(f.g,f.w,f.w.game,{},v);check(f.api.starts==0,"other room never starts");
         f.api.data=[cpu(),{kind:1},{kind:2}];trigger(f);trigger(f);
         check(f.api.starts==1,"initial=false real transition starts once");
         var lowerSawPause:Boolean=false;
         f.stage.addEventListener(Event.ENTER_FRAME,function(e:Event):void {lowerSawPause=f.api.pauses==1;},false,100006);
         next(f);row=f.p.finish();
         check(lowerSawPause,"pause precedes lower-priority listener on same stage");
         check(row.complete && row.samplingComplete && row.cpuEvidenceComplete,"normal complete CPU window");
         check(row.cpu==1 && row.allocationsSkipped==1 && row.deletionsSkipped==1,"CPU-only accounting");
         check(row.clocks.stop.t<row.clocks.collectEnd.t && row.collectMs>0,"collection cost outside sample boundary");
         check(f.api.ops.indexOf("pause")<f.api.ops.indexOf("samples"),"pause before enumeration");
         check(f.api.owner==null && f.api.stops==1 && row.cleanupComplete,"owned sampler cleaned and released");
         f.p.dispose();

         f=fixture();row=f.p.finish();check(row.reason=="not-triggered" && f.api.starts==0,"missing ensure not substituted");f.p.dispose();
         f=fixture();trigger(f);row=f.p.finish("cancel");
         check(!row.complete && row.reason=="cancel" && f.api.stops==1,"cancellation closes without complete label");f.p.dispose();

         f=fixture();
         for(i=0;i<3;i++) {
            if(i>0){f.p.begin(f.w);f.p.bind(f.w,f.room,f.g);}
            trigger(f);next(f);f.p.finish();
         }
         check(f.api.starts==3 && !f.p.begin(f.w),"three segments maximum");
         result=f.p.dispose();check(result.rows.length==3,"at most three retained rows");

         f=fixture();f.api.owner={foreign:true};trigger(f);row=f.p.finish();
         check(row.reason=="sampler-conflict" && f.api.ops.length==0,"foreign lease never cleared or paused");f.p.dispose();
         f=fixture();trigger(f);f.api.owner={foreign:true};next(f);row=f.p.finish();
         check(!row.ownerPreserved && !row.complete && f.api.pauses==0 && f.api.stops==0,"lost lease does not stop new owner");f.p.dispose();
         f=fixture();trigger(f);f.w.loc={};next(f);row=f.p.finish();
         check(!row.complete && !row.identityPreserved && row.cleanupComplete,"world replacement rejects window but cleans own sampler");f.p.dispose();
         f=fixture();trigger(f);f.ownership.valid=false;next(f);row=f.p.finish();
         check(!row.complete && !row.slotPreserved && row.cleanupComplete,"observer replacement rejects window");f.p.dispose();

         f=fixture();f.api.fail="start";trigger(f);row=f.p.finish();
         check(!row.started && !row.complete && row.cleanupComplete && f.api.stops==1,"partly-started throwing adapter cleaned");f.p.dispose();
         f=fixture();trigger(f);f.api.fail="pause";next(f);row=f.p.finish();
         check(!row.complete && f.api.ops.indexOf("samples")<0 && row.cleanupComplete,"pause failure skips collection and stops");f.p.dispose();
         f=fixture();f.api.data=[cpu()];trigger(f);f.api.fail="kind";next(f);row=f.p.finish();
         check(!row.complete && row.cleanupComplete,"collection failure still cleans");f.p.dispose();
         f=fixture();trigger(f);f.api.fail="stop";
         check(!f.p.begin(f.w),"cancel cleanup failure blocks new segment");
         result=f.p.dispose();check(result.cleanupBlocked && f.api.owner!=null,"failed stop retains lease and reports cleanup failure");
         f=fixture();trigger(f);f.api.t=0;f.stage.dispatchEvent(new Event(Event.ENTER_FRAME));row=f.p.finish();
         check(!row.complete && !row.clockOrdered && row.cleanupComplete,"clock reversal not qualified");f.p.dispose();

         f=fixture();var shared:Object=cpu();
         for(i=0;i<PaintTailSampler.SAMPLE_LIMIT+1;i++)f.api.data.push(shared);
         trigger(f);next(f);row=f.p.finish();
         check(row.complete && row.visited==PaintTailSampler.SAMPLE_LIMIT && row.sampleTruncated
            && !row.samplingComplete && !row.cpuEvidenceComplete,"sample cap rejects complete CPU evidence");f.p.dispose();
         f=fixture();f.api.data=[cpu("deep",PaintTailSampler.DEPTH_LIMIT+1)];trigger(f);next(f);row=f.p.finish();
         check(row.depthTruncated==1 && !row.samplingComplete,"depth truncation marked incomplete");f.p.dispose();
         f=fixture();var longName:String="";for(i=0;i<PaintTailSampler.FRAME_TEXT_LIMIT+1;i++)longName+="x";
         f.api.data=[cpu(longName)];trigger(f);next(f);row=f.p.finish();
         check(row.textTruncated==1 && !row.cpuEvidenceComplete,"frame text truncation marked incomplete");f.p.dispose();
         f=fixture();for(i=0;i<PaintTailSampler.STACK_LIMIT+1;i++)f.api.data.push(cpu("s"+i));
         trigger(f);next(f);row=f.p.finish();
         check(row.uniqueStacks==PaintTailSampler.STACK_LIMIT && row.stackOverflow==1 && !row.samplingComplete,"unique stack cap enforced");f.p.dispose();
         f=fixture();for(i=0;i<100;i++)f.api.data.push(cpu("long"+i+longName.substr(0,400),10));
         trigger(f);next(f);row=f.p.finish();
         check(row.stackTextChars<=PaintTailSampler.TEXT_LIMIT && row.textOverflow>0 && !row.samplingComplete,"total stack text bounded");f.p.dispose();
         f=fixture();trigger(f);next(f);row=f.p.finish();
         check(row.samplingComplete && !row.cpuEvidenceAvailable && !row.cpuEvidenceComplete,"zero samples are unavailable not CPU-free");f.p.dispose();
         f=fixture();f.api.data=[cpu()];f.api.countOverride=0;trigger(f);next(f);row=f.p.finish();
         check(!row.complete && !row.samplingComplete && !row.cpuEvidenceComplete && row.cleanupComplete,
            "paused count and enumeration disagreement rejects CPU evidence");f.p.dispose();
         return {kind:"paint-tail-injected-component",checks:checks,failures:failures,assertions:assertions,
            failed:failures.length,passed:failures.length==0,
            fakeSampler:true,realSamplerUsed:false,gameLoaded:false,performanceQualified:false};
      }
   }

}
