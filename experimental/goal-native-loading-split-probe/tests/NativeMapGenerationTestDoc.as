package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Pip travel semantics: start Manehattan, revisit that expedition,
    * then start two new expeditions. No RandomRooms scene-picker shortcuts. */
   public class NativeMapGenerationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,lastReady:int=0;
      private var remoteReady:Boolean=false,peerMap:Object,localMap:Object;
      private var firstMap:String="",previousMap:String="",firstLand:Object,previousLand:Object;
      private var hostBeforeJoin:String="",joinSeed:uint=0;
      private const TARGET:String="random_mane";
      public function NativeMapGenerationTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"native-map "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="native-map-test";p.op=op;p.round=round;
         p.room=mod.game.roomKey();p.epoch=mod.game.roomEpoch;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function hash(s:String):String {
         var h:uint=2166136261;for(var i:int=0;i<s.length;i++)h=uint(h*31+s.charCodeAt(i));return h.toString(16);
      }
      private function fingerprint():Object {
         var rows:Array=[],collision:Object={},land:Object=mod.game.world.land;
         for each(var column:Object in land.locs)for each(var columnRow:Object in column)for each(var room:Object in columnRow) {
            if(room==null)continue;
            var tiles:Array=[];
            for(var x:int=0;x<int(room.spaceX);x++)for(var y:int=0;y<int(room.spaceY);y++) {
               var tile:Object=room.space[x][y];
               tiles.push([tile.phis,tile.stair,tile.shelf,tile.water].join(","));
            }
            collision[mod.game.roomKey(room)]=hash(tiles.join(";"));
            rows.push([room.landX,room.landY,room.landZ,String(room.room.id),Boolean(room.mirror),
               hash(room.room.xml.a.toXMLString())].join(":"));
         }
         rows.sort();
         // Boxes/checkpoints can alter collision tiles after native generation.
         // Unvisited rooms have not exchanged their contents yet. Compare all
         // immutable templates, plus live collision in the shared settled room.
         return {layout:rows.join("|"),collision:collision,rooms:rows.length,stage:land.act.landStage,land:land.act.id,
            current:mod.game.roomKey(),seed:Number(GameBridge.probe(land,"rconnectLayoutSeed"))};
      }
      private function stable(id:String):Boolean {
         var w:Object=mod.game.world;
         return w!=null&&w.land!=null&&w.land.act!=null&&String(w.game.curLandId)==id&&String(w.land.act.id)==id
            &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning()
            &&(!w.vblack.visible||w.vblack.alpha==0);
      }
      private function depart():void {
         remoteReady=false;peerMap=null;send("depart");mod.game.forceCloseOverlays();
         // Native gotoLand preserves the cached Land. beginMission explicitly
         // requests a new Land, exactly as starting a new expedition in Pip.
         if(round==1)mod.game.world.game.gotoLand(TARGET);
         else mod.game.world.game.beginMission(TARGET);
         change("travel");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="native-map-test")return;
         if(p.op=="done"){finish();return;}
         if(host&&p.op=="ready"&&p.room==mod.game.roomKey()&&p.epoch==mod.game.roomEpoch) {
            remoteReady=true;if((phase=="boot"||phase=="base")&&stable("rbl"))depart();
         }else if(!host&&p.op=="rejoin") {
            round=int(p.round);hostBeforeJoin=String(p.layout);mod.session.leave();
            mod.game.world.game.gotoLand("rbl");change("offline-base");
         }else if(!host&&(p.op=="depart"||p.op=="base")) {round=int(p.round);change(p.op=="base"?"base":"travel");}
         else if(host&&p.op=="map"&&int(p.round)==round&&(phase=="travel"||phase=="map"||phase=="rejoin")) {
            if(phase=="rejoin"){localMap=fingerprint();change("map");}
            peerMap=p.data;if(phase=="map")compare();
         }
      }
      private function compare():void {
         if(peerMap==null)return;
         check(peerMap.layout==localMap.layout,"both sides have identical room templates and mirrors including background rooms");
         check(peerMap.current==localMap.current&&peerMap.collision[localMap.current]==localMap.collision[localMap.current],
            "shared settled room has identical live collision tiles");
         var current:Object=mod.game.world.land;
         if(round==0){firstLand=current;firstMap=localMap.layout;}
         else if(round==1) {
            check(current===firstLand,"ordinary revisit retains native Land instance");
            check(localMap.layout==firstMap,"ordinary revisit retains the same layout");
         }else if(round<4) {
            check(current!==previousLand,"new expedition actually constructs a new native Land");
            check(localMap.layout!=previousMap,"new expedition changes the layout");
         }
         if(round==4) {
            check(current===previousLand,"joining a different seed never reconstructs the host Land");
            check(localMap.layout==previousMap,"joining a different seed preserves the host expedition");
            send("done");finish();return;
         }
         previousLand=current;previousMap=localMap.layout;
         if(round==3){round=4;send("rejoin",{layout:localMap.layout});change("rejoin");return;}
         round++;send("base");mod.game.world.game.gotoLand("rbl");change("base");
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>110000){check(false,"timeout "+phase);send("done");finish();return;}
         mod.config.setValue("followTeammate","0");mod.game.gg.invulner=true;
         try {
            var w:Object=mod.game.world;
            if(!host&&phase=="offline-base"&&!mod.game.isTransitioning()&&String(w.land.act.id)=="rbl") {
               mod.game.forceCloseOverlays();w.game.beginMission(TARGET);change("offline-map");return;
            }
            if(!host&&phase=="offline-map"&&!mod.game.isTransitioning()&&String(w.land.act.id)==TARGET) {
               var own:Object=fingerprint();joinSeed=uint(own.seed);
               check(own.layout!=hostBeforeJoin,"joining player starts with a genuinely different same-ID expedition");
               Log.d("NATIVE MAP BEFORE JOIN "+JSON.stringify(own));
               mod.session.startJoin();change("travel");return;
            }
            if((phase=="boot"||phase=="base")&&stable("rbl")) {
               if(!host&&getTimer()-lastReady>1000){lastReady=getTimer();send("ready");}
               else if(host&&remoteReady)depart();
            }else if(phase=="travel"&&stable(TARGET)) {
               localMap=fingerprint();check(localMap.rooms>10,"native Manehattan has multiple constructed rooms");
               if(!host&&round==4)check(uint(localMap.seed)!=joinSeed,"joining player adopts the host seed before room settlement");
               Log.d("NATIVE MAP "+JSON.stringify({round:round,data:localMap,epoch:mod.game.roomEpoch}));
               if(!host){send("map",{data:localMap});change("wait");}else {change("map");compare();}
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      protected function finish():void {if(phase=="done")return;change("done");t.stop();Log.d("COOP EFFECTS DONE native-map "+(host?"host":"join"));}
   }
}
