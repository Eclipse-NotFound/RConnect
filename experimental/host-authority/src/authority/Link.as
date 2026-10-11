package authority {
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.ProgressEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.setTimeout;
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
         var bytes:ByteArray;
         try {bytes=WireCodec.encode(value);}catch(error:*){close(String(error));return false;}
         if(bytes.length>LIMIT || socket.bytesPending>2*LIMIT){Log.write("backlog",{bytes:bytes.length,pending:socket.bytesPending,type:value.type});close("send backlog");return false;}
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
      public function finish(finalMessage:Object,reason:String):void {
         // Socket.flush queues the bytes; closing in the same callback can
         // discard the leave packet. Detach the session immediately but let
         // AIR drain this one final message before releasing its socket.
         if(ended)return;
         message=null;connected=null;closed=null;
         if(!send(finalMessage)){close(reason);return;}
         var attempts:int=0,self:Link=this;
         var drain:Function=function():void {
            if(ended)return;
            if(!socket.connected || socket.bytesPending==0 || ++attempts>=20)self.close(reason);
            else setTimeout(drain,25);
         };
         setTimeout(drain,25);
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
               var payload:ByteArray=new ByteArray();buffer.readBytes(payload,0,size);
               var item:Object=WireCodec.decode(payload);
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
