package authority {
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.ProgressEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   /** B has a distinct greeting. A packets never enable a legacy fallback. */
   public class Link {
      public static const LIMIT:int=1024*1024;
      public var message:Function, closed:Function, connected:Function;
      public var socket:Socket;
      private var buffer:ByteArray=new ByteArray();
      private var ended:Boolean=false;
      public function Link(socket:Socket=null) {
         this.socket=socket || new Socket();
         this.socket.addEventListener(Event.CONNECT,onConnect);
         this.socket.addEventListener(Event.CLOSE,onClose);
         this.socket.addEventListener(IOErrorEvent.IO_ERROR,onError);
         this.socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
         this.socket.addEventListener(ProgressEvent.SOCKET_DATA,onData);
      }
      public function connect(host:String,port:int):void {socket.connect(host,port);}
      public function send(value:Object):Boolean {
         if(ended || !socket.connected)return false;
         var bytes:ByteArray=new ByteArray();bytes.writeUTFBytes(JSON.stringify(value));
         if(bytes.length>LIMIT || socket.bytesPending>2*LIMIT){close("send backlog");return false;}
         try {socket.writeUnsignedInt(bytes.length);socket.writeBytes(bytes);socket.flush();}
         catch(e:*){close(String(e));return false;}
         return true;
      }
      public function close(reason:String="closed"):void {
         if(ended)return;
         ended=true;
         socket.removeEventListener(Event.CONNECT,onConnect);socket.removeEventListener(Event.CLOSE,onClose);
         socket.removeEventListener(IOErrorEvent.IO_ERROR,onError);socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
         socket.removeEventListener(ProgressEvent.SOCKET_DATA,onData);
         try{socket.close();}catch(ignored:*){}
         buffer.clear();
         if(closed!=null)closed(reason);
      }
      private function onConnect(e:Event):void {if(connected!=null)connected();}
      private function onClose(e:Event):void {close("peer closed");}
      private function onError(e:Event):void {close(e.toString());}
      private function onData(e:ProgressEvent):void {
         try {
            if(buffer.length+socket.bytesAvailable>2*LIMIT)throw new Error("receive backlog");
            socket.readBytes(buffer,buffer.length);buffer.position=0;
            while(buffer.bytesAvailable>=4 && !ended) {
               var start:int=buffer.position,size:uint=buffer.readUnsignedInt();
               if(size==0 || size>LIMIT)throw new Error("invalid frame size");
               if(buffer.bytesAvailable<size){buffer.position=start;break;}
               var item:Object=JSON.parse(buffer.readUTFBytes(size));
               if(item==null || item is Array || !(item.type is String))throw new Error("invalid message");
               if(message!=null)message(item);
            }
            if(!ended && buffer.position>0) {
               var rest:ByteArray=new ByteArray();
               if(buffer.bytesAvailable>0)rest.writeBytes(buffer,buffer.position,buffer.bytesAvailable);
               buffer=rest;
            }
         }catch(error:*){Log.error(error);close("invalid packet");}
      }
   }
}
