package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.GameBridge;
   import rconnect.game.TelekinesisVisuals;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** The grabbed player owns consent, input and native collision simulation.
    * The caster sends intent, never coordinates for the other player's body. */
   public class PeerGrip {
      private var mod:RConnectMod,timer:Timer=new Timer(50),links:Dictionary=new Dictionary(),retired:Dictionary=new Dictionary();
      private var outgoing:Object,incoming:Object,keys:Object,beforeMotion:Object;
      private var throwDamage:PeerThrowDamage;
      private var aura:TelekinesisVisuals=new TelekinesisVisuals();
      private var serial:int=0,errors:int=0,lastFrame:int=getTimer(),wasPaused:Boolean=false,manaBefore:Number=0;
      private static const MOVEMENT:Array=["keyLeft","keyRight","keyBeUp","keySit","keyJump","keyDash","keyDubLeft","keyDubRight"];
      public function PeerGrip(m:RConnectMod) {
         mod=m;throwDamage=new PeerThrowDamage(m);m.stage.addEventListener(Event.ENTER_FRAME,before,false,98000);
         m.stage.addEventListener(Event.ENTER_FRAME,after,false,-8500);
         m.stage.addEventListener(Event.RENDER,presentAura,false,-11000);
         timer.addEventListener(TimerEvent.TIMER,sendHeld);timer.start();
      }
      private function get game():Object {return mod.game;}
      private function get session():Object {return mod.session;}
      private function get rooms():Object {return session.rooms;}
      public function get allowed():Boolean {return mod.config.getValue("allowPeerGrip")=="1";}
      public function get struggle():Boolean {return mod.config.getValue("peerGripStruggle")!="0";}
      public function get heldByTeammate():Boolean {return incoming!=null;}
      public function get throwDamageAllowed():Boolean {return throwDamage.allowed;}
      public function get throwDamageActive():Boolean {return throwDamage.active;}
      public function setThrowDamageAllowed(value:Boolean):void {throwDamage.setAllowed(value);}
      public function setPreferences(allow:Boolean,escape:Boolean):void {
         mod.config.setValue("allowPeerGrip",allow?"1":"0");mod.config.setValue("peerGripStruggle",escape?"1":"0");mod.config.save();
         if(!allow)endIncoming("consent");
      }
      public function policy():Object {
         var g:Object=game.gg;return {allow:allowed&&g!=null&&g.sost==1&&!game.isPlayerDead(),mass:g==null?1:Number(g.massa)};
      }
      public function locallyHeld(u:Object):Boolean {return game.gg!=null&&game.gg.teleObj===u&&peerFor(u)!=null;}
      public function prepareGhost(u:Object,s:Object):void {
         if(u==null)return;
         u.beforeNativeStep=beforeGhostStep;
         u.levitPoss=s!=null&&s.allow===true;u.levit_max=0;
         if(s!=null&&isFinite(Number(s.mass))&&Number(s.mass)>0)u.massa=Number(s.mass);
         if(!u.levitPoss&&game.gg!=null&&game.gg.teleObj===u)game.gg.dropTeleObj();
      }
      private function connected():Boolean {return session.mode==Session.CONNECTED&&session.link!=null&&session.link.isOpen||session.mode==Session.HOSTING&&session.peers.length>0;}
      private function ready():Boolean {return connected()&&rooms.ready&&!rooms.busy&&!game.roomHold&&game.gg!=null&&game.loc!=null&&!game.isTransitioning();}
      private function peerFor(u:Object):TcpLink {
         if(u==null)return null;
         if(session.mode==Session.CONNECTED)return game.getRemoteGhost(0)===u?session.link:null;
         if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)if(game.getRemoteGhost(p.id)===u)return p.link;
         return null;
      }
      private function actor(link:TcpLink):Object {return game.getRemoteGhost(session.mode==Session.CONNECTED?0:link.id);}
      private function known(link:TcpLink):Boolean {
         if(session.mode==Session.CONNECTED)return link===session.link;
         if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)if(p.link===link)return true;
         return false;
      }
      private function watch():void {
         for(var old:Object in links)if(!old.isOpen){old.removeEventListener(TcpLink.MESSAGE,receive);delete links[old];delete retired[old];}
         var list:Array=[];if(session.mode==Session.CONNECTED)list.push(session.link);
         else if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)list.push(p.link);
         for each(var l:TcpLink in list)if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function stamp(op:String,token:int):Object {return rooms.stamp({type:"peer-grip",op:op,token:token});}
      private function matches(p:Object):Boolean {return ready()&&String(p.roomKey)==game.roomKey()&&int(p.roomEpoch)==rooms.epoch&&int(p.roomTerm)==rooms.term;}
      private function sendHeld(e:TimerEvent=null):void {
         try {
            if(outgoing==null||!ready()||game.gg.teleObj!==outgoing.raw)return;
            var g:Object=game.gg,p:Object=stamp("hold",outgoing.token);
            p.input={cx:g.celX,cy:g.celY,speed:g.teleSpeed,accel:g.teleAccel,mana:g.mana,startMana:outgoing.startMana,
               mass:g.pers.maxTeleMassa,range:g.pers.teleDist,master:g.pers.telemaster};
            p.aura=outgoing.style;outgoing.link.send(p);
         }catch(e:Error){fault(e);}
      }
      private function paused():Boolean {return session.pause!=null&&session.pause.paused;}
      private function beforeGhostStep(u:Object):void {
         try {
            if(outgoing==null||outgoing.raw!==u||game.gg==null||game.gg.teleObj===u||beforeMotion==null||beforeMotion.raw!==u)return;
            // Native gg.step has just thrown; ghost.step would consume 45 and
            // simulate an extra collision before the owner's body receives it.
            if(int(u.t_throw)==45) {
               var prior:Object=beforeMotion;endOutgoing(true,true);
               u.dx=prior.dx;u.dy=prior.dy;u.t_throw=0;
            }
         }catch(err:Error){fault(err);}
      }
      private function before(e:Event):void {
         try {
            restoreKeys();watch();var now:int=getTimer(),pause:Boolean=paused();
            if(incoming!=null&&(pause||wasPaused))incoming.until+=Math.max(0,now-lastFrame);
            lastFrame=now;wasPaused=pause;
            if(!ready()){reset();return;}
            throwDamage.beforeStep();
            var g:Object=game.gg;manaBefore=g.mana;
            if(outgoing!=null&&(game.isPlayerDead()||!outgoing.link.isOpen||peerFor(outgoing.raw)!==outgoing.link
               ||outgoing.raw.loc!==game.loc||!outgoing.raw.in_chain||!outgoing.raw.levitPoss||(!outgoing.accepted&&now>outgoing.until)
               ||(!pause&&!session.pause.requested&&(CoopPause.nativeReasons(game.world)!=0||game.world.onPause))))endOutgoing(true);
            var raw:Object=g.teleObj;beforeMotion=peerFor(raw)==null?null:{raw:raw,dx:raw.dx,dy:raw.dy,t:raw.t_throw};
            if(incoming==null)return;
            if(!allowed||game.isPlayerDead()||incoming.player!==g||!incoming.link.isOpen||!matches(incoming.stamp)||now>incoming.until
               ||actor(incoming.link)==null||(!pause&&!session.pause.requested&&(CoopPause.nativeReasons(game.world)!=0||game.world.onPause))) {endIncoming("ended");return;}
            if(pause||game.world.allStat!=1||game.world.onPause)return;
            var ctr:Object=game.world.ctr;
            if(struggle&&(ctr.keyLeft||ctr.keyRight||ctr.keyBeUp||ctr.keySit)){endIncoming("struggle");return;}
            keys={ctr:ctr,values:{}};for each(var k:String in MOVEMENT){keys.values[k]=ctr[k];ctr[k]=false;}
            var input:Object=incoming.input;g.levit=2;g.stay=false;g.isLaz=0;g.isFly=false;g.walk=0;
            // Native UnitPlayer.forces/run still handles damping and terrain.
            if(g.X<input.cx-15&&g.dx<input.speed)g.dx+=input.accel;
            if(g.X>input.cx+15&&g.dx>-input.speed)g.dx-=input.accel;
            if(g.Y-g.scY/2<input.cy-15&&g.dy<input.speed)g.dy+=input.accel;
            if(g.Y-g.scY/2>input.cy+15&&g.dy>-input.speed)g.dy-=input.accel;
         }catch(err:Error){fault(err);reset();}
      }
      private function after(e:Event):void {
         try {
            restoreKeys();throwDamage.afterStep();if(!ready()){reset();return;}
            presentAura();
            var g:Object=game.gg,raw:Object=g.teleObj,link:TcpLink=peerFor(raw);
            if(outgoing!=null&&raw!==outgoing.raw)endOutgoing(true,true);
            if(link==null||raw==null)return;
            if(!raw.levitPoss||incoming!=null||game.isPlayerDead()){g.dropTeleObj();return;}
            if(outgoing==null){outgoing={raw:raw,link:link,token:++serial,startMana:manaBefore,accepted:false,
               style:TelekinesisVisuals.captureObject(raw),until:getTimer()+2000};sendHeld();}
         }catch(err:Error){throwDamage.reset();fault(err);}
      }
      private function presentAura(e:Event=null):void {
         if(incoming==null)return;
         aura.object(incoming.player,incoming.aura);
         aura.tick(game.loc,null,false);
      }
      private function safe(p:Object):Boolean {
         if(p==null)return false;for each(var k:String in ["cx","cy","speed","accel","mana","startMana","mass","range","master"])
            if(p[k]===undefined||!isFinite(Number(p[k])))return false;
         return p.speed>=0&&p.speed<=1000&&p.accel>=0&&p.accel<=1000&&p.mass>=0&&p.range>0;
      }
      private function reply(l:TcpLink,p:Object,ok:Boolean,why:String=""):void {if(!l.isOpen)return;var m:Object=stamp("ack",int(p.token));m.accept=ok;m.reason=why;l.send(m);}
      private function retire(l:TcpLink,p:Object):void {retired[l]=Math.max(int(retired[l]),int(p.token));}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,l:TcpLink=e.target as TcpLink;if(p==null||p.type!="peer-grip"||!known(l))return;
         try {
            if(p.op=="ack") {
               if(outgoing==null||outgoing.link!==l||outgoing.token!=p.token||!matches(p))return;
               if(p.accept===true)outgoing.accepted=true;else endOutgoing(false);return;
            }
            if(!matches(p))return;
            if(p.op=="release") {
               if(incoming==null||incoming.link!==l||incoming.token!=p.token)return;
               var g:Object=incoming.player,kick:Object=p.kick;endIncoming("released");
               if(kick!=null&&isFinite(Number(kick.x))&&isFinite(Number(kick.y))&&Math.abs(kick.x)<=1000&&Math.abs(kick.y)<=1000){
                  g.dx+=Number(kick.x);g.dy+=Number(kick.y);g.t_throw=45;throwDamage.arm(g,l,p);
               }
               return;
            }
            if(p.op!="hold"||!safe(p.input)||int(p.token)<=0||Number(p.token)!=int(p.token))return;
            g=game.gg;var source:Object=actor(l),input:Object=p.input;
            var eligible:Boolean=allowed&&!game.isPlayerDead()&&g.sost==1&&g.hp>0&&source!=null&&source.loc===game.loc&&outgoing==null
               &&int(p.token)>int(retired[l])&&input.mana>0;
            if(incoming==null)eligible=eligible&&input.startMana>=200&&g.massa<=input.mass&&g.levit==0;
            else eligible=eligible&&incoming.link===l&&incoming.token==p.token&&incoming.player===g;
            if(eligible) {
               var dx:Number=g.X-source.X,dy:Number=g.Y-source.Y;
               eligible=dx*dx+dy*dy<=input.range*(incoming==null?1:1.2)
                  &&(incoming!=null||input.master!=0&&game.loc.portOn||game.loc.isLine(source.X,source.Y-source.scY*.75,g.X,g.Y-g.scY/2));
            }
            if(!eligible){retire(l,p);reply(l,p,false,"ineligible");if(incoming!=null&&incoming.token==p.token)endIncoming("ineligible");return;}
            if(incoming==null){throwDamage.reset();incoming={player:g,link:l,token:p.token,stamp:p};g.levit=2;g.stay=false;reply(l,p,true);}
            incoming.input=input;incoming.aura=TelekinesisVisuals.validated(p.aura);incoming.until=getTimer()+1500;presentAura();
         }catch(err:Error){fault(err);}
      }
      private function endOutgoing(relay:Boolean,detectThrow:Boolean=false):void {
         var rec:Object=outgoing;outgoing=null;if(rec==null)return;
         if(relay&&rec.link.isOpen) {
            var p:Object=stamp("release",rec.token);
            if(detectThrow&&beforeMotion!=null&&beforeMotion.raw===rec.raw&&int(rec.raw.t_throw)==45) {
               var dx:Number=Number(rec.raw.dx)-Number(beforeMotion.dx),dy:Number=Number(rec.raw.dy)-Number(beforeMotion.dy);
               if(beforeMotion.t<45||Math.abs(dx)+Math.abs(dy)>.01)p.kick={x:dx,y:dy};
            }rec.link.send(p);
         }
         if(game.gg!=null&&game.gg.teleObj===rec.raw)game.gg.dropTeleObj();
         if(game.loc!=null&&game.loc.celObj===rec.raw)game.loc.celObj=null;
         rec.raw.onCursor=0;
      }
      private function endIncoming(reason:String):void {
         var rec:Object=incoming;incoming=null;if(rec==null)return;
         aura.reset();
         restoreKeys();retire(rec.link,rec);if(rec.player!=null&&rec.player.levit==2)rec.player.levit=0;
         reply(rec.link,rec,false,reason);
      }
      private function restoreKeys():void {if(keys==null)return;var saved:Object=keys;keys=null;for(var k:String in saved.values)saved.ctr[k]=saved.values[k];}
      public function reset():void {throwDamage.reset();endIncoming("reset");endOutgoing(true);restoreKeys();beforeMotion=null;
         if(game.gg!=null&&peerFor(game.gg.teleObj)!=null)game.gg.dropTeleObj();}
      private function fault(e:Error):void {if(errors++<4)Log.d("RConnectPeerGrip: failed "+e.getStackTrace());}
   }
}
