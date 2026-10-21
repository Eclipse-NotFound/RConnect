package {
   import flash.display.*;
   import flash.events.Event;
   import flash.filesystem.*;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   /** External native-game observer, never included in production. */
   public final class NativeLoadingProbe {
      private var mod:RConnectMod,frames:int=0,tail:int=0,errors:Object={},picture:BitmapData;
      private var started:int=-1,ended:int=-1;
      private var signature:String="",phases:Array=[],seenErrors:int=0;
      public function NativeLoadingProbe(m:RConnectMod) {
         mod=m;m.stage.addEventListener(Event.RENDER,observe,false,-2147483648);
         // A render sample alone misses synchronous generation. Record before
         // and after native stepping, using a shared wall clock across AIR IDs.
         m.stage.addEventListener(Event.ENTER_FRAME,before,false,2147483647);
         m.stage.addEventListener(Event.ENTER_FRAME,after,false,-2147483648);
      }
      private function before(e:Event):void {phase("before");}
      private function after(e:Event):void {phase("after");}
      private function phase(edge:String):void {
         var w:Object=mod.game.world;if(w==null || w.loc==null)return;
         var key:String=int(w.t_exit)+":"+Boolean(w.vwait.visible)+":"+mod.game.roomKey()+":"+mod.session.rooms.entryPending;
         if(key==signature)return;signature=key;
         var row:Object={at:getTimer(),wallMs:new Date().time,edge:edge,exit:int(w.t_exit),
            visible:Boolean(w.vwait.visible),room:mod.game.roomKey(),pending:mod.session.rooms.entryPending,
            ready:mod.session.rooms.ready,hold:mod.game.roomHold};
         phases.push(row);Log.d("NATIVE LOADING PHASE "+JSON.stringify(row));
      }
      private function require(ok:Boolean,label:String):void {
         if(!ok && !errors[label]){errors[label]=true;seenErrors++;Log.d("COOP FAIL native-loading "+label);}
      }
      private function observe(e:Event):void {
         var w:Object=mod.game.world;if(w==null || w.loc==null)return;
         phase("render");
         var visual:DisplayObject=w.visual as DisplayObject;if(visual==null || visual.parent==null)return;
         var cover:DisplayObjectContainer=visual.parent.getChildByName("rconnect-room-entry") as DisplayObjectContainer;
         if(cover==null)return;
         frames++;if(started<0)started=getTimer();ended=getTimer();
         var asset:Object=cover.getChildByName("rconnect-native-loading");
         require(asset!=null,"pending room contains native loading artwork");if(asset==null)return;
         require(getQualifiedClassName(asset)==getQualifiedClassName(w.vwait),"loading artwork is the actual native class");
         require(asset!==w.vwait && w.vwait.parent!==cover,"native loader ownership is retained");
         require(cover.numChildren==1,"no additional handoff text overlay");
         require(asset.progres.text==w.vwait.progres.text,"localized native text agrees");
         require(asset.skill.currentFrame==w.vwait.skill.currentFrame,"native illustration agrees");
         require(asset.story.visible==w.vwait.story.visible,"native story state agrees");
         if(!w.vwait.visible) {
            tail++;require(asset.visible,"native loading remains visible during network completion");
            if(picture==null) {
               picture=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);picture.draw(mod.stage);
            }
         }
      }
      public function finish():void {
         mod.stage.removeEventListener(Event.RENDER,observe);
         mod.stage.removeEventListener(Event.ENTER_FRAME,before);
         mod.stage.removeEventListener(Event.ENTER_FRAME,after);
         // A shorter handoff may have no rendered tail at all. Do not require
         // the very delay this change is meant to remove in order to pass.
         Log.d("COOP "+(frames>0&&seenErrors==0?"PASS ":"FAIL ")+"native-loading observed native asset across barrier frames="+frames+" tail="+tail);
         Log.d("NATIVE LOADING RESULT "+JSON.stringify({frames:frames,tail:tail,started:started,ended:ended,failures:errors,phases:phases}));
         if(picture!=null) {
            var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("presentation-native-loading-wait.png"),FileMode.WRITE);
            stream.writeBytes(picture.encode(picture.rect,new PNGEncoderOptions()));stream.close();picture.dispose();picture=null;
         }
      }
   }
}
