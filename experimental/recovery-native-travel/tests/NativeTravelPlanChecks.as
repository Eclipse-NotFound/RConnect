package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.core.NativeTravelPlan;
   public class NativeTravelPlanChecks extends Sprite {
      private var count:int=0,failed:int=0,assertions:Array=[];
      public function NativeTravelPlanChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function begin(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,begin);
         try{run();}catch(error:Error){
            if(assertions.length==0 || assertions[assertions.length-1].passed) {
               assertions.push({passed:false,label:"uncaught "+error+" "+error.getStackTrace()});failed++;
            }
            trace(error+" "+error.getStackTrace());
         }
         var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         file.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,
            functional_only:true,native_runtime:false}));file.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function run():void {
         var world:Object={},g:Object={curLandId:"way"};
         world.game=g;
         var host:NativeTravelPlan=new NativeTravelPlan("host"),join:NativeTravelPlan=new NativeTravelPlan("join");
         check(host.adopt(world,g)==null,"offline/no plan preserves native decision");
         var input:Object={curLandId:"way",nativeCreate:true,firstVisit:true,constructorLevel:29,entryCoord:"1:2"};
         var msg:Object=host.offer(input,4,world);
         check(NativeTravelPlan.valid(msg),"native decision valid");
         check(msg.travelId=="host:1","host identity monotonic");
         check(join.receive(msg,world,4),"receiver accepts native plan");
         check(!join.receive(msg,world,4),"duplicate prepare before start is inert");
         check(join.adopt(world,g)==null,"not started cannot consume plan");
         join.markStarted(world);
         var actual:Object=join.adopt(world,g);
         check(actual.curLandId=="way","resolved Encounter target preserved");
         check(actual.firstVisit===true,"first visit preserved independently of local visited");
         check(actual.constructorLevel==29,"raw constructor input preserved");
         check(actual.entryCoord=="1:2","native coordinate preserved");
         check(join.adopt(world,g)==null,"native plan consumed once");
         check(!join.receive(msg,world,4),"duplicate prepare after adoption is inert");
         expect(function():void{join.markStarted(world);},"duplicate native start rejected");
         expect(function():void{host.offer(input,4,world);},"new host plan cannot overtake active plan");
         var info:Object={curLandId:"way",roomKey:"way/1/2/0",landX:1,landY:2,landZ:0,x:100,y:200};
         var anchor:Object=host.captureAnchor(info);info.x=999;
         check(host.captureAnchor(info).x==100,"anchor does not follow host movement");
         join.acceptAnchor(anchor);anchor.x=888;
         check(join.anchor.x==100,"received anchor is copied");
         expect(function():void{join.acceptAnchor(anchor);},"changed anchor rejected");
         check(join.accepts(msg.travelId)&&!join.accepts("other:1"),"room control uses active identity");
         expect(function():void{join.finish("other:1");},"wrong completion rejected");
         join.finish(msg.travelId);host.finish(msg.travelId);
         check(!join.receive(msg,world,4),"retired prepare does not restart same map");
         check(join.retiredToken(msg.travelId),"retired world snapshots cannot restart cancelled or completed travel");
         check(join.accepts("")&&!join.accepts(msg.travelId),"legacy room transfer allowed only without native plan");
         var again:Object=host.offer(input,5,world);
         check(again.travelId=="host:2","same target new creation gets distinct identity");
         expect(function():void{join.receive(again,world,4);},"old epoch cannot accept next plan");
         check(join.receive(again,world,5),"next native entry accepted");
         expect(function():void{join.markStarted({});},"world replacement cannot consume old start");
         join.markStarted(world);expect(function():void{join.adopt(world,{curLandId:"post"});},"redirected local destination refused");
         join.cancel();check(!join.receive(again,world,5),"cancelled token cannot re-enter after world change");
         host.cancel();var third:Object=host.offer(input,6,world);third.info.constructorLevel=null;
         check(!NativeTravelPlan.valid(third),"missing level rejected");
         third.info.constructorLevel=2.5;check(!NativeTravelPlan.valid(third),"fractional level rejected");
         third.info.constructorLevel=2;third.sequence=3.5;check(!NativeTravelPlan.valid(third),"fractional sequence rejected");
         var replacement:NativeTravelPlan=new NativeTravelPlan("replacement"),replacementMessage:Object={type:"room",op:"prepare",
            planVersion:1,nonce:"reload",sequence:1,travelId:"reload:1",fromEpoch:6,
            info:{curLandId:"way",nativeCreate:true,firstVisit:true,constructorLevel:1,entryCoord:null}};
         replacement.receive(replacementMessage,world,6);replacement.markStarted(world);
         world.game={curLandId:"way"};
         check(!replacement.matchesWorld(world),"same World with replaced Game invalidates plan");
         expect(function():void{replacement.adopt(world,world.game);},"loadGame cannot consume the previous Game plan");
         trace("NATIVE_TRAVEL_CHECKS_PASS count="+count);
      }
      private function check(value:Boolean,label:String):void {
         assertions.push({passed:value,label:label});
         if(!value){failed++;throw new Error("FAIL "+label);}count++;
      }
      private function expect(fn:Function,label:String):void {var failed:Boolean=false;try{fn();}catch(e:Error){failed=true;}check(failed,label);}
   }
}
