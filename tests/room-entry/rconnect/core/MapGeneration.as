package rconnect.core {
   public class MapGeneration {
      public function MapGeneration(s:Session){}
      public function reset():void{}
      public function receive(info:Object):void{}
      public function differs(info:Object,land:Object):Boolean{return false;}
      public function sceneMode(land:Object,constructing:Boolean=false):Boolean{return false;}
   }
}
