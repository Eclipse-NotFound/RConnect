package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.FirstRasterGate;
   public class FirstRasterGateChecks extends Sprite {
      private var rows:Array=[];
      public function FirstRasterGateChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function run(e:Event):void {
         try {
            var g:Object={ready:false,sceneViewReady:function():Boolean{return g.ready;}};
            var w:Object={game:{},land:{},grafon:g};w.loc={land:w.land};
            var gate:FirstRasterGate=new FirstRasterGate(),t:Object=gate.open(w,w.loc,g,"host:1");
            check(t!=null && t.waiting && t.unpainted,"initial exact ticket waits without pretending pixels");
            check(gate.open(w,w.loc,g,"host:1")===t,"same identity does not allocate a new ticket");
            check(gate.open(w,w.loc,g,"host:2")==null,"new travel cannot overtake live ticket");
            check(!gate.matches(w,w.loc,{},"host:1"),"renderer replacement rejects binding");
            check(!gate.matches(w,{land:w.land},g,"host:1"),"location replacement rejects binding");
            var oldGame:Object=w.game;w.game={};check(!gate.matches(w,w.loc,g,"host:1"),"Game replacement inside same World rejects binding");w.game=oldGame;
            var oldLand:Object=w.land;w.land={};check(!gate.matches(w,w.loc,g,"host:1"),"Land replacement rejects binding");w.land=oldLand;
            var threw:Boolean=false;try{gate.beginRestore(w,w.loc,g,"host:0");}catch(error:Error){threw=true;}
            check(threw && t.waiting,"old grant cannot release raster wait");
            gate.beginRestore(w,w.loc,g,"host:1");check(!t.waiting && t.unpainted,"restore allows drawing without declaring it painted");
            gate.restored(w,w.loc,g,"host:1",4,2,8);
            check(gate.sameGrant(4,2,"host:1") && !gate.sameGrant(3,2,"host:1"),"receipt keeps exact barrier/epoch/travel");
            g.ready=true;t.unpainted=false;
            check(!gate.ready(w,w.loc,g,"host:1",8),"same frame cannot complete anchored view");
            g.ready=false;check(!gate.ready(w,w.loc,g,"host:1",9),"unready native viewport cannot ACK");
            g.ready=true;check(gate.ready(w,w.loc,g,"host:1",9),"next actually ready native view can finish");
            var r:Object=gate.complete();check(r.barrier==4 && !gate.active && !gate.awaitingView,"completion releases all retained native identities");
            t=gate.open(w,w.loc,g,"host:2");gate.cancel();
            check(!gate.active && !t.waiting && t.unpainted,"cancel unblocks drawing but preserves need for real pixels");
            check(!gate.ready(w,w.loc,g,"host:2",100),"late completion cannot ACK a canceled ticket");
            check(gate.open(null,w.loc,g,"host:3")==null,"unknown world falls back to native");
            check(gate.open(w,w.loc,g,"")==null,"unknown travel falls back to native");
            check(gate.open(w,w.loc,{},"host:3")==null,"foreign renderer falls back to native");
         }catch(e:Error){check(false,e+" "+e.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,native_game_test:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
