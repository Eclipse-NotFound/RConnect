package rconnect.core
{
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import modlocales.connect.RCLocale;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Host policy, one pause reason per authenticated connection, native UI alive.
    * World.onPause belongs to RoomSync and is never acquired or released here. */
   public class CoopPause
   {
      private static const MENU:int=1, SATS:int=2;
      private static var nativeLeases:Dictionary=new Dictionary(true);
      private var session:Session,game:GameBridge;
      private var timer:Timer=new Timer(50);
      private var watched:Dictionary=new Dictionary();
      private var transport:Object;
      private var epoch:int=-1,serial:int=0,lastState:int=-1;
      private var nextSend:int=0,lastMask:int=-1;
      private var reports:Dictionary=new Dictionary();
      private var remoteReasons:Array=[];
      private var frameWorld:Object;
      private var leasedStand:Object;
      private var injected:Boolean=false;
      private var _paused:Boolean=false,_menus:Boolean=false,_sats:Boolean=false;
      private var knownPolicy:Boolean=false;
      private var reasons:Array=[];
      private var lastSummary:String="",errors:int=0;

      public function CoopPause(s:Session)
      {
         session=s;game=s.mod.game;
         readPolicy();
         s.mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99500,true);
         s.mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-7000,true);
         timer.addEventListener(TimerEvent.TIMER,tick);
         timer.start();
      }
      public function get paused():Boolean {return _paused;}
      public function get requested():Boolean
      {return ready() && (host() || knownPolicy) && allowed(nativeReasons(game.world))!=0;}
      public function get blocked():Boolean {return _paused || session.rooms.busy;}
      public function get policyMenus():Boolean {return _menus;}
      public function get policySats():Boolean {return _sats;}
      public function get canChangePolicy():Boolean
      {return session.mode==Session.OFFLINE || session.mode==Session.HOSTING;}

      public function setPolicy(menus:Boolean,sats:Boolean):Boolean
      {
         if(!canChangePolicy)
         {session.rooms.notice("联机暂停开关由宿主设置");return false;}
         session.mod.config.setValue("pauseMenus",menus?"1":"0");
         session.mod.config.setValue("pauseSats",sats?"1":"0");
         session.mod.config.save();readPolicy();nextSend=0;
         refresh();return true;
      }
      private function readPolicy():void
      {
         _menus=session.mod.config.getValue("pauseMenus")=="1";
         _sats=session.mod.config.getValue("pauseSats")=="1";
      }
      private function host():Boolean {return session.mode==Session.HOSTING;}
      private function connected():Boolean
      {
         if(host())return session.peers.length>0;
         return session.mode==Session.CONNECTED && session.link!=null && session.link.isOpen;
      }
      /** Only actual native overlays count; allStat also contains our own lease. */
      public static function nativeReasons(w:Object):int
      {
         if(w==null)return 0;
         var mask:int=0;
         if(GameBridge.probe(GameBridge.probe(w,"pip"),"active")==true
            || nativeStandActive(w)
            || GameBridge.probe(GameBridge.probe(w,"gui"),"guiPause")==true
            || GameBridge.probe(GameBridge.probe(w,"mm"),"active")==true)mask|=MENU;
         if(GameBridge.probe(GameBridge.probe(w,"sats"),"active")==true)mask|=SATS;
         return mask;
      }
      private static function nativeStandActive(w:Object):Boolean
      {
         var stand:Object=GameBridge.probe(w,"stand");
         return GameBridge.probe(stand,"active")==true
            && (nativeLeases[w]!==stand || GameBridge.probe(GameBridge.probe(w,"vstand"),"visible")==true);
      }
      private function ready():Boolean
      {
         return connected() && session.rooms.ready && !session.rooms.busy
            && game.world!=null && game.gg!=null && game.loc!=null
            && int(GameBridge.probe(game.world,"allStat"))>=1
            && !game.isTransitioning() && !game.isPlayerDead();
      }
      private function allowed(mask:int):int {return mask & ((_menus?MENU:0)|(_sats?SATS:0));}
      private function peerFor(link:TcpLink):Object
      {for each(var p:Object in session.peers)if(p.link===link && link.isOpen)return p;return null;}

      public function reset():void
      {
         releaseFrame();
         for(var key:Object in watched)TcpLink(key).removeEventListener(TcpLink.MESSAGE,receive);
         watched=new Dictionary();reports=new Dictionary();remoteReasons=[];reasons=[];
         transport=null;epoch=-1;serial=0;lastState=-1;lastMask=-1;nextSend=0;
         knownPolicy=false;readPolicy();setPaused(false);
      }
      private function watch(link:TcpLink):void
      {
         if(link==null || !link.isOpen || watched[link])return;
         watched[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);
         nextSend=0;
      }
      private function syncLinks():void
      {
         var current:Object=host()?session.server:session.link;
         if(current!==transport) {reset();transport=current;}
         for(var key:Object in watched)
         {
            var link:TcpLink=key as TcpLink;
            if(!link.isOpen || (host()?peerFor(link)==null:link!==session.link))
            {
               link.removeEventListener(TcpLink.MESSAGE,receive);
               delete watched[link];delete reports[link];nextSend=0;
            }
         }
         if(host())for each(var p:Object in session.peers)watch(p.link as TcpLink);
         else watch(session.link);
         if(epoch!=session.rooms.epoch)
         {
            epoch=session.rooms.epoch;reports=new Dictionary();remoteReasons=[];
            lastMask=-1;nextSend=0;
         }
      }
      private function receive(e:NetMessageEvent):void
      {
         var msg:Object=e.data,link:TcpLink=e.target as TcpLink;
         if(msg==null || msg.type!="coop-pause")return;
         try
         {
            if(host())
            {
               if(peerFor(link)==null || msg.op!="report" || int(msg.epoch)!=session.rooms.epoch)return;
               var record:Object=reports[link];
               if(!isFinite(Number(msg.seq)) || int(msg.seq)<0 || (record!=null && int(msg.seq)<=int(record.seq)))return;
               reports[link]={seq:int(msg.seq),mask:int(msg.mask)&3};
               nextSend=0;
            }
            else
            {
               if(session.mode!=Session.CONNECTED || link!==session.link || !link.isOpen || msg.op!="state")return;
               if(!isFinite(Number(msg.seq)) || int(msg.seq)<=lastState || int(msg.epoch)!=session.rooms.epoch)return;
               lastState=int(msg.seq);_menus=msg.menus===true;_sats=msg.sats===true;knownPolicy=true;
               remoteReasons=msg.reasons is Array?(msg.reasons as Array).slice(0,2):[];
            }
            refresh();
         }
         catch(error:Error) {reportError(error);}
      }
      private function refresh():void
      {
         syncLinks();
         if(canChangePolicy)readPolicy();
         reasons=[];
         var playable:Boolean=ready(),mask:int=playable?nativeReasons(game.world):0;
         var filtered:int=allowed(mask);
         if(host())
         {
            if(playable && filtered!=0)reasons.push({id:0,name:session.myName,mask:filtered});
            if(playable)for each(var p:Object in session.peers)
            {
               var report:Object=reports[p.link],peerMask:int=report==null?0:allowed(int(report.mask));
               if(p.link!=null && p.link.isOpen && peerMask!=0)reasons.push({id:p.id,name:p.name,mask:peerMask});
            }
         }
         else if(playable && knownPolicy)
         {
            reasons=remoteReasons.concat();
            // Opening pauses locally at once. Closing waits for the host's ack,
            // so it cannot clear the other player's independent pause reason.
            if(filtered!=0)
            {
               var listed:Boolean=false;
               for each(var r:Object in reasons)if(int(r.id)==session.myId)listed=true;
               if(!listed)reasons.push({id:session.myId,name:session.myName,mask:filtered});
            }
         }
         setPaused(playable && reasons.length>0);
         if(!connected())return;
         var now:int=getTimer();
         if(host())
         {
            var summary:String=JSON.stringify({epoch:epoch,menus:_menus,sats:_sats,reasons:reasons});
            if(now<nextSend && summary==lastSummary)return;
            lastSummary=summary;nextSend=now+250;
            var state:Object={type:"coop-pause",op:"state",seq:++serial,epoch:epoch,menus:_menus,sats:_sats,reasons:reasons};
            for each(p in session.peers)if(p.link!=null && p.link.isOpen)p.link.send(state);
         }
         else if(now>=nextSend || mask!=lastMask)
         {
            lastMask=mask;nextSend=now+250;
            session.link.send({type:"coop-pause",op:"report",seq:++serial,epoch:epoch,mask:mask});
         }
      }
      private function setPaused(value:Boolean):void
      {
         if(value==_paused)return;
         _paused=value;
         game.setCoopPaused(value);
         Log.d("RConnectPause: "+(value?"paused":"resumed")+" epoch="+session.rooms.epoch);
      }
      public function description():String
      {
         if(!_paused)return "";
         var names:Array=[];
         for each(var r:Object in reasons)
         {
            var reason:String=(int(r.mask)&SATS)!=0?RCLocale.text("SATS"):RCLocale.text("菜单");
            names.push(String(r.name || "Pony")+" ("+reason+")");
         }
         return RCLocale.format("联机已暂停：{0}",names.join(" / "));
      }
      private function tick(e:TimerEvent):void
      {try {refresh();}catch(error:Error){reportError(error);}}
      private function before(e:Event):void
      {
         try
         {
            releaseFrame();refresh();
            if(_paused)
            {
               frameWorld=game.world;
               if(int(frameWorld.allStat)==1){injected=true;frameWorld.allStat=2;}
               // Keep native World.step's final recomputation and downstream
               // installed mod callbacks paused, without showing a stand UI.
               // Stand has no per-frame UI driver; SATS/Pip input remains live.
               var stand:Object=GameBridge.probe(frameWorld,"stand"),visual:Object=GameBridge.probe(frameWorld,"vstand");
               if(stand!=null && !stand.active && visual!=null && !visual.visible)
               {leasedStand=stand;nativeLeases[frameWorld]=stand;stand.active=true;}
            }
         }
         catch(error:Error) {reportError(error);}
      }
      private function after(e:Event):void
      {try {releaseFrame();refresh();}catch(error:Error){reportError(error);}}
      private function releaseFrame():void
      {
         // A genuine weapon stand opened later in this frame owns its flag.
         // Its public native visual distinguishes that from our invisible lease.
         if(leasedStand!=null && frameWorld!=null)
         {
            if(GameBridge.probe(frameWorld,"stand")===leasedStand
               && GameBridge.probe(GameBridge.probe(frameWorld,"vstand"),"visible")!=true)leasedStand.active=false;
            delete nativeLeases[frameWorld];
         }
         leasedStand=null;
         // World.step recomputes allStat from native overlays. Undo only a lease
         // still left behind (e.g. MainMenu skipped World.step), never onPause.
         if(injected && frameWorld!=null && int(frameWorld.allStat)==2 && nativeReasons(frameWorld)==0)
            frameWorld.allStat=1;
         frameWorld=null;injected=false;
      }
      private function reportError(error:Error):void
      {if(errors++<3)Log.d("RConnectPause: failed "+error+" "+error.getStackTrace());}
   }
}
