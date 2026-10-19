package {
   import flash.utils.setTimeout;
   import rconnect.net.*;
   public class SecurityTestLink extends TcpLink {
      public var other:SecurityTestLink,sent:Array=[],dropStates:int=0,dropped:int=0;
      public function SecurityTestLink(){isOpen=true;}
      override public function send(q:Object):void {
         var p:Object=JSON.parse(JSON.stringify(q));sent.push(p);
         if(p.op=="state" && dropStates>0){dropStates--;dropped++;return;}
         setTimeout(function():void {other.dispatchEvent(new NetMessageEvent(TcpLink.MESSAGE,p));},0);
      }
   }
}
