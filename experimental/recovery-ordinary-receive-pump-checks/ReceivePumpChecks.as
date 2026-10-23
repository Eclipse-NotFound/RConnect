package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.events.ErrorEvent;
 import flash.events.IOErrorEvent;
 import flash.events.ProgressEvent;
 import flash.events.ServerSocketConnectEvent;
 import flash.events.SecurityErrorEvent;
 import flash.events.TimerEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.net.ServerSocket;
 import flash.net.Socket;
 import flash.utils.ByteArray;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 import rconnect.net.Protocol;
 import rconnect.net.BinaryMessageCodec;

 /** Real loopback bytes; deliberate event blocking isolates the polling path.
  * This is a transport correctness test, not evidence of real-game latency. */
 public class ReceivePumpChecks extends Sprite {
  private var assertions:Array=[],failed:int=0,done:Boolean=false;
  private var server:ServerSocket,writer:Socket,accepted:Socket,link:TcpLink;
  private var clock:Timer,started:int=getTimer(),phase:int=-1,received:Array=[];
  private var wakeups:int=0,blocked:int=0,closes:int=0,faults:int=0,reentered:Boolean=false;
  private var allowWakeup:Boolean=false,part:ByteArray,throwing:Boolean=false;
  public function ReceivePumpChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
  private function check(ok:Boolean,label:String):void {
   assertions.push({passed:ok,label:label});if(!ok){failed++;throw new Error(label);}
  }
  private function rawCheck(ok:Boolean,label:String):void {
   assertions.push({passed:ok,label:label});if(!ok)failed++;
  }
  private function start(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,start);
   try {connectPair();clock=new Timer(20);clock.addEventListener(TimerEvent.TIMER,tick);clock.start();}
   catch(error:*){abort(error);}
  }
  private function connectPair():void {
   server=new ServerSocket();server.bind(0,"127.0.0.1");
   server.addEventListener(ServerSocketConnectEvent.CONNECT,connected);server.listen();
   writer=new Socket();writer.addEventListener(IOErrorEvent.IO_ERROR,writerError);
   writer.addEventListener(SecurityErrorEvent.SECURITY_ERROR,writerError);
   writer.connect("127.0.0.1",server.localPort);
  }
  private function connected(e:ServerSocketConnectEvent):void {
   try {
    accepted=e.socket;
    accepted.addEventListener(ProgressEvent.SOCKET_DATA,notice,false,100);
    link=new TcpLink(accepted);link.addEventListener(TcpLink.MESSAGE,message);
    link.addEventListener(TcpLink.CLOSED,closed);link.addEventListener(TcpLink.FAILED,fault);
    if(phase<0)phase=0;else if(phase==9)phase=10;else if(phase==12)phase=13;
    else throw new Error("Unexpected connection phase "+phase);
   }catch(error:*){abort(error);}
  }
  private function notice(e:ProgressEvent):void {
   wakeups++;if(!allowWakeup){blocked++;e.stopImmediatePropagation();}
  }
  private function closed(e:Event):void {closes++;}
  private function fault(e:Event):void {faults++;}
  private function writerError(e:ErrorEvent):void {if(!done)abort(e.text);}
  private function message(e:NetMessageEvent):void {
   if(throwing)throw new Error("intentional-handler-exception");
   received.push(e.data);
   if(e.data.n===1){reentered=true;link.pollIncoming();}
   if(e.data.close===true)link.close();
  }
  private function jsonFrame(value:Object):ByteArray {
   var text:ByteArray=new ByteArray();text.writeUTFBytes(Protocol.encode(value));return wrap(text,false);
  }
  private function wrap(body:ByteArray,binary:Boolean):ByteArray {
   var frame:ByteArray=new ByteArray();frame.writeInt(binary?-int(body.length):int(body.length));
   frame.writeBytes(body,0,body.length);frame.position=0;return frame;
  }
  private function put(bytes:ByteArray,offset:uint=0,count:uint=0):void {
   writer.writeBytes(bytes,offset,count);writer.flush();
  }
  private function ready():Boolean {return accepted!=null && accepted.bytesAvailable>0;}
  private function cleanupPair():void {
   if(link!=null){link.close();link.removeEventListener(TcpLink.MESSAGE,message);
    link.removeEventListener(TcpLink.CLOSED,closed);link.removeEventListener(TcpLink.FAILED,fault);}
   if(writer!=null){writer.removeEventListener(IOErrorEvent.IO_ERROR,writerError);
    writer.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,writerError);
    if(writer.connected)writer.close();}
   if(accepted!=null){accepted.removeEventListener(ProgressEvent.SOCKET_DATA,notice);
    if(accepted.connected)accepted.close();}
   if(server!=null){server.removeEventListener(ServerSocketConnectEvent.CONNECT,connected);
    if(server.bound)server.close();}
  }
  private function tick(e:TimerEvent):void {
   if(done)return;
   try {
    if(getTimer()-started>20000)throw new Error("Timed out at phase "+phase);
    switch(phase) {
     case 0:
      check(link.isOpen && accepted.connected && writer.connected,"real loopback link connected");
      link.pollIncoming();check(received.length==0,"empty poll produces no message");
      part=jsonFrame({type:"chat",n:1,text:"partial"});put(part,0,2);phase=1;break;
     case 1:
      if(!ready())break;
      link.pollIncoming();check(received.length==0 && accepted.bytesAvailable==0,"partial two-byte header waits");
      put(part,2,5);phase=2;break;
     case 2:
      if(!ready())break;
      link.pollIncoming();check(received.length==0,"complete header with partial payload waits");
      var rest:ByteArray=new ByteArray();rest.writeBytes(part,7,part.length-7);
      var second:ByteArray=jsonFrame({type:"chat",n:2});rest.writeBytes(second,0,second.length);put(rest);phase=3;break;
     case 3:
      if(!ready())break;
      link.pollIncoming();
      check(received.length==2 && received[0].n===1 && received[1].n===2,"completed partial frame and next frame retain FIFO");
      check(reentered,"handler attempted reentrant poll");
      check(accepted.bytesAvailable==0 && faults==0,"reentrant poll neither duplicates nor fails");
      allowWakeup=true;accepted.dispatchEvent(new ProgressEvent(ProgressEvent.SOCKET_DATA));allowWakeup=false;
      check(received.length==2,"late empty socket notification cannot replay delivered frames");
      put(jsonFrame({type:Protocol.MSG_HELLO,binary:BinaryMessageCodec.CAPABILITY}));phase=4;break;
     case 4:
      if(!ready())break;
      link.pollIncoming();check(link.binaryEnabled && received.length==3,"original JSON handshake enables original binary codec");
      var both:ByteArray=wrap(BinaryMessageCodec.pack({type:"chat",n:3,data:[1,"x",true]}),true);
      var invalid:ByteArray=new ByteArray();invalid.writeUTFBytes("{");var bad:ByteArray=wrap(invalid,false);
      both.position=both.length;both.writeBytes(bad);var fourth:ByteArray=jsonFrame({type:"chat",n:4});both.writeBytes(fourth);put(both);phase=5;break;
     case 5:
      if(!ready())break;
      link.pollIncoming();
      check(received.length==5 && received[3].n===3 && received[4].n===4,"binary plus invalid JSON plus valid JSON preserves original acceptance and order");
      check(link.binaryReceived==1 && faults==0,"exactly one valid binary frame accepted");
      allowWakeup=true;put(jsonFrame({type:"chat",n:5}));phase=6;break;
     case 6:
      if(received.length<6)break;
      check(received.length==6 && received[5].n===5,"ordinary socket event still uses same parser");
      link.pollIncoming();check(received.length==6,"poll after ordinary event cannot duplicate");
      allowWakeup=false;var ending:ByteArray=jsonFrame({type:"chat",n:6,close:true});
      var old:ByteArray=jsonFrame({type:"chat",n:7});ending.position=ending.length;ending.writeBytes(old);put(ending);phase=7;break;
     case 7:
      if(!ready())break;
      link.pollIncoming();
      check(received.length==7 && received[6].n===6,"handler closure prevents delivery of following old-link frame");
      check(!link.isOpen && !accepted.connected && closes==1,"handler closes actual socket exactly once");
      link.pollIncoming();check(received.length==7,"closed link poll is inert");
      check(blocked>0 && wakeups>blocked,"both delayed-event and ordinary-event paths were exercised");
      cleanupPair();check(!server.bound && !writer.connected,"first loopback resources released");
      phase=9;connectPair();break;
     case 10:
      var forbidden:ByteArray=wrap(BinaryMessageCodec.pack({type:"chat",n:8}),true);put(forbidden);phase=11;break;
     case 11:
      if(!ready())break;
      link.pollIncoming();check(faults==1 && !link.isOpen && received.length==7,"binary before handshake retains original rejection");
      cleanupPair();phase=12;connectPair();break;
     case 13:
      throwing=true;put(jsonFrame({type:"chat",n:9}));phase=14;break;
     case 14:
      if(!ready())break;
      var escaped:Boolean=false;
      try {link.pollIncoming();}catch(expected:Error){escaped=expected.message=="intentional-handler-exception";}
      check(escaped && faults==1,"business handler exception propagates without becoming transport failure");
      throwing=false;cleanupPair();check(!server.bound && !writer.connected && !accepted.connected,"all owned sockets and listener cleaned");
      finish();break;
    }
   }catch(error:*){abort(error);}
  }
  private function abort(error:*):void {rawCheck(false,"unexpected: "+String(error));finish();}
  private function finish():void {
   if(done)return;done=true;if(clock!=null)clock.stop();
   try{cleanupPair();}catch(error:*){rawCheck(false,"cleanup: "+String(error));}
   var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   file.writeUTFBytes(JSON.stringify({assertions:assertions,failed:failed,passed:failed==0,
    blockedSocketEvents:blocked,observedSocketEvents:wakeups,received:received.length,
    gameLoaded:false,performanceQualified:false}));file.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
