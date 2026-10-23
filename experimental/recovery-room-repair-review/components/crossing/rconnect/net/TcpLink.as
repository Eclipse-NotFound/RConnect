package rconnect.net {
   public class TcpLink {
      public var id:int=1,messages:Array=[];
      public function send(v:Object):void{messages.push(v);}
   }
}
