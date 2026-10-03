package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.PNGEncoderOptions;
   import flash.events.TimerEvent;
   import flash.events.Event;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native background-door entry/return over TCP, with separate-room ownership. */
   public class HiddenRoomTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,started:Boolean=false,floor:int=0;
      private var front:Object,back:Object,doorInfo:Object,localPlayer:Object,hostX:Number,hostY:Number;
      private var victim:Object,survivor:Object,loss:Number;
      private var followHost:Boolean;
      private var preserveCorpses:Boolean;
      private var testOverlays:Boolean;
      private var rounds:int;
      private var doorRoom:Object,armedDoor:Object;
      private var round:int=0,moveX:Number,moveY:Number,bodyPixels:int=0,renderCount:int=0;
      private var renderCallbacks:int=0;
      private var renderFallback:Boolean=false;
      private var actionWaitLogged:Boolean=false;
      private var expectedHp:Number=1000;
      public function HiddenRoomTestDoc(follow:Boolean=false,corpses:Boolean=false,overlays:Boolean=false,count:int=5) {
         followHost=follow;preserveCorpses=corpses;testOverlays=overlays;rounds=count;
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         addEventListener(Event.ENTER_FRAME,holdDoorPosition,false,200000);
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"hidden-room "+s);}
      // Native critical damage is fractional. Reordered additions after JSON
      // transport can differ by 1e-13; this tolerance remains far below one HP.
      private function sameHealth(actual:Number,expected:Number):Boolean {return isFinite(actual) && isFinite(expected) && Math.abs(actual-expected)<0.0000001;}
      private function setPhase(s:String):void {phase=s;at=getTimer();Log.d("HIDDEN TEST "+(host?"host ":"join ")+s);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="hidden-room-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function finish():void {
         if(phase=="done")return;setPhase("done");timer.stop();
         if(mod!=null){mod.game.gg.ctr.keyLeft=false;mod.stage.removeEventListener(Event.RENDER,render);}
         removeEventListener(Event.ENTER_FRAME,holdDoorPosition);
         Log.d("COOP EFFECTS DONE hidden-room "+(host?"host":"join"));
      }
      private function info(room:Object):Object {return {landX:room.landX,landY:room.landY,landZ:room.landZ,landProb:room.landProb,key:mod.game.roomKey(room)};}
      private function nativeDoor(room:Object):Object {for each(var o:Object in room.objs)if(o.inter!=null && o.inter.allact=="comein" && o.inter.prob==null)return o;return null;}
      private function find(id:String):Object {for each(var u:Object in mod.game.loc.units)if(u.id==id)return u;return null;}
      private function holdDoorPosition(e:Event):void {
         if(mod!=null && host && phase=="control")mod.stage.invalidate();
         if(mod==null || armedDoor==null)return;
         var g:GameBridge=mod.game;
         if(g.loc!==doorRoom || g.gg.actionObj!==armedDoor){armedDoor=null;return;}
         g.gg.setPos(armedDoor.X,armedDoor.Y);g.gg.dx=g.gg.dy=0;
      }
      private function render(e:Event):void {
         if(!host || phase!="control")return;
         if(e!=null)renderCallbacks++;
         var root:DisplayObject=mod.main as DisplayObject,vis:DisplayObject=localPlayer.vis;
         var rect:Rectangle=vis.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(rect.width<1 || rect.height<1)return;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),z:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y),visible:Boolean=vis.visible;
         a.draw(root,matrix);vis.visible=false;z.draw(root,matrix);vis.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect),zv:Vector.<uint>=z.getVector(z.rect),n:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=zv[i])n++;
         bodyPixels=Math.max(bodyPixels,n);renderCount++;
         if(renderCount==10 && round==0){var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("presentation-hidden-host-body.png"),FileMode.WRITE);file.writeBytes(a.encode(a.rect,new PNGEncoderOptions()));file.close();}
         a.dispose();z.dispose();
      }
      private function bodyBounds():Object {
         var root:DisplayObject=mod.main as DisplayObject,vis:DisplayObject=localPlayer.vis;
         var bounds:Rectangle=vis.getBounds(root),screen:Rectangle=vis.getBounds(mod.stage);
         return {root:String(bounds),stage:String(screen),stageWidth:mod.stage.stageWidth,stageHeight:mod.stage.stageHeight,
            callbacks:renderCallbacks,timerFallback:renderFallback,localWidth:vis.width,localHeight:vis.height};
      }
      private function scenePicture():void {
         var picture:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         picture.draw(mod.main as DisplayObject);
         var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("presentation-hidden-scene-"+round+".png"),FileMode.WRITE);
         file.writeBytes(picture.encode(picture.rect,new PNGEncoderOptions()));file.close();picture.dispose();
      }
      private function auditEnemies():void {
         var alive:Array=[],orphan:Array=[],seen:Dictionary=new Dictionary(),u:Object=mod.game.loc.firstObj;
         while(u!=null && !seen[u]) {
            seen[u]=true;
            if(enemy(u) && u.sost<3 && u.hp>0) {
               if(u.id!="hidden_live")alive.push({id:u.id,code:u.code,hp:u.hp,sost:u.sost,disabled:u.disabled});
               if(mod.game.loc.units.indexOf(u)<0)orphan.push({id:u.id,code:u.code});
            }
            u=u.nobj;
         }
         Log.d("HIDDEN TEST enemies round="+round+" "+JSON.stringify({unexpected:alive,orphan:orphan}));
         check(alive.length==0,"native defeated enemies absent from live display chain round "+round);
         check(orphan.length==0,"no live enemy outside combat list round "+round);
         if(preserveCorpses) {
            var corpse:Object=find("hidden_dead"),pose:String=corpse==null?"absent":String(corpse.animState);
            Log.d("HIDDEN TEST corpse "+JSON.stringify({round:round,pose:pose,sost:corpse==null?null:corpse.sost,
               attached:corpse!=null && corpse.vis!=null && corpse.vis.stage!=null,inChain:corpse==null?null:corpse.in_chain}));
            check(corpse==null || corpse.vis==null || corpse.vis.stage==null || ["die","death","fall"].indexOf(pose)>=0,
               "returned corpse never displays a living pose round "+round+" pose="+pose);
         }
      }
      private function enemy(u:Object):Boolean {
         var cls:String=getQualifiedClassName(u);
         return u is Unit && u!==mod.game.gg && u.fraction>0 && u.fraction<100
            && cls!="fe.unit::UnitTrigger" && cls!="fe.unit::VirtualUnit";
      }
      private function state():Object {
         var g:GameBridge=mod.game,w:Object=g.world,l:Object=w.land;
         return {room:g.roomKey(),landZ:l.locZ,worldLoc:w.loc.id,landLoc:l.loc.id,ggLoc:g.gg.loc.id,
            samePlayer:w.gg===localPlayer,landPlayer:l.gg===localPlayer,roomPlayer:g.loc.gg===localPlayer,
            bodyVisible:localPlayer.vis.visible,bodyAttached:localPlayer.vis.stage!=null,disabled:localPlayer.disabled,
            control:localPlayer.ggControl,bodyAlpha:localPlayer.vis.alpha,bodyInnerVisible:GameBridge.probe(localPlayer.vis,"osn")==null?null:localPlayer.vis.osn.visible,
            sost:localPlayer.sost,hp:localPlayer.hp,dead:localPlayer.pers.dead,t_die:w.t_die,
            renderedRoom:w.grafon.loc.id,
            x:g.gg.X,y:g.gg.Y,authority:mod.session.rooms.authority,busy:mod.session.rooms.busy,ready:mod.session.rooms.ready};
      }
      private function useDoor():void {
         var g:GameBridge=mod.game,d:Object=nativeDoor(g.loc);
         check(d!=null,"native comein door exists at "+g.roomKey());
         if(d==null){send("done");finish();return;}
         g.gg.setPos(d.inter.X,d.inter.Y);g.gg.setVisPos();g.gg.actionObj=null;g.gg.teleObj=null;g.gg.t_work=0;
         d.inter.setAct("lock",0);d.inter.mine=0;d.inter.is_ready=true;
         Log.d("HIDDEN TEST door-before "+JSON.stringify(state()));
         // Let UnitPlayer.actions and Box.step perform the actual in-frame
         // interaction; a Timer-side direct act() skips that ordering.
         g.gg.ctr.keyAction=true;g.gg.actionObj=d.inter;g.gg.t_action=d.inter.t_action;
         doorRoom=g.loc;armedDoor=d.inter;actionWaitLogged=false;d.inter.beginAct();
         Log.d("HIDDEN TEST door-armed "+JSON.stringify(state()));
      }
      private function selectPair():Boolean {
         var land:Object=mod.game.world.land,candidates:Array=[];
         for each(var col:Array in land.locs)if(col!=null)for each(var row:Array in col)if(row!=null && row[0]!=null && row[1]!=null) {
            var a:Object=row[0],b:Object=row[1],d:Object=nativeDoor(a);
            if(d!=null && nativeDoor(b)!=null && !TravelGuard.restricted(a) && !TravelGuard.restricted(b)) {
               candidates.push({front:info(a),back:info(b),door:{x:d.inter.X,y:d.inter.Y}});
            }
         }
         if(candidates.length==0)return false;
         var chosen:Object=candidates[0];
         // Match the foreground/background coordinates in the user session log
         // when this isolated map generation contains the same pair.
         for each(var pair:Object in candidates)if(pair.front.landX==4 && pair.front.landY==2)chosen=pair;
         front=chosen.front;back=chosen.back;doorInfo=chosen.door;
         Log.d("HIDDEN TEST pair "+JSON.stringify(chosen));
         TravelGuard.follow(mod.game,front);send("align",{front:front,back:back,door:doorInfo});setPhase("align");return true;
      }
      private function makeEnemy(id:String,x:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitMerc") as Class;
         var u:Object=new cls("1",100,<unit tr="1"/>,null);u.id=id;
         u.putLoc(mod.game.loc,x,doorInfo.y);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.stun=100000;u.xp=0;u.hp=u.maxhp=1000;u.skin=u.armor=u.armor_qual=u.shithp=0;return u;
      }
      private function prepareFollower():void {
         if(!testOverlays)return;
         if(round%2==0)mod.game.world.pip.onoff(2);else mod.game.world.sats.onoff(1);
         Log.d("HIDDEN TEST overlay-before "+JSON.stringify({round:round,pip:mod.game.world.pip.active,sats:mod.game.world.sats.active}));
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="hidden-room-test")return;
         try {
            if(p.stage=="done"){finish();return;}
            if(host) {
               if(p.stage=="ready" && !started){started=true;setPhase("select");}
               else if(p.stage=="aligned") {
                  var count:int=0;
                  for each(var old:Object in (mod.game.loc.units as Array).concat())if(enemy(old) && old.sost<3) {
                     old.code="hidden_native_"+(++count);
                     if(preserveCorpses)old.hp=1;
                     old.damage(preserveCorpses?10:100000,100,null,true);
                  }
                  Log.d("HIDDEN TEST defeated native cohort="+count);
                  victim=makeEnemy("hidden_dead",doorInfo.x+160);survivor=makeEnemy("hidden_live",doorInfo.x+240);
                  if(preserveCorpses)victim.hp=1;
                  victim.damage(preserveCorpses?10:100000,100,null,true);
                  check(victim.hp<=0 || victim.sost>=3,"foreground enemy defeated before door entry");
                  hostX=mod.game.gg.X;hostY=mod.game.gg.Y;prepareFollower();send("enter");setPhase("inside-wait");
               } else if(p.stage=="inside") {
                  if(testOverlays){mod.game.world.pip.onoff(-1);mod.game.world.sats.onoff(-1);}
                  Log.d("HIDDEN TEST host-after-join-entry "+JSON.stringify(state()));
                  check(mod.game.roomKey()==(followHost?back.key:front.key),followHost?"enabled host follows join into background":"host remains in foreground when join enters background");
                  check(mod.game.world.gg===localPlayer && localPlayer.loc===mod.game.loc && mod.game.world.land.gg===localPlayer,"host camera/player world pointers remain local");
                  check(localPlayer.vis.visible && localPlayer.vis.stage!=null,"host local player body remains visible after join entry");
                  check(localPlayer.ggControl && !localPlayer.disabled,"host input remains enabled after join entry round "+round);
                  moveX=localPlayer.X;moveY=localPlayer.Y;bodyPixels=renderCount=renderCallbacks=0;renderFallback=false;localPlayer.ctr.keyLeft=true;
                  setPhase("control");
               } else if(p.stage=="shot"){loss=Number(p.loss);setPhase("settle");}
            } else {
               if(p.stage=="align"){front=p.front;back=p.back;doorInfo=p.door;TravelGuard.follow(mod.game,front);setPhase("align");}
               else if(p.stage=="enter"){round=int(p.round);expectedHp=p.hp==null?1000:Number(p.hp);setPhase("enter");}
               else if(p.stage=="exit"){useDoor();setPhase("exit");}
            }
         }catch(error:Error){check(false,"message "+error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null || mod.game.loc==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         try {
            if(phase=="boot" && mod.config.getValue("autoLoadSave")=="9") {
               var loaded:Object=mod.game.world.getSave(9);
               if(timer.currentCount<140 || loaded==null || loaded.pers==null
                  || mod.game.gg.pers.level!=loaded.pers.level || mod.game.isTransitioning())return;
            }
            if(localPlayer==null)localPlayer=mod.game.gg;
            mod.game.gg.invulner=true;
            mod.config.setValue("followTeammate",host&&followHost?"1":"0");
            if(phase=="done")return;
            if(at>0 && getTimer()-at>30000){check(false,"timeout "+phase+" "+JSON.stringify(state()));send("done");finish();return;}
            if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
            if(mod.game.readWorldInfo().curLandId!="random_mane") {
               // Native Continue can restore a random-map character at base.
               // Wait for the saved profile above, then use ordinary mission travel.
               if(host && phase=="boot")mod.game.travelToLand("random_mane");
               return;
            }
            if(phase=="boot") {
               mod.game.forceCloseOverlays();mod.stage.addEventListener(Event.RENDER,render,false,-30000);
               Log.d("HIDDEN TEST profile "+JSON.stringify({level:mod.game.gg.pers.level,world:mod.game.readWorldInfo()}));setPhase("ready");
            }
            if(!host && phase=="ready")send("ready");
            if(host && phase=="select") {
               if(!selectPair()) {
                  if(++floor>3){check(false,"no native background door pair in sampled floors");send("done");finish();}
                  else {mod.game.world.game.gotoNextLevel();setPhase("next-floor");}
               }
            }
            if(host && phase=="next-floor" && getTimer()-at>1500)setPhase("select");
            if(host && phase=="control" && getTimer()-at>900) {
               localPlayer.ctr.keyLeft=false;
               // A hidden native window can suppress RENDER entirely when RV
               // is disabled. Sample the completed display tree from this later
               // timer; do not equate a missing callback with a missing body.
               if(renderCallbacks==0){renderFallback=true;render(null);}
               check(Math.abs(localPlayer.X-moveX)>2,"host moves through native input after follow round "+round);
               check(renderCount>0 && bodyPixels>30,"host body contributes pixels to final scene round "+round);
               Log.d("HIDDEN TEST control "+JSON.stringify({round:round,from:moveX,to:localPlayer.X,renders:renderCount,pixels:bodyPixels,bounds:bodyBounds(),state:state()}));
               // This input probe is repeated in one room. Restore its starting
               // position after observing movement, otherwise the fifth probe
               // can walk out through a normal side exit and invalidate reunion.
               localPlayer.setPos(moveX,moveY);localPlayer.dx=localPlayer.dy=0;localPlayer.setVisPos();
               if(round==0)scenePicture();
               send("exit");setPhase("exit-wait");
            }
            if(!host && phase=="align" && getTimer()-at>1000) {
               check(mod.game.roomKey()==front.key,"join aligned with foreground room");
               mod.game.gg.setPos(doorInfo.x,doorInfo.y);mod.game.gg.setVisPos();send("aligned");setPhase("wait-enter");
            }
            if(!host && phase=="enter" && getTimer()-at>1200){useDoor();setPhase("inside");}
            if(!host && phase=="inside" && getTimer()-at>1800) {
               if(mod.game.roomKey()!=back.key) {
                  // Native interaction counts simulation frames, not wall time.
                  // Wait for an in-progress action without rearming a cancelled
                  // one or forcing the transition under test.
                  var interaction:Object=mod.game.gg.actionObj;
                  var actionState:Object={remaining:mod.game.gg.t_action,key:mod.game.gg.ctr.keyAction,
                     pending:interaction!=null && interaction===armedDoor,
                     active:interaction==null?null:interaction.active,
                     isAct:armedDoor==null?null:armedDoor.is_act,elapsed:getTimer()-at,world:state()};
                  if(actionState.pending && getTimer()-at<15000) {
                     if(!actionWaitLogged){Log.d("HIDDEN TEST waiting-native-action "+JSON.stringify(actionState));actionWaitLogged=true;}
                     return;
                  }
                  check(false,"join enters distinct background Z room through native door "+JSON.stringify(actionState));send("done");finish();return;
               }
               if(followHost && mod.session.rooms.authority)return;
               check(true,"join enters distinct background Z room through native door");
               check(mod.session.rooms.authority!=followHost,followHost?"join returns to mirror after host follows inside":"join owns native simulation while host stays outside");
               Log.d("HIDDEN TEST join-inside "+JSON.stringify(state()));send("inside");setPhase("wait-exit");
            }
            if(!host && phase=="exit" && getTimer()-at>1800) {
               if(mod.session.rooms.authority)return;
               check(mod.game.roomKey()==front.key,"join returns to original foreground through native door");
               var dead:Object=find("hidden_dead"),alive:Object=find("hidden_live");
               check(dead==null || dead.hp<=0 || dead.sost>=3,"defeated foreground enemy does not respawn alive");
               check(alive!=null && sameHealth(alive.hp,expectedHp),"surviving foreground enemy keeps authoritative health expected="+expectedHp+" actual="+(alive==null?"missing":alive.hp));
               check(!mod.session.rooms.authority,"reunited join returns to mirrored combat");
               auditEnemies();
               loss=0;
               if(alive!=null) {
                  var gun:NativeTestGun=new NativeTestGun(mod.game.gg as Unit),weapon:Object=gun,hp:Number=alive.hp;
                  weapon.setPers(mod.game.gg,mod.game.gg.pers);weapon.damage=40;weapon.critCh=0;gun.fireAt(alive,true);loss=hp-alive.hp;
               }
               check(loss>0,"join native LMG can damage surviving enemy after return");
               Log.d("HIDDEN TEST shot "+JSON.stringify({round:round,before:hp,loss:loss,after:alive==null?null:alive.hp}));
               Log.d("HIDDEN TEST join-after-return "+JSON.stringify(state()));send("shot",{loss:loss});setPhase("wait-settle");
            }
            if(host && phase=="settle" && getTimer()-at>1200) {
               var currentLive:Object=find("hidden_live"),currentDead:Object=find("hidden_dead");
               check(currentLive!=null && sameHealth(currentLive.hp,expectedHp-loss) && loss>0,"host settles returned join hit once expected="+(expectedHp-loss)+" actual="+(currentLive==null?"missing":currentLive.hp));
               check(currentDead==null || currentDead.hp<=0 || currentDead.sost>=3,"host defeated enemy remains dead after round trip");
               auditEnemies();
               expectedHp-=loss;
               if(++round<rounds){prepareFollower();send("enter",{round:round,hp:expectedHp});setPhase("inside-wait");}
               else {send("done");finish();}
            }
         }catch(error:Error){check(false,"tick "+error.getStackTrace());send("done");finish();}
      }
   }
}
