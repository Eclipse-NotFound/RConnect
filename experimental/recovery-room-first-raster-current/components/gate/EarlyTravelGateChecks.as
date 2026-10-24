package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.EarlyTravelGate;
   public class EarlyTravelGateChecks extends Sprite {
      private var rows:Array=[],gate:EarlyTravelGate,w:Object,info:Object,t:Object,scans:int;
      public function EarlyTravelGateChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function setup():void {
         gate=new EarlyTravelGate();scans=0;
         w={game:{lands:{city:{rnd:true}},curLandId:"city"},land:{},gg:{},t_die:0,comLoad:-1,ng_wait:0,t_exit:19};
         w.grafon={sceneCullRender:true,scenePreload:false,sceneViewReady:function():Boolean{scans++;return true;}};
         info={curLandId:"city",layoutSeed:77,sceneMerged:true,earlyId:"token:1",earlyEpoch:1};
         gate.arm(info,w,1);w.land={act:{id:"city"},rconnectLayoutSeed:77};w.loc={land:w.land};
         t=gate.open(w,w.loc,w.grafon);gate.finishConstruction(w);
      }
      private function seal():Object{return {earlyId:"token:1",epoch:2,barrier:4,info:{curLandId:"city",layoutSeed:77,sceneMerged:true,roomKey:"city//0,0,0",x:800,y:240}};}
      private function run():void {
         setup();check(gate.active && gate.constructed && t.waiting,"exact constructed target obtains held raster");
         check(gate.acceptSeal(seal()) && gate.acceptSeal(seal()),"exact duplicate seal preserves fixed anchor");
         var m:Object=seal();m.info.layoutSeed=78;check(!gate.acceptSeal(m),"same map different seed rejected");
         m=seal();m.epoch=1;check(!gate.acceptSeal(m),"old epoch rejected");
         m=seal();m.epoch=3;check(!gate.acceptSeal(m),"skipped generation rejected");
         m=seal();m.barrier=5;var threw:Boolean=false;try{gate.acceptSeal(m);}catch(e:Error){threw=true;}
         check(threw,"changed barrier cannot replace fixed seal");
         m=seal();m.info.x=801;threw=false;try{gate.acceptSeal(m);}catch(e2:Error){threw=true;}
         check(threw,"changed birth position cannot replace fixed seal");
         gate.allowPaint(w,9);check(t.waiting===false && !gate.viewReady(w,10),"paint release does not bypass native loading");
         w.t_exit=0;check(!gate.viewReady(w,10),"native zero without actual raster is not ready");
         t.unpainted=false;check(!gate.viewReady(w,9),"same native frame is not a completed first view");
         check(gate.viewReady(w,10) && scans==1,"later native-ready frame scans real renderer once");
         check(gate.viewReady(w,11) && scans==1,"completed view does not rescan every frame");
         w.game={};check(!gate.valid(w) && !gate.viewReady(w,12),"replacement Game invalidates even already-ready ticket");
         setup();w.land.rconnectLayoutSeed=78;check(!gate.finishConstruction(w) && !gate.valid(w),"changed destination generation invalidates gate");
         setup();w.gg={};check(!gate.sameWorld(w),"replacement local player rejected");
         setup();w.t_die=1;check(!gate.safeWorld(w),"death invalidates native loading exception");
         setup();w.comLoad=0;check(!gate.safeWorld(w),"load request invalidates native loading exception");
         setup();w.ng_wait=1;check(!gate.safeWorld(w),"new game request invalidates native loading exception");
         setup();w.t_exit=20;check(!gate.safeWorld(w),"new transition cannot borrow a constructed ticket");
         setup();gate.cancel();check(t.waiting===false && t.unpainted===true && !gate.active,"cancel releases waiting only; it never invents painted evidence");
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
