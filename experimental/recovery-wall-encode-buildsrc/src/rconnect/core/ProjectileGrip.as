package rconnect.core {
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.game.TelekinesisVisuals;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** A remote grenade has one inert Obj for native Q/E and one original
    * PhisBullet for motion, fuse and damage. Never creates a second bullet. */
   public class ProjectileGrip {
      public static var instance:ProjectileGrip;
      private var mod:Object,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var ids:Dictionary=new Dictionary(true),owned:Object={},proxies:Dictionary=new Dictionary();
      private var retired:Dictionary=new Dictionary(),outgoing:Object,incoming:Object,beforeMotion:Object;
      private var aura:TelekinesisVisuals=new TelekinesisVisuals();
      private var serial:int=0,token:int=0,errors:int=0,lastFrame:int=getTimer(),wasPaused:Boolean=false;
      private var manaBefore:Number=0,hasState:Boolean=false;
      public function ProjectileGrip(m:Object) {
         mod=m;instance=this;
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,97000);
         m.stage.addEventListener(Event.ENTER_FRAME,after,false,-8700);
         m.stage.addEventListener(Event.RENDER,presentAura,false,-11500);
         timer.addEventListener(TimerEvent.TIMER,sendHeld);timer.start();
      }
      private function get game():Object {return mod.game;}
      private function get session():Object {return mod.session;}
      private function get rooms():Object {return session.rooms;}
      private function ready():Boolean {
         return (session.mode==Session.CONNECTED&&session.link!=null&&session.link.isOpen
            || session.mode==Session.HOSTING&&session.peers.length>0)
            &&rooms.ready&&!rooms.busy&&!game.roomHold&&game.gg!=null&&game.loc!=null&&!game.isTransitioning();
      }
      private function matches(p:Object):Boolean {
         return p!=null&&ready()&&String(p.roomKey)==game.roomKey()
            &&int(p.roomEpoch)==rooms.epoch&&int(p.roomTerm)==rooms.term;
      }
      private function peerFor(u:Object):TcpLink {
         if(u==null)return null;
         if(session.mode==Session.CONNECTED)return game.getRemoteGhost(0)===u?session.link:null;
         if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)
            if(game.getRemoteGhost(p.id)===u)return p.link;
         return null;
      }
      private function actor(link:TcpLink):Object {return game.getRemoteGhost(session.mode==Session.CONNECTED?0:link.id);}
      private function known(link:TcpLink):Boolean {return link!=null&&link.isOpen&&peerFor(actor(link))===link;}
      private function paused():Boolean {return session.pause!=null&&session.pause.paused;}
      private function alive(b:Object):Boolean {
         return b!=null&&getQualifiedClassName(b)=="fe.weapon::PhisBullet"&&b.owner===game.gg
            &&b.loc===game.loc&&b.in_chain&&!b.babah&&b.liv>3;
      }
      /** Added to the existing projectile event, so identity survives a weapon
       * switch and shares its displayed motion/lifetime rather than a new clock. */
      public function describe(b:Object):Object {
         if(!ready()||getQualifiedClassName(b)!="fe.weapon::PhisBullet"||b.owner!==game.gg)return null;
         if(ids[b]===undefined){ids[b]=String(++serial);owned[ids[b]]=b;hasState=true;}
         var id:String=String(ids[b]);
         return rooms.stamp({id:id,active:alive(b)&&b.levitPoss,selectable:alive(b)&&b.levitPoss&&b.liv>5,
            mass:b.massa,sx:b.scX,sy:b.scY,dx:b.dx,dy:b.dy});
      }
      /** Called after the existing projectile display has sampled its frame. */
      public function present(rec:Object):void {
         var s:Object=rec.s.grip,v:MovieClip=rec.vis as MovieClip;
         if(s==null||!matches(s)||peerFor(rec.owner)==null||v==null||!v.visible||v.stage==null) {
            forget(rec);return;
         }
         for each(var key:String in ["mass","sx","sy","dx","dy"])
            if(s[key]===undefined||!isFinite(Number(s[key]))){forget(rec);return;}
         if(Number(s.mass)<=0||Number(s.sx)<=0||Number(s.sy)<=0||String(s.id)=="") {forget(rec);return;}
         if(s.active!==true){forget(rec);return;}
         var o:Object=rec.gripProxy;
         if(o==null) {
            var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.Obj") as Class;
            o=new cls();o.loc=rec.loc;o.sloy=2;o.uid="rconnect-projectile-"+String(s.id);o.code="rconnect-projectile";
            rec.gripProxy=o;proxies[o]=rec;rec.loc.addObj(o);hasState=true;
         }
         o.vis=v;o.X=v.x;o.Y=v.y;o.massa=Number(s.mass);o.scX=Number(s.sx);o.scY=Number(s.sy);
         o.levitPoss=true;
         // Native Q/E modifies these velocities; do not erase its impulse
         // between gg.step and this module's after-frame observation.
         if(outgoing==null||outgoing.raw!==o){o.dx=Number(s.dx);o.dy=Number(s.dy);}
         o.onCursor=s.selectable===true&&Math.abs(game.world.celX-o.X)<o.scX/2
            &&Math.abs(game.world.celY-o.Y)<o.scY/2?3:0;
         // Original PhisBullet also clears hover in its final fuse frames.
         if(s.selectable!==true&&game.gg.teleObj!==o)o.levitPoss=false;
      }
      public function forget(rec:Object):void {
         var o:Object=rec.gripProxy;if(o==null)return;
         if(outgoing!=null&&outgoing.raw===o)endOutgoing(true);
         if(game.gg!=null&&game.gg.teleObj===o)game.gg.dropTeleObj();
         o.onCursor=0;o.levitPoss=false;o.vis=null;
         if(o.loc!=null){if(o.loc.celObj===o)o.loc.celObj=null;if(o.in_chain)o.loc.remObj(o);}
         delete proxies[o];rec.gripProxy=null;
      }
      private function watch():void {
         for(var old:Object in links)if(!old.isOpen){old.removeEventListener(TcpLink.MESSAGE,receive);delete links[old];delete retired[old];}
         var list:Array=[];if(session.mode==Session.CONNECTED)list.push(session.link);
         else if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)list.push(p.link);
         for each(var link:TcpLink in list)if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function message(op:String,id:String,n:int):Object {return rooms.stamp({type:"projectile-grip",op:op,id:id,token:n});}
      private function sendHeld(e:TimerEvent=null):void {
         try {
            if(outgoing==null||!ready()||game.gg.teleObj!==outgoing.raw)return;
            var g:Object=game.gg,p:Object=message("hold",outgoing.id,outgoing.token);
            p.input={cx:g.celX,cy:g.celY,speed:g.teleSpeed,accel:g.teleAccel,mana:g.mana,startMana:outgoing.startMana,
               mass:g.pers.maxTeleMassa,range:g.pers.teleDist,master:g.pers.telemaster};
            p.aura=TelekinesisVisuals.captureObject(outgoing.raw);outgoing.link.send(p);
         }catch(error:Error){fault(error);}
      }
      private function before(e:Event):void {
         try {
            watch();var now:int=getTimer(),pause:Boolean=paused();
            if(incoming!=null&&(pause||wasPaused))incoming.until+=Math.max(0,now-lastFrame);
            lastFrame=now;wasPaused=pause;
            if(!ready()){if(hasState)reset();return;}
            for(var id:String in owned)if(!alive(owned[id]))delete owned[id];
            var g:Object=game.gg;manaBefore=g.mana;
            if(outgoing!=null&&(!outgoing.link.isOpen||!matches(outgoing.stamp)||g.hp<=0||g.sost>=3
               ||!outgoing.raw.levitPoss||(!outgoing.accepted&&now>outgoing.until)))endOutgoing(true);
            var raw:Object=g.teleObj,rec:Object=raw==null?null:proxies[raw];
            beforeMotion=rec==null?null:{raw:raw,dx:raw.dx,dy:raw.dy,action:game.world.ctr.keyAction};
            if(incoming==null)return;
            var b:Object=incoming.target,a:Object=actor(incoming.link);
            if(!alive(b)||!b.levitPoss||!known(incoming.link)||!matches(incoming.stamp)||now>incoming.until
               ||a==null||a.loc!==game.loc||a.hp<=0||a.sost>=3) {endIncoming("ended");return;}
            if(g.teleObj===b)g.dropTeleObj();
            b.levit=1;b.fracLevit=a.fraction;
            if(pause||game.world.allStat!=1||game.world.onPause)return;
            var input:Object=incoming.input;
            // Exactly the native UnitPlayer.actions acceleration/deadband.
            if(b.X<input.cx-15&&b.dx<input.speed)b.dx+=input.accel;
            if(b.X>input.cx+15&&b.dx>-input.speed)b.dx-=input.accel;
            if(b.Y-b.scY/2<input.cy-15&&b.dy<input.speed)b.dy+=input.accel;
            if(b.Y-b.scY/2>input.cy+15&&b.dy>-input.speed)b.dy-=input.accel;
         }catch(error:Error){fault(error);reset();}
      }
      private function after(e:Event):void {
         try {
            if(!ready())return;
            var raw:Object=game.gg.teleObj,rec:Object=raw==null?null:proxies[raw];
            if(outgoing!=null&&raw!==outgoing.raw)endOutgoing(true,true);
            if(rec==null)return;
            if(outgoing==null) {
               var link:TcpLink=peerFor(rec.owner);if(link==null){game.gg.dropTeleObj();return;}
               outgoing={raw:raw,id:String(rec.s.grip.id),token:++token,link:link,stamp:rec.s.grip,
                  startMana:manaBefore,accepted:false,until:getTimer()+2000};sendHeld();
            }
         }catch(error:Error){fault(error);}
      }
      private function endOutgoing(relay:Boolean,detectThrow:Boolean=false):void {
         var rec:Object=outgoing;outgoing=null;if(rec==null)return;
         if(relay&&rec.link.isOpen) {
            var p:Object=message("release",rec.id,rec.token);
            if(detectThrow&&beforeMotion!=null&&beforeMotion.raw===rec.raw&&beforeMotion.action===true) {
               var x:Number=rec.raw.dx-beforeMotion.dx,y:Number=rec.raw.dy-beforeMotion.dy;
               if(isFinite(x)&&isFinite(y)&&Math.abs(x)<=1000&&Math.abs(y)<=1000)p.kick={x:x,y:y};
            }
            rec.link.send(p);
         }
         if(game.gg!=null&&game.gg.teleObj===rec.raw)game.gg.dropTeleObj();
      }
      private function safeInput(p:Object):Boolean {
         if(p==null)return false;
         for each(var k:String in ["cx","cy","speed","accel","mana","startMana","mass","range","master"])
            if(p[k]===undefined||!isFinite(Number(p[k])))return false;
         return p.speed>=0&&p.speed<=1000&&p.accel>=0&&p.accel<=1000&&p.mass>=0&&p.range>0;
      }
      private function reply(link:TcpLink,p:Object,accept:Boolean,reason:String=""):void {
         var ack:Object=message("ack",String(p.id),int(p.token));ack.accept=accept;ack.reason=reason;link.send(ack);
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,link:TcpLink=e.target as TcpLink;if(p==null||p.type!="projectile-grip")return;
         try {
            if(!known(link)||!matches(p))return;
            if(p.op=="ack") {
               if(outgoing==null||outgoing.link!==link||p.id!=outgoing.id||p.token!=outgoing.token)return;
               if(p.accept===true)outgoing.accepted=true;else endOutgoing(false);return;
            }
            if(p.op=="release") {
               if(incoming==null||incoming.link!==link||p.id!=incoming.id||p.token!=incoming.token)return;
               var b:Object=incoming.target,kick:Object=p.kick;endIncoming("released");
               if(alive(b)&&kick!=null&&isFinite(Number(kick.x))&&isFinite(Number(kick.y))
                  &&Math.abs(kick.x)<=1000&&Math.abs(kick.y)<=1000){b.dx+=Number(kick.x);b.dy+=Number(kick.y);}
               return;
            }
            if(p.op!="hold"||!safeInput(p.input)||int(p.token)<=0||Number(p.token)!=int(p.token))return;
            if(int(p.token)<=int(retired[link])){reply(link,p,false,"retired");return;}
            if(incoming!=null&&(incoming.link!==link||incoming.id!=p.id||incoming.token!=p.token)){reply(link,p,false,"busy");return;}
            b=owned[String(p.id)];var a:Object=actor(link),input:Object=p.input;
            if(!alive(b)||!b.levitPoss||a==null||a.loc!==game.loc||a.hp<=0||a.sost>=3||input.mana<=0
               ||(incoming==null&&(b.liv<=5||input.startMana<200||b.massa>input.mass||b.levit>0||game.gg.teleObj===b))) {
               reject(link,p,"ineligible");return;
            }
            var x:Number=b.X-a.X,y:Number=b.Y-a.Y;
            if(x*x+y*y>input.range*(incoming==null?1:1.2)
               ||(incoming==null&&(input.master==0||!game.loc.portOn)&&!game.loc.isLine(a.X,a.Y-a.scY*.75,b.X,b.Y-b.scY/2))) {
               reject(link,p,"range");return;
            }
            if(incoming==null) {
               incoming={id:String(p.id),token:int(p.token),target:b,link:link,stamp:p};
               b.levit=1;b.fracLevit=a.fraction;b.stay=false;reply(link,p,true);
            }
            incoming.input=input;incoming.style=validateAura(p.aura);incoming.until=getTimer()+1500;
         }catch(error:Error){fault(error);}
      }
      private function reject(link:TcpLink,p:Object,reason:String):void {
         retired[link]=Math.max(int(retired[link]),int(p.token));reply(link,p,false,reason);
         if(incoming!=null)endIncoming(reason);
      }
      private static function validateAura(s:Object):Object {
         if(s==null||!(s.glow is Array)||!(s.ct is Array)||s.ct.length!=8||s.glow.length>4)return null;
         var glows:Array=[],ct:Array=[],i:int;
         for each(var a:* in s.glow) {
            if(!(a is Array)||a.length!=8)return null;
            for(i=0;i<6;i++)if(!isFinite(Number(a[i])))return null;
            glows.push([uint(a[0])&0xffffff,Math.max(0,Math.min(1,Number(a[1]))),
               Math.max(0,Math.min(64,Number(a[2]))),Math.max(0,Math.min(64,Number(a[3]))),
               Math.max(0,Math.min(16,Number(a[4]))),Math.max(1,Math.min(3,int(a[5]))),a[6]===true,a[7]===true]);
         }
         for(i=0;i<8;i++) {
            if(!isFinite(Number(s.ct[i])))return null;
            ct.push(i<4?Math.max(0,Math.min(4,Number(s.ct[i]))):Math.max(-255,Math.min(255,Number(s.ct[i]))));
         }
         return {glow:glows,ct:ct};
      }
      private function endIncoming(reason:String):void {
         var rec:Object=incoming;incoming=null;if(rec==null)return;
         retired[rec.link]=Math.max(int(retired[rec.link]),int(rec.token));
         if(rec.target.levit==1)rec.target.levit=0;
         aura.object(rec.target,null);aura.tick(game.loc,game.gg==null?null:game.gg.teleObj,false);
         if(rec.link.isOpen)reply(rec.link,rec,false,reason);
      }
      private function presentAura(e:Event):void {
         try {
            if(incoming!=null)aura.object(incoming.target,incoming.style);
            aura.tick(game.loc,game.gg==null?null:game.gg.teleObj,false);
         }catch(error:Error){fault(error);}
      }
      public function reset():void {
         endOutgoing(true);endIncoming("reset");
         var list:Array=[];for each(var rec:Object in proxies)list.push(rec);
         for each(rec in list)forget(rec);
         owned={};ids=new Dictionary(true);beforeMotion=null;aura.reset();hasState=false;
      }
      private function fault(error:Error):void {if(errors++<4)Log.d("RConnectProjectileGrip: failed "+error+" "+error.getStackTrace());}
   }
}
