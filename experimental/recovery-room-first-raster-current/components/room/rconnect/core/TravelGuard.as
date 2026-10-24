package rconnect.core {
   import rconnect.game.GameBridge;
   public class TravelGuard {
      public static var returns:int=0;
      public static function reset():void{returns=0;}
      public static function clear():void{}
      public static function guardTravel(g:GameBridge,r:RoomSync):void{}
      public static function update(g:GameBridge,joining:Boolean):void{}
      public static function restricted(room:Object):Boolean{return room!=null && room.restricted===true;}
      public static function returnTo(g:GameBridge,room:Object):void{returns++;g.setRoom(String(room.key));}
      public static function allowTravel(id:String,travelId:String=""):void{}
      public static function endTravel():void{}
      public static function follow(g:GameBridge,info:Object,mirror:Boolean=false):Boolean {
         if(String(g.world.land.act.id)!=String(info.curLandId))throw new Error("Fixture: follow attempted inside the wrong native Land");
         return g.roomKey()==String(info.roomKey);
      }
   }
}
