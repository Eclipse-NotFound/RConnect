package {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   /** Read-only raster/permit evidence. No production receive/acquire calls. */
   public final class FirstRasterSceneProbe {
      private var mod:Object,cls:Object,original:Function,wrapper:Function,active:Boolean=false;
      private var tickets:Dictionary=new Dictionary(),rows:Array=[],expected:Boolean=false;
      private var startPermit:Object,heldSeen:Boolean=false;
      public function FirstRasterSceneProbe(value:Object) {
         mod=value;cls=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
         if(!("rconnectRasterBridge" in cls) || !(cls.rconnectRasterBridge is Function))return;
         original=cls.rconnectRasterBridge;
         wrapper=function(w:Object,l:Object,g:Object):Object {
            var ticket:Object=original(w,l,g);
            if(active && ticket!=null && tickets[ticket]==null) {
               var permit:Object=query();
               var row:Object={at:getTimer(),wall:new Date().time,initialWaiting:ticket.waiting,
                  initialUnpainted:ticket.unpainted,exit:w.t_exit,paused:w.onPause,
                  firstReleased:-1,firstPainted:-1,permit:permit,
                  earlyPending:Boolean(mod.session.rooms.earlyTravelPending)};
               tickets[ticket]=row;rows.push(row);
               if(permit!=null && permit.held===true)heldSeen=true;
            }
            return ticket;
         };
         cls.rconnectRasterBridge=wrapper;
      }
      private function query():Object {
         var carrier:Object=mod.game.main.getChildByName("SandevistanTravelHoldV1");
         if(carrier==null)return null;
         if(carrier.version!==1 || carrier.contract!=="sandy-travel-hold/1")return {invalid:true};
         var w:Object=mod.game.world;
         return carrier.query(w,w.game);
      }
      public function begin(required:Boolean):void {
         active=true;expected=required;tickets=new Dictionary();rows=[];heldSeen=false;startPermit=query();
      }
      public function sample():void {
         if(!active)return;
         for(var ticket:Object in tickets) {
            var row:Object=tickets[ticket];
            if(ticket.waiting===false && row.firstReleased<0)row.firstReleased=getTimer();
            if(ticket.unpainted===false && row.firstPainted<0)row.firstPainted=getTimer();
         }
      }
      public function finish():Object {
         sample();active=false;var permit:Object=query();
         var ok:Boolean=expected?(original!=null && rows.length==1):rows.length==0;
         for each(var row:Object in rows) {
            ok=ok && row.initialWaiting===true && row.initialUnpainted===true
               && row.firstReleased>=0 && row.firstPainted>=row.firstReleased;
            if(SceneRasterBuildConfig.EXPECT_EARLY)ok=ok && row.earlyPending===true
               && row.permit!=null && row.permit.version===1
               && row.permit.contract==="sandy-travel-hold/1" && row.permit.held===true && row.permit.phase==="idle";
            else ok=ok && row.earlyPending===false && row.permit==null;
         }
         if(SceneRasterBuildConfig.EXPECT_EARLY) {
            ok=ok && startPermit!=null && startPermit.version===1 && startPermit.contract==="sandy-travel-hold/1"
               && startPermit.phase==="idle" && startPermit.held===false
               && permit!=null && permit.held===false && permit.phase==="idle"
               && !mod.session.rooms.earlyTravelPending && (!expected || heldSeen);
         }else ok=ok && startPermit==null && permit==null && !mod.session.rooms.earlyTravelPending;
         return {passed:ok,expected:expected,expectedEarly:SceneRasterBuildConfig.EXPECT_EARLY,
            callbackAvailable:original!=null,tickets:rows,startPermit:startPermit,finalPermit:permit,heldSeen:heldSeen,
            readbackOnly:true,pixelEquality:false,fullModFreezeQualified:false};
      }
      public function dispose():void {
         if(cls!=null && cls.rconnectRasterBridge===wrapper)cls.rconnectRasterBridge=original;
         active=false;tickets=new Dictionary();
      }
   }
}
