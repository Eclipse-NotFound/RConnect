package {
   import flash.desktop.NativeApplication;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Actual installed RandomRooms picker, three fresh expeditions and host
    * whole-map travel. Same seed twice, then its real random-seed button. */
   public class MapGenerationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(200),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,seed:String="",firstSeed:String="";
      private var firstMap:String="",localMap:String="",reported:Boolean=false,remoteReady:Boolean=false,lastReady:int=0;
      private var peerMap:Object;
      public function MapGenerationTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"map-generation "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();reported=false;}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="map-generation-test";p.op=op;
         p.room=mod.game.roomKey();p.epoch=mod.game.roomEpoch;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function find(node:DisplayObject,name:String):DisplayObject {
         if(node==null)return null;if(node.name==name)return node;
         var c:DisplayObjectContainer=node as DisplayObjectContainer;if(c!=null)for(var i:int=0;i<c.numChildren;i++) {
            var result:DisplayObject=find(c.getChildAt(i),name);if(result!=null)return result;
         }return null;
      }
      private function textParent(node:DisplayObject,words:String):DisplayObject {
         if(node is TextField&&TextField(node).text.indexOf(words)>=0)return node.parent;
         var c:DisplayObjectContainer=node as DisplayObjectContainer;if(c!=null)for(var i:int=0;i<c.numChildren;i++) {
            var result:DisplayObject=textParent(c.getChildAt(i),words);if(result!=null)return result;
         }return null;
      }
      private function key(code:int):void {
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,code));
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,code));
      }
      private function hash(s:String):String {var h:uint=0;for(var i:int=0;i<s.length;i++)h=uint(h*31+s.charCodeAt(i));return h.toString(16);}
      private function signature():String {
         var result:Array=[],land:Object=mod.game.world.land;
         for each(var column:Object in land.locs)for each(var row:Object in column)for each(var room:Object in row)
            if(room!=null)result.push([room.landX,room.landY,room.landZ,room.id,String(room.room.id),hash(room.room.xml.a.toXMLString())].join(":"));
         return result.join("|");
      }
      private function stable():Boolean {
         var w:Object=mod.game.world;
         return w!=null&&w.land!=null&&w.land.act!=null&&String(w.game.curLandId)==String(w.land.act.id)
            &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning()
            &&(!w.vblack.visible||w.vblack.alpha==0);
      }
      private function select():void {
         mod.game.forceCloseOverlays();mod.game.world.lang="en";key(112);change("picker");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="map-generation-test")return;
         if(p.op=="done"){finish();return;}
         if(host&&p.op=="ready"&&p.room==mod.game.roomKey()&&p.epoch==mod.game.roomEpoch) {
            remoteReady=true;if(phase=="boot"||phase=="base")select();
         }else if(!host&&p.op=="chosen") {round=p.round;seed=p.seed;change("travel");}
         else if(!host&&p.op=="base"){round=p.round;change("base");}
         else if(host&&p.op=="map"&&int(p.round)==round&&(phase=="travel"||phase=="map")) {
            peerMap=p;if(phase=="map")compare();
         }
      }
      private function compare():void {
            var p:Object=peerMap;if(p==null)return;peerMap=null;
            check(p.signature==localMap,"joining map geometry equals host's newly generated map");
            if(round==0){firstMap=localMap;firstSeed=seed;}
            else if(round==1){check(seed==firstSeed,"picker retains comparison seed");check(localMap==firstMap,"same seed/scene/depth deliberately reproduces geometry");}
            else {check(seed!=firstSeed,"real random-seed button selected a different seed");check(localMap!=firstMap,"different seed changes map while RConnect is connected");send("done");finish();return;}
            round++;remoteReady=false;send("base",{round:round});key(113);change("base");
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>110000){check(false,"timeout "+phase);send("done");finish();return;}
         mod.config.setValue("followTeammate","0");mod.game.gg.invulner=true;
         try {
            if(phase=="picker"&&host) {
               var input:TextField=find(mod.stage,"rrComparisonSeed") as TextField;if(input==null)return;
               if(round==2) {
                  var button:DisplayObject=textParent(mod.stage,"换一组种子");
                  if(button==null)button=textParent(mod.stage,"New seed");
                  // The picker has the same coordinates/natural click handler
                  // in every language; name is the input contract, not its text.
                  if(button==null)throw new Error("native seed button missing");
                  button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
               }
               seed=input.text;check(/^\d+$/.test(seed),"actual scene picker seed="+seed);
               mod.stage.focus=null;send("chosen",{round:round,seed:seed});key(52);change("travel");return;
            }
            if(!stable())return;
            if((phase=="boot"||phase=="base")&&String(mod.game.world.game.curLandId)=="rbl") {
               if(!host&&getTimer()-lastReady>1000){lastReady=getTimer();send("ready");}
               else if(host&&remoteReady)select();
            }else if(phase=="travel"&&String(mod.game.world.game.curLandId)!="rbl"&&getTimer()-at>2500) {
               localMap=signature();check(localMap.length>100,"actual generated map contains multiple rooms");
               Log.d("MAP GENERATION "+JSON.stringify({round:round,seed:seed,land:mod.game.world.game.curLandId,signature:localMap}));
               if(!host){send("map",{round:round,signature:localMap});change("wait");}else {change("map");compare();}
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function finish():void {if(phase=="done")return;change("done");t.stop();Log.d("COOP EFFECTS DONE map-generation "+(host?"host":"join"));}
   }
}
