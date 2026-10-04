package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native client grab/mana, one authoritative enemy simulation. The lease
    * expires on lost input; room handoffs release it before capturing state. */
   public class EnemyGrip {
      private var mod:Object;
      private var timer:Timer=new Timer(50);
      private var links:Dictionary=new Dictionary();
      private var retired:Dictionary=new Dictionary();
      private var local:Object,lease:Object,beforeMotion:Object;
      private var serial:int=0,errors:int=0;
      private var lastFrame:int=getTimer(),wasPaused:Boolean=false;
      private var manaBefore:Number=0;
      public function EnemyGrip(m:Object) {
         mod=m;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-8000);
         timer.addEventListener(TimerEvent.TIMER,sendHeld);timer.start();
      }
      private function get game():Object {return mod.game;}
      private function get session():Object {return mod.session;}
      private function get rooms():Object {return session.rooms;}
      private function validRoom():Boolean {
         return rooms.ready && !rooms.busy && !game.roomHold && game.gg!=null && game.loc!=null && !game.isTransitioning();
      }
      private function sameStamp(p:Object):Boolean {
         return validRoom() && String(p.roomKey)==game.roomKey() && int(p.roomEpoch)==rooms.epoch && int(p.roomTerm)==rooms.term;
      }
      private function connected():Boolean {
         return session.mode==Session.CONNECTED && session.link!=null && session.link.isOpen
            || session.mode==Session.HOSTING && session.peers.length>0;
      }
      private function watch(link:TcpLink):void {
         if(link==null || links[link])return;
         links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);
      }
      private function watchPeers():void {
         for(var old:Object in links)if(!old.isOpen){old.removeEventListener(TcpLink.MESSAGE,receive);delete links[old];delete retired[old];}
         if(session.mode==Session.HOSTING)for each(var peer:Object in session.peers)watch(peer.link);
         else if(session.mode==Session.CONNECTED)watch(session.link);
      }
      private function input():Object {
         var g:Object=game.gg,p:Object=g.pers;
         return {cx:g.celX,cy:g.celY,speed:g.teleSpeed,accel:g.teleAccel,mana:g.mana,startMana:local.startMana,
            mass:p.maxTeleMassa,range:p.teleDist,mult:p.unitLevitMult,master:p.telemaster,fraction:g.fraction};
      }
      private function safeInput(p:Object):Boolean {
         if(p==null)return false;
         for each(var k:String in ["cx","cy","speed","accel","mana","startMana","mass","range","mult","master","fraction"])
            if(p[k]===undefined || !isFinite(Number(p[k])))return false;
         return p.speed>=0 && p.speed<=1000 && p.accel>=0 && p.accel<=1000 && p.mass>=0 && p.range>0 && p.mult>=0;
      }
      private function message(op:String,rec:Object):Object {
         return {type:"unit-grip",op:op,k:rec.k,token:rec.token,
            roomKey:rec.roomKey,roomEpoch:rec.roomEpoch,roomTerm:rec.roomTerm};
      }
      private function sendHeld(e:TimerEvent=null):void {
         try {
            if(local==null || !validRoom() || rooms.authority || session.mode!=Session.CONNECTED)return;
            if(game.gg.teleObj!==local.raw)return;
            var p:Object=message("hold",local);p.input=input();session.link.send(p);
         } catch(error:Error){fault(error);}
      }
      private function before(e:Event):void {
         try {
            var now:int=getTimer(),pause:Object=GameBridge.probe(session,"pause");
            var paused:Boolean=pause!=null && GameBridge.probe(pause,"paused")==true;
            if(lease!=null && (paused || wasPaused))lease.until+=Math.max(0,now-lastFrame);
            lastFrame=now;wasPaused=paused;
            watchPeers();
            if(!connected() || !validRoom()){reset();return;}
            manaBefore=Number(game.gg.mana);
            if(local!=null && (game.gg.sost>=3 || game.gg.hp<=0 || !enemy(local.target)
               || (!local.accepted && now>local.until)
               // allStat can still be 2 for one frame after native Pip closes.
               // Only an actual local overlay/pause should release the caster.
               || ((!paused && GameBridge.probe(pause,"requested")!=true) && (CoopPause.nativeReasons(game.world)!=0 || game.world.onPause)))) {
               if(game.gg.teleObj===local.raw)game.gg.dropTeleObj();
               endLocal(true);
            }
            var raw:Object=game.gg.teleObj;
            beforeMotion=game.grabBody(raw)==null?null:{raw:raw,dx:raw.dx,dy:raw.dy,t:raw.t_throw};
            if(lease==null)return;
            var u:Object=lease.target,actor:Object=game.getRemoteGhost(lease.link.id);
            if(!rooms.authority || !lease.link.isOpen || !sameStamp(lease.stamp) || !enemy(u)
               || !u.levitPoss || actor==null || actor.sost>=3 || actor.hp<=0 || getTimer()>lease.until) {endLease("ended");return;}
            if(u.levit_max>0 && u.levit_r>u.levit_max*Number(lease.input.mult)) {
               u.levitPoss=false;endLease("exhausted");return;
            }
            if(game.gg.teleObj===u)game.gg.dropTeleObj(); // Earlier accepted holder wins.
            u.levit=1;u.fracLevit=int(lease.input.fraction);u.stay=false;
            if(paused || game.world.allStat!=1 || game.world.onPause)return;
            var p:Object=lease.input;
            // The same acceleration/deadband used in native UnitPlayer.actions.
            if(u.X<p.cx-15 && u.dx<p.speed)u.dx+=p.accel;
            if(u.X>p.cx+15 && u.dx>-p.speed)u.dx-=p.accel;
            if(u.Y-u.scY/2<p.cy-15 && u.dy<p.speed)u.dy+=p.accel;
            if(u.Y-u.scY/2>p.cy+15 && u.dy>-p.speed)u.dy-=p.accel;
         } catch(error:Error){fault(error);reset();}
      }
      private function after(e:Event):void {
         try {
            if(!connected() || !validRoom() || rooms.authority){if(local!=null)endLocal(false);return;}
            var raw:Object=game.gg.teleObj,u:Object=game.grabBody(raw),key:String=u==null?"":game.unitKey(u);
            if(local!=null && raw!==local.raw)endLocal(true,true);
            if(raw==null || key=="" || !enemy(u))return;
            if(local==null){local=rooms.stamp({raw:raw,target:u,k:key,token:++serial,startMana:manaBefore,
               accepted:false,until:getTimer()+2000});sendHeld();}
            preserveLocal(u);
         } catch(error:Error){fault(error);}
      }
      private function enemy(u:Object):Boolean {
         return game.grabBody(u)===u && u!=null && u.loc===game.loc && u.in_chain && u.fraction<100 && u.sost<3;
      }
      private function endLocal(relay:Boolean,detectThrow:Boolean=false):void {
         var rec:Object=local;local=null;if(rec==null)return;
         if(relay && session.link!=null && session.link.isOpen) {
            var p:Object=message("release",rec);
            if(detectThrow && beforeMotion!=null && beforeMotion.raw===rec.raw && int(rec.raw.t_throw)==45) {
               var dx:Number=Number(rec.raw.dx)-Number(beforeMotion.dx),dy:Number=Number(rec.raw.dy)-Number(beforeMotion.dy);
               if(beforeMotion.t<45 || Math.abs(dx)+Math.abs(dy)>0.01){p.kick={x:dx,y:dy};}
            }
            session.link.send(p);
         }
      }
      private function reply(link:TcpLink,p:Object,accept:Boolean,reason:String=""):void {
         var ack:Object={type:"unit-grip",op:"ack",k:p.k,token:p.token,accept:accept,reason:reason};
         link.send(rooms.stamp(ack));
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,link:TcpLink=e.target as TcpLink;if(p==null || p.type!="unit-grip")return;
         try {
            if(session.mode==Session.CONNECTED) {
               if(link!==session.link || p.op!="ack" || !rooms.accepts(p) || local==null || p.token!=local.token || p.k!=local.k)return;
               if(p.accept!==true){if(game.gg.teleObj===local.raw)game.gg.dropTeleObj();local=null;}
               else local.accepted=true;
               return;
            }
            if(session.mode!=Session.HOSTING || !sameStamp(p) || !rooms.authority)return;
            var known:Boolean=false;for each(var peer:Object in session.peers)if(peer.link===link)known=true;
            if(!known)return;
            if(p.op=="release") {
               if(lease==null || lease.link!==link || p.k!=lease.k || p.token!=lease.token)return;
               var released:Object=lease.target,kick:Object=p.kick;endLease("released");
               if(kick!=null && isFinite(Number(kick.x)) && isFinite(Number(kick.y)) && Math.abs(kick.x)<=1000 && Math.abs(kick.y)<=1000) {
                  released.dx+=Number(kick.x);released.dy+=Number(kick.y);released.t_throw=45;
               }
               return;
            }
            if(p.op!="hold" || !safeInput(p.input) || int(p.token)<=0 || Number(p.token)!=int(p.token))return;
            if(int(p.token)<=int(retired[link])){reply(link,p,false,"retired");return;}
            if(lease!=null && (lease.link!==link || lease.k!=p.k || lease.token!=p.token)){reply(link,p,false,"busy");return;}
            var u:Object=game.unitForKey(String(p.k)),actor:Object=game.getRemoteGhost(link.id);
            if(!enemy(u) || !u.levitPoss || actor==null || actor.loc!==game.loc || actor.sost>=3 || actor.hp<=0
               || p.input.mana<=0 || (lease==null && (p.input.startMana<200 || u.massa>p.input.mass || u.levit>0 || game.gg.teleObj===u))) {
               retire(link,p);reply(link,p,false,"ineligible");if(lease!=null)endLease("ineligible");return;
            }
            var x:Number=u.X-actor.X,y:Number=u.Y-actor.Y;
            if(x*x+y*y>p.input.range*(lease==null?1:1.2)
               || (lease==null && (p.input.master==0 || !game.loc.portOn) && !game.loc.isLine(actor.X,actor.Y-actor.scY*.75,u.X,u.Y-u.scY/2))) {
               retire(link,p);reply(link,p,false,"range");if(lease!=null)endLease("range");return;
            }
            if(lease==null) {
               lease={target:u,link:link,k:p.k,token:p.token,stamp:p};
               u.alarma(actor.X,actor.Y);u.levit=1;u.fracLevit=int(p.input.fraction);u.stay=false;
               reply(link,p,true);
            }
            lease.input=p.input;lease.until=getTimer()+1500;
         } catch(error:Error){fault(error);}
      }
      public function remotelyHeld(u:Object):Boolean {return lease!=null && lease.target===u;}
      public function preserveLocal(u:Object):void {
         var raw:Object=game.gg==null?null:game.gg.teleObj;
         if(raw!=null && game.grabBody(raw)===u && u.levitPoss && enemy(u)) {
            u.levit=1;raw.levit=1;
         }
      }
      private function retire(link:TcpLink,rec:Object):void {retired[link]=Math.max(int(retired[link]),int(rec.token));}
      private function endLease(reason:String):void {
         var rec:Object=lease;lease=null;if(rec==null)return;
         retire(rec.link,rec);
         if(rec.target!=null && rec.target.levit==1)rec.target.levit=0;
         if(rec.link.isOpen)reply(rec.link,rec,false,reason);
      }
      /** Room ownership may change while the native caster stays in place. */
      public function releaseForHandoff():void {
         reset();
         if(game.gg!=null && game.grabBody(game.gg.teleObj)!=null)game.gg.dropTeleObj();
      }
      /** Clear network grips, including when called each offline frame. */
      public function reset():void {
         endLease("reset");
         if(local!=null){if(game.gg!=null && game.gg.teleObj===local.raw)game.gg.dropTeleObj();endLocal(true);}
         beforeMotion=null;
      }
      private function fault(error:Error):void {if(errors++<4)Log.d("RConnectGrip: failed "+error+" "+error.getStackTrace());}
   }
}
