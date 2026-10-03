package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.PNGEncoderOptions;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TeammateNavigation;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Native map controls, final pixels and real TCP room/position transitions. */
   public class TeammateNavigationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(150),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,a:Object,b:Object,origin:Object,oldX:Number,oldHp:Number;
      public function TeammateNavigationTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"navigation "+s);}
      private function setPhase(s:String):void {phase=s;at=getTimer();Log.d("NAV TEST "+(host?"host ":"join ")+s);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="navigation-test";p.phase=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function info(r:Object):Object {return {landX:r.landX,landY:r.landY,landZ:r.landZ,landProb:r.landProb,key:mod.game.roomKey(r)};}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function go(i:Object):void {mod.game.world.pip.onoff(-1);TravelGuard.follow(mod.game,i);}
      private function stand():Object {
         var gg:Object=mod.game.gg,room:Object=mod.game.loc;
         for(var ty:int=3;ty<room.spaceY-1;ty++)for(var tx:int=4;tx<room.spaceX-4;tx++) {
            var x:Number=tx*40+20,y:Number=ty*40;
            if(!gg.collisionAll(x-gg.X,y-gg.Y)&&gg.collisionAll(x-gg.X,y-gg.Y+2)) {
               var point:Object=TeammateNavigation.findLanding(gg,x,y);
               if(point!=null){gg.setPos(point.x,point.y);gg.setVisPos();return point;}
            }
         }
         throw new Error("No native standing position in test room");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="navigation-test")return;
         try {
            if(p.phase=="done"){finish();return;}
            if(host) {
               if(p.phase=="ready"&&phase=="ready") {
                  var rooms:Array=[];
                  for each(var col:Array in mod.game.world.land.locs)if(col)for each(var row:Array in col)if(row)for each(var room:Object in row)
                     if(room && !room.noMap && !TravelGuard.restricted(room) && room.landZ==0)rooms.push(room);
                  check(rooms.length>=2,"two ordinary mapped rooms available");
                  if(rooms.length<2){send("done");finish();return;}
                  a=info(rooms[0]);b=info(rooms[1]);go(a);send("align",{a:a,b:b});setPhase("align");
               } else if(p.phase=="map-ready") {setPhase("host-map");}
               else if(p.phase=="joined-near") {check(Math.abs(Number(p.x)-mod.game.gg.X)<=150,"joining player teleports near host over TCP");send("split");setPhase("split");}
               else if(p.phase=="split-ready") {setPhase("host-split-map");}
               else if(p.phase=="host-arrived") {go(a);setPhase("return-a");}
               else if(p.phase=="join-arrived") {setPhase("last-check");}
            } else {
               if(p.phase=="align"){a=p.a;b=p.b;go(a);setPhase("align");}
               else if(p.phase=="origin"){origin=p.origin;mod.game.gg.setPos(origin.x,origin.y);mod.game.gg.setVisPos();setPhase("map");}
               else if(p.phase=="near"){oldX=mod.game.gg.X;mod.game.gg.setPos(oldX+350,mod.game.gg.Y);oldHp=mod.game.gg.hp;setPhase("near");}
               else if(p.phase=="split"){go(b);setPhase("split");}
               else if(p.phase=="host-travel"){setPhase("host-travel");}
               else if(p.phase=="host-arrived"){setPhase("reunion-check");}
               else if(p.phase=="join-travel"){setPhase("join-travel");}
               else if(p.phase=="disconnect"){mod.session.leave();mod.navigation.refresh();mod.teammateMap.update();check(layer()==null,"leaving clears map markers");finish();}
               else if(p.phase=="done")finish();
            }
         }catch(error:Error){check(false,"receive "+error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null)return;
         if(host && mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         if(phase=="done")return;
         try {
            mod.game.gg.invulner=true;mod.game.gg.disabled=true;mod.game.gg.dx=mod.game.gg.dy=0;
            if(host && phase=="disconnect" && mod.session.peers.length==0) {
               mod.navigation.refresh();mod.teammateMap.update();check(layer()==null || layer().numChildren==0,"host removes departed teammate marker");finish();return;
            }
            if(phase!="boot"&&getTimer()-at>30000){check(false,"timeout "+phase+" room="+mod.game.roomKey());send("done");finish();return;}
            if(!stable() || mod.game.readWorldInfo().curLandId!="random_mane")return;
            if(phase=="boot") {mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();setPhase("ready");}
            if(!host && phase=="ready")send("ready");
            var elapsed:int=getTimer()-at;
            if(host && phase=="align" && mod.game.roomKey()==a.key && elapsed>1600) {
               origin=stand();send("origin",{origin:origin});setPhase("wait-map");
            }
            if(!host && phase=="map" && elapsed>1600) {mapChecks(true);send("map-ready");setPhase("wait-near");}
            if(host && phase=="host-map" && elapsed>700) {mapChecks(false);guards();send("near");setPhase("wait-near");}
            if(!host && phase=="near" && elapsed>900) {
               clickTeleport();check(!mod.game.world.pip.active,"teleport closes native map before moving");setPhase("near-check");
            }
            if(!host && phase=="near-check" && elapsed>900) {
               check(Math.abs(mod.game.gg.X-origin.x)<=150 && Math.abs(mod.game.gg.X-(oldX+350))>100,"join same-room teleport changes only local position");
               check(!mod.game.gg.collisionAll() && mod.game.gg.collisionAll(0,3),"join landing is clear and supported");
               check(mod.game.gg.hp==oldHp,"teleport does not heal or change health");
               send("joined-near",{x:mod.game.gg.X});setPhase("wait-split");
            }
            if(!host && phase=="split" && mod.game.roomKey()==b.key && elapsed>1500) {stand();send("split-ready");setPhase("wait-host-travel");}
            if(host && phase=="host-split-map" && elapsed>900) {
               mapChecks(false);check(mod.game.getRemoteGhost(1)==null,"map includes teammate without a same-room avatar");
               check(String(mod.navigation.teammate().snap.roomKey)==b.key,"remote ordinary room position is fresh");
               clickTeleport();send("host-travel");setPhase("host-travel");
            }
            if(host && phase=="host-travel" && mod.game.roomKey()==b.key && elapsed>1800) {
               check(!mod.navigation.travelling && !mod.game.gg.collisionAll(),"host cross-room teleport settles after handoff");
               var s:Object=mod.navigation.teammate().snap;
               check(Math.abs(mod.game.gg.X-Number(s.x))<=150 && Math.abs(mod.game.gg.Y-Number(s.y))<=165,"host arrives beside joining teammate");
               check(mod.session.rooms.authority,"host retains authority when reunited");send("host-arrived");setPhase("wait-reunion");
            }
            if(!host && phase=="reunion-check" && mod.game.roomKey()==b.key && elapsed>600) {check(!mod.session.rooms.authority,"joining room becomes mirrored after host enters");send("host-arrived");setPhase("wait-join-travel");}
            if(host && phase=="return-a" && mod.game.roomKey()==a.key && elapsed>1500) {stand();send("join-travel");setPhase("wait-join");}
            if(!host && phase=="join-travel" && elapsed>1200) {clickTeleport();setPhase("join-travel-check");}
            if(!host && phase=="join-travel-check" && mod.game.roomKey()==a.key && elapsed>1800) {
               s=mod.navigation.teammate().snap;
               check(!mod.navigation.travelling && Math.abs(mod.game.gg.X-Number(s.x))<=150,"join cross-room teleport reaches host");
               check(!mod.game.gg.collisionAll() && mod.game.gg.collisionAll(0,3),"cross-room landing checks restored terrain");
               send("join-arrived");setPhase("wait-end");
            }
            if(host && phase=="last-check" && elapsed>1200) {mapChecks(false);send("disconnect");setPhase("disconnect");}
         }catch(error:Error){check(false,"tick "+error.getStackTrace());send("done");finish();}
      }
      private function page():Object {return mod.game.world.pip.currentPage;}
      private function layer():DisplayObjectContainer {
         var map:Object=GameBridge.probe(page(),"map");
         return map!=null && map.parent!=null?map.parent.getChildByName("rconnect-teammate-map") as DisplayObjectContainer:null;
      }
      private function pixels(d:DisplayObject):int {
         var root:DisplayObject=mod.main as DisplayObject,rect:Rectangle=d.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(rect.width<1 || rect.height<1)return 0;
         var first:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),second:BitmapData=first.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y);first.draw(root,matrix);d.visible=false;second.draw(root,matrix);d.visible=true;
         var av:Vector.<uint>=first.getVector(first.rect),bv:Vector.<uint>=second.getVector(second.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])count++;
         first.dispose();second.dispose();return count;
      }
      private function mapChecks(complete:Boolean):void {
         mod.hud.visible=false;mod.game.world.pip.onoff(3,1);mod.navigation.refresh();mod.teammateMap.update();
         var p:Object=page(),holder:DisplayObjectContainer=layer();
         check(holder!=null && holder.numChildren==1,"native local map has exactly one teammate marker");if(holder==null || !holder.numChildren)return;
         var marker:DisplayObject=holder.getChildAt(0),s:Object=mod.navigation.teammate().snap,room:Object=mod.game.world.land;
         var expectedX:Number=((s.worldInfo.landX-room.minLocX)*48+s.x/40)*p.map.scaleX;
         var expectedY:Number=((s.worldInfo.landY-room.minLocY)*25+(s.y-s.hitShape.scY/2)/40)*p.map.scaleY;
         check(Math.abs(marker.x-expectedX)<1 && Math.abs(marker.y-expectedY)<1,"marker matches native world-to-map coordinates");
         p.map.parent.x=350-marker.x;p.map.parent.y=260-marker.y;
         check(pixels(marker)>15,"teammate icon and name contribute final map pixels");
         check(!holder.mouseEnabled && !holder.mouseChildren,"markers leave native dragging and zoom controls usable");
         if(!complete)return;
         var localTag:DisplayObject=p.map.parent.getChildByName("plTag");
         check(localTag!=null && Math.abs(marker.x-localTag.x)<1 && Math.abs(marker.y-localTag.y)<1,"same-position teammate aligns with native local player tag");
         var width:Number=marker.width; p.funZoomP(null);mod.teammateMap.update();
         check(Math.abs(marker.x-expectedX*1.5)<1 && Math.abs(marker.y-expectedY*1.5)<1,"native zoom rescales map position");
         check(Math.abs(marker.width-width)<.01,"marker and name stay readable at different zoom levels");
         var before:Point=marker.localToGlobal(new Point());p.map.parent.x+=37;p.map.parent.y-=21;
         var after:Point=marker.localToGlobal(new Point());check(Math.abs(after.x-before.x-37)<1 && Math.abs(after.y-before.y+21)<1,"map drag carries marker with terrain");
         var peer:Object=mod.navigation.teammate(),oldName:String=peer.name;peer.name="Звёздная 小马";mod.teammateMap.update();
         var label:TextField=(marker as DisplayObjectContainer).getChildAt(0) as TextField;
         check(label.text==peer.name && label.textWidth>20,"player-authored Russian and Chinese name stays intact");peer.name=oldName;
         for each(var lang:String in ["en","ru","tw"]) {
            mod.game.world.lang=lang;mod.hud.refresh();var button:TextField=mod.hud.getChildByName("rconnect-teleport") as TextField;
            check(button.textWidth<button.width-4,"teleport label fits native language "+lang);
         }
         mod.game.world.pip.onoff(3,2);mod.teammateMap.update();check(layer()==null,"quest page does not keep a map marker overlay");
         mod.game.world.pip.onoff(3,1);mod.teammateMap.update();check(layer()!=null && layer().numChildren==1,"map reopening creates no duplicate markers");
         var noMap:Boolean=mod.game.loc.noMap;mod.game.loc.noMap=true;mod.teammateMap.update();check(layer()==null,"native no-map room hides teammate overlay");mod.game.loc.noMap=noMap;
         mod.teammateMap.update();holder=layer();marker=holder.getChildAt(0);p=page();p.map.parent.x=350-marker.x;p.map.parent.y=260-marker.y;
         saveImage("navigation-map.png");
      }
      private function saveImage(name:String):void {
         var image:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);image.draw(mod.stage);
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);
         stream.writeBytes(image.encode(image.rect,new PNGEncoderOptions()));stream.close();image.dispose();
      }
      private function guards():void {
         var source:Object=host?mod.session.peers[0]:mod.session.remotes[0],original:Object=source.snap;
         var x:Number=mod.game.gg.X,y:Number=mod.game.gg.Y,oldSost:int=mod.game.gg.sost,oldBusy:Boolean=mod.session.rooms.busy;
         try {
            source.snap=JSON.parse(JSON.stringify(original));source.snap.roomEpoch++;mod.navigation.refresh();mod.teammateMap.update();
            check(layer()==null || layer().numChildren==0,"stale map generation cannot leave a marker");check(!mod.navigation.request(),"stale generation cannot teleport");
            source.snap=JSON.parse(JSON.stringify(original));source.snap.worldInfo.curLandId="rbl";check(!mod.navigation.request(),"different-map teleport is rejected");
            source.snap=JSON.parse(JSON.stringify(original));source.snap.worldInfo.landProb="challenge";check(!mod.navigation.request(),"challenge travel is rejected");
            source.snap=JSON.parse(JSON.stringify(original));source.snap.hp=0;source.snap.sost=3;check(!mod.navigation.request(),"dead teammate cannot be a destination");
            source.snap=original;mod.session.rooms.busy=true;check(!mod.navigation.request(),"handoff cannot be interrupted by another teleport");mod.session.rooms.busy=oldBusy;
            mod.game.gg.sost=3;check(!mod.navigation.request(),"dead local player cannot teleport out of respawn");mod.game.gg.sost=oldSost;
            check(TeammateNavigation.findLanding(mod.game.gg,-10000,-10000)==null,"invalid destinations cannot put player outside terrain");
            check(mod.game.gg.X==x && mod.game.gg.Y==y,"rejected requests and landing search do not move player");
         } finally {source.snap=original;mod.game.gg.sost=oldSost;mod.session.rooms.busy=oldBusy;mod.navigation.refresh();}
      }
      private function clickTeleport():void {
         mod.hud.visible=true;mod.game.world.pip.onoff(3,1);mod.navigation.refresh();mod.hud.refresh();saveImage("navigation-panel.png");
         var button:TextField=mod.hud.getChildByName("rconnect-teleport") as TextField;
         check(button!=null && mod.navigation.unavailable()=="","teleport is available through the F10 button");
         if(button!=null)button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
      }
      private function finish():void {if(phase=="done")return;setPhase("done");timer.stop();Log.d("COOP EFFECTS DONE navigation "+(host?"host":"join"));}
   }
}
