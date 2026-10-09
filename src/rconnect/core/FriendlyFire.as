package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.NativeHit;
   import rconnect.game.PeerHitUnit;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** One host policy, local native hit detection, victim-owned mitigation.
    * No second AI or projectile simulation is created for friendly fire. */
   public class FriendlyFire {
      private var mod:RConnectMod,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var transport:Object,mode:String="",known:Boolean=false,policy:Boolean=false;
      private var revision:int=0,serial:int=0,nextState:int=0,errors:int=0;
      private var incoming:NativeHit=new NativeHit();
      public function FriendlyFire(m:RConnectMod) {
         mod=m;
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
         for(var key:Object in links) {
            clearBody(links[key]);TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);
         }
         links=new Dictionary();known=false;policy=false;serial=0;revision=0;nextState=0;
         transport=null;mode="";
      }
      private function watch(l:TcpLink):void {
         if(l==null || !l.isOpen || links[l]!=null)return;
         links[l]={last:0,body:null,proxy:null};l.addEventListener(TcpLink.MESSAGE,receive);nextState=0;
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
            if(p.op!="hit" || !ready(l) || int(p.revision)!=revision
               || String(p.roomKey)!=game.roomKey() || int(p.roomEpoch)!=session.rooms.epoch
               || int(p.roomTerm)!=session.rooms.term || !isFinite(Number(p.seq)) || int(p.seq)<=int(links[l].last))return;
            var hit:Object=p.hit;
            if(hit==null || !isFinite(Number(hit.amount)) || Number(hit.amount)<=0 || Number(hit.amount)>1e8
               || !isFinite(Number(hit.kind)) || int(hit.kind)<0 || int(hit.kind)>100 || hit.bullet==null)return;
            links[l].last=int(p.seq);
            incoming.apply(game.gg,hit,mod.main);
         }catch(err:Error){fault(err);}
      }
      private function before(e:Event):void {
         try {sync();refreshBodies();}catch(err:Error){fault(err);}
      }
      private function tick(e:TimerEvent):void {
         try {sync();broadcastPolicy();refreshBodies();}catch(err:Error){fault(err);}
      }
      private function fault(err:Error):void {if(errors++<8)Log.d("RConnect friendly fire: "+err);}
   }
}
