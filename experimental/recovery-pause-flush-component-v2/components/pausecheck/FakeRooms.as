package pausecheck {
   public class FakeRooms {
      public var ready:Boolean=true,busy:Boolean=false,authority:Boolean=true,current:Boolean=true;
      public var epoch:int=7,term:int=3;
      public function get canSyncWorld():Boolean {return ready&&!busy&&current;}
      public function stamp(o:Object):Object {o.roomKey="room-a";o.roomEpoch=epoch;o.roomTerm=term;return o;}
      public function notice(s:String):void {}
   }
}
