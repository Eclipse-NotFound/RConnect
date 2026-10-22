package rconnect.net {
   import flash.events.EventDispatcher;
   import pausecheck.Probe;
   public class TcpLink extends EventDispatcher {
      public static const MESSAGE:String="message";
      public var isOpen:Boolean=true,sent:Array=[];
      public function send(o:Object):void{sent.push(o);Probe.events.push("pause-"+o.op);}
      public function receive(o:Object):void{dispatchEvent(new NetMessageEvent(MESSAGE,o));}
   }
}
