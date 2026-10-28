package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.RConnectSecurityAccess;
   import fe.serv.RConnectSecurityInteractionAccess;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.game.SecurityAccessState;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Host chooses grant scope. The current room owner retains all native AI,
    * weapon simulation and XP settlement, including when players split rooms. */
   public class SecurityTerminals {
      private var mod:Object,links:Dictionary=new Dictionary(),applied:Dictionary=new Dictionary(true);
      private var timer:Timer=new Timer(100),ledger:SecurityAccessState=new SecurityAccessState();
      private var localViews:Object={},pending:Object={};
      private var transport:Object,mode:String="",epoch:int=-1,serial:int=0,requestSerial:int=0;
      private var known:Boolean=false,policy:Boolean=true,policyRevision:int=0,nextState:int=0,nextHello:int=0,errors:int=0;
      private var factory:Object,hookFunction:Function;
      private var lastRoom:Object,lastApply:String="";
      public var supported:Boolean=false;
      public function SecurityTerminals(m:Object) {
         mod=m;hookFunction=hook;
         try {
            factory=m.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret");
            supported="rconnectSecurity" in factory;
         } catch(e:Error) {fault(e);}
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,96000);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function get session():Object {return mod.session;}
      private function get game():Object {return mod.game;}
      private function host():Boolean {return session.mode==Session.HOSTING;}
      private function live():Boolean {return supported && (session.mode==Session.CONNECTED || host() && session.peers.length>0);}
      private function ready():Boolean {
         return live() && session.myId>=0 && session.rooms.ready && !session.rooms.busy
            && !game.roomHold && game.loc!=null && game.gg!=null && !game.isTransitioning();
      }
      public function get canChangePolicy():Boolean {return supported && (host() || session.mode==Session.OFFLINE);}
      public function get stateReady():Boolean {return supported && (host() || session.mode==Session.OFFLINE || known);}
      public function get shared():Boolean {return host() || session.mode==Session.OFFLINE?mod.config.getValue("sharedSecurityHack")!="0":policy;}
      public function setShared(value:Boolean):Boolean {
         if(!canChangePolicy)return false;
         sync();mod.config.setValue("sharedSecurityHack",value?"1":"0");mod.config.save();
         policy=value;policyRevision++;nextState=0;broadcast();return true;
      }
      /** All lock/open replication for this terminal is owned here, not by the
       * generic door/container channel or a different player's room checkpoint. */
      public function ownsInteraction(inter:Object):Boolean {
         return live() && inter!=null && GameBridge.probe(inter,"allact")=="hack_robot"
            && GameBridge.probe(inter,"prob")==null;
      }
      private function connected(l:TcpLink):Boolean {
         if(l==null || !l.isOpen)return false;
         if(session.mode==Session.CONNECTED)return l===session.link;
         if(host())for each(var p:Object in session.peers)if(p.link===l)return true;
         return false;
      }
      private function resetWorld():void {
         ledger.reset();localViews={};pending={};applied=new Dictionary(true);serial=0;requestSerial=0;
         lastRoom=null;lastApply="";
      }
      private function sync():void {
         var current:Object=host()?session.server:session.link;
         if(mode!=session.mode || transport!==current) {
            for(var old:Object in links)TcpLink(old).removeEventListener(TcpLink.MESSAGE,receive);
            links=new Dictionary();resetWorld();mode=session.mode;transport=current;epoch=-1;
            known=host();policy=mod.config.getValue("sharedSecurityHack")!="0";policyRevision=host()?1:0;nextState=0;nextHello=0;
         }
         if(epoch!=int(session.rooms.epoch)) {
            resetWorld();epoch=int(session.rooms.epoch);known=host();nextState=0;nextHello=0;
            // Request numbers belong to this map epoch, just like receipts.
            for(var peer:Object in links){links[peer].last=0;links[peer].state="";}
         }
         for(var key:Object in links)if(!connected(key as TcpLink)) {
            TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);delete links[key];
         }
         if(host())for each(var p:Object in session.peers)watch(p.link as TcpLink);
         else if(session.mode==Session.CONNECTED)watch(session.link as TcpLink);
         if(supported) {
            var callback:Function=live()?hookFunction:null;
            if(factory.rconnectSecurity!==callback)factory.rconnectSecurity=callback;
         }
      }
      private function watch(l:TcpLink):void {
         if(l==null || !l.isOpen || links[l]!=null)return;
         links[l]={last:0,state:""};l.addEventListener(TcpLink.MESSAGE,receive);nextState=0;
      }
      private function broadcast():void {
         if(!host() || getTimer()<nextState)return;
         nextState=getTimer()+1000;
         var signature:String=epoch+":"+policyRevision+":"+serial,needed:Boolean=false;
         for(var peer:Object in links)if(links[peer].state!=signature){needed=true;break;}
         if(!needed)return;
         var packet:Object={type:"security-terminals",op:"state",epoch:epoch,policyRevision:policyRevision,
            shared:shared,receipts:ledger.exportReceipts()};
         for(var l:Object in links)if(links[l].state!=signature) {
            TcpLink(l).send(packet);links[l].state=signature;
         }
      }
      private function requestState():void {
         if(known || session.mode!=Session.CONNECTED || !connected(session.link as TcpLink) || getTimer()<nextHello)return;
         // Welcome and the first state can arrive in one socket batch before
         // this controller's next tick attaches its listener. Ask until known.
         nextHello=getTimer()+1000;
         session.link.send({type:"security-terminals",op:"hello",epoch:epoch});
      }
      private function sendPending():void {
         if(host() || !known || !connected(session.link as TcpLink))return;
         var queue:Array=[];
         for each(var p:Object in pending)if(!p.sent && p.request.epoch==epoch)queue.push(p);
         queue.sort(function(a:Object,b:Object):Number {return a.request.seq-b.request.seq;});
         for each(p in queue){p.sent=true;session.link.send(p.request);}
      }
      private function request(inter:Object,skill:int):void {
         if(!ready() || int(inter.lock)!=0)return;
         var unitKeys:Array=[],room:String=game.roomKey(),terminal:String=game.securityObjectKey(inter.owner);
         for each(var u:Object in game.loc.units)if(RConnectSecurityAccess.turret(u) && u.sost<3 && u.hp>0) {
            var unitKey:String=game.securityUnitKey(u),state:Object=RConnectSecurityAccess.state(u);
            // Native saves/scripts may already have disabled or reprogrammed a
            // turret for everyone. A new personal hack cannot revoke that.
            if(ledger.get(room,unitKey)==null && (state.sleep || state.reprog || int(u.fraction)==100))continue;
            unitKeys.push(unitKey);
         }
         if(terminal=="")return;
         var q:Object={type:"security-terminals",op:"request",epoch:epoch,seq:++requestSerial,
            room:room,terminal:terminal,skill:Math.max(0,Math.min(2,skill)),units:unitKeys};
         pending[room+"|"+terminal]={request:q,sent:false};
         if(host())accept(q,session.myId);else {sendPending();requestState();}
      }
      private function accept(q:Object,actor:int):void {
         var receipt:Object={id:serial+1,room:q.room,terminal:q.terminal,actor:actor,
            shared:shared,skill:q.skill,units:q.units};
         if(!SecurityAccessState.valid(receipt))return;
         // Reusing an unlocked terminal can address newly spawned turrets, but
         // cannot reshare old personal grants just because the setting changed.
         var fresh:Array=[];
         for each(var unit:String in receipt.units)if(!ledger.protects(receipt.room,unit,actor))fresh.push(unit);
         receipt.units=fresh;
         if(fresh.length==0 && ledger.terminalOpen(receipt.room,receipt.terminal,actor)) {
            for(var link:Object in links)links[link].state="";
            nextState=0;broadcast();return;
         }
         serial++;ledger.add(receipt);nextState=0;applyCurrent();broadcast();
      }
      private function receive(e:NetMessageEvent):void {
         var q:Object=e.data,l:TcpLink=e.target as TcpLink;
         if(q==null || q.type!="security-terminals" || !connected(l))return;
         try {
            sync();
            if(int(q.epoch)!=epoch)return;
            if(q.op=="hello" && host() && links[l]!=null) {
               links[l].state="";nextState=0;broadcast();return;
            }
            if(q.op=="request" && host() && links[l]!=null && q.seq is Number && q.seq>links[l].last) {
               var check:Object={id:1,room:q.room,terminal:q.terminal,actor:l.id,shared:shared,skill:q.skill,units:q.units};
               if(!SecurityAccessState.valid(check))return;
               links[l].last=int(q.seq);accept(q,l.id);return;
            }
            if(q.op!="state" || host() || l!==session.link || !(q.receipts is Array)
               || q.receipts.length>2048 || !(q.shared is Boolean) || q.policyRevision<policyRevision)return;
            for each(var r:Object in q.receipts)if(!SecurityAccessState.valid(r))return;
            known=true;policy=q.shared;policyRevision=int(q.policyRevision);
            for each(r in q.receipts)ledger.add(r);
            sendPending();
            applyCurrent();
         } catch(err:Error) {fault(err);}
      }
      private function playerId(o:Object):int {
         if(o===game.gg)return session.myId;
         if(host())for each(var p:Object in session.peers)if(o===game.getRemoteGhost(p.link.id))return p.link.id;
         if(!host() && o===game.getRemoteGhost(0))return 0;
         return -1;
      }
      private function players():Array {
         var a:Array=[game.gg];
         if(host())for each(var p:Object in session.peers)a.push(game.getRemoteGhost(p.link.id));
         else a.push(game.getRemoteGhost(0));
         return a;
      }
      private function permission(t:Object,p:Object):* {
         var id:int=playerId(p),key:String=game.unitKey(t),room:String=game.roomKey(t.loc);
         if(id<0 || key=="" || ledger.get(room,key)==null)return null;
         return ledger.protects(room,key,id);
      }
      private function prepare(t:Object):void {
         var key:String=game.unitKey(t),room:String=game.roomKey(t.loc),grant:Object=ledger.get(room,key);
         if(grant==null)return;
         if(session.rooms.authority && t.loc===game.loc && applied[t]!=grant.version) {
            var everyone:Boolean=grant.shared===true;
            if(!everyone) {
               everyone=ledger.protects(room,key,0);
               if(host())for each(var p:Object in session.peers)everyone=everyone && ledger.protects(room,key,p.link.id);
               else everyone=everyone && ledger.protects(room,key,session.myId);
            }
            RConnectSecurityAccess.apply(t,int(grant.skill),everyone,session.rooms.authority && t.loc===game.loc);
            applied[t]=grant.version;
         }
         RConnectSecurityAccess.clearTarget(t,function(p:Object):Boolean {return permission(t,p)===true;});
      }
      private function hook(op:String,a:Object,b:*=null):* {
         if(!live())return null;
         if(op=="terminal") {
            if(!ownsInteraction(a))return null;
            sync();request(a,int(b));return true;
         }
         if(op=="hit") {
            var source:Object=a,target:Object=b;
            if(source is MirrorHitUnit)source=MirrorHitUnit(source).body;
            if(target is MirrorHitUnit)target=MirrorHitUnit(target).body;
            if(RConnectSecurityAccess.turret(source)) {
               var allowed:*=permission(source,target);
               return allowed==null?null:!Boolean(allowed);
            }
            if(RConnectSecurityAccess.turret(target) && permission(target,source)===false)return true;
            return null;
         }
         if(!ready() || !session.rooms.authority || a.loc!==game.loc || !RConnectSecurityAccess.turret(a))return null;
         var grant:Object=ledger.get(game.roomKey(),game.unitKey(a));if(grant==null)return null;
         prepare(a);
         if(op=="step")return null;
         if(op!="find")return null;
         var state:Object=RConnectSecurityAccess.state(a);
         if(state.sleep)return false;
         // Keep a legitimate non-player priority target when reprogrammed.
         if(state.reprog && a.priorUnit!=null && playerId(a.priorUnit)<0 && a.isMeet(a.priorUnit)
            && a.priorUnit.sost<3 && a.priorUnit.hp>0 && !a.priorUnit.doop)return null;
         var candidates:Array=players();
         if(playerId(a.priorUnit)>=0)candidates.unshift(a.priorUnit);
         for each(var p:Object in candidates)if(p!=null && permission(a,p)===false
            && RConnectSecurityAccess.detect(a,p,Boolean(b)))return true;
         if(state.reprog)return null; // Native enemy selection remains unchanged.
         a.celUnit=null;a.priorUnit=null;return false;
      }
      private function applyCurrent():void {
         if(!ready())return;
         var stamp:String=ledger.revision+":"+session.rooms.authority+":"+game.loc.units.length+":"+game.loc.objs.length;
         if(lastRoom===game.loc && lastApply==stamp)return;
         lastRoom=game.loc;lastApply=stamp;
         var room:String=game.roomKey();
         for each(var u:Object in game.loc.units)if(RConnectSecurityAccess.turret(u))prepare(u);
         for each(var box:Object in game.loc.objs) {
            var inter:Object=GameBridge.probe(box,"inter");if(!ownsInteraction(inter))continue;
            var terminal:String=game.securityObjectKey(box),key:String=room+"|"+terminal;
            var view:Object=localViews[key];
            if(view==null)localViews[key]=RConnectSecurityInteractionAccess.capture(inter);
            if(ledger.terminalOpen(room,terminal,session.myId)) {
               if(int(inter.lock)!=0)inter.setAct("lock",101);
               localViews[key]=RConnectSecurityInteractionAccess.capture(inter);delete pending[key];
            } else if(pending[key]==null) {
               // Own attempts (including failures) remain local and survive a revisit.
               localViews[key]=RConnectSecurityInteractionAccess.capture(inter);
            }
         }
      }
      /** Called around checkpoint restore, so another player's lock/failure
       * state never overwrites this player's independent attempts. */
      public function rememberInteraction(inter:Object,terminal:String):void {
         if(ownsInteraction(inter))localViews[game.roomKey()+"|"+terminal]=RConnectSecurityInteractionAccess.capture(inter);
      }
      public function worldChanged():void {lastRoom=null;lastApply="";}
      public function restoreInteraction(inter:Object,terminal:String):void {
         if(!ownsInteraction(inter))return;
         var key:String=game.roomKey()+"|"+terminal,view:Object=localViews[key];
         if(view!=null)RConnectSecurityInteractionAccess.restore(inter,view);
         if(ledger.terminalOpen(game.roomKey(),terminal,session.myId) && int(inter.lock)!=0)inter.setAct("lock",101);
      }
      private function before(e:Event):void {try {sync();applyCurrent();}catch(err:Error){fault(err);}}
      private function tick(e:TimerEvent):void {try {sync();requestState();broadcast();}catch(err:Error){fault(err);}}
      private function fault(e:Error):void {if(errors++<8)Log.d("RConnect security: "+e);}
   }
}
