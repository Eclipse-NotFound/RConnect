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
   import flash.utils.getTimer;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /**
    * 单条 TCP 连接：长度前缀、半包/粘包处理，协商后的纯数据二进制或 JSON。
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
      public var binaryEnabled:Boolean = false;
      public var binarySent:int=0,binaryReceived:int=0;

      private var _rbuf:ByteArray = new ByteArray();
      private var _closedNotified:Boolean = false;

      // Isolated diagnostic only. No wire fields or transport decisions change.
      private static var timingEnabled:Boolean=false;
      private static var timingRole:String="",timingApp:String="";
      private static var timingRound:int=-1,timingNext:int=0;
      private static var timingActive:Boolean=false,timingOverflow:Boolean=false;
      private static var timingDropped:int=0,timingFaultCount:int=0;
      private static var timingRows:Array=[],timingFaults:Array=[];
      private static var timingWritten:Object={};
      private static var timingStarted:Object,timingLocalSampled:Object,timingPeerSampled:Object;
      private static var timingAck:Object;
      private static var timingCalls:int=0,timingTotal:int=0,timingMax:int=0;
      // One isolated off/on trial. These rows never enter a network packet.
      private static var socketTrialMode:String="",socketTrialRequested:String="";
      private static var socketTrialCount:int=0;
      private static var socketTrialRows:Array=[],socketTrialSockets:Array=[];

      public static function wallAckTimingConfigure(flag:*,role:String,trial:*=""):void
      {
         if(String(flag)!="1")return;
         try {
            var app:String=NativeApplication.nativeApplication.applicationID;
            var match:Object=/^pfe-modsettings-rconnect-coop-(host|join)-[0-9a-f]{10}$/.exec(app);
            if(app=="pfe" || match==null || String(match[1])!=role) {
               Log.d("WALL ACK TIMING DISABLED: isolated application/role required");return;
            }
            if(timingEnabled){timingFault("duplicate configure");return;}
            timingApp=app;timingRole=role;timingEnabled=true;
            if(trial!=="") {
               socketTrialRequested=String(trial).substr(0,40);
               if(!(trial is String) || (trial!=="off" && trial!=="on"))
                  timingFault("socketNoDelayTrial requires exact off/on string");
               else socketTrialMode=String(trial);
            }
         } catch(error:*) {timingFault("configure: "+String(error));}
      }

      /** Run only on a real CONNECT or accepted Socket, before original dispatch. */
      private function socketNoDelayApply(direction:String,actual:Socket):void
      {
         if(!timingEnabled || socketTrialMode=="")return;
         var row:Object=null;
         try {
            socketTrialCount++;
            if(socketTrialRows.length>=8)throw new Error("trial connection bound exceeded");
            if(socketTrialSockets.indexOf(actual)>=0)throw new Error("duplicate trial Socket");
            row={connection:socketTrialCount,role:timingRole,direction:direction,linkIdAtSet:id,
               at:getTimer(),wall:new Date().time,expected:socketTrialMode=="on",
               sameSocket:actual===socket,connectedAtSet:false,setSucceeded:false,readSucceeded:false,
               readback:null,success:false};
            socketTrialRows.push(row);socketTrialSockets.push(actual);
            if(actual==null || actual!==socket || !actual.connected)
               throw new Error("trial requires the actual connected Socket");
            row.connectedAtSet=true;
            row.localAddress=actual.localAddress;row.localPort=actual.localPort;
            row.remoteAddress=actual.remoteAddress;row.remotePort=actual.remotePort;
            if(direction!=(timingRole=="host"?"accept":"connect"))
               throw new Error("trial role/direction mismatch");
            // Deliberately attempt the real setter, including false in the off arm.
            // A missing API is failed evidence, never an unavailable-is-success guard.
            Object(actual)["tcpNoDelay"]=row.expected;
            row.setSucceeded=true;
            var value:*=Object(actual)["tcpNoDelay"];
            row.readSucceeded=true;row.readback=value;
            row.success=value is Boolean && value===row.expected;
            if(!row.success)throw new Error("trial setter/readback mismatch");
         }catch(error:*) {
            if(row!=null)row.error=String(error).substr(0,400);
            timingFault("socket trial apply: "+String(error));
         }
      }

      /** Recheck after sampling; no mutation or per-packet observations. */
      private static function socketNoDelayStatus():Object
      {
         if(socketTrialMode=="" && socketTrialRequested=="")return null;
         var result:Object={requested:socketTrialRequested,mode:socketTrialMode,enabled:socketTrialMode!="",
            expected:socketTrialMode==""?null:socketTrialMode=="on",qualified:false,
            connectionCount:socketTrialCount,connections:[]};
         try {
            var good:Boolean=socketTrialMode!="" && socketTrialCount==1 && socketTrialRows.length==1;
            if(!good)timingFault("socket trial requires one recorded connection");
            for(var i:int=0;i<socketTrialRows.length;i++) {
               var source:Object=socketTrialRows[i],copy:Object={};
               for(var key:String in source)copy[key]=source[key];
               result.connections.push(copy);
               copy.checkedAt=getTimer();copy.checkedWall=new Date().time;
               copy.connectedAtCheck=false;copy.readSucceededAtCheck=false;copy.readbackAtCheck=null;
               copy.qualified=false;
               try {
                  var actual:Socket=socketTrialSockets[i] as Socket;
                  copy.connectedAtCheck=actual!=null && actual.connected;
                  if(source.success!==true || !copy.connectedAtCheck)
                     throw new Error("trial Socket not successfully set and still connected");
                  var value:*=Object(actual)["tcpNoDelay"];
                  copy.readSucceededAtCheck=true;copy.readbackAtCheck=value;
                  copy.qualified=value is Boolean && value===source.expected;
                  if(!copy.qualified)throw new Error("trial Socket value changed");
               }catch(readError:*) {
                  copy.checkError=String(readError).substr(0,400);
                  timingFault("socket trial recheck: "+String(readError));
               }
               if(copy.qualified!==true)good=false;
            }
            result.qualified=good;
         }catch(error:*) {
            result.error=String(error).substr(0,400);
            timingFault("socket trial snapshot: "+String(error));
         }
         return result;
      }

      private static function timingFault(reason:String):void
      {
         timingFaultCount++;
         if(timingFaults.length<16)timingFaults.push(reason.substr(0,400));
      }

      private static function timingClock():Object
      {return {at:getTimer(),wall:new Date().time};}

      private static function timingMeta(msg:Object,batch:Object,peer:int,paint:Boolean=false):Object
      {
         var cells:Array=paint?batch as Array:batch.cells as Array;
         if(cells==null)throw new Error("missing diagnostic cells");
         if(!paint && cells.length>3)timingFault("ordinary report/ACK exceeds three cells");
         var key:String=String(msg.roomKey);
         if(msg.roomKey==null || msg.roomEpoch==null || msg.roomTerm==null || key.length>256)
            timingFault("missing/oversized room identity");
         var seq:*=paint?null:batch.seq;
         if(!paint && (seq==null || !isFinite(Number(seq)) || Number(seq)<=0 || Number(seq)!=int(seq)))
            timingFault("invalid wall sequence");
         var out:Array=[],chars:int=0;
         for(var i:int=0;i<Math.min(3,cells.length);i++) {
            var c:Object=cells[i];if(c==null)throw new Error("null diagnostic cell");
            out.push({x:c.x,y:c.y,v:c.v,sv:c.sv,full:c.full===true,needsNative:c.needsNative===true});
            if(c.d is String)chars+=String(c.d).length;
         }
         return {type:String(msg.type),roomKey:key.substr(0,256),roomEpoch:msg.roomEpoch,roomTerm:msg.roomTerm,
            seq:seq,tick:msg.tick==null?null:msg.tick,linkId:peer,cellCount:cells.length,
            sampledCellCount:out.length,metadataPrefixOnly:cells.length>out.length,prefixEncodedChars:chars,cells:out};
      }

      private static function timingPush(kind:String,clock:Object,meta:Object,extra:Object=null):Object
      {
         if(timingRows.length>=256){timingOverflow=true;timingDropped++;return null;}
         var row:Object={kind:kind,at:clock.at,wall:clock.wall,round:timingRound,role:timingRole,probeMs:0};
         for(var key:String in meta)row[key]=meta[key];
         if(extra!=null)for(key in extra)row[key]=extra[key];
         timingRows.push(row);return row;
      }

      private static function timingCost(start:int,row:Object):void
      {
         var cost:int=getTimer()-start;
         timingCalls++;timingTotal+=cost;timingMax=Math.max(timingMax,cost);
         if(row!=null)row.probeMs=cost;
      }

      private static function timingMarker(msg:Object,outgoing:Boolean):void
      {
         var op:String=String(msg.op),round:int=int(msg.round);
         if((op=="go" || op=="sampled" || op=="analyze") &&
            (msg.round==null || !isFinite(Number(msg.round)) || Number(msg.round)!=round)) {
            timingFault("non-integer marker round");return;
         }
         if(op=="go") {
            if((timingRole=="host")!=outgoing || Number(msg.round)!=round || round!=timingNext || round<0 || round>3 || timingActive) {
               timingFault("unexpected go round/direction");return;
            }
            timingRound=round;timingRows=[];timingDropped=0;timingOverflow=false;
            timingCalls=timingTotal=timingMax=0;timingAck=null;
            timingStarted=timingClock();timingLocalSampled=timingPeerSampled=null;timingActive=true;
         } else if(op=="sampled") {
            if(!timingActive || round!=timingRound){timingFault("sampled outside active round");return;}
            if(outgoing) {
               if(timingLocalSampled!=null)timingFault("duplicate local sampled");
               else timingLocalSampled=timingClock();
            } else {
               if(timingPeerSampled!=null)timingFault("duplicate peer sampled");
               else timingPeerSampled=timingClock();
            }
         } else if(op=="analyze") {
            if(!timingActive || round!=timingRound || (timingRole=="host")!=outgoing) {
               timingFault("unexpected analyze round/direction");return;
            }
            var both:Boolean=timingLocalSampled!=null && timingPeerSampled!=null;
            if(!both)timingFault("analyze before both sampled");
            timingDump("analyze",both);timingNext=round+1;
         } else if(op=="stop" || op=="done") {
            if(timingActive){timingFault("test ended during active round");timingDump(op,false);}
         }
      }

      /** One narrow entry for successful flush and pre-dispatch observations. */
      private static function timingTransport(msg:Object,peer:int,outgoing:Boolean):void
      {
         if(!timingEnabled)return;
         try{timingTransportInside(msg,peer,outgoing);}
         catch(error:*){timingFault("transport observer: "+String(error));}
      }

      private static function timingTransportInside(msg:Object,peer:int,outgoing:Boolean):void
      {
         if(msg!=null && msg.type=="large-wall-test") {
            try{timingMarker(msg,outgoing);}catch(markerError:*){timingFault("marker: "+String(markerError));}
            return;
         }
         if(!timingActive || msg==null)return;
         var batch:Object,paint:Boolean=false,kind:String;
         if(msg.type==Protocol.MSG_TERRAIN && msg.wall!=null){batch=msg.wall;kind="report";}
         else if(msg.type==Protocol.MSG_TERRAIN_ACK && msg.wallReceipt!=null){batch=msg.wallReceipt;kind="ack";}
         else if((msg.type==Protocol.MSG_WORLDSTATE || msg.type==Protocol.MSG_UNITSYNC) && msg.wallPaint is Array)
         {batch=msg.wallPaint;kind="paint";paint=true;}
         else return;
         var clock:Object=timingClock(),row:Object=null;
         try{row=timingPush((outgoing?"tx-":"rx-")+kind,clock,timingMeta(msg,batch,peer,paint));}
         catch(probeError:*){timingFault("transport probe: "+String(probeError));}
         finally{timingCost(int(clock.at),row);}
      }

      public static function wallAckTimingReceived(msg:Object,accepted:Boolean,peer:int):Object
      {
         var previous:Object=timingAck;
         if(!timingEnabled || !timingActive || msg==null || msg.wallReceipt==null)return previous;
         var clock:Object=timingClock(),row:Object=null;
         try {
            var meta:Object=timingMeta(msg,msg.wallReceipt,peer);
            timingAck={meta:meta,accepted:accepted};
            row=timingPush("ack-received",clock,meta,{acceptedRoom:accepted});
         }catch(error:*){timingFault("ACK received: "+String(error));}
         finally{timingCost(int(clock.at),row);}
         return previous;
      }

      public static function wallAckTimingProcessed(msg:Object,previous:Object,completed:Boolean):void
      {
         if(!timingEnabled || !timingActive || msg==null || msg.wallReceipt==null){timingAck=previous;return;}
         var clock:Object=timingClock(),row:Object=null;
         try {
            if(timingActive && msg!=null && msg.wallReceipt!=null) {
               if(timingAck==null || timingAck.meta.seq!=msg.wallReceipt.seq)timingFault("ACK processed context mismatch");
               else row=timingPush("ack-processed",clock,timingAck.meta,{acceptedRoom:timingAck.accepted,completed:completed});
               if(!completed)timingFault("native ACK processing threw");
            }
         }catch(error:*){timingFault("ACK processed: "+String(error));}
         finally{timingAck=previous;timingCost(int(clock.at),row);}
      }

      public static function wallAckTimingReleaseStart(seq:*):Object
      {
         if(!timingEnabled || !timingActive)return null;
         var start:int=getTimer();
         try {
            var clock:Object=timingClock();
            if(timingAck==null || timingAck.accepted!==true || timingAck.meta.seq!=seq) {
               timingFault("pending release without matching accepted ACK context");return null;
            }
            return clock;
         }catch(error:*){timingFault("pending release clock: "+String(error));}
         finally{timingCost(start,null);}
         return null;
      }

      public static function wallAckTimingReleased(seq:*,queued:Object,cells:Object,released:Object):void
      {
         if(!timingEnabled || !timingActive)return;
         var clock:Object=timingClock(),row:Object=null;
         try {
            if(released==null || timingAck==null || timingAck.accepted!==true || timingAck.meta.seq!=seq) {
               timingFault("pending release without matching accepted ACK context");return;
            }
            var first:Object={found:false,key:null,valid:null,eligible:null};
            for(var key:String in queued) {
               var q:Object=queued[key],c:Object=cells[key];
               first={found:true,key:key.substr(0,80),valid:q!=null && c!=null,
                  eligible:c==null?false:q==null?null:(!Boolean(c.needsNative) && q.sv==c.sv),
                  x:q==null?null:q.x,y:q==null?null:q.y,sv:q==null?null:q.sv,
                  cellSv:c==null?null:c.sv,needsNative:c==null?null:Boolean(c.needsNative)};
               if(key.length>80)timingFault("oversized queued key");
               break;
            }
            row=timingPush("pending-released",clock,timingAck.meta,{acceptedRoom:true,
               releaseAt:released.at,releaseWall:released.wall,completedAt:clock.at,completedWall:clock.wall,queuedFirst:first});
         }catch(error:*){timingFault("pending release: "+String(error));}
         finally{timingCost(int(clock.at),row);}
      }

      private static function timingDump(reason:String,normal:Boolean):void
      {
         var name:String=timingActive?"round-"+timingRound:"abort";
         if(timingWritten[name])return;
         var trial:Object=socketNoDelayStatus();
         var ended:Object=timingClock(),both:Boolean=timingLocalSampled!=null && timingPeerSampled!=null;
         var result:Object={kind:"ordinary-wall-ack-timing-v1",appId:timingApp,role:timingRole,round:timingRound,
            complete:normal && both && !timingOverflow && timingFaultCount==0,termination:reason,
            started:timingStarted,ended:ended,localSampled:timingLocalSampled,peerSampled:timingPeerSampled,bothSampled:both,
            capacity:256,overflow:timingOverflow,dropped:timingDropped,eventCount:timingRows.length,
            faultCount:timingFaultCount,faults:timingFaults.concat(),probeCalls:timingCalls,probeTotalMs:timingTotal,probeMaxMs:timingMax,
            events:timingRows};
         if(trial!=null)result.socketNoDelayTrial=trial;
         timingActive=false;timingWritten[name]=true;
         var fs:FileStream=null;
         try {
            var file:File=File.applicationStorageDirectory.resolvePath("wall-ack-timing/"+name+".json");
            if(file.exists)throw new Error("diagnostic output already exists");
            file.parent.createDirectory();
            var text:String=JSON.stringify(result),started:int=getTimer();
            fs=new FileStream();fs.open(file,FileMode.WRITE);fs.writeUTFBytes(text);fs.close();fs=null;
            Log.d("WALL ACK TIMING FILE "+JSON.stringify({round:timingRound,file:file.name,complete:result.complete,
               events:result.eventCount,overflow:result.overflow,faultCount:result.faultCount,writeMs:getTimer()-started}));
         }catch(error:*) {
            timingFault("output: "+String(error));
            Log.d("WALL ACK TIMING OUTPUT FAILED "+String(error));
         }finally {
            if(fs!=null)try{fs.close();}catch(closeError:*){timingFault("output close: "+String(closeError));}
            timingRows=[];timingAck=null;
         }
      }

      private static function timingAbort(reason:String):void
      {
         if(!timingEnabled || (!timingActive && timingNext==4 && timingFaultCount==0))return;
         try{timingDump(reason,false);}catch(error:*){timingFault("abort output: "+String(error));}
      }

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
         socketNoDelayApply("accept",sock);
         dispatchEvent(new Event(CONNECTED));
      }

      public function send(msg:Object):void
      {
         if(socket == null || !socket.connected)
         {
            return;
         }
         try
         {
            var handshake:Boolean=msg.type==Protocol.MSG_HELLO || msg.type==Protocol.MSG_WELCOME;
            if(handshake)msg.binary=BinaryMessageCodec.CAPABILITY;
            // The greeting stays ordinary JSON. Only peers advertising the
            // same plain-data codec receive binary frames; others keep JSON.
            var ba:ByteArray=binaryEnabled && !handshake?BinaryMessageCodec.pack(msg):null;
            var binary:Boolean=ba!=null;
            if(!binary) {ba=new ByteArray();ba.writeUTFBytes(Protocol.encode(msg));}
            if(ba.length>BinaryMessageCodec.MAX_BYTES)throw new Error("Outgoing frame exceeds limit");
            socket.writeInt(binary?-int(ba.length):int(ba.length));
            socket.writeBytes(ba, 0, ba.length);
            socket.flush();
            timingTransport(msg,id,true);
            if(binary)binarySent++;
         }
         catch(err:*)
         {
            Log.d("RConnectNet: send failed: " + err);
            fail("send threw: " + err);
         }
      }

      public function close():void
      {
         timingAbort("local-close");
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
         socketNoDelayApply("connect",e.currentTarget as Socket);
         Log.d("RConnectNet: link connected");
         dispatchEvent(new Event(CONNECTED));
      }

      private function onClose(e:Event):void
      {
         timingAbort("remote-close");
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
         timingAbort("link-failed: "+reason.substr(0,240));
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
            var header:int = _rbuf.readInt(), binary:Boolean=header<0;
            var len:int=binary?-header:header;
            if(len <= 0 || len > BinaryMessageCodec.MAX_BYTES || binary && !binaryEnabled)
            {
               fail("bad frame length: " + len);
               return;
            }
            if(_rbuf.bytesAvailable < len)
            {
               _rbuf.position = headPos;   // 回退，等待剩余字节
               break;
            }
            var msg:Object;
            if(binary) {
               var body:ByteArray=new ByteArray();_rbuf.readBytes(body,0,len);
               msg=BinaryMessageCodec.unpack(body);
               if(msg==null){fail("invalid binary frame");return;}
               binaryReceived++;
            } else msg=Protocol.decode(_rbuf.readUTFBytes(len));
            if(msg != null)
            {
               if((msg.type==Protocol.MSG_HELLO || msg.type==Protocol.MSG_WELCOME)
                  && msg.binary===BinaryMessageCodec.CAPABILITY)binaryEnabled=true;
                timingTransport(msg,id,false);
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
