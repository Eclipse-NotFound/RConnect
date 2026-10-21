package rconnect.core {
   import RConnectModDomains;
   import rconnect.game.GameBridge;

   /** One seed per actual native Land construction. Cached visits never call
    * this hook. The host announces the seed before either side builds the map. */
   public final class MapGeneration {
      private var session:Session;
      private var remote:Object;
      public var nativeTravelSupported:Boolean=false;
      private var sceneClass:Object;
      private var savedSceneMode:*;
      public var supported:Boolean=false;
      public function MapGeneration(s:Session) {
         session=s;
         var nativeGame:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Game");
         if("rconnectTravelBridge" in nativeGame) {
            if(nativeGame.rconnectTravelBridge!=null)throw new Error("Native travel hook already owned");
            nativeGame.rconnectTravelBridge=nativeTravel;nativeTravelSupported=true;
         }
         var grafon:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
         if("rconnectRasterBridge" in grafon) {
            if(grafon.rconnectRasterBridge!=null)throw new Error("Native first raster hook already owned");
            grafon.rconnectRasterBridge=firstRaster;
         }
         var cls:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
         if("rconnectSeedSource" in cls) {
            cls.rconnectSeedSource=seedFor; supported=true;
            Log.d("RConnectMap: native expedition seed interface ready");
         }else Log.d("RConnectMap: legacy fixed-seed Land; native expedition patch required");
      }
      private function firstRaster(w:Object,l:Object,g:Object):Object {
         if(session.rooms==null || session.mode!=Session.CONNECTED)return null;
         return session.rooms.openFirstRaster(w,l,g);
      }
      private function nativeTravel(phase:String,g:Object,info:Object):Object {
         var bridge:GameBridge=session.mod.game;
         if(bridge.world==null || bridge.world.game!==g || int(bridge.world.t_exit)<=0
            || int(bridge.world.t_die)>0 || int(bridge.world.comLoad)>=0)return null;
         if(phase=="adopt" && session.mode==Session.CONNECTED)
            return session.rooms.adoptNativeTravel(g);
         if(phase=="announce" && session.mode==Session.HOSTING && session.peers.length>0) {
            // Sending an optimization hint must not break the host's native load.
            try {
               info.sceneMerged=sceneMode({act:g.curLand},true);
               info.layoutSeed=0;
               session.rooms.announceNativeTravel(info);
            } catch(error:Error){Log.d("RConnectTravel: prepare failed; native travel continues: "+error);}
         }
         return null;
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
