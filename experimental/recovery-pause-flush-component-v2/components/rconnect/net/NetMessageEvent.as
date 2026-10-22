package rconnect.net {
   import flash.events.Event;
   public class NetMessageEvent extends Event {
      public var data:Object;
      public function NetMessageEvent(type:String,value:Object){super(type);data=value;}
   }
}
