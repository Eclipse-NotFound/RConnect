package rconnect.core {
   import rconnect.net.TcpLink;
   public class Session {
      public static const CONNECTED:String="connected",HOSTING:String="hosting",OFFLINE:String="offline";
      public var mode:String=OFFLINE,mod:RConnectMod,rooms:RoomSync;
      public var peers:Array=[],outbox:Array=[],link:TcpLink=new TcpLink(),server:Object;
      public var pause:Object,progress:Object;
      public function Session(m:RConnectMod) {
         mod=m;var self:Session=this;
         server={broadcast:function(v:Object):void{self.outbox.push(v);}};
      }
      public function flushProgress():void{}
      public function flushGhostDamage():void{}
      public function flushRoomReports(scene:Boolean=true,closing:Boolean=false):void{}
   }
}
