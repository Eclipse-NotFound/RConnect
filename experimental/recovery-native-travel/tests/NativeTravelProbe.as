package {
   import flash.events.Event;
   import flash.utils.getTimer;
   /** External observer only. The production callback is always called exactly
    * once; this class neither starts a trip nor changes its decision. */
   public final class NativeTravelProbe {
      private static var mod:Object,main:Object,role:String,cls:Object,original:Function,wrapper:Function,lastLand:Object,lastExit:int=-1,lastReady:Boolean=false;
      public static function install(m:Object,rc:Object,name:String):void {
         main=m;mod=rc;role=name;
         cls=main.loaderInfo.applicationDomain.getDefinition("fe.loc.Game");
         original=cls.rconnectTravelBridge;
         if(original==null)throw new Error("Native travel observer requires registered production bridge");
         wrapper=function(phase:String,g:Object,info:Object):Object {
            mark(phase=="adopt"?"native-enter":"native-before-constructor",{target:g.curLandId,info:info});
            return original(phase,g,info);
         };
         cls.rconnectTravelBridge=wrapper;
         main.stage.addEventListener(Event.ENTER_FRAME,frame,false,-2000000000);
      }
      private static function frame(event:Event):void {
         var w:Object=mod.game.world;if(w==null)return;
         var exit:int=int(w.t_exit);
         if(exit!=lastExit){mark("exit-state",{exit:exit});lastExit=exit;}
         if(w.land!==lastLand){mark("land-visible-to-frame-observer",{id:w.land==null?null:w.land.act.id});lastLand=w.land;}
         var ready:Boolean=mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();
         if(ready!=lastReady){mark("confirmed-control",{ready:ready,key:mod.game.roomKey(),x:mod.game.gg==null?null:mod.game.gg.X,y:mod.game.gg==null?null:mod.game.gg.Y});lastReady=ready;}
      }
      private static function mark(kind:String,details:Object):void {
         trace("NATIVE_TRAVEL_PROBE "+JSON.stringify({role:role,kind:kind,wallMs:new Date().time,t:getTimer(),travelId:mod.game.activeTravelId,detail:details}));
      }
      public static function dispose():void {
         if(main!=null)main.stage.removeEventListener(Event.ENTER_FRAME,frame);
         if(cls!=null && cls.rconnectTravelBridge===wrapper)cls.rconnectTravelBridge=original;
         main=null;mod=null;cls=null;original=null;wrapper=null;lastLand=null;
      }
   }
}
