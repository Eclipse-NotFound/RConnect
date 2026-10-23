package rconnect.core {
   import RConnectModDomains;
   import rconnect.game.GameBridge;

   /** One seed per actual native Land construction. Cached visits never call
    * this hook. The host announces the seed before either side builds the map. */
   public final class MapGeneration {
      private var session:Session;
      private var remote:Object;
      private var sceneClass:Object;
      private var savedSceneMode:*;
      public var supported:Boolean=false;
      public function MapGeneration(s:Session) {
         session=s;
         var cls:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
         if("rconnectSeedSource" in cls) {
            cls.rconnectSeedSource=seedFor; supported=true;
            Log.d("RConnectMap: native expedition seed interface ready");
         }else Log.d("RConnectMap: legacy fixed-seed Land; native expedition patch required");
      }
      public function reset():void {
         remote=null;
         if(sceneClass!=null && savedSceneMode!==undefined)sceneClass.nativeEnabled=savedSceneMode;
         savedSceneMode=undefined;
      }
      private function scene():Object {
         if(sceneClass==null)try {
            var domain:Object=RConnectModDomains.find(session.mod.game.main,"ContinuousSceneMod");
            if(domain!=null)sceneClass=domain.getDefinition("ContinuousSceneMod");
         }catch(e:*){}
         return sceneClass;
      }
      /** Report the actual cached world, not the preference for the next trip. */
      public function sceneMode(land:Object,constructing:Boolean=false):Boolean {
         if(scene()==null || land==null || String(land.act.tip)=="base")return false;
         if(constructing)return Boolean(sceneClass.nativeEnabled);
         try {return session.mod.game.world.grafon.sceneNativeCall("state",[land])!=null;}catch(e:*){}
         return false;
      }
      public function receive(info:Object):void {
         if(info!=null && info.worldReady!==false) {
            remote=info;
            if(info.sceneMerged!==undefined && scene()!=null) {
               if(savedSceneMode===undefined)savedSceneMode=sceneClass.nativeEnabled;
               // Session-only adoption. Never overwrite the player's settings file.
               sceneClass.nativeEnabled=Boolean(info.sceneMerged);
            }
         }
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
         if(session.mode==Session.HOSTING && session.peers.length>0)
            session.rooms.prepareMap(land,seed,true);
         return seed;
      }
      public function differs(info:Object,land:Object):Boolean {
         return land!=null&&String(info.curLandId)==String(land.act.id)
            && ((supported&&valid(info)&&Number(GameBridge.probe(land,"rconnectLayoutSeed"))!=Number(info.layoutSeed))
               || (info.sceneMerged!==undefined && Boolean(info.sceneMerged)!=sceneMode(land)));
      }
      public function adopt(info:Object,act:Object):void {
         receive(info);
         if(differs(info,act.land))act.land=null;
      }
   }
}
