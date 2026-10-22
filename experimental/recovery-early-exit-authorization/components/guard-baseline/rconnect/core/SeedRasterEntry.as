package rconnect.core {
   /** Local-only identity for an already started legacy seed prepare.
    * No wire token, seed generation, room ownership or checkpoint data here. */
   public final class SeedRasterEntry {
      private var boundWorld:Object,boundGame:Object,oldLand:Object;
      private var target:String="",seed:Number=0,fromEpoch:int=0,serial:int=0;
      private var token:String="",sealedBarrier:int=0,sealedEpoch:int=0;
      public var anchor:Object;
      public function get active():Boolean {return token!="";}
      public function get id():String {return token;}
      public function start(info:Object,w:Object,previousLand:Object,epoch:int,pending:int):Boolean {
         if(active || pending>0 || w==null || w.game==null || previousLand==null || w.land!==previousLand
            || info==null || info.sceneMerged!==true || !(info.curLandId is String))return false;
         var n:Number=Number(info.layoutSeed),act:Object=w.game.lands[String(info.curLandId)];
         if(act==null || !act.rnd || !isFinite(n) || n<1 || n>4294967295 || n!=Math.floor(n))return false;
         boundWorld=w;boundGame=w.game;oldLand=previousLand;target=String(info.curLandId);
         seed=n;fromEpoch=epoch;token="seed-raster:"+(++serial);sealedBarrier=sealedEpoch=0;anchor=null;return true;
      }
      public function matchesWorld(w:Object):Boolean {
         return active && w===boundWorld && w!=null && w.game===boundGame;
      }
      public function matchesInfo(info:Object):Boolean {
         return active && info!=null && info.worldReady!==false && String(info.curLandId)==target
            && Number(info.layoutSeed)==seed && info.sceneMerged===true;
      }
      public function destination(w:Object,l:Object):Boolean {
         return matchesWorld(w) && w.land!=null && w.land!==oldLand && l!=null && w.loc===l && l.land===w.land
            && String(w.game.curLandId)==target && String(w.land.act.id)==target
            && Number(w.land.rconnectLayoutSeed)==seed;
      }
      public function acceptSeal(msg:Object):Boolean {
         if(!active || String(msg.travelId||"")!="" || !matchesInfo(msg.info) || int(msg.epoch)<=fromEpoch)return false;
         if(Number(msg.epoch)!=int(msg.epoch) || Number(msg.barrier)!=int(msg.barrier) || int(msg.barrier)<=0)
            throw new Error("Invalid seed raster barrier");
         var info:Object=msg.info;
         if(!(info.roomKey is String) || info.roomKey=="" || info.x==null || info.y==null
            || !isFinite(Number(info.x)) || !isFinite(Number(info.y)))throw new Error("Seed raster entry anchor missing");
         if(anchor!=null) {
            if(sealedBarrier!=int(msg.barrier) || sealedEpoch!=int(msg.epoch)
               || anchor.roomKey!==info.roomKey || anchor.x!==Number(info.x) || anchor.y!==Number(info.y))
               throw new Error("Seed raster seal changed");
            return true;
         }
         sealedBarrier=int(msg.barrier);sealedEpoch=int(msg.epoch);
         anchor={roomKey:String(info.roomKey),x:Number(info.x),y:Number(info.y)};return true;
      }
      public function acceptsGrant(msg:Object,w:Object,l:Object):Boolean {
         return anchor!=null && destination(w,l) && String(msg.travelId||"")==""
            && int(msg.barrier)==sealedBarrier && int(msg.epoch)==sealedEpoch
            && String(msg.key)==String(anchor.roomKey);
      }
      public function acceptsBarrier(barrier:int,epoch:int):Boolean {
         return active && anchor!=null && barrier==sealedBarrier && epoch==sealedEpoch;
      }
      public function clear():void {
         boundWorld=boundGame=oldLand=anchor=null;target=token="";seed=0;fromEpoch=sealedBarrier=sealedEpoch=0;
      }
   }
}
