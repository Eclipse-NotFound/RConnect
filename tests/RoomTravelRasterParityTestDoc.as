package {
   import flash.events.Event;
   public class RoomTravelRasterParityTestDoc extends RoomTravelSceneTestDoc {
      private var parity:RoomRasterParity;
      public function RoomTravelRasterParityTestDoc(){addEventListener(Event.ENTER_FRAME,attach);}
      private function attach(e:Event):void {
         if(RConnectMod.instance==null)return;
         parity=new RoomRasterParity(RConnectMod.instance);removeEventListener(Event.ENTER_FRAME,attach);
      }
   }
}
