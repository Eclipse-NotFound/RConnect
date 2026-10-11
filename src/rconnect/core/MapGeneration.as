package rconnect.core {
   import rconnect.game.GameBridge;

   /** One seed per actual native Land construction. Cached visits never call
    * this hook. The joiner adopts the host's completed expedition before travel. */
   public final class MapGeneration {
      private var session:Session;
      private var remote:Object;
      public var supported:Boolean=false;
      public function MapGeneration(s:Session) {
         session=s;
         var cls:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
         if("rconnectSeedSource" in cls) {
            cls.rconnectSeedSource=seedFor; supported=true;
            Log.d("RConnectMap: native expedition seed interface ready");
         }else Log.d("RConnectMap: legacy fixed-seed Land; native expedition patch required");
      }
      public function reset():void {remote=null;}
      public function receive(info:Object):void {
         if(info!=null && info.worldReady!==false)remote=info;
      }
      private function valid(info:Object):Boolean {
         if(info==null)return false;
         var n:Number=Number(info.layoutSeed);
         return isFinite(n)&&n>=1&&n<=4294967295&&n==Math.floor(n);
      }
      private function seedFor(land:Object):uint {
         if(session.mode==Session.CONNECTED && valid(remote) && String(remote.curLandId)==String(land.act.id)) {
            var level:Number=Number(remote.layoutLevel);
            if(isFinite(level)&&level>=0)land.landDifLevel=level;
            Log.d("RConnectMap: adopt expedition "+land.act.id+" seed="+remote.layoutSeed);
            return uint(remote.layoutSeed);
         }
         var seed:uint=1+uint(Math.random()*4294967295);
         Log.d("RConnectMap: new expedition "+land.act.id+" seed="+seed);
         return seed;
      }
      public function differs(info:Object,land:Object):Boolean {
         return supported&&valid(info)&&land!=null&&String(info.curLandId)==String(land.act.id)
            &&Number(GameBridge.probe(land,"rconnectLayoutSeed"))!=Number(info.layoutSeed);
      }
      public function adopt(info:Object,act:Object):void {
         receive(info);
         if(differs(info,act.land))act.land=null;
      }
   }
}
