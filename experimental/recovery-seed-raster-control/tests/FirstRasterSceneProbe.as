package {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   /** Observes existing production tickets; never alters them or scans pixels. */
   public final class FirstRasterSceneProbe {
      private var cls:Object,original:Function,wrapper:Function,active:Boolean=false;
      private var tickets:Dictionary=new Dictionary(),rows:Array=[],expected:Boolean=false;
      public function FirstRasterSceneProbe(mod:Object) {
         cls=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
         if(!("rconnectRasterBridge" in cls) || !(cls.rconnectRasterBridge is Function))return;
         original=cls.rconnectRasterBridge;
         wrapper=function(w:Object,l:Object,g:Object):Object {
            var ticket:Object=original(w,l,g);
            if(active && ticket!=null && tickets[ticket]==null) {
               var row:Object={at:getTimer(),wall:new Date().time,initialWaiting:ticket.waiting,
                  initialUnpainted:ticket.unpainted,exit:w.t_exit,paused:w.onPause,
                  firstReleased:-1,firstPainted:-1};
               tickets[ticket]=row;rows.push(row);
            }
            return ticket;
         };
         cls.rconnectRasterBridge=wrapper;
      }
      public function begin(required:Boolean):void {active=true;expected=required;tickets=new Dictionary();rows=[];}
      public function sample():void {
         if(!active)return;
         for(var ticket:Object in tickets) {
            var row:Object=tickets[ticket];
            if(ticket.waiting===false && row.firstReleased<0)row.firstReleased=getTimer();
            if(ticket.unpainted===false && row.firstPainted<0)row.firstPainted=getTimer();
         }
      }
      public function finish():Object {
         sample();active=false;var ok:Boolean=expected?(original!=null && rows.length==1):rows.length==0;
         for each(var row:Object in rows)ok=ok && row.initialWaiting===true && row.initialUnpainted===true
            && row.firstReleased>=0 && row.firstPainted>=row.firstReleased;
         return {passed:ok,expected:expected,callbackAvailable:original!=null,tickets:rows,
            readbackOnly:true,pixelEquality:false};
      }
      public function dispose():void {
         if(cls!=null && cls.rconnectRasterBridge===wrapper)cls.rconnectRasterBridge=original;
         active=false;tickets=new Dictionary();
      }
   }
}
