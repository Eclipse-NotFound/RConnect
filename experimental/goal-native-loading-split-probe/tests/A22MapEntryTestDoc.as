package {
   import flash.events.Event;
   public class A22MapEntryTestDoc extends NativeMapGenerationTestDoc {
      private var entry:RoomEntryProbe;
      public function A22MapEntryTestDoc(){super();addEventListener(Event.ENTER_FRAME,attach);}
      private function attach(e:Event):void {
         if(RConnectMod.instance==null)return;
         entry=new RoomEntryProbe(RConnectMod.instance);removeEventListener(Event.ENTER_FRAME,attach);
      }
      override protected function finish():void {if(entry!=null)entry.finish(true);super.finish();}
   }
}
