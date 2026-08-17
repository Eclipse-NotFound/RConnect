package rconnect.net
{
   import rconnect.core.Log;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;

   /**
    * 单条 TCP 连接封装：长度前缀分帧、半包/粘包处理、JSON 消息分发。
    * 既可作为客户端主动 connect，也可 attach 服务端 accept 到的 Socket。
    */
   public class TcpLink extends EventDispatcher
   {
      public static const MESSAGE:String = "message";   // data: 解码后的 Object
      public static const CONNECTED:String = "connected";
      public static const CLOSED:String = "closed";
      public static const FAILED:String = "failed";

      public var id:int = -1;
      public var peerName:String = "";
      public var socket:Socket;
      public var isOpen:Boolean = false;

      private var _rbuf:ByteArray = new ByteArray();
      private var _closedNotified:Boolean = false;

      public function TcpLink(sock:Socket = null)
      {
         if(sock != null)
         {
            attach(sock);
         }
      }

      /** 客户端：主动连接。 */
      public function connect(host:String, port:int):void
      {
         socket = new Socket();
         wireEvents();
         try
         {
            socket.connect(host, port);
         }
         catch(err:*)
         {
            fail("connect threw: " + err);
         }
      }

      /** 服务端：接管 accept 到的连接。 */
      public function attach(sock:Socket):void
      {
         socket = sock;
         isOpen = sock.connected;
         wireEvents();
         dispatchEvent(new Event(CONNECTED));
      }

      public function send(msg:Object):void
      {
         if(socket == null || !socket.connected)
         {
            return;
         }
         var body:String = Protocol.encode(msg);
         try
         {
            // 长度必须按 UTF-8 字节数（String.length 是字符数，
            // 非 ASCII（如俄文房间名）会导致长度前缀与实际字节不符→流错位）
            var ba:ByteArray = new ByteArray();
            ba.writeUTFBytes(body);
            socket.writeInt(ba.length);
            socket.writeBytes(ba, 0, ba.length);
            socket.flush();
         }
         catch(err:*)
         {
            Log.d("RConnectNet: send failed: " + err);
            fail("send threw: " + err);
         }
      }

      public function close():void
      {
         try
         {
            if(socket != null && socket.connected)
            {
               socket.close();
            }
         }
         catch(err:*)
         {
         }
         if(!_closedNotified)
         {
            _closedNotified = true;
            isOpen = false;
            dispatchEvent(new Event(CLOSED));
         }
      }

      private function wireEvents():void
      {
         socket.addEventListener(Event.CONNECT, onConnect);
         socket.addEventListener(Event.CLOSE, onClose);
         socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
         socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
         socket.addEventListener(ProgressEvent.SOCKET_DATA, onData);
      }

      private function onConnect(e:Event):void
      {
         isOpen = true;
         Log.d("RConnectNet: link connected");
         dispatchEvent(new Event(CONNECTED));
      }

      private function onClose(e:Event):void
      {
         Log.d("RConnectNet: link closed");
         if(!_closedNotified)
         {
            _closedNotified = true;
            isOpen = false;
            dispatchEvent(new Event(CLOSED));
         }
      }

      private function onError(e:IOErrorEvent):void
      {
         fail("IOError: " + e.text);
      }

      private function onSecError(e:SecurityErrorEvent):void
      {
         fail("SecurityError: " + e.text);
      }

      private function fail(reason:String):void
      {
         Log.d("RConnectNet: link failed: " + reason);
         if(!_closedNotified)
         {
            _closedNotified = true;
            isOpen = false;
            dispatchEvent(new Event(FAILED));
         }
      }

      private function onData(e:ProgressEvent):void
      {
         try
         {
            socket.readBytes(_rbuf, _rbuf.length);
         }
         catch(err:*)
         {
            fail("read threw: " + err);
            return;
         }
         _rbuf.position = 0;
         // 循环解帧：长度不足时回退游标，等待更多数据（半包）
         while(_rbuf.bytesAvailable >= 4)
         {
            var headPos:int = _rbuf.position;
            var len:int = _rbuf.readInt();
            if(len <= 0 || len > 1024 * 1024)
            {
               fail("bad frame length: " + len);
               return;
            }
            if(_rbuf.bytesAvailable < len)
            {
               _rbuf.position = headPos;   // 回退，等待剩余字节
               break;
            }
            var json:String = _rbuf.readUTFBytes(len);
            var msg:Object = Protocol.decode(json);
            if(msg != null)
            {
               dispatchEvent(new NetMessageEvent(MESSAGE, msg));
            }
         }
         // 丢弃已消费部分，压紧缓冲
         if(_rbuf.position > 0)
         {
            var rest:ByteArray = new ByteArray();
            rest.writeBytes(_rbuf, _rbuf.position, _rbuf.bytesAvailable);
            _rbuf = rest;
         }
      }
   }
}
