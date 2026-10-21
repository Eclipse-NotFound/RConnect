package rconnect.core {
   /** Only native integration I/O is substituted; RoomSync is copied unchanged. */
   public class MapGeneration {
      public var nativeTravelSupported:Boolean=true;
      public function MapGeneration(s:Session){}
      public function reset():void{}
      public function receive(info:Object):void{}
      public function differs(info:Object,land:Object):Boolean{return false;}
      public function sceneMode(land:Object,constructing:Boolean=false):Boolean{return false;}
   }
}
