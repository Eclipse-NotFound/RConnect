package {
   import rconnect.core.Log;
   public class NativeMapLeaseProbe {
      private var session:Object,earlyCarrier:Object,earlyWorld:Object,earlyGame:Object;
      private var earlyOwner:Object={},earlyLeaseId:String="";
      public function NativeMapLeaseProbe(s:Object){session=s;}
      public function acquireEarly(id:String):Boolean {
         var w:Object=session.mod.game.world;
         if(id=="" || w==null || w.game==null)return false;
         if(earlyCarrier!=null)return earlyLeaseId==id && earlyWorld===w && earlyGame===w.game;
         // A local room hold may account for onPause; any other pause/menu is
         // not an eligible starting state for this optimization.
         if(w.onPause && !session.mod.game.roomHold || w.pip!=null && w.pip.active
            || w.sats!=null && w.sats.active || w.stand!=null && w.stand.active
            || w.gui!=null && w.gui.guiPause)return false;
         try {
            var c:Object=session.mod.game.main.getChildByName("SandevistanTravelHoldV1");
            if(c==null || int(c.version)!=1 || String(c.contract)!="sandy-travel-hold/1")return false;
            var state:Object=c.query(w,w.game);
            if(state==null || state.version!==1 || state.contract!=="sandy-travel-hold/1"
               || state.phase!=="idle" || state.debugTest===true)return false;
            if(c.acquire(earlyOwner,w,w.game,id)!==true)return false;
            earlyCarrier=c;earlyWorld=w;earlyGame=w.game;earlyLeaseId=id;return true;
         }catch(error:Error){Log.d("RConnectEarly: external acquire unavailable: "+error);return false;}
         return false; // ASC requires an explicit post-try fallthrough.
      }

      public function releaseEarly(id:String):Boolean {
         if(earlyCarrier==null)return true;
         if(id!=earlyLeaseId)return false;
         try {
            var released:Boolean=earlyCarrier.release(earlyOwner,id)===true;
            var current:Object=session.mod.game.world;
            if(!released && (current==null || current===earlyWorld && current.game===earlyGame))return false;
            earlyCarrier=earlyWorld=earlyGame=null;earlyLeaseId="";return true;
         }catch(error:Error){Log.d("RConnectEarly: external release failed: "+error);return false;}
         return false; // ASC requires an explicit post-try fallthrough.
      }
   }
}
