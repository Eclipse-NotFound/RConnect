package {
   import rconnect.core.Log;
   /** A known native corridor, only inside the independently compiled driver.
    * Host chooses a reproducible test layout; join uses production seed adoption. */
   public class PeerAuraFixture {
      public static const SEED:uint=1192051184;
      private static var bound:Boolean=false;
      public static function prepare(mod:Object,host:Boolean):void {
         if(bound || !host)return;
         var landClass:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
         if(!("rconnectSeedSource" in landClass) || !(landClass.rconnectSeedSource is Function))
            throw new Error("native seed boundary unavailable for test fixture");
         var info:Object=mod.game.readWorldInfo();
         if(info!=null && info.curLandId=="random_mane")throw new Error("test seed binding was too late");
         var previous:Function=landClass.rconnectSeedSource;
         landClass.rconnectSeedSource=function(land:Object):uint {
            if(land!=null && land.act!=null && land.act.id=="random_mane") {
               Log.d("PEER AURA FIXTURE native layout seed="+SEED);return SEED;
            }
            return previous(land);
         };
         bound=true;
      }
   }
}
