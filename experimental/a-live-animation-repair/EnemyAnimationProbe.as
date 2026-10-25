package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import fe.unit.RConnectAnimationAccess;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Controlled native shooters; receiving actors are never driven by this probe. */
   public class EnemyAnimationProbe extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,baseX:Number,baseY:Number;
      private var units:Array=[],rows:Array=[],wire:Array=[],shotSeen:Object={},shots:int=0,dead:Boolean=false;
      private var done:Boolean=false,peerDone:Boolean=false;
      private var frameSerial:int=0,sampledSerial:int=-1,sourceShots:Array=[0,0,0],lastBullet:Array=[null,null,null];
      public function EnemyAnimationProbe() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"enemy-animation "+s);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="enemy-animation-probe";p.op=op;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         var b:Object=mod.game,g:Object=b.gg;
         if(phase=="boot"&&g!=null&&g.sost==1&&g.t_work==0&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning())
            if(!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase!="done"&&getTimer()-at>60000){check(false,"timeout "+phase);finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(!host&&phase=="running")for each(var stream:String in ["units","enemyMotion"])if(p[stream] is Array)
            for each(var u:Object in p[stream])if(String(u.id).indexOf("animprobe_")==0) {
               var events:Array=[];
               for each(var w:Object in u.weapons)for each(var shot:Object in w.events) {
                  var key:String=u.id+":"+w.stream+":"+shot.seq;
                  if(!shotSeen[key]){shotSeen[key]=true;events.push({key:key,born:shot.at,sent:w.sampleTime,flight:shot.flight==null?null:shot.flight.cls});}
               }
               wire.push({at:getTimer(),stream:stream,id:u.id,stamp:u.sampleTime,sost:u.sost,anim:u.anim,pose:u.pose,events:events,bytes:JSON.stringify(u).length});
            }
         if(p.type!="enemy-animation-probe")return;
         if(host&&p.op=="ready"&&phase=="boot") {
            baseX=Math.max(160,Math.min(mod.game.gg.X,mod.game.loc.limX-500));baseY=Math.max(200,mod.game.gg.Y);
            setup();send("setup",{x:baseX,y:baseY});
         } else if(!host&&p.op=="setup"&&phase=="boot") {baseX=p.x;baseY=p.y;setup();send("installed");}
         else if(host&&p.op=="installed"){phase="running";at=getTimer();send("start");}
         else if(!host&&p.op=="start"){phase="running";at=getTimer();}
         else if(p.op=="sampled"){peerDone=true;if(done){send("done");finish();}}
         else if(p.op=="done")finish();
      }
      private function spawn(clsName:String,id:String,kind:String,offset:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+clsName) as Class;
         var u:Object=new cls(kind,100,<unit tr="1" vis="right"/>,null);u.id="animprobe_"+id;
         u.putLoc(mod.game.loc,baseX+offset,baseY-100);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.lootIsDrop=true;u.xp=0;u.dx=u.dy=0;units.push(u);return u;
      }
      private function setup():void {
         mod.game.forceCloseOverlays();mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;
         mod.game.gg.disabled=true;
         if(host) {
            spawn("UnitAlicorn","alicorn","1",160);
            spawn("UnitRaider","raider","1",300);
            var turret:Object=spawn("UnitTurret","turret","land",80);turret.alarma();turret.fixed=true;turret.stay=true;
            check(units[0].currentWeapon!=null&&turret.currentWeapon!=null,"native alicorn and turret weapons exist");
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
         phase="warm";at=getTimer();
      }
      private function drive(e:Event):void {
         frameSerial++;if(phase!="running")return;
         var age:int=getTimer()-at,b:Object=mod.game;
         b.forceCloseOverlays();b.gg.disabled=true;b.gg.invulner=true;
         if(host) {
            for(var i:int=0;i<units.length;i++) {
               var u:Object=units[i];u.disabled=true;
               if(i<2&&u.sost<3) {
                  u.setPos(baseX+160+i*140+Math.sin(age/600)*55,baseY-(i==0?120+Math.cos(age/800)*25:0));
                  u.dx=Math.cos(age/600)*3;u.dy=i==0?Math.sin(age/800):0;
                  u.stay=i!=0;u.isFly=i==0;
               }
               u.setVisPos();u.animate();
            }
            if(age>2500&&age<11000) {
               for each(i in [0,2]) {
                  u=units[i];var w:Object=u.currentWeapon;
                  u.celX=u.X+250;u.celY=u.Y-30;
                  w.hold=999;w.damage=w.damageExpl=w.destroy=0;
                  w.attack();w.step();u.animate();
                  if(w.b!=null&&lastBullet[i]!==w.b){sourceShots[i]++;lastBullet[i]=w.b;shots++;}
               }
            }
            if(age>12500&&!dead){dead=true;units[1].dam=0;units[1].hp=0;units[1].die();send("death",{at:getTimer()});}
         }
         mod.stage.invalidate();
      }
      private function sample(e:Event):void {
         if(phase!="running"||sampledSerial==frameSerial)return;sampledSerial=frameSerial;
         var age:int=getTimer()-at,actors:Array=[],bullets:Array=[];
         for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&String(u.id).indexOf("animprobe_")==0) {
            var gun:Object=u.currentWeapon,body:Object=GameBridge.probe(u.vis,"osn"),barrel:Object=GameBridge.probe(body,"puha");
            var muzzle:Object=GameBridge.probe(barrel,"puha");
            actors.push({id:u.id,x:u.X,y:u.Y,sost:u.sost,anim:u.animState,pose:RConnectAnimationAccess.capture(u as Unit),
               barrel:GameBridge.probe(muzzle,"currentFrame"),gunFrame:GameBridge.probe(GameBridge.probe(gun,"vis"),"currentFrame"),
               shots:GameBridge.probe(gun,"kol_shoot"),firing:GameBridge.probe(gun,"t_shoot")});
         }
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2] as DisplayObjectContainer;
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i),name:String=getQualifiedClassName(v);
            if(name.indexOf("visbul")==0&&v.visible)bullets.push({cls:name,x:v.x,y:v.y,rot:v.rotation,a:v.alpha});
         }
         rows.push({at:getTimer(),age:age,actors:actors,bullets:bullets});
         if(age<17500)return;
         Log.d("ENEMY ANIMATION TRACE "+JSON.stringify({role:host?"host":"join",rows:rows,wire:wire,shots:shots,sourceShots:sourceShots}));
         if(host)check(sourceShots[0]>5&&sourceShots[2]>5,"native continuous fire alicorn="+sourceShots[0]+" turret="+sourceShots[2]);
         check(rows.length>300,"final render samples="+rows.length);
         var found:Object={},seenBullets:int=0,deathFrames:int=0;
         for each(var row:Object in rows) {
            seenBullets+=row.bullets.length;
            for each(var a:Object in row.actors){found[a.id]=true;if(a.id=="animprobe_raider"&&a.sost>=3)deathFrames++;}
         }
         check(found.animprobe_alicorn===true&&found.animprobe_turret===true&&found.animprobe_raider===true,"three native actor classes rendered");
         check(seenBullets>0,"actual projectile display observations="+seenBullets);
         check(deathFrames>0,"native death display samples="+deathFrames);
         done=true;phase="sampled";send("sampled");if(peerDone){send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE enemy-animation "+(host?"host":"join"));
      }
   }
}
