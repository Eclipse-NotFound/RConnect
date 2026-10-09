package rconnect.core {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import fe.unit.RConnectUnitAccess;
   import rconnect.game.GameBridge;
   import rconnect.game.NativeRoomState;
   import rconnect.game.PlayerMineGate;
   import rconnect.game.RemoteMotion;
   import rconnect.game.DeathVisuals;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** A planted Mine is a persistent room object, not a flying Bullet.
    * One native Mine runs on the current room owner. All other copies are
    * inert display receivers outside firstObj; no client damage is replayed.
    * Native inventory consumption stays with WThrow on the placing player. */
   public class PlayerMines {
      private static const TYPE:String="player-mines";
      private static const IDS:Array=["hmine","mine","cryomine","plamine","impmine","x37","zebmine","balemine"];
      private static const PLACE_FIELDS:Array=["X","Y","dx","dy","damage1","explRadius","explTime","reloadTime","massa","massaMove","massaFix"];
      private var mod:RConnectMod,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var data:Dictionary=new Dictionary(),known:Dictionary=new Dictionary();
      private var serial:int=0,errors:int=0,context:Object,land:Object,lastRoom:Object;
      private var active:Boolean=false,gate:PlayerMineGate;

      public function PlayerMines(m:RConnectMod) {
         mod=m;
         // Set this public GameBridge reference in RConnectMod during wiring.
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,96000);
         m.stage.addEventListener(Event.ENTER_FRAME,after,false,-8000);
         m.stage.addEventListener(Event.RENDER,render,false,-15000);
         timer.addEventListener(TimerEvent.TIMER,broadcast);timer.start();
      }
      private function get game():Object {return mod.game;}
      private function get session():Object {return mod.session;}
      private function get rooms():Object {return session.rooms;}
      private function connected():Boolean {return session.mode==Session.CONNECTED&&session.link!=null&&session.link.isOpen || session.mode==Session.HOSTING&&session.peers.length>0;}
      private function ready():Boolean {return connected()&&rooms.ready&&!rooms.busy&&game.loc!=null&&game.gg!=null&&!game.isTransitioning();}
      private function entry(room:Object):Object {
         if(data[room]==null)data[room]={room:room,records:{},sent:0,received:0,term:-1};
         return data[room];
      }
      private function ai(u:Object):int {return int(RConnectUnitAccess.capture(u as Unit).ai);}
      private function setAi(u:Object,n:int):void {RConnectUnitAccess.restore(u as Unit,{groups:{Unit:{aiState:n}}});}
      public static function isPlayerMine(u:Object):Boolean {return u!=null&&getQualifiedClassName(u)=="fe.unit::Mine"&&GameBridge.probe(u,"fraction")==100;}
      /** Provenance is separate from faction: retain it for future policies. */
      public function ownerOf(u:Object):int {return known[u]==null?-1:int(known[u].owner);}
      private function nativeState(u:Object):Object {return {runtime:NativeRoomState.unit(u),inter:NativeRoomState.scalars(u.inter)};}
      private function view(u:Object):Object {
         var v:Object=u.vis;
         return {id:String(u.id),x:Number(u.X),y:Number(u.Y),dx:Number(u.dx),dy:Number(u.dy),
            frame:v==null?1:int(v.currentFrame),alpha:v==null?1:Number(v.alpha),visible:u.isVis===true,
            sost:int(u.sost),exploded:u.lootIsDrop===true,damageType:int(u.tipDamage),ai:ai(u),sampleTime:getTimer()};
      }
      private function newKey():String {return "M"+int(rooms.epoch)+":"+int(session.myId)+":"+(++serial);}
      private function ensureLand():void {
         if(game.world!=null&&land!==game.world.land){clearViews();data=new Dictionary();known=new Dictionary();land=game.world.land;lastRoom=null;}
      }
      private function updateContext():void {
         if(ready())context={room:game.loc,key:game.roomKey(),epoch:rooms.epoch,term:rooms.term,authority:rooms.authority};
      }
      private function watch():void {
         for(var old:Object in links)if(!old.isOpen){old.removeEventListener(TcpLink.MESSAGE,receive);delete links[old];}
         var list:Array=[];
         if(session.mode==Session.CONNECTED)list.push(session.link);
         else if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)list.push(p.link);
         for each(var l:TcpLink in list)if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function authenticated(l:TcpLink):Boolean {
         if(session.mode==Session.CONNECTED)return l===session.link;
         if(session.mode==Session.HOSTING)for each(var p:Object in session.peers)if(p.link===l)return true;
         return false;
      }
      private function packet(op:String):Object {return rooms.stamp({type:TYPE,op:op});}
      private function matches(p:Object):Boolean {
         // During a seal the previous room still owns ordered, in-flight inputs.
         // The next term invalidates them, even if an old native room survives.
         return connected()&&rooms.ready&&context!=null&&int(p.roomEpoch)==rooms.epoch&&int(p.roomTerm)==rooms.term&&String(p.roomKey)==String(context.key);
      }
      private function before(e:Event):void {
         try {
            watch();if(!connected()){if(active)reset();return;}active=true;
            if(!ready())return;
            ensureLand();
            if(lastRoom!==game.loc){hideRoom(lastRoom);lastRoom=game.loc;}
            updateContext();
            var d:Object=entry(game.loc);
            if(int(d.term)!=rooms.term){d.term=rooms.term;d.received=0;}
            installGate(game.loc);
         }catch(error:Error){fault(error);}
      }
      private function after(e:Event):void {
         try {if(ready())commands();}catch(error:Error){fault(error);}
      }
      private function installGate(room:Object):void {
         if(gate!=null&&Object(gate).loc!==room){gate.dispose();gate=null;}
         if(room==null)return;
         if(gate==null)gate=new PlayerMineGate(room,collectAtNativeBoundary);
         var g:Object=gate;
         if(room.firstObj===g)return;
         if(g.in_chain)room.remObj(g);
         var first:Object=room.firstObj;g.pobj=null;g.nobj=first;g.in_chain=true;
         if(first!=null)first.pobj=g;else room.lastObj=g;
         room.firstObj=g;
      }
      private function collectAtNativeBoundary(room:Object):void {
         try {if(context!=null&&room===context.room&&connected())discover(room,Boolean(context.authority));}
         catch(error:Error){fault(error);}
      }
      /** Called before Session.flushRoomReports in the room seal barrier. */
      public function flush():void {
         if(!connected()||game.loc==null||!rooms.ready)return;
         discover(game.loc,Boolean(rooms.authority));
      }
      private function discover(room:Object,authority:Boolean):void {
         var d:Object=entry(room);
         for each(var u:Object in room.units as Array) {
            if(!isPlayerMine(u)||known[u]!=null||int(u.sost)>=4)continue;
            var rec:Object={key:newKey(),owner:int(session.myId),raw:u,role:authority?"native":"pending",state:view(u),played:false};
            rec.state.key=rec.key;rec.state.owner=rec.owner;rec.nativeData=nativeState(u);
            known[u]=rec;d.records[rec.key]=rec;
            if(authority)continue;
            var p:Object=packet("place");p.key=rec.key;p.id=String(u.id);p.values={};
            for each(var name:String in PLACE_FIELDS)p.values[name]=Number(u[name]);
            p.values.fixed=Boolean(u.fixed);p.values.stay=Boolean(u.stay);
            p.values.v4=Number(u.vulner[4]);p.values.v6=Number(u.vulner[6]);
            rec.request=p;rec.requestAt=getTimer();
            // Native sensor/physics and all Bullet target scans stop here,
            // before the rest of this Location.step's firstObj chain advances.
            u.disabled=true;room.remObj(u);u.inter.active=false;attachVisual(u);
            session.link.send(p);
         }
      }
      private function commands():void {
         if(rooms.authority)return;
         var d:Object=entry(game.loc);
         for each(var rec:Object in d.records) {
            if(rec.role=="pending"&&getTimer()-int(rec.requestAt)>15000) {
               // An unknown outcome cannot safely refund ammo or create a
               // local live mine. Remove the preview; a later valid authority
               // snapshot may still confirm the already-consumed placement.
               remove(rec.raw);rec.raw=null;rec.role="expired";continue;
            }
            if(rec.role=="native"||rec.raw==null||rec.state.sost>=4)continue;
            var u:Object=rec.raw;
            // Native WThrow.detonator visits loc.units even though this receiver
            // is disabled and absent from firstObj. Relay that exact input.
            if(String(u.id)=="x37"&&ai(u)==2&&int(rec.state.ai)!=2&&!rec.commanded) {
               var p:Object=packet("detonate");p.key=rec.key;rec.commanded=true;session.link.send(p);
            }
            setAi(u,int(rec.state.ai));u.disabled=true;u.inter.active=false;
         }
      }
      private function safePlacement(p:Object,room:Object):Boolean {
         if(p==null||IDS.indexOf(String(p.id))<0||p.values==null||!/^M\d+:\d+:\d+$/.test(String(p.key)))return false;
         var v:Object=p.values;
         for each(var k:String in PLACE_FIELDS)if(v[k]===undefined||!isFinite(Number(v[k])))return false;
         var tile:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Tile");
         return v.X>=-Number(tile.tileX)&&v.X<=room.spaceX*Number(tile.tileX)+Number(tile.tileX)
            &&v.Y>=-Number(tile.tileY)&&v.Y<=room.spaceY*Number(tile.tileY)+Number(tile.tileY)
            &&Math.abs(v.dx)<=1000&&Math.abs(v.dy)<=1000&&v.damage1>=0&&v.damage1<=1000000
            &&v.explRadius>=0&&v.explRadius<=10000&&v.explTime>=0&&v.explTime<=10000
            &&v.reloadTime>=0&&v.reloadTime<=75&&v.massa>0&&v.massaMove>0&&v.massaFix>0
            &&isFinite(Number(v.v4))&&isFinite(Number(v.v6))&&v.v4>=0&&v.v6>=0;
      }
      private function construct(id:String,room:Object,x:Number,y:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.Mine") as Class;
         var u:Object=new c(id);u.putLoc(room,x,y);u.fraction=100;u.setVis(true);return u;
      }
      private function accept(p:Object,l:TcpLink,room:Object):void {
         var d:Object=entry(room),key:String=String(p.key),rec:Object=d.records[key];
         // Tombstones remain in the checkpoint: old/replayed requests cannot
         // replant a detonated or disarmed mine after ownership changes.
         if(rec!=null)return;
         if(!safePlacement(p,room)||key.split(":")[1]!=String(l.id)) {
            var no:Object=packet("reject");no.key=key;l.send(no);return;
         }
         var u:Object=construct(String(p.id),room,p.values.X,p.values.Y);
         for each(var name:String in PLACE_FIELDS)u[name]=Number(p.values[name]);
         u.setPos(p.values.X,p.values.Y);u.fixed=p.values.fixed===true;u.stay=p.values.stay===true;
         u.vulner[4]=p.values.v4;u.vulner[6]=p.values.v6;u.inter.mine=1;
         u.vis.gotoAndStop(u.reloadTime>1?1:2);u.disabled=false;
         room.addObj(u);room.units.push(u);
         rec={key:key,owner:l.id,raw:u,role:"native",state:view(u),played:false};known[u]=rec;d.records[key]=rec;
         rec.state.key=key;rec.state.owner=rec.owner;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,l:TcpLink=e.target as TcpLink;
         if(p==null||p.type!=TYPE||!authenticated(l))return;
         try {
            updateContext();
            if(!matches(p))return;
            var room:Object=context.room,d:Object=entry(room),rec:Object=d.records[String(p.key)];
            if(context.authority) {
               if(session.mode!=Session.HOSTING)return;
               if(p.op=="place")game.inRoom(room,function():void {accept(p,l,room);});
               else if(p.op=="detonate"&&rec!=null&&rec.role=="native"&&rec.raw!=null&&rec.raw.id=="x37"&&rec.raw.sost<4&&!rec.detonated) {
                  rec.detonated=true;game.inRoom(room,function():void {rec.raw.activate();});
               }
               return;
            }
            if(p.op=="reject"&&rec!=null&&rec.role=="pending") {
               // The attempt consumed one real item. Remove its inert preview;
               // do not turn a rejected/outdated input into a local explosion.
               remove(rec.raw);delete d.records[rec.key];return;
            }
            if(p.op!="state"||!(p.list is Array)||int(p.serial)<=int(d.received))return;
            d.received=int(p.serial);
            commands(); // Preserve a native radio input received before this snapshot.
            for each(var s:Object in p.list)apply(d,s,true);
         }catch(error:Error){fault(error);}
      }
      private function broadcast(e:TimerEvent=null):void {
         try {
            if(!ready()||!rooms.authority)return;
            discover(game.loc,true);var d:Object=entry(game.loc),list:Array=[];
            for each(var rec:Object in d.records)if(rec.role=="native") {
               rec.state=view(rec.raw);rec.state.key=rec.key;rec.state.owner=rec.owner;list.push(rec.state);
            }
            // Empty packets also order the initial room state. No sender can
            // force a receiver to run Mine.control or Unit.explosion.
            if(session.mode==Session.HOSTING){var p:Object=packet("state");p.serial=++d.sent;p.list=list;session.server.broadcast(p);}
         }catch(error:Error){fault(error);}
      }
      private function apply(d:Object,s:Object,effects:Boolean):void {
         if(s==null||IDS.indexOf(String(s.id))<0||s.key==null||!isFinite(Number(s.x))||!isFinite(Number(s.y)))return;
         var rec:Object=d.records[String(s.key)];
         if(rec==null)rec=d.records[String(s.key)]={key:String(s.key),owner:int(s.owner),raw:null,role:"mirror",played:false};
         if(rec.role=="native")return;
         if(rec.role=="pending"||rec.role=="expired") {remove(rec.raw);rec.raw=null;rec.role="mirror";rec.request=null;}
         rec.state=s;
         if(int(s.sost)>=4) {
            if(effects&&s.exploded===true&&!rec.played&&d.room===game.loc)DeathVisuals.play(mod.main,d.room,{type:int(s.damageType),water:false},Number(s.x),Number(s.y)-3);
            rec.played=true;remove(rec.raw);rec.raw=null;return;
         }
         if(rec.raw==null) {
            rec.raw=construct(String(s.id),d.room,Number(s.x),Number(s.y));known[rec.raw]=rec;
            rec.raw.disabled=true;rec.raw.inter.active=false;
            // Present to native radio enumeration, never to physics/AI.
            d.room.units.push(rec.raw);rec.motion=new RemoteMotion(100);
         }
         rec.raw.disabled=true;setAi(rec.raw,int(s.ai));
         rec.motion.push(s,getTimer());draw(rec,d.room);
      }
      private function draw(rec:Object,room:Object):void {
         var u:Object=rec.raw;if(u==null||rec.state==null||int(rec.state.sost)>=4)return;
         if(room!==game.loc){u.remVisual();return;}
         if(rec.role=="native")return;
         var s:Object=rec.state;
         if(rec.motion!=null)s=game.coopPaused?rec.motion.settle(getTimer()):rec.motion.sample(getTimer());
         u.setPos(Number(s.x),Number(s.y));u.setVisPos();
         // Native drawAllObjs replaces the layer while this inert receiver is
         // outside firstObj. A non-null parent may be a detached old layer.
         if(u.vis!=null){if(u.vis.parent!==game.world.grafon.visObjs[int(u.sloy)])attachVisual(u);u.vis.gotoAndStop(Math.max(1,int(s.frame)));u.vis.alpha=Number(s.alpha);u.vis.visible=s.visible===true;}
      }
      private function attachVisual(u:Object):void {
         // Unit.addVisual exits for disabled units. Attach just the native
         // display clip; no HP bar, cursor, collision receiver or death script.
         if(u!=null&&u.vis!=null&&u.loc===game.loc&&u.loc.active)game.world.grafon.visObjs[int(u.sloy)].addChild(u.vis);
      }
      private function render(e:Event):void {
         try {
            if(!ready())return;var d:Object=entry(game.loc);
            for each(var rec:Object in d.records)draw(rec,game.loc);
         }catch(error:Error){fault(error);}
      }
      /** Called inside GameBridge.inRoom too; do not assume game.loc is active. */
      public function checkpoint():Array {
         if(game.loc==null)return [];
         ensureLand();
         if(connected())discover(game.loc,true);
         var out:Array=[],d:Object=entry(game.loc);
         for each(var rec:Object in d.records) {
            if(rec.role=="native") {rec.state=view(rec.raw);rec.state.key=rec.key;rec.state.owner=rec.owner;rec.nativeData=nativeState(rec.raw);}
            if(rec.role!="pending"&&rec.role!="expired")out.push({key:rec.key,owner:rec.owner,state:rec.state,nativeData:rec.nativeData});
         }
         return out;
      }
      /** Fresh grants and authority transfer carry the complete native scalar
       * state, including fuse/reload counters. No constructor random reroll. */
      public function restore(saved:Array,authority:Boolean,foreign:Boolean):void {
         var room:Object=game.loc;if(room==null)return;ensureLand();installGate(null);
         var d:Object=entry(room);
         for each(var old:Object in d.records)remove(old.raw);
         for each(var oldMine:Object in (room.units as Array).concat())if(isPlayerMine(oldMine))remove(oldMine);
         d.records={};d.received=0;d.term=-1;
         for each(var item:Object in saved) {
            if(item==null||item.state==null||IDS.indexOf(String(item.state.id))<0)continue;
            var rec:Object={key:String(item.key),owner:int(item.owner),raw:null,role:authority?"native":"mirror",state:item.state,nativeData:item.nativeData,played:int(item.state.sost)>=4};
            d.records[rec.key]=rec;
            if(authority) {
               var u:Object=construct(String(item.state.id),room,item.state.x,item.state.y);
               if(item.nativeData!=null&&item.nativeData.runtime!=null) {
                  NativeRoomState.restoreUnit(u,item.nativeData.runtime,mod.main);NativeRoomState.restore(u.inter,item.nativeData.inter);
               }
               u.fraction=100;rec.raw=u;known[u]=rec;
               if(u.sost<4){room.addObj(u);room.units.push(u);u.setVisPos();
                  u.vis.gotoAndStop(Math.max(1,int(item.state.frame)));if(ai(u)==2)u.vis.play();}
            }else apply(d,item.state,false);
         }
      }
      private function remove(u:Object):void {
         if(u==null)return;u.disabled=true;u.inter.active=false;
         var room:Object=u.loc;if(room!=null){room.remObj(u);var i:int=room.units.indexOf(u);if(i>=0)room.units.splice(i,1);}
         u.remVisual();delete known[u];
      }
      private function hideRoom(room:Object):void {if(room==null||data[room]==null)return;for each(var rec:Object in data[room].records)if(rec.role!="native"&&rec.raw!=null)rec.raw.remVisual();}
      private function clearViews():void {installGate(null);for each(var d:Object in data)for each(var rec:Object in d.records)if(rec.role!="native")remove(rec.raw);}
      /** Disconnect cleans display receivers and unaccepted previews only;
       * already-authoritative native mines continue ordinary offline play. */
      public function reset():void {clearViews();for(var l:Object in links)l.removeEventListener(TcpLink.MESSAGE,receive);links=new Dictionary();
         data=new Dictionary();known=new Dictionary();context=null;land=null;lastRoom=null;active=false;}
      private function fault(e:Error):void {if(errors++<8)Log.d("RConnectMine: "+e.message+" | "+e.getStackTrace());}
   }
}
