package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.filesystem.*;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.*;

   /** Real RoomSync timeout with a bounded wall-clock wait, not clock rewriting. */
   public class FollowWaitChecks extends Sprite {
      private var m:RConnectMod,rows:Array=[],timer:Timer,started:int;
      public function FollowWaitChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function frame():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));}
      private function last(op:String):Object {
         var found:Object;for each(var msg:Object in m.session.outbox)if(msg.op==op)found=msg;
         if(found==null)throw new Error("Missing "+op);return found;
      }
      private function begin(e:Event):void {
         try {
            m=new RConnectMod(stage);m.session.mode=Session.HOSTING;m.session.peers=[{}];m.session.pause={paused:false};
            m.session.rooms=new RoomSync(m.session);frame();var seal:Object=last("seal");
            m.session.rooms.handle({type:"room",op:"ready",barrier:seal.barrier,epoch:seal.epoch,
               info:m.game.readWorldInfo(),oldKey:"",oldTerm:0,own:null,fresh:null});
            m.session.rooms.handle({type:"room",op:"ack",barrier:seal.barrier});
            check(m.session.rooms.canSyncWorld,"native fixture starts settled");
            var origin:Object=m.game.loc;
            m.game.setRoom("map//1,0,0");var target:Object=m.game.loc;m.game.setRoom("map//0,0,0");
            m.game.world.land.locs=[[[origin]],[[target]]];m.game.followCalls=0;
            m.config={getValue:function(k:String):String{return k=="followTeammate"?"1":"0";}};
            var here:Object=m.game.readWorldInfo(),there:Object=m.game.readWorldInfo();
            there.roomKey="map//1,0,0";there.landX=1;
            m.session.rooms.observeTeammate(here);m.session.rooms.observeTeammate(there);
            m.game.transition=true;m.game.world.t_exit=17;started=getTimer();frame();
            timer=new Timer(3300,1);timer.addEventListener(TimerEvent.TIMER_COMPLETE,resume);timer.start();
         }catch(error:Error){check(false,error+" "+error.getStackTrace());finish();}
      }
      private function resume(e:TimerEvent):void {
         try {
            check(getTimer()-started>=3000,"the blocked interval exceeds the old three-second expiry");
            check(int(m.game.followCalls)==0,"blocked loading cannot attempt a room transition");
            m.game.transition=false;m.game.world.t_exit=0;frame();
            check(int(m.game.followCalls)==1,"follow intent is still attempted immediately after loading");
            check(Log.errors.length==0,"waiting produces no room error");
         }catch(error:Error){check(false,error+" "+error.getStackTrace());}
         finish();
      }
      private function finish():void {
         if(timer!=null)timer.stop();var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
