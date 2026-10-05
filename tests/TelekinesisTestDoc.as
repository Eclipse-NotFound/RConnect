package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.filters.GlowFilter;
   import flash.filters.BlurFilter;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   import fe.unit.TelekinesisProbe;

   /** Native weaponLevit/control -> real Session/TCP -> final display filters. */
   public class TelekinesisTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,readyAt:int=0,baseX:Number,baseY:Number;
      private var enemy:Object,box:Object,peerExpected:Object,localDone:Boolean=false,peerDone:Boolean=false;
      private var samples:int=0,good:int=0,pixelCount:int=0,enemyGood:int=0,boxGood:int=0;
      private var ownColor:uint,peerColor:uint;
      private var wire:Object;
      private var sourceReadyAt:int=0,frameSerial:int=0,renderedSerial:int=-1;
      private var knownWeaponStyles:Object={},transitionFrames:int=0,transitionBad:int=0;
      private var round:int=0,alicorn:Object,loot:Object,boxTint:String,heldExpected:Object;
      private var colorMiss:int=0;
      private var sceneWire:Array=[];
      public function TelekinesisTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         ownColor=host?0x20D0FF:0xE040B0;peerColor=host?0xE040B0:0x20D0FF;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"telekinesis "+s);}
      private function klass(s:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(s) as Class;}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="telekinesis-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.loots is Array)sceneWire=p.loots;
         var incoming:Object=host?p.snap:null;
         if(!host && p.players is Array)for each(var player:Object in p.players)if(player.id==0)incoming=player.snap;
         if(incoming!=null) {
            wire={wi:incoming.wi,weapons:incoming.weapons,tele:incoming.tele};
            for each(var ws:Object in incoming.weapons as Array)if(ws.main===true && ws.aura!=null) {
               var styles:Array=knownWeaponStyles[ws.id] as Array;
               if(styles==null)styles=knownWeaponStyles[ws.id]=[];
               var encoded:String=JSON.stringify(ws.aura),found:Boolean=false;
               for each(var old:Object in styles)if(JSON.stringify(old)==encoded)found=true;
               if(!found)styles.push(ws.aura);
            }
         }
         if(p.type!="telekinesis-test")return;
         try {
            if(host && phase=="boot" && p.stage=="ready" && nativeReady()) {baseX=mod.game.gg.X;baseY=mod.game.gg.Y;setup();send("setup",{x:baseX,y:baseY,enemy:enemy.id,enemyColor:glow(target(enemy.currentWeapon)).color});}
            else if(!host && p.stage=="setup") {baseX=p.x;baseY=p.y;peerExpected=p;setup();send("prepared");}
            else if(host && p.stage=="prepared"){startRound(0);send("show",{round:0});}
            else if(!host && p.stage=="show")startRound(int(p.round));
            else if(p.stage=="held-style")heldExpected=p.style;
            else if(p.stage=="sampled"){peerDone=true;if(host && localDone)advance();}
            else if(!host && p.stage=="done-request"){send("done-ack");finish();}
            else if(host && p.stage=="done-ack")leaveAndFinish();
            else if(p.stage=="done")finish();
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(host && mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         if(mod.game.gg!=null){mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning() || mod.game.gg==null)return;
         if(phase=="boot" && !host && nativeReady() && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase!="done" && at>0 && getTimer()-at>20000){check(false,"timeout "+phase);send("done");finish();}
      }
      private function nativeReady():Boolean {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         // Do not freeze the new character in its opening/revival animation
         // or measure through the native fade covering the whole scene.
         return g!=null && !g.disabled && g.work!="res" && Number(g.t_work)<=0
            && !w.onPause && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function setup():void {
         var b:Object=mod.game,g:Object=b.gg;phase="prepared";at=getTimer();
         b.forceCloseOverlays();g.disabled=true;g.invulner=true;g.isTake=0;g.dx=g.dy=0;g.work="";g.anim("stay",true);
         g.setPos(baseX+(host?0:80),baseY);g.setVisPos();b.loc.base=false;
         b.world.app.cMagic=ownColor;g.refreshVis();
         equip(g,"lmg");
         check(glow(target(g.currentWeapon))!=null && glow(target(g.currentWeapon)).color==ownColor,"native player weapon emits its own magic color");
         if(host){
            var c:Class=klass("fe.unit.UnitRaider");
            for(var i:int=1;i<=9;i++) {
               var xml:XML=<unit weap="lmg"/>;xml.@tr=i;
               var u:Object=new c(String(i),100,xml,null);
               if(glow(target(u.currentWeapon))!=null){enemy=u;break;}
            }
            if(enemy==null)throw new Error("no native levitating raider weapon");
            enemy.id="telekinesis_raider";enemy.putLoc(b.loc,baseX+170,baseY);b.loc.addObj(enemy);b.loc.units.push(enemy);
            enemy.disabled=true;enemy.doop=true;enemy.xp=0;
            var boxClass:Class=klass("fe.loc.Box");
            box=new boxClass(b.loc,"case",baseX+45,baseY-60,<obj/>,null);b.loc.addObj(box);b.loc.objs.push(box);
            grab(box);
            c=klass("fe.unit.UnitAlicorn");alicorn=new c("1",100,<unit tr="1"/>,null);
            alicorn.id="telekinesis_alicorn";alicorn.putLoc(b.loc,baseX+220,baseY);b.loc.addObj(alicorn);b.loc.units.push(alicorn);
            alicorn.disabled=true;alicorn.doop=true;alicorn.xp=0;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.RENDER,renderSample,false,-30000);
      }
      private function equip(g:Object,id:String,mount:int=0):void {
         if(g.currentWeapon!=null)g.currentWeapon.remVisual();
         var factory:Object=klass("fe.weapon.Weapon");g.currentWeapon=factory.create(g,id,0);g.childObjs=[g.currentWeapon];g.weaponKrep=mount;g.weaponLevit();g.currentWeapon.addVisual();
         aimWeapon(g);
      }
      private function aimWeapon(g:Object):void {
         g.storona=1;g.celX=g.X+250;g.celY=g.Y-45;
         g.setWeaponPos(g.currentWeapon.tip);g.currentWeapon.step();
      }
      private function tint(o:Object):String {return o==null?"missing":JSON.stringify(o.vis.transform.colorTransform);}
      private function findBox():Object {
         for each(var o:Object in mod.game.loc.objs)if(o.id=="case" && Math.abs(o.X-baseX-45)<10)return o;return null;
      }
      private function findLoot():Object {
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)
            if(GameBridge.probe(o,"item")!=null && o.item.id=="kofe")return o;return null;
      }
      private function grab(o:Object):void {
         var b:Object=mod.game,g:Object=b.gg;if(o==null)throw new Error("missing grab fixture round "+round);
         if(g.teleObj!=null)g.dropTeleObj();
         o.levitPoss=true;o.massa=1;o.onCursor=1;
         b.loc.celObj=o;b.loc.celDist=0;b.world.celX=o.X;b.world.celY=o.Y;
         g.mana=1000;g.pers.telemaster=1;g.pers.maxTeleMassa=100;g.pers.teleDist=1000000;b.loc.portOn=true;
         TelekinesisProbe.grabPlayer(g);
         check(g.teleObj===o && glow(o.vis)!=null,"native player grabs "+String(GameBridge.probe(o,"id") || GameBridge.probe(GameBridge.probe(o,"item"),"id"))+" round="+round);
         send("held-style",{style:{color:glow(o.vis)==null?0:glow(o.vis).color,tint:tint(o)}});
      }
      private function startRound(n:int):void {
         round=n;phase="show";at=getTimer();sourceReadyAt=0;localDone=peerDone=false;samples=good=enemyGood=boxGood=pixelCount=colorMiss=0;
         var b:Object=mod.game,g:Object=b.gg;
         if(box==null)box=findBox();
         if(n==0 && host)send("held-style",{style:{color:ownColor,tint:tint(box)}});
         if(n==1){
            if(host)g.dropTeleObj();
            ownColor=host?0x70FF30:0xA060FF;peerColor=host?0xA060FF:0x70FF30;
            b.world.app.cMagic=ownColor;g.refreshVis();equip(g,"assr");b.world.redrawLoc();
            check(GameBridge.probe(g.currentWeapon.vis,"kor")!=null,"native alternate weapon uses a separate glowing body");
         }
         if(n==2){
            ownColor=host?0xFFA020:0x4080FF;peerColor=host?0x4080FF:0xFFA020;
            b.world.app.cMagic=ownColor;g.refreshVis();g.weaponLevit();
            boxTint=tint(box);if(host)box.vis.filters=[new BlurFilter(0,0)];else grab(box);
         }
         if(n==3){
            if(!host)g.dropTeleObj();
            else {TelekinesisProbe.grabEnemy(alicorn,box);check(box.levit==2 && glow(box.vis)!=null,"native alicorn lifts the box");send("held-style",{style:{color:glow(box.vis).color,tint:tint(box)}});}
         }
         if(n==4){
            if(host){alicorn.dropTeleObj();var lc:Class=klass("fe.loc.Loot"),ic:Class=klass("fe.serv.Item");
               loot=new lc(b.loc,new ic(null,"kofe",1),baseX+50,baseY-90,false,false,false);loot.auto=false;loot.stay=true;grab(loot);}
         }
         if(n==5){if(host)g.dropTeleObj();else {loot=findLoot();grab(loot);}}
         if(n==6){if(!host)g.dropTeleObj();equip(g,"lmg",1);b.world.redrawLoc();}
         if(n==7){equip(g,"lmg");if(host)box.vis.filters=[new BlurFilter(0,0)];else grab(box);}
         check(isFinite(Number(g.currentWeapon.rot)),"round="+round+" native aim produces a finite weapon angle");
      }
      private function advance():void {
         if(round<7){var n:int=round+1;startRound(n);send("show",{round:n});}
         else {
            // Wait for the peer's completion receipt before closing its socket.
            phase="closing";at=getTimer();send("done-request");
         }
      }
      private function leaveAndFinish():void {
         mod.session.leave();check(glow(box.vis)==null && tint(box)==boxTint,"leaving clears remote held aura and restores native tint");
         check(hasBlur(box.vis),"leaving preserves unrelated native filters");finish();
      }
      private function drive(e:Event):void {
         if(phase=="done")return;++frameSerial;var g:Object=mod.game.gg;
         mod.game.forceCloseOverlays();g.disabled=true;g.isTake=0;g.dx=g.dy=0;
         g.setPos(baseX+(host?0:80),baseY);g.setVisPos();
         aimWeapon(g);
         if(host){enemy.disabled=true;enemy.dx=enemy.dy=0;enemy.setVisPos();alicorn.disabled=true;alicorn.dx=alicorn.dy=0;}
         if(g.teleObj!=null){var held:Object=g.teleObj;held.dx=held.dy=0;held.stay=true;}
         mod.stage.invalidate();
      }
      private function wireReady():Boolean {
         if(wire==null || !(wire.weapons is Array))return false;
         var expectedId:String=round>=1 && round<=5?"assr":"lmg";
         for each(var s:Object in wire.weapons)if(s.main===true && s.id==expectedId && s.aura!=null) {
            var list:Array=s.aura.glow as Array;
            return round==6?list!=null && list.length==0:list!=null && list.length>0 && uint(list[0][0])==peerColor;
         }
         return false;
      }
      private function renderSample(e:Event):void {
         if(phase!="show" || renderedSerial==frameSerial)return;
         renderedSerial=frameSerial;
         var ghost:Object=mod.game.getRemoteGhost(host?1:0),weapon:Object=GameBridge.probe(ghost,"currentWeapon");
         var styles:Array=knownWeaponStyles[GameBridge.probe(weapon,"id")] as Array;
         if(weapon!=null && styles!=null) {
            var matched:Boolean=false;
            for each(var style:Object in styles) {
               var root:Object=weapon.vis,v:Object=style.kor===true?GameBridge.probe(root,"kor"):root;
               var f:GlowFilter=glow(v),list:Array=style.glow as Array;
               if(v!=null && list!=null && (list.length==0?f==null:f!=null && f.color==uint(list[0][0])))matched=true;
            }
            transitionFrames++;
            if(!matched) {
               transitionBad++;
               if(transitionBad<=4)Log.d("TELEKINESIS TRANSITION "+JSON.stringify({round:round,weapon:weapon.id,known:styles,root:glow(weapon.vis),body:glow(target(weapon))}));
            }
         }
         if(sourceReadyAt==0 && wireReady())sourceReadyAt=getTimer();
         if(sourceReadyAt>0)sample();
      }
      private function target(w:Object):DisplayObject {
         var v:Object=GameBridge.probe(w,"vis");return (GameBridge.probe(v,"kor") || v) as DisplayObject;
      }
      private function glow(v:Object):GlowFilter {
         if(v!=null)for each(var f:Object in v.filters)if(f is GlowFilter)return f as GlowFilter;return null;
      }
      private function hasBlur(v:Object):Boolean {for each(var f:Object in v.filters)if(f is BlurFilter)return true;return false;}
      private function pixels(v:DisplayObject):int {
         if(v==null || v.stage==null)return 0;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);r.inflate(10,10);
         r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone(),m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),fs:Array=v.filters;
         a.draw(root,m);v.filters=[];b.draw(root,m);v.filters=fs;
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),n:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;a.dispose();b.dispose();return n;
      }
      /** Bounded read-only evidence; unchanged pixel and ownership assertions below. */
      private function objectState(o:Object):Object {
         if(o==null)return null;
         var item:Object=GameBridge.probe(o,"item");
         return {cls:getQualifiedClassName(o),id:GameBridge.probe(o,"id"),item:GameBridge.probe(item,"id"),kol:GameBridge.probe(item,"kol"),
            x:GameBridge.probe(o,"X"),y:GameBridge.probe(o,"Y"),begX:GameBridge.probe(o,"begX"),begY:GameBridge.probe(o,"begY"),
            levit:GameBridge.probe(o,"levit"),stay:GameBridge.probe(o,"stay"),invis:GameBridge.probe(o,"invis"),
            inChain:GameBridge.probe(o,"in_chain"),localHeld:mod.game.gg.teleObj===o,
            enemyHeld:alicorn!=null && TelekinesisProbe.enemyHeld(alicorn)===o,
            glow:glow(GameBridge.probe(o,"vis")),tint:GameBridge.probe(o,"vis")==null?null:tint(o)};
      }
      private function displayState(v:DisplayObject):Object {
         if(v==null)return null;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root),chain:Array=[];
         for(var node:DisplayObject=v;node!=null && chain.length<12;node=node.parent) {
            chain.push({cls:getQualifiedClassName(node),name:node.name,visible:node.visible,alpha:node.alpha,x:node.x,y:node.y,
               scaleX:node.scaleX,scaleY:node.scaleY,scrollRect:node.scrollRect,
               mask:node.mask==null?null:{name:node.mask.name,bounds:node.mask.getBounds(root)},
               parentIndex:node.parent==null?-1:node.parent.getChildIndex(node)});
         }
         var clipped:Rectangle=r.clone();clipped.inflate(10,10);
         clipped=clipped.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         return {onStage:v.stage!=null,contained:root is DisplayObjectContainer && DisplayObjectContainer(root).contains(v),
            bounds:r,clipped:clipped,chain:chain};
      }
      private function diagnose(v:DisplayObject,observed:Object):void {
         var coffee:Array=[],cases:Array=[];
         for(var o:Object=mod.game.loc.firstObj;o!=null && coffee.length<12;o=o.nobj)
            if(GameBridge.probe(GameBridge.probe(o,"item"),"id")=="kofe")coffee.push(objectState(o));
         for each(o in mod.game.loc.objs)if(o.id=="case" && cases.length<12)cases.push(objectState(o));
         Log.d("TELEKINESIS DISPLAY "+JSON.stringify({host:host,round:round,stage:[mod.stage.stageWidth,mod.stage.stageHeight],
            room:mod.game.roomKey(),player:objectState(mod.game.gg),wire:wire,sceneWire:sceneWire,
            weapon:displayState(v),observed:objectState(observed),heldDisplay:displayState(GameBridge.probe(observed,"vis") as DisplayObject),
            box:objectState(box),loot:objectState(loot),coffee:coffee,cases:cases}));
         var image:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         image.draw(mod.main as DisplayObject);
         var out:FileStream=new FileStream();
         out.open(File.applicationStorageDirectory.resolvePath("presentation-aura-round"+round+"-scene.png"),FileMode.WRITE);
         out.writeBytes(image.encode(image.rect,new PNGEncoderOptions()));out.close();image.dispose();
      }
      private function sample():void {
         // Wait for source input, not for the renderer to become correct.
         if(getTimer()-sourceReadyAt<1500)return;
         if(box==null)box=findBox();
         var ghost:Object=mod.game.getRemoteGhost(host?1:0),v:DisplayObject=target(GameBridge.probe(ghost,"currentWeapon")),f:GlowFilter=glow(v);
         samples++;if(round==6?f==null:(f!=null && f.color==peerColor))good++;
         else if(colorMiss++<4)Log.d("TELEKINESIS COLOR MISS "+JSON.stringify({round:round,host:host,
            elapsed:getTimer()-sourceReadyAt,expected:peerColor,actual:f==null?null:f.color,wire:wire}));
         if(pixelCount==0 && f!=null)pixelCount=pixels(v);
         if(!host){
            for each(var u:Object in mod.game.loc.units)if(u.id==peerExpected.enemy){var ef:GlowFilter=glow(target(u.currentWeapon));if(ef!=null && ef.color==peerExpected.enemyColor)enemyGood++;}
            if(round==0 && box!=null && glow(box.vis)!=null && glow(box.vis).color==peerColor)boxGood++;
         }
         if(getTimer()-sourceReadyAt<3000)return;
         check(samples>=5,"round="+round+" network-converged samples="+samples);
         check(good==samples,"round="+round+" remote weapon "+(round==6?"removes non-levitating glow":"uses peer color")+" frames="+good+"/"+samples);
         if(round==0){check(pixelCount>5,"remote weapon contributes scene pixels="+pixelCount);
            if(!host){check(enemyGood==samples,"native enemy weapon aura frames="+enemyGood+"/"+samples);check(boxGood==samples,"host-held box aura frames="+boxGood+"/"+samples);}}
         if(round==1)check(pixelCount>5 && v===GameBridge.probe(ghost.currentWeapon.vis,"kor"),"alternate weapon aura stays on the native child and produces pixels");
         if(round==1 || round==4 || round==6)check(box!=null && glow(box.vis)==null,"round="+round+" released box has no stale glow");
         if(round==3 && host) {
            check(TelekinesisProbe.enemyHeld(alicorn)===box && box.levit==2,"new native enemy caster survives the previous remote Q release");
            Log.d("TELEKINESIS NATIVE ENEMY OWNER "+JSON.stringify({held:TelekinesisProbe.enemyHeld(alicorn)===box,
               levit:box.levit,glow:glow(box.vis),tint:tint(box)}));
         }
         var observed:Object=((round==0 || round==3) && !host) || ((round==2 || round==7) && host)?box:null;
         if(round==4 && !host){loot=findLoot();observed=loot;}
         if(round==5 && host)observed=loot;
         diagnose(v,observed);
         if(observed!=null){
            check(glow(observed.vis)!=null && heldExpected!=null && glow(observed.vis).color==heldExpected.color,"round="+round+" remote held object has caster color");
            check(heldExpected!=null && tint(observed)==heldExpected.tint,"round="+round+" remote held tint matches native source expected="+(heldExpected==null?null:heldExpected.tint)+" actual="+tint(observed));
            check(pixels(observed.vis)>5,"round="+round+" held aura produces visible pixels");
         }
         if(round==6)check(loot!=null && glow(loot.vis)==null,"released loot removes aura despite retained fracLevit");
         if(round==2 || round==5 || round==7) {
            if(!host)check(mod.game.gg.teleObj===(round==5?loot:box) && glow(mod.game.gg.teleObj.vis).color==ownColor,"round="+round+" local grab keeps its native ownership and glow");
            else {
               var remoteHeld:Object=round==5?loot:box;
               check(mod.game.gg.teleObj==null && Number(remoteHeld.levit)==(round==5?0:1)
                  && remoteHeld.stay===true && Math.abs(Number(remoteHeld.dx))+Math.abs(Number(remoteHeld.dy))<.001,
                  "round="+round+" remote motion holds its object without enabling a local caster");
            }
         }
         if(host && (round==2 || round==7))check(hasBlur(box.vis),"round="+round+" aura preserves unrelated object filter");
         Log.d("TELEKINESIS TRACE "+JSON.stringify({host:host,round:round,remote:f,wire:wire}));
         localDone=true;phase="sampled";send("sampled",{round:round});if(host && peerDone)advance();
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,renderSample);}
         check(transitionFrames>10 && transitionBad==0,"weapon and aura share one presentation state frames="+transitionFrames+" mismatches="+transitionBad);
         Log.d("COOP EFFECTS DONE telekinesis "+(host?"host":"join"));
      }
   }
}
