package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import rconnect.game.ImpactEventQueue;
   import rconnect.game.RemoteMotion;
   public class ImpactQueueChecks extends Sprite {
      private var checks:Array=[],failures:int=0,calls:Array=[];
      private var loc:Object={active:true,lastObj:null,firstObj:null};
      private var main:Object;
      public function ImpactQueueChecks() {
         main={loaderInfo:{applicationDomain:{getDefinition:definition}}};
         try {run();ImpactCaptureChecks.run(check);}catch(e:Error){check(false,"uncaught "+e.getStackTrace());}
         var s:FileStream=new FileStream();s.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         s.writeUTFBytes(JSON.stringify({pass:checks.length-failures,fail:failures,checks:checks,gameLoaded:false}));s.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }
      private function check(ok:Boolean,label:String):void {checks.push({pass:ok,label:label});if(!ok)failures++;}
      private function definition(name:String):Object {
         if(name!="fe.graph.Emitter")throw new Error("Unexpected native call "+name);
         // Count the real production renderer's Emitter boundary only. No fake
         // collision, world, damage method or weapon exists in this component.
         return {emit:function(kind:String,room:Object,x:Number,y:Number,options:Object):void {
            calls.push({kind:kind,room:room,x:x,y:y,count:options.kol,dx:options.dx,dy:options.dy});
         }};
      }
      private function hit(seq:int,stamp:Number=1100):Object {
         return {seq:seq,flight:{impact:{at:stamp,x:200+seq,y:100,groups:[{kind:"iskr_bul",count:4,dx:-10,dy:0}]}}};
      }
      private function run():void {
         var q:ImpactEventQueue=new ImpactEventQueue(),clock:RemoteMotion=new RemoteMotion(),channel:Object={},now:int=getTimer();
         q.receive(channel,[{seq:1,flight:{}}],loc,main,0,100,clock);q.tick(loc,now);
         check(calls.length==0,"flight without actual hit emits nothing");
         q.receive(channel,[hit(1)],loc,main,0,100,clock);q.tick(loc,now);
         check(calls.length==0,"impact waits for source playback time");
         clock.sourceTime=1100;q.tick(loc,now);
         check(calls.length==1 && calls[0].x==201 && calls[0].count==4 && calls[0].dx==-10,"confirmed hit uses native recipe/position/count/direction");
         for(var i:int=0;i<100;i++){q.receive(channel,[hit(1)],loc,main,0,100,clock);q.tick(loc,now);}
         check(calls.length==1,"100 repeated snapshots do not duplicate impact");
         q.receive(channel,[hit(4)],loc,main,0,100,clock);q.tick(loc,now);
         q.receive(channel,[hit(2)],loc,main,0,100,clock);q.tick(loc,now);
         check(calls.length==3,"late older shot impact survives newer sequence");
         q.receive({},[hit(1)],loc,main,0,100,clock);q.tick(loc,now);
         check(calls.length==4,"different weapon stream keeps its own identity");
         q.receive(channel,[hit(5,1200)],loc,main,0,100,clock);q.tick({active:true},now);clock.sourceTime=1200;q.tick(loc,now);
         check(calls.length==4,"room departure discards queued impact");
         q.receive(channel,[hit(6,1300)],loc,main,0,100,clock);q.reset();clock.sourceTime=1300;q.tick(loc,now);
         check(calls.length==4,"disconnect/reset drops pending impact");
         q.receive(channel,[hit(1,1300)],loc,main,0,100,clock);q.tick(loc,now);
         check(calls.length==5,"new session may reuse old sequence");
         q.receive(channel,[hit(7,1400)],loc,main,0,100,clock);q.setPaused(true);q.tick(loc,now+5000);
         check(calls.length==5,"frozen source clock does not advance impact during pause");
         q.setPaused(false);clock.sourceTime=1400;q.tick(loc,getTimer());
         check(calls.length==6,"resume emits pending impact once");
         var invalid:Object=hit(8,1400);invalid.flight.impact.groups[0].kind="damaging-explosion";
         q.receive(channel,[invalid],loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==6,"unrecognised recipe never reaches native emitter");
         invalid=hit(9,1400);invalid.flight.impact.x=NaN;
         q.receive(channel,[invalid],loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==6,"invalid coordinates never reach native emitter");
         q.receive(channel,[hit(10,1500)],loc,main,0,100,clock);clock.sourceTime=1600;q.tick(loc,getTimer());
         check(calls.length==7,"packet that skips whole flight still displays confirmed hit");
         clock.sourceTime=20000;q.receive(channel,[hit(11,1000)],loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==7,"stale old-room timestamp is not revived");
         loc.active=false;q.receive(channel,[hit(12,20000)],loc,main,0,100,clock);q.tick(loc,getTimer());loc.active=true;
         check(calls.length==7,"inactive native room emits nothing");
         var burst:Array=[];for(i=0;i<200;i++)burst.push(hit(100+i,20000));
         q.receive(channel,burst,loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==207,"200 dense independent confirmed impacts are preserved");
         q.receive(channel,burst,loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==207,"dense duplicate packet stays deduplicated");
         var detached:Object=hit(400,20000);detached.impact=detached.flight.impact;detached.flight=null;
         q.receive(channel,[detached],loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==208,"confirmed collision survives disposed projectile clip");
         q.receive(channel,[detached],loc,main,0,100,clock);q.tick(loc,getTimer());
         check(calls.length==208,"clip-less collision still deduplicates on shot sequence");
         q.reset();
      }
   }
}
