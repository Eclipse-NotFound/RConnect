package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Same native Pip travel sequence offline and over TCP. Timing includes
    * native transition, synchronization, final placement and return of control. */
   public class RoomTravelTimingTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,solo:Boolean,links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,target:String="rbl";
      private var peer:Object,reported:Boolean=false,bootNotice:int=0,configured:Boolean=false;
      private var exitAt:int=-1,exitDone:int=-1,coverMs:int=0,pausedMs:int=0,lastFrame:int=0;
      private var localResult:Object;
      private var soloBootTravel:Boolean=false;
      private var sceneClass:Object;
      private var metrics:A22RoomMetrics;
      private var landClass:Object,originalSeed:Function,timingSeed:Function;
      private static const MAP_SEED:uint=1380142925;
      protected function merged():Boolean{return false;}
      protected function profileFirstFrame():Boolean{return false;}
      public function RoomTravelTimingTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;addEventListener(Event.ENTER_FRAME,tick);
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"travel-timing "+label+" round="+round);}
      private function stable(id:String):Boolean {
         var w:Object=mod.game.world;
         return w!=null && w.loc!=null && w.land!=null && String(w.game.curLandId)==id && String(w.land.act.id)==id
            && !mod.game.isTransitioning() && (solo || (mod.session.rooms.ready && !mod.session.rooms.busy))
            && !mod.session.rooms.entryPending && !w.onPause && w.allStat==1
            && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function send(op:String,value:Object=null):void {
         if(solo)return;
         value=value||{};value.type="travel-timing-test";value.op=op;value.round=round;
         if(host)mod.session.server.broadcast(value);else mod.session.link.send(value);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="travel-timing-test")return;
         if(p.op=="done"){finish();return;}
         if(host && p.op=="ready" && phase=="boot"){depart();return;}
         if(!host && p.op=="depart") {round=int(p.round);target=String(p.target);begin();}
         if(host && p.op=="result" && int(p.round)==round){peer=p.value;if(localResult!=null)compare();}
      }
      private function begin():void {
         phase="travel";at=getTimer();lastFrame=at;exitAt=exitDone=-1;coverMs=pausedMs=0;
         localResult=null;reported=false;peer=null;
         Log.d("TRAVEL CLOCK "+JSON.stringify({started:at,round:round,target:target}));
      }
      private function depart():void {
         target=round%2==0?"random_mane":"rbl";
         send("depart",{target:target});begin();mod.game.forceCloseOverlays();mod.game.world.pers.healAll();
         if(round==0)mod.game.world.game.beginMission(target);
         else mod.game.world.game.gotoLand(target);
      }
      private function result():Object {
         var w:Object=mod.game.world,info:Object=mod.game.readWorldInfo();
         var actual:Boolean=false;
         try {actual=w.grafon.sceneNativeCall("state",[w.land])!=null;}catch(ignored:*){}
         if(target=="random_mane") {
            check(Number(info.layoutSeed)==MAP_SEED,"timing uses the same native generation seed");
            check(actual==merged(),"requested scene mode matches the native constructed world");
            if(merged())check(w.loc.spaceX>48 || w.loc.spaceY>25,"native merged scene is actually larger than one ordinary room");
         }
         check(w.gg.ggControl && !w.pip.noAct,"native player controls are restored");
         return {round:round,at:getTimer(),started:at,elapsed:getTimer()-at,exitStart:exitAt<0?-1:exitAt-at,
            exitEnd:exitDone<0?-1:exitDone-at,cover:coverMs,paused:pausedMs,solo:solo,
            x:Number(w.gg.X),y:Number(w.gg.Y),key:mod.game.roomKey(),width:w.loc.spaceX,height:w.loc.spaceY,
            seed:info.layoutSeed,units:w.loc.units.length,merged:merged(),actualMerged:actual,target:target};
      }
      private function compare():void {
         if(localResult==null || (!solo && peer==null))return;
         if(!solo) {
            check(localResult.key==peer.key,"shared travel finishes in the same room");
            check(localResult.width==peer.width && localResult.height==peer.height,"both native room dimensions agree");
            check(localResult.seed==peer.seed,"expedition seed agrees");
            var dx:Number=localResult.x-peer.x,dy:Number=localResult.y-peer.y;
            check(dx*dx+dy*dy<=80*80,"both arrivals share one entrance, distance="+Math.sqrt(dx*dx+dy*dy));
         }
         Log.d("TRAVEL COMPARISON "+JSON.stringify({host:localResult,join:peer}));
         if(round>=2){send("done");finish();return;}
         round++;phase="rest";at=getTimer();
      }
      private function tick(e:Event):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null)return;
         if(metrics==null)metrics=new A22RoomMetrics(mod,profileFirstFrame());
         solo=mod.config.getValue("autoRole")=="";
         if(!configured) {
            configured=true;mod.config.setValue("followTeammate","0");
            var sceneConfigured:Boolean=false;
            try {
               var nativeMain:MainFE=mod.game.main as MainFE;
               for(var key:Object in nativeMain.modEntryByLoader) {
                  var loader:Loader=key as Loader;
                  if(loader==null || !loader.contentLoaderInfo.applicationDomain.hasDefinition("ContinuousSceneMod"))continue;
                  var cls:Object=loader.contentLoaderInfo.applicationDomain.getDefinition("ContinuousSceneMod");
                  sceneClass=cls;
                  cls.nativeEnabled=host&&merged();
                  sceneConfigured=Boolean(cls.nativeEnabled)==(host&&merged());break;
               }
            }catch(error:*){Log.d("TRAVEL CONFIG ERROR "+error);}
            check(sceneConfigured,"native scene preference was explicitly configured");
            // Control only this isolated benchmark's random input. Keep native
            // generation and the production prepare/adopt path; the separate
            // map suite still exercises the unmodified random seed policy.
            landClass=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
            originalSeed=landClass.rconnectSeedSource;
            timingSeed=function(land:Object):uint {
               if(!solo && !host)return originalSeed(land);
               if(!solo && host)Object(mod.session.rooms).prepareMap(land,MAP_SEED,true);
               return MAP_SEED;
            };
            landClass.rconnectSeedSource=timingSeed;
            Log.d("TRAVEL CONFIG "+JSON.stringify({host:host,solo:solo,merged:merged()}));
         }
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         var w:Object=mod.game.world,now:int=getTimer();mod.game.gg.invulner=true;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         // Production autoTravelLand only runs while hosting. The offline
         // control therefore performs the same native setup trip explicitly.
         if(solo && phase=="boot" && !soloBootTravel && stable("begin")) {
            soloBootTravel=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand("rbl");at=now;
         }
         if(now-at>(phase=="boot"?240000:95000)){check(false,"timeout phase="+phase);send("done");finish();return;}
         if(phase=="boot" && stable("rbl")) {
            if(solo)depart();
            else if(!host && now-bootNotice>500){bootNotice=now;send("ready");}
         }else if(phase=="rest" && now-at>1000)depart();
         else if(phase=="travel") {
            if(int(w.t_exit)>0 && exitAt<0)exitAt=now;
            if(int(w.t_exit)==0 && exitAt>=0 && exitDone<0)exitDone=now;
            if(mod.session.rooms.entryPending)coverMs+=now-lastFrame;
            if(w.onPause)pausedMs+=now-lastFrame;
            lastFrame=now;
            if(!reported && exitAt>=0 && stable(target)) {
               reported=true;localResult=result();Log.d("TRAVEL RESULT "+JSON.stringify(localResult));
               check(true,"native travel and input restoration finished");
               if(host)compare();else {send("result",{value:localResult});phase="wait";at=now;}
            }
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";removeEventListener(Event.ENTER_FRAME,tick);
         if(metrics!=null)metrics.finish();
         if(landClass!=null && landClass.rconnectSeedSource===timingSeed)landClass.rconnectSeedSource=originalSeed;
         if(!host && !solo && sceneClass!=null) {
            mod.session.leave();
            check(sceneClass.nativeEnabled===false,"disconnect restores the joiner's original scene preference");
         }
         Log.d("COOP EFFECTS DONE travel-timing "+(host?"host":"join"));
      }
   }
}
