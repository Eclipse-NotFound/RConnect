package rconnect.net
{
   import flash.events.Event;

   /** 携带 payload 数据的事件（消息对象或连接对象）。 */
   public class NetMessageEvent extends Event
   {
      public var data:Object;

      public function NetMessageEvent(type:String, data:Object = null)
      {
         super(type);
         this.data = data;
      }

      override public function clone():Event
      {
         return new NetMessageEvent(type, data);
      }
   }
}
