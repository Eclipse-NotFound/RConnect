package {
   import flash.events.Event;
   public class A22RoomEntryTestDoc extends RoomCooperationTestDoc {
      private var entry:RoomEntryProbe;
      public function A22RoomEntryTestDoc(){super("random_mane",false);addEventListener(Event.ENTER_FRAME,attach);}
      private function attach(e:Event):void {
         if(RConnectMod.instance==null)return;
         entry=new RoomEntryProbe(RConnectMod.instance);removeEventListener(Event.ENTER_FRAME,attach);
      }
      override protected function finish():void {if(entry!=null)entry.finish(false);super.finish();}
   }
}
