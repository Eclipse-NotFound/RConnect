package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.NativeHit;
   import rconnect.game.PeerHitUnit;
   import rconnect.game.HitFeedback;
   import rconnect.game.FriendlyOptics;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** One host policy, local native hit detection, victim-owned mitigation.
    * No second AI or projectile simulation is created for friendly fire. */
   public class FriendlyFire {
      private var mod:RConnectMod,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var transport:Object,mode:String="",known:Boolean=false,policy:Boolean=false;
      private var revision:int=0,serial:int=0,nextState:int=0,errors:int=0;
      private var incoming:NativeHit=new NativeHit();
      private var optics:FriendlyOptics;
      public function FriendlyFire(m:RConnectMod) {
         mod=m;
         optics=new FriendlyOptics(m,sendBlind);
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,97000);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function get session():Object {return mod.session;}
      private function get game():Object {return mod.game;}
      public function get canChangePolicy():Boolean {
         return session.mode==Session.OFFLINE || session.mode==Session.HOSTING;
      }
      public function get enabled():Boolean {
         return canChangePolicy?mod.config.getValue("friendlyFire")=="1":known&&policy;
      }
      public function setEnabled(value:Boolean):Boolean {
         if(!canChangePolicy)return false;
         sync();
         mod.config.setValue("friendlyFire",value?"1":"0");mod.config.save();
         policy=value;revision++;nextState=0;
         refreshBodies();broadcastPolicy();return true;
      }
      private function host():Boolean {return session.mode==Session.HOSTING;}
      private function actor(l:TcpLink):Object {return game.getRemoteGhost(host()?l.id:0);}
      private function connected(l:TcpLink):Boolean {
         if(l==null || !l.isOpen)return false;
         if(session.mode==Session.CONNECTED)return l===session.link;
         if(host())for each(var p:Object in session.peers)if(p.link===l)return true;
         return false;
      }
      private function ready(l:TcpLink):Boolean {
         var body:Object=actor(l);
         return enabled && connected(l) && session.rooms.ready && !session.rooms.busy
            && !game.roomHold && !game.coopPaused && game.gg!=null && game.loc!=null
            && !game.isTransitioning() && !game.isPlayerDead() && body!=null
            && body.loc===game.loc && body.sost<3 && body.hp>0 && !body.disabled
            && game.loc.units.indexOf(body)>=0;
      }
      private function clearBody(r:Object):void {
         if(r.proxy!=null)r.proxy.dispose();r.proxy=null;r.body=null;
      }
      public function reset():void {
         if(optics!=null)optics.reset();
         for(var key:Object in links) {
            clearBody(links[key]);TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);
         }
         links=new Dictionary();known=false;policy=false;serial=0;revision=0;nextState=0;
         transport=null;mode="";
      }
      private function watch(l:TcpLink):void {
         if(l==null || !l.isOpen || links[l]!=null)return;
         links[l]={last:0,resultLast:0,body:null,proxy:null,pending:{},feedback:new HitFeedback()};l.addEventListener(TcpLink.MESSAGE,receive);nextState=0;
      }
      private function sync():void {
         var current:Object=host()?session.server:session.link;
         if(mode!=session.mode || transport!==current) {
            reset();mode=session.mode;transport=current;
            if(host()){policy=enabled;revision=1;known=true;}
         }
         for(var key:Object in links)if(!connected(key as TcpLink)) {
            clearBody(links[key]);TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);delete links[key];
         }
         if(host())for each(var p:Object in session.peers)watch(p.link as TcpLink);
         else if(session.mode==Session.CONNECTED)watch(session.link);
      }
      private function broadcastPolicy():void {
         if(!host() || getTimer()<nextState)return;
         nextState=getTimer()+500;
         for(var key:Object in links)TcpLink(key).send({type:"friendly-fire",op:"policy",revision:revision,enabled:enabled});
      }
      private function refreshBodies():void {
         for(var key:Object in links) {
            var l:TcpLink=key as TcpLink,r:Object=links[key],body:Object=actor(l);
            if(!ready(l)){clearBody(r);continue;}
            if(r.body!==body || r.proxy==null || game.loc.units.indexOf(r.proxy)<0) {
               clearBody(r);r.body=body;r.proxy=makeReceiver(l);
               game.loc.units.push(r.proxy);
            }
            r.proxy.sync();
         }
      }
      private function makeReceiver(l:TcpLink):PeerHitUnit {
         return new PeerHitUnit(actor(l),function():Boolean{return ready(l);},
            function(hit:Object):void{sendHit(l,hit);});
      }
      private function sendHit(l:TcpLink,hit:Object):void {
         if(!ready(l))return;
         var p:Object=session.rooms.stamp({type:"friendly-fire",op:"hit",revision:revision,seq:++serial,hit:hit});
         links[l].pending[p.seq]={packet:p,at:getTimer()};
         l.send(p);
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,l:TcpLink=e.target as TcpLink;
         if(p==null || p.type!="friendly-fire" || !connected(l) || links[l]==null)return;
         try {
            if(p.op=="policy") {
               if(host() || session.mode!=Session.CONNECTED || l!==session.link
                  || !isFinite(Number(p.revision)) || int(p.revision)<revision || int(p.revision)<1)return;
               revision=int(p.revision);policy=p.enabled===true;known=true;refreshBodies();return;
            }
            if(p.op=="result") {showResult(l,p);return;}
            if(p.op=="mine-result") {showMineResult(l,p);return;}
            if((p.op!="hit"&&p.op!="blind") || !ready(l) || int(p.revision)!=revision
               || String(p.roomKey)!=game.roomKey() || int(p.roomEpoch)!=session.rooms.epoch
               || int(p.roomTerm)!=session.rooms.term || !isFinite(Number(p.seq)) || int(p.seq)<=int(links[l].last))return;
            if(p.op=="blind") {
               if(["laser","pointer"].indexOf(String(p.source))<0||!isFinite(Number(p.duration))||Number(p.duration)<=0||Number(p.duration)>60)return;
               links[l].last=int(p.seq);
               var effect:Object=null;
               for each(var active:Object in game.gg.effects)if(active.id=="blindness"&&!active.vse){effect=active;break;}
               var fresh:Boolean=effect==null;
               if(fresh)effect=game.gg.addEffect("blindness",0,0,false);
               if(effect!=null)effect.t=fresh?Math.ceil(Number(p.duration)*30):Math.max(Number(effect.t),Math.ceil(Number(p.duration)*30));
               return;
            }
            var hit:Object=p.hit;
            if(hit==null || !isFinite(Number(hit.amount)) || Number(hit.amount)<=0 || Number(hit.amount)>1e8
               || !isFinite(Number(hit.kind)) || int(hit.kind)<0 || int(hit.kind)>100 || hit.bullet==null)return;
            links[l].last=int(p.seq);
            var result:Object=incoming.settle(game.gg,hit,mod.main);
            l.send(session.rooms.stamp({type:"friendly-fire",op:"result",revision:revision,seq:p.seq,result:result}));
         }catch(err:Error){fault(err);}
      }
      private function before(e:Event):void {
         try {sync();refreshBodies();}catch(err:Error){fault(err);}
      }
      private function tick(e:TimerEvent):void {
         try {sync();broadcastPolicy();refreshBodies();
            for each(var r:Object in links)for(var key:String in r.pending)
               if(getTimer()-int(r.pending[key].at)>5000)delete r.pending[key];
         }catch(err:Error){fault(err);}
      }
      private function showResult(l:TcpLink,p:Object):void {
         var r:Object=links[l],pending:Object=r.pending[int(p.seq)];
         if(pending==null||!enabled||int(p.revision)!=revision||String(p.roomKey)!=game.roomKey()
            ||int(p.roomEpoch)!=session.rooms.epoch||int(p.roomTerm)!=session.rooms.term)return;
         var result:Object=p.result;
         if(result==null||!isFinite(Number(result.hp))||Number(result.hp)<0||Number(result.hp)>1e8
            ||!isFinite(Number(result.shield))||Number(result.shield)<0||Number(result.shield)>1e8)return;
         delete r.pending[int(p.seq)];
         var body:Object=actor(l);if(body==null||body.loc!==game.loc)return;
         var bullet:Object=pending.packet.hit.bullet;
         var style:Object={frame:int(result.frame)==3?3:2,scale:Number(result.scale)>=1.5?1.6:1,
            x:bullet.X,y:bullet.Y};
         r.feedback.show(body,Number(result.hp),Number(result.shield),style,true);
      }
      public function isTeammate(body:Object):Boolean {
         for(var key:Object in links)if(body===actor(key as TcpLink)&&ready(key as TcpLink))return true;
         return false;
      }
      public function playerId(body:Object):int {
         if(body===game.gg)return int(session.myId);
         for(var key:Object in links)if(body===actor(key as TcpLink))return host()?int(TcpLink(key).id):0;
         return -1;
      }
      public function mineReceiver(body:Object,placer:int,mineKey:String,mine:Object):PeerHitUnit {
         if(!enabled||playerId(body)<0||playerId(body)==placer)return null;
         return new PeerHitUnit(body,function():Boolean {
            return enabled&&session.rooms.ready&&!session.rooms.busy&&!game.roomHold&&!game.coopPaused
               &&game.loc===body.loc&&body.sost<3&&!body.disabled;
         },function(hit:Object):void {
            if(body===game.gg) {
               var result:Object=incoming.settle(game.gg,hit,mod.main);
               for(var key:Object in links) {
                  var l:TcpLink=key as TcpLink;if((host()?int(l.id):0)!=placer)continue;
                  l.send(session.rooms.stamp({type:"friendly-fire",op:"mine-result",revision:revision,
                     seq:++serial,key:mineKey,result:result,point:hit.bullet}));
               }
            }else for(key in links)if(body===actor(key as TcpLink))sendHit(key as TcpLink,hit);
         },function(bullet:Object):Boolean {return GameBridge.probe(bullet,"owner")===mine;});
      }
      private function showMineResult(l:TcpLink,p:Object):void {
         var r:Object=links[l],result:Object=p.result;
         if(!enabled||int(p.revision)!=revision||int(p.seq)<=int(r.resultLast)||String(p.roomKey)!=game.roomKey()
            ||int(p.roomEpoch)!=session.rooms.epoch||int(p.roomTerm)!=session.rooms.term
            ||mod.playerMines==null||!mod.playerMines.ownsKey(String(p.key)))return;
         if(result==null||!isFinite(Number(result.hp))||Number(result.hp)<0||Number(result.hp)>1e8
            ||!isFinite(Number(result.shield))||Number(result.shield)<0||Number(result.shield)>1e8)return;
         r.resultLast=int(p.seq);var body:Object=actor(l);if(body==null||body.loc!==game.loc)return;
         r.feedback.show(body,Number(result.hp),Number(result.shield),{frame:2,scale:Number(result.scale)>=1.5?1.6:1,
            x:GameBridge.probe(p.point,"X"),y:GameBridge.probe(p.point,"Y")},true);
      }
      private function sendBlind(body:Object,source:String,duration:Number):void {
         for(var key:Object in links) {
            var l:TcpLink=key as TcpLink;if(body!==actor(l)||!ready(l))continue;
            l.send(session.rooms.stamp({type:"friendly-fire",op:"blind",revision:revision,seq:++serial,source:source,duration:duration}));
         }
      }
      private function fault(err:Error):void {if(errors++<8)Log.d("RConnect friendly fire: "+err);}
   }
}
