package rconnect.core {
   import rconnect.game.GameBridge;
   public class TravelGuard {
      public static function reset():void{}
      public static function clear():void{}
      public static function guardTravel(g:GameBridge,r:RoomSync):void{}
      public static function update(g:GameBridge,joining:Boolean):void{}
      public static function restricted(room:Object):Boolean{return false;}
      public static function returnTo(g:GameBridge,room:Object):void{}
      public static function allowTravel(id:String):void{}
      public static function endTravel():void{}
      public static function follow(g:GameBridge,info:Object,mirror:Boolean=false):Boolean{return true;}
   }
}
