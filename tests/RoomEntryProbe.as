package {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;
   import rconnect.core.Log;
   import rconnect.core.Session;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   /** Observe real native transitions at the final rendering boundary. The
    * enclosing native suites still compare templates, tiles, doors and owners. */
   public class RoomEntryProbe {
      private var mod:RConnectMod,confirmedRoom:Object,confirmedLand:Object,confirmedStamp:Object;
      private var pendingFrames:int=0,loadFrames:int=0,releasedFrames:int=0,links:Dictionary=new Dictionary();
      private var failures:Object={},finished:Boolean=false;
      private var pictures:Object={},pendingAt:int=-1,waits:Array=[];
      private var worldPackets:int=0;
      public function RoomEntryProbe(m:RConnectMod) {
         mod=m;m.stage.addEventListener(Event.RENDER,render,false,-2147483648);
         m.stage.addEventListener(Event.ENTER_FRAME,watch,false,200000);watch();
      }
      private function check(ok:Boolean,label:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"room-entry "+label);
      }
      private function require(ok:Boolean,label:String):void {
         if(!ok && !failures[label]) {
            failures[label]=true;check(false,label);
            Log.d("ROOM ENTRY FAILURE "+JSON.stringify({label:label,at:getTimer(),room:mod.game.roomKey(),
               confirmed:confirmedStamp,stamp:mod.session.rooms.stamp({}),sameRoom:mod.game.world.loc===confirmedRoom,
               sameLand:mod.game.world.land===confirmedLand,ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,
               exit:mod.game.world.t_exit,transition:mod.game.isTransitioning()}));
         }
      }
      private function watch(e:Event=null):void {
         var session:Object=mod.session;
         observeLink(session.link as TcpLink);
         for each(var peer:Object in session.peers)observeLink(peer.link as TcpLink);
      }
      private function observeLink(link:TcpLink):void {
         if(link==null || links[link])return;
         links[link]=true;link.addEventListener(TcpLink.MESSAGE,settled);
      }
      private function settled(e:NetMessageEvent):void {
         var p:Object=e.data,rooms:Object=mod.session.rooms;
         if(p!=null && mod.session.mode==Session.CONNECTED) {
            var info:Object=null,hasWorld:Boolean=false;
            if(p.type=="unitsync"){info=p.worldInfo;hasWorld=true;}
            else if(p.type=="worldstate" && (p.enemyMotion is Array || p.lootMotion is Array || p.wallPaint is Array)) {
               hasWorld=true;
               for each(var player:Object in p.players)if(int(player.id)==0 && player.snap!=null)info=player.snap.worldInfo;
            }
            if(hasWorld) {
               worldPackets++;
               require(info!=null && String(p.roomKey)==String(info.roomKey),"world payload and room stamp name the same native room");
            }
         }
         if(p==null || p.type!="room")return;
         // Session handles these messages first. Record the actual confirmed
         // identity here: a test/native action can travel again before RENDER.
         if((mod.session.mode==Session.HOSTING && p.op=="ack") ||
            (mod.session.mode==Session.CONNECTED && p.op=="grant")) {
            if(!rooms.ready || rooms.busy || int(p.barrier)!=int(rooms.term))return;
            confirmedRoom=mod.game.world.loc;confirmedLand=mod.game.world.land;
            confirmedStamp=rooms.stamp({});
         }
      }
      private function render(e:Event):void {
         if(finished || mod.game==null || mod.game.world==null)return;
         var session:Object=mod.session,w:Object=mod.game.world,rooms:Object=session.rooms;
         if(session.mode!=Session.CONNECTED && !(session.mode==Session.HOSTING && session.peers.length))return;
         var visual:DisplayObject=w.visual as DisplayObject;
         if(w.loc==null || visual==null || visual.parent==null)return;
         var parent:DisplayObjectContainer=visual.parent;
         var cover:DisplayObject=parent.getChildByName("rconnect-room-entry");
         var earlyLoad:Boolean=int(w.t_exit)>0 && int(w.t_exit)<=16;
         var sameConfirmed:Boolean=confirmedRoom!=null && w.loc===confirmedRoom && w.land===confirmedLand;
         // A remote-only handoff does not invalidate this confirmed native
         // scene. It must remain visible while the ownership messages travel.
         var pending:Boolean=!rooms.ready || !sameConfirmed;
         if(pending) {
            if(pendingAt<0)pendingAt=getTimer();
            pendingFrames++;if(earlyLoad)loadFrames++;
            require(cover!=null && cover.visible && cover.alpha==1 && parent.getChildIndex(cover)>parent.getChildIndex(visual),
               "unconfirmed native scene is covered at render");
            capture("waiting",w);
         }
         if(confirmedRoom!=null && !sameConfirmed)
            require(!rooms.accepts(confirmedStamp),"new native room rejects previous room state");
         if(!sameConfirmed)
            require(!rooms.canSyncWorld,"new native room cannot publish before handoff");
         if(!pending) {
            if(pendingAt>=0){waits.push(getTimer()-pendingAt);pendingAt=-1;}
            releasedFrames++;
            require(cover==null,"completed checkpoint has no leftover loading cover");
            require(w.loc===mod.game.loc && w.land.loc===w.loc && w.gg.loc===w.loc,"first released frame has one native room identity");
            if(pendingFrames>0)capture("ready",w);
         }
      }
      private function capture(label:String,w:Object):void {
         if(pictures[label]!=null || (w.vblack.visible && w.vblack.alpha>0))return;
         try {
            var b:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
            b.draw(mod.stage);pictures[label]=b;
         }catch(error:Error){require(false,"capture "+label+": "+error);}
      }
      public function finish(nativeLoad:Boolean):void {
         if(finished)return;finished=true;mod.stage.removeEventListener(Event.RENDER,render);
         mod.stage.removeEventListener(Event.ENTER_FRAME,watch);
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,settled);
         check(pendingFrames>0,"observed pending frames="+pendingFrames);
         check(releasedFrames>0,"observed settled frames="+releasedFrames);
         if(nativeLoad)check(loadFrames>0,"observed native exit 16..1 frames="+loadFrames);
         if(mod.session.mode==Session.CONNECTED)check(worldPackets>0,"checked incoming world packet identities="+worldPackets);
         Log.d("ROOM ENTRY waits-ms="+JSON.stringify(waits)+" unfinished="+(pendingAt>=0));
         for(var label:String in pictures) {
            var b:BitmapData=pictures[label],file:FileStream=new FileStream();
            try {
               file.open(File.applicationStorageDirectory.resolvePath("presentation-room-entry-"+label+".png"),FileMode.WRITE);
               file.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));
            }catch(error:Error){check(false,"write capture "+label+": "+error);}
            finally {file.close();b.dispose();}
         }
      }
   }
}
