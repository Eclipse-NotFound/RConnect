package authority {
   import flash.display.Stage;
   import flash.events.Event;
   /** Native resizeDisplay opens PipBuck even when the viewport did not change.
    * Retain that behavior for real resizes; redundant AIR notifications must
    * not become player menu input. Other resize listeners still receive them. */
   public final class NativeViewport {
      private var stage:Stage,original:Function;
      private var width:int,height:int,disposed:Boolean=false;
      public function NativeViewport(stage:Stage,world:Object) {
         this.stage=stage;original=world.mm.resizeDisplay;
         width=stage.stageWidth;height=stage.stageHeight;
         stage.removeEventListener(Event.RESIZE,original);
         stage.addEventListener(Event.RESIZE,resized);
      }
      private function resized(event:Event):void {
         if(stage.stageWidth==width && stage.stageHeight==height)return;
         width=stage.stageWidth;height=stage.stageHeight;
         original(event);
      }
      public function dispose():void {
         if(disposed)return;disposed=true;
         stage.removeEventListener(Event.RESIZE,resized);
         stage.addEventListener(Event.RESIZE,original);
      }
   }
}
