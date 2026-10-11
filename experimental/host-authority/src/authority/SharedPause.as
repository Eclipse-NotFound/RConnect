package authority {
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   /** One host freeze boundary; native UI and the network remain alive. */
   public final class SharedPause {
      public var enabled:Boolean=false,paused:Boolean=false,remote:Boolean=false,epoch:uint=0;
      public var policyMenus:Boolean=false,policySats:Boolean=false,remoteMenus:Boolean=false,remoteSats:Boolean=false;
      private var clips:Array=[];
      public static function requested(world:Object):Boolean {
         return world.sats.active || menus(world);
      }
      public static function menus(world:Object):Boolean {return world.pip.active || world.stand.active || world.gui.guiPause || world.mm.active;}
      public function update(session:HostSession):void {
         var w:Object=session.access.world,next:Boolean=enabled && (remote || requested(w)) ||
            policyMenus && (remoteMenus || menus(w)) || policySats && (remoteSats || w.sats.active);
         if(next!=paused) {
            paused=next;++epoch;
            if(next) {
               for each(var record:Object in session.runtime.rooms.records)freeze(record.visual);
            }else {
               for each(var rec:Object in clips)if(rec.playing)rec.clip.play();
               clips=[];w.onPause=false;
            }
            session.publish();
         }
         if(paused)w.onPause=true;
         // Native UI pauses the only original player through allStat. B lets
         // the other room run when shared pause is disabled.
         else if(w.allStat==2 && !w.mm.active)w.allStat=1;
      }
      private function freeze(parent:DisplayObjectContainer):void {
         var clip:MovieClip=parent as MovieClip;
         if(clip!=null){clips.push({clip:clip,playing:clip.isPlaying});clip.stop();}
         for(var i:int=0;i<parent.numChildren;i++)if(parent.getChildAt(i) is DisplayObjectContainer)freeze(parent.getChildAt(i) as DisplayObjectContainer);
      }
      public function dispose():void {for each(var rec:Object in clips)if(rec.playing)rec.clip.play();clips=[];paused=false;}
   }
}
