package rconnect.net
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.ServerSocketConnectEvent;
   import flash.net.ServerSocket;
   import flash.net.Socket;

   /**
    * 宿主端 TCP 服务器：接受连接、维护 peer 表、广播。
    * ServerSocket 是 AIR 专属 API（模组按 AIR 内容编译，运行时实测可用）。
    */
   public class HostServer extends EventDispatcher
   {
      public static const CLIENT_ADDED:String = "clientAdded";   // data: TcpLink
      public static const CLIENT_REMOVED:String = "clientRemoved"; // data: TcpLink
      public static const STARTED:String = "started";
      public static const FAILED:String = "failed";

      private var _server:ServerSocket = new ServerSocket();
      public var clients:Array = [];   // TcpLink[]
      public var port:int = 0;
      public var bound:Boolean = false;

      public function listen(port:int):void
      {
         this.port = port;
         try
         {
            _server.bind(port);
            _server.listen();
            bound = true;
            _server.addEventListener(ServerSocketConnectEvent.CONNECT, onAccept);
            dispatchEvent(new Event(STARTED));
         }
         catch(err:*)
         {
            trace("RConnectNet: listen failed: " + err);
            dispatchEvent(new Event(FAILED));
         }
      }

      private function onAccept(e:ServerSocketConnectEvent):void
      {
         var sock:Socket = e.socket;
         var link:TcpLink = new TcpLink(sock);
         link.addEventListener(TcpLink.CLOSED, onLinkClosed);
         link.addEventListener(TcpLink.FAILED, onLinkClosed);
         clients.push(link);
         dispatchEvent(new NetMessageEvent(CLIENT_ADDED, link));
      }

      private function onLinkClosed(e:Event):void
      {
         removeClient(e.target as TcpLink);
      }

      public function removeClient(link:TcpLink):void
      {
         var i:int = clients.indexOf(link);
         if(i >= 0)
         {
            clients.splice(i, 1);
            try
            {
               link.close();
            }
            catch(err:*)
            {
            }
            dispatchEvent(new NetMessageEvent(CLIENT_REMOVED, link));
         }
      }

      public function broadcast(msg:Object, except:TcpLink = null):void
      {
         for each(var link:TcpLink in clients)
         {
            if(link != except && link.isOpen)
            {
               link.send(msg);
            }
         }
      }

      public function close():void
      {
         try
         {
            _server.close();
         }
         catch(err:*)
         {
         }
         bound = false;
         while(clients.length > 0)
         {
            removeClient(clients[0]);
         }
      }
   }
}
