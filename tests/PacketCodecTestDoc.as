package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.ServerSocketConnectEvent;
   import flash.events.ProgressEvent;
   import flash.net.ServerSocket;
   import flash.net.Socket;
   import flash.net.registerClassAlias;
   import flash.utils.ByteArray;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.setTimeout;
   import rconnect.core.Log;
   import rconnect.net.BinaryMessageCodec;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.Protocol;
   import rconnect.net.TcpLink;

   /** Codec semantics and actual half-frame/coalesced TCP input, isolated from
    * the gameplay connection. The real gameplay link must also use the codec. */
   public class PacketCodecTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),began:int=getTimer(),started:Boolean=false,done:Boolean=false;
      private var host:Boolean,listener:ServerSocket,raw:Socket,receiver:TcpLink,received:int=0;
      private var want:Object={type:"codec-data",text:"中文 · русский 🦄",values:[null,true,false,0,-3,2147483648,1.23456789]};
      public function PacketCodecTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"packet-codec "+label);}
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || (a is Array)!=(b is Array))return false;
         if(typeof a!="object")return false;
         if(a is Array && a.length!=b.length)return false;
         var key:String,n:int=0,m:int=0;
         for(key in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;return n==m;
      }
      private function checks():void {
         RoomEncodingRegression.run(check);
         var shared:Object={n:7,items:["same",2]},input:Object={type:"codec-data",text:want.text,
            numbers:[0,-1,2147483648,1.25,NaN,Infinity,-Infinity,undefined],a:shared,b:shared,
            missing:undefined,callback:function():void {},value:null,yes:true,no:false};
         var packed:ByteArray=BinaryMessageCodec.pack(input),decoded:Object=BinaryMessageCodec.unpack(packed);
         check(packed!=null && decoded!=null,"anonymous native encoding decodes");
         check(same(JSON.parse(JSON.stringify(input)),decoded),"round trip matches existing JSON values and omissions");
         check(decoded!=null && decoded.a!==decoded.b && decoded.a.items!==decoded.b.items,"shared input references become independent receiver values");
         var malformed:int=0;
         for(var i:int=0;i<packed.length;i++) {
            var short:ByteArray=new ByteArray();if(i>0)short.writeBytes(packed,0,i);
            if(BinaryMessageCodec.unpack(short)!=null)malformed++;
         }
         check(malformed==0,"every truncated prefix is rejected");
         var trailing:ByteArray=new ByteArray();trailing.writeBytes(packed);trailing.writeByte(1);
         check(BinaryMessageCodec.unpack(trailing)==null,"trailing data rejected before decode");
         var array:ByteArray=new ByteArray();array.writeObject([1,2]);
         check(BinaryMessageCodec.unpack(array)==null,"non-message root rejected");
         var empty:Object={type:"x"};empty[""]=42;
         check(BinaryMessageCodec.pack(empty)==null,"empty property names retain JSON fallback");
         var cyclic:Object={type:"x"};cyclic.self=cyclic;
         check(BinaryMessageCodec.pack(cyclic)==null,"cyclic input cannot enter binary codec");
         registerClassAlias("RConnectCodecExternalProbe",PacketExternalProbe);
         var typed:PacketExternalProbe=new PacketExternalProbe(),external:ByteArray=new ByteArray();external.writeObject(typed);
         PacketExternalProbe.executed=0;
         check(BinaryMessageCodec.unpack(external)==null && PacketExternalProbe.executed==0,"typed externalizable input rejected without running its code");
         check(BinaryMessageCodec.pack({type:"x",typed:typed})==null,"typed sender data retains JSON fallback");
      }
      private function tick(e:TimerEvent):void {
         if(done)return;
         if(getTimer()-began>40000){check(false,"codec scenario completes within deadline");finish();return;}
         var mod:RConnectMod=RConnectMod.instance;
         if(started || mod==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         var gameplay:TcpLink=host?(mod.session.peers.length?mod.session.peers[0].link:null):mod.session.link;
         if(gameplay==null || gameplay.binarySent==0 || gameplay.binaryReceived==0)return;
         started=true;check(gameplay.binaryEnabled,"real game connection negotiated codec");
         check(gameplay.binarySent>0 && gameplay.binaryReceived>0,"actual gameplay binary messages flow in both directions");
         try {checks();network();} catch(err:*) {check(false,"exception "+err);finish();}
      }
      private function network():void {
         listener=new ServerSocket();listener.bind(0,"127.0.0.1");listener.listen();
         listener.addEventListener(ServerSocketConnectEvent.CONNECT,function(e:ServerSocketConnectEvent):void {
            receiver=new TcpLink(e.socket);
            receiver.addEventListener(TcpLink.MESSAGE,function(ev:NetMessageEvent):void {
               if(ev.data.type=="hello") {check(receiver.binaryEnabled,"JSON greeting enables binary input");return;}
               check(same(ev.data,want),"split/coalesced frame preserves unicode and numeric data "+received);
               received++;
               if(received==2){check(receiver.binaryReceived==2,"both binary frames consumed exactly once");finish();}
            });
            receiver.addEventListener(TcpLink.FAILED,function(ev:Event):void {check(false,"local framed input rejected unexpectedly");finish();});
         });
         raw=new Socket();raw.addEventListener(Event.CONNECT,function(e:Event):void {
            var all:ByteArray=new ByteArray(),greeting:ByteArray=new ByteArray();
            greeting.writeUTFBytes(JSON.stringify({type:"hello",binary:BinaryMessageCodec.CAPABILITY}));
            all.writeInt(greeting.length);all.writeBytes(greeting);
            var payload:ByteArray=BinaryMessageCodec.pack(want);
            for(var i:int=0;i<2;i++){all.writeInt(-int(payload.length));all.writeBytes(payload);}
            raw.writeBytes(all,0,2);raw.flush();
            setTimeout(function():void {if(done)return;raw.writeBytes(all,2,7);raw.flush();
               setTimeout(function():void {if(done)return;raw.writeBytes(all,9,all.length-9);raw.flush();},30);},30);
         });
         raw.connect("127.0.0.1",listener.localPort);
      }
      private function finish():void {
         if(done)return;done=true;timer.stop();
         try {if(receiver!=null)receiver.close();if(raw!=null && raw.connected)raw.close();if(listener!=null)listener.close();}catch(e:*){}
         Log.d("COOP EFFECTS DONE packet-codec "+(host?"host":"join"));
      }
   }
}
