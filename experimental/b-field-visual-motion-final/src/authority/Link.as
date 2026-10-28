package authority {
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.ProgressEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.setTimeout;
   import flash.utils.getTimer;
   /** B has a distinct greeting. A packets never enable a legacy fallback. */
   public class Link {
      public static const LIMIT:int=1024*1024;
      public var message:Function, closed:Function, connected:Function;
      public var socket:Socket;
      private var buffer:ByteArray=new ByteArray();
      private var readOffset:uint=0;
      private static const COMPACT_AFTER:uint=64*1024;
      private var ended:Boolean=false;
      private var scheduled:Boolean=false,draining:Boolean=false;
      private var peerEnded:Boolean=false;
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
         buffer.clear();readOffset=0;
         if(closed!=null)closed(reason);
      }
      public function finish(finalMessage:Object,reason:String):void {
         // Socket.flush/bytesPending only describe the local output buffer.
         // Wait for the peer application to acknowledge normal Leave, so its
         // final character confirmation has actually been consumed before EOF.
         if(ended)return;
         var acknowledged:Boolean=false,deadline:int=getTimer()+5000;
         message=function(value:Object):void {
            if(value.session!==finalMessage.session)return;
            if(value.type=="leave-ack")acknowledged=true;
            else if(value.type=="leave") {
               acknowledged=true;send({type:"leave-ack",session:finalMessage.session});
            }
         };
         connected=null;closed=null;
         if(!send(finalMessage)){close(reason);return;}
         var self:Link=this;
         var drain:Function=function():void {
            if(ended)return;
            if(!socket.connected || acknowledged && socket.bytesPending==0 || getTimer()>=deadline)self.close(reason);
            else setTimeout(drain,25);
         };
         setTimeout(drain,25);
      }
      private function onConnect(e:Event):void {if(connected!=null)connected();}
      private function onClose(e:Event):void {
         if(ended)return;
         // CLOSE can arrive while our bounded receive loop has already queued
         // another batch. Process every complete ordered message already read,
         // including the final character state and normal Leave notification.
         peerEnded=true;
         try {if(socket.bytesAvailable>0)socket.readBytes(buffer,buffer.length);}
         catch(ignored:*){} // The socket may already have released its input.
         if(!draining)drain();
      }
      private function onError(e:Event):void {close(e.toString());}
      private function onData(e:ProgressEvent):void {
         try {
            if(buffer.length-readOffset+socket.bytesAvailable>2*LIMIT)throw new Error("receive backlog");
            socket.readBytes(buffer,buffer.length);
            if(!scheduled && !draining)drain();
         }catch(error:*){Log.error(error);close("invalid packet");}
      }
      private function drain():void {
         scheduled=false;if(ended || draining)return;draining=true;
         var began:int=Timing.start();
         var deadline:int=getTimer()+8;
         try {
            while(!ended && buffer.length-readOffset>=4) {
               buffer.position=readOffset;
               var size:uint=buffer.readUnsignedInt();
               if(size==0 || size>LIMIT)throw new Error("invalid frame size");
               if(buffer.bytesAvailable<size)break;
               var payload:ByteArray=new ByteArray();buffer.readBytes(payload,0,size);
               // Commit only a complete payload. A partial header/body keeps
               // this cursor so a later socket event resumes the same packet.
               readOffset=buffer.position;
               var item:Object=WireCodec.decode(payload);
               if(message!=null)message(item);
               // Preserve every ordered delta, but yield after bounded work so
               // ENTER_FRAME can sample current controls and show the result.
               // A first full room can itself exceed this budget; never drop it.
               if(getTimer()>=deadline)break;
            }
            if(!ended)compact();
            if(!ended && buffer.length-readOffset>=4) {
               buffer.position=readOffset;var nextSize:uint=buffer.readUnsignedInt();buffer.position=readOffset;
               if(nextSize==0 || nextSize>LIMIT)throw new Error("invalid frame size");
               if(buffer.length-readOffset>=nextSize+4){scheduled=true;setTimeout(drain,1);}
            }
         }catch(error:*){Log.error(error);close("invalid packet");}
         finally {
            draining=false;Timing.end("network.receiveBatch",began);
            if(peerEnded && !ended && !scheduled)close(buffer.length==readOffset?"peer closed":"peer closed with incomplete frame");
         }
      }
      private function compact():void {
         if(readOffset==0)return;
         if(readOffset==buffer.length){buffer.clear();readOffset=0;return;}
         // A slow decoder can yield with many complete packets still queued.
         // Do not copy that entire tail after each 8 ms batch. Copy only when
         // the consumed prefix is large and at least as long as the remainder;
         // every retained byte is then charged to bytes already consumed.
         if(readOffset<COMPACT_AFTER || readOffset<buffer.length-readOffset)return;
         var rest:ByteArray=new ByteArray();
         rest.writeBytes(buffer,readOffset,buffer.length-readOffset);
         buffer=rest;readOffset=0;
      }
   }
}
