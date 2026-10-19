package rconnect.core {
   import fe.inter.RConnectPortPreview;
   import fe.unit.RConnectPortAccess;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Host policy + short-lived, point-specific sight answers. Exploration
    * history is never permission. The native player still owns the spell. */
   public class PeerVisionTeleport {
      private static const TTL:int=350;
      private var mod:RConnectMod,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var mode:String="",transport:Object,known:Boolean=false,policy:Boolean=false;
      private var revision:int=0,serial:int=0,nextPolicy:int=0,nextQuery:int=0,errors:int=0;
      private var location:Object,room:String="",epoch:int=0,term:int=0,release:Object;
      private var wasActive:Boolean=false;
      public function PeerVisionTeleport(m:RConnectMod) {
         mod=m;
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,90000);
         m.stage.addEventListener(Event.ENTER_FRAME,after,false,-7500);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function get session():Object {return mod.session;}
      private function get game():Object {return mod.game;}
      private function host():Boolean {return session.mode==Session.HOSTING;}
      public function get canChangePolicy():Boolean {return host() || session.mode==Session.OFFLINE;}
      public function get enabled():Boolean {
         return canChangePolicy?mod.config.getValue("peerVisionTeleport")=="1":known&&policy;
      }
      public function setEnabled(value:Boolean):Boolean {
         if(!canChangePolicy)return false;
         sync();mod.config.setValue("peerVisionTeleport",value?"1":"0");mod.config.save();
         policy=value;revision++;clearSight();nextPolicy=0;broadcast();return true;
      }
      private function connected(l:TcpLink):Boolean {
         if(l==null || !l.isOpen)return false;
         if(session.mode==Session.CONNECTED)return l===session.link;
         if(host())for each(var peer:Object in session.peers)if(peer.link===l)return true;
         return false;
      }
      private function active():Boolean {
         return enabled && (host() || session.mode==Session.CONNECTED) && game.gg!=null && game.loc!=null
            && game.world!=null && game.world.gg===game.gg && game.world.loc===game.loc
            && game.gg.loc===game.loc && game.loc.active
            && session.rooms.ready && !session.rooms.busy && !game.roomHold && !game.coopPaused
            && !game.isTransitioning() && !game.isPlayerDead();
      }
      private function ready(l:TcpLink):Boolean {
         if(!active() || !connected(l))return false;
         var body:Object=game.getRemoteGhost(host()?l.id:0);
         // A teammate must actually occupy this room. Disabled render proxies
         // are normal; their native life/room fields, not AI flags, are used.
         return body!=null && body.loc===game.loc && body.sost<3 && body.hp>0;
      }
      private function clearSight():void {
         release=null;nextQuery=0;
         for each(var r:Object in links){r.pending={};r.proof=null;r.last=0;}
      }
      private function reset():void {
         for(var key:Object in links)TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);
         links=new Dictionary();known=policy=false;revision=0;nextPolicy=nextQuery=0;release=null;
         location=null;room="";epoch=term=0;wasActive=false;
      }
      private function watch(l:TcpLink):void {
         if(l==null || !l.isOpen || links[l]!=null)return;
         links[l]={pending:{},proof:null,last:0};l.addEventListener(TcpLink.MESSAGE,receive);nextPolicy=0;
      }
      private function sync():void {
         var current:Object=host()?session.server:session.link;
         if(mode!=session.mode || transport!==current) {
            reset();mode=session.mode;transport=current;
            if(host()){known=true;policy=enabled;revision=1;}
         }
         for(var key:Object in links)if(!connected(key as TcpLink)) {
            TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);delete links[key];
         }
         if(host())for each(var peer:Object in session.peers)watch(peer.link as TcpLink);
         else if(session.mode==Session.CONNECTED)watch(session.link);
         if(!active()) {
            if(wasActive)clearSight();wasActive=false;return;
         }
         if(!wasActive){clearSight();location=null;wasActive=true;}
         if(location!==game.loc || epoch!=session.rooms.epoch || term!=session.rooms.term) {
            clearSight();location=game.loc;room=game.roomKey();epoch=session.rooms.epoch;term=session.rooms.term;
         }
      }
      private function broadcast():void {
         if(!host() || getTimer()<nextPolicy)return;
         nextPolicy=getTimer()+500;
         for(var key:Object in links)TcpLink(key).send({type:"peer-vision-port",op:"policy",revision:revision,enabled:enabled});
      }
      private function point(x:Number,y:Number):Object {
         if(game.loc==null || !isFinite(x) || !isFinite(y) || x<0 || y<0
            || x>=game.loc.limX || y>=game.loc.limY)return null;
         var tile:Object=game.loc.getAbsTile(x,y);
         if(tile==null || !isFinite(Number(tile.visi)))return null;
         return {x:x,y:y,tile:tile};
      }
      private function aim():Object {
         return game.world==null?null:point(Number(game.world.celX),Number(game.world.celY));
      }
      private function requestSight():void {
         if(!active() || getTimer()<nextQuery)return;
         var g:Object=game.gg;
         if(g.t_port<=0 && !game.world.ctr.keyTele)return;
         var a:Object=aim();if(a==null)return;
         nextQuery=getTimer()+100;
         for(var key:Object in links) {
            var l:TcpLink=key as TcpLink,r:Object=links[key];
            if(!ready(l)){r.proof=null;continue;}
            for(var id:String in r.pending)if(getTimer()-r.pending[id].at>TTL)delete r.pending[id];
            var seq:int=++serial;
            r.pending[seq]={at:getTimer(),x:a.x,y:a.y,tile:a.tile};
            l.send(session.rooms.stamp({type:"peer-vision-port",op:"query",revision:revision,seq:seq,x:a.x,y:a.y}));
         }
      }
      private function matches(p:Object):Boolean {
         return String(p.roomKey)==room && int(p.roomEpoch)==epoch && int(p.roomTerm)==term;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,l:TcpLink=e.target as TcpLink;
         if(p==null || p.type!="peer-vision-port" || !connected(l) || links[l]==null)return;
         try {
            sync();
            if(p.op=="policy") {
               if(host() || session.mode!=Session.CONNECTED || l!==session.link
                  || !isFinite(Number(p.revision)) || int(p.revision)<1 || int(p.revision)<revision)return;
               if(revision!=int(p.revision) || policy!=(p.enabled===true))clearSight();
               revision=int(p.revision);known=true;policy=p.enabled===true;return;
            }
            if(!ready(l) || int(p.revision)!=revision || !matches(p)
               || !isFinite(Number(p.seq)) || Number(p.seq)!=int(p.seq) || int(p.seq)<=0)return;
            if(p.op=="query") {
               var a:Object=point(Number(p.x),Number(p.y));
               l.send(session.rooms.stamp({type:"peer-vision-port",op:"answer",revision:revision,
                  seq:int(p.seq),seen:a!=null && PortSight.visible(game.loc,game.gg,a.tile)}));
            } else if(p.op=="answer") {
               var r:Object=links[l],q:Object=r.pending[int(p.seq)];
               delete r.pending[int(p.seq)];
               if(q==null || int(p.seq)<=r.last || getTimer()-int(q.at)>TTL)return;
               r.last=int(p.seq);r.proof=p.seen===true?q:null;
            }
         }catch(err:Error){fault(err);}
      }
      private function permitted(a:Object):Boolean {
         if(a==null || !active())return false;
         for(var key:Object in links) {
            var p:Object=links[key].proof;
            if(ready(key as TcpLink) && p!=null && p.tile===a.tile && getTimer()-int(p.at)<=TTL)return true;
         }
         return false;
      }
      private function castable():Boolean {
         if(!active() || !RConnectPortAccess.controllable(game.gg))return false;
         var g:Object=game.gg,w:Object=game.world,c:Object=w.ctr;
         return c!=null && c.active && !w.alicorn && !game.loc.base && game.loc.portOn && !game.loc.sky
            && g.rat==0 && g.pers.portPoss && g.pers.spellsPoss && g.t_culd<=0
            && !c.keyAction && !c.keyAttack && !g.autoAttack && !c.keyMagic && !c.keyGrenad
            && !c.keyPunch && !c.keyDef;
      }
      private function before(e:Event):void {
         release=null;
         if(!enabled)return;
         try {
            sync();broadcast();requestSight();
            if(!castable())return;
            var a:Object=aim(),g:Object=game.gg;
            // Only augment an actual native Q release, and only where native
            // sight would reject it. Native consumption of the charge below
            // proves the player control step ran (menus/pauses cannot cast).
            if(!game.world.ctr.keyTele && g.t_port>0 && g.t_port>=g.pers.portTime && a!=null
               && Number(a.tile.visi)<.8 && permitted(a))
               release={gg:g,loc:game.loc,x:a.x,y:a.y,tile:a.tile};
         }catch(err:Error){fault(err);}
      }
      private function after(e:Event):void {
         if(!enabled){release=null;return;}
         try {
            var g:Object=game.gg,r:Object=release;release=null;
            if(g==null || r==null && g.t_port<=15)return;
            var a:Object=aim();
            if(r!=null && g===r.gg && game.loc===r.loc && castable() && g.t_port==0
               && !game.world.ctr.keyTele && a!=null
               && a.tile===r.tile && Number(a.tile.visi)<.8 && permitted(a)
               && g.mana>=g.pers.portMana*g.pers.allDManaMult) {
               if(RConnectPortAccess.cast(g,a.tile)) {
                  // Unit.step already placed the body before this fallback.
                  // Match its new native position before the current render.
                  g.setVisPos();Log.d("RConnect peer-vision Q: native spell cast");
               }
            }
            if(castable() && g.t_port>15 && a!=null && Number(a.tile.visi)<.8 && permitted(a))
               RConnectPortPreview.show(game.world.gui,a.tile);
         }catch(err:Error){fault(err);}
      }
      private function tick(e:TimerEvent):void {
         try {sync();broadcast();requestSight();}catch(err:Error){fault(err);}
      }
      private function fault(e:Error):void {if(errors++<8)Log.d("RConnect peer-vision Q failed: "+e);}
   }
}
