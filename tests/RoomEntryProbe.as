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
   import rconnect.core.Log;
   import rconnect.core.Session;
   /** Observe real native transitions at the final rendering boundary. The
    * enclosing native suites still compare templates, tiles, doors and owners. */
   public class RoomEntryProbe {
      private var mod:RConnectMod,lastSettled:Object,pendingFrames:int=0,loadFrames:int=0,releasedFrames:int=0;
      private var failures:Object={},finished:Boolean=false;
      private var pictures:Object={},pendingAt:int=-1,waits:Array=[];
      public function RoomEntryProbe(m:RConnectMod) {
         mod=m;m.stage.addEventListener(Event.RENDER,render,false,-2147483648);
      }
      private function check(ok:Boolean,label:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"room-entry "+label);
      }
      private function require(ok:Boolean,label:String):void {
         if(!ok && !failures[label]){failures[label]=true;check(false,label);}
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
         var pending:Boolean=!rooms.ready || rooms.busy || earlyLoad || (lastSettled!=null && w.loc!==lastSettled && mod.game.isTransitioning());
         if(pending) {
            if(pendingAt<0)pendingAt=getTimer();
            pendingFrames++;if(earlyLoad)loadFrames++;
            require(cover!=null && cover.visible && cover.alpha==1 && parent.getChildIndex(cover)>parent.getChildIndex(visual),
               "unconfirmed native scene is covered at render");
            capture("waiting",w);
         }
         if(!rooms.ready || rooms.busy || mod.game.isTransitioning()) {
            if(lastSettled!=null && w.loc!==lastSettled)
               require(!rooms.accepts(rooms.stamp({})),"new native room rejects previous room state");
         }else {
            if(pendingAt>=0){waits.push(getTimer()-pendingAt);pendingAt=-1;}
            releasedFrames++;lastSettled=w.loc;
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
         check(pendingFrames>0,"observed pending frames="+pendingFrames);
         check(releasedFrames>0,"observed settled frames="+releasedFrames);
         if(nativeLoad)check(loadFrames>0,"observed native exit 16..1 frames="+loadFrames);
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
