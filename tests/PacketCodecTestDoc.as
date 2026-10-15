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
      private var readyAt:int=0;
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
      private function differences(a:*,b:*,path:String,out:Array):void {
         if(a===b || out.length>=16)return;
         if(a!=null && b!=null && typeof a=="object" && typeof b=="object") {
            for(var key:String in a)differences(a[key],b[key],path+"."+key,out);
            for(key in b)if(!a.hasOwnProperty(key))out.push({path:path+"."+key,extra:true});
         } else out.push({path:path,jsonValue:a,binaryValue:b,jsonType:typeof a,binaryType:typeof b,
            absolute:(a is Number && b is Number)?Math.abs(Number(a)-Number(b)):null});
      }
      private function checks(mod:RConnectMod):void {
         RoomEncodingRegression.run(check);
         // Compare the actual current native objects too, not only a tree
         // normalized by JSON before entering the binary encoder.
         var nativePacket:Object={type:"native-codec-oracle",units:mod.game.readUnitsSnapshot(),player:mod.game.readSnapshot()};
         var nativeBytes:ByteArray=BinaryMessageCodec.pack(nativePacket);
         check(nativeBytes!=null,"actual native player and unit snapshots support negotiated encoding");
         var mismatches:Array=[];differences(JSON.parse(JSON.stringify(nativePacket)),BinaryMessageCodec.unpack(nativeBytes),"native",mismatches);
         if(mismatches.length)Log.d("CODEC NATIVE DIFFERENCES "+JSON.stringify(mismatches));
         check(nativeBytes!=null && same(JSON.parse(JSON.stringify(nativePacket)),BinaryMessageCodec.unpack(nativeBytes)),
            "actual native snapshot decoding preserves the prior JSON data model");
         var beforeInteger:ByteArray=BeforeIntegerMessageCodec.pack(nativePacket);
         check(beforeInteger!=null&&same(BinaryMessageCodec.unpack(beforeInteger),BinaryMessageCodec.unpack(nativeBytes)),
            "actual native packet matches frozen pre-integer-optimization codec");
         var shared:Object={n:7,items:["same",2]},input:Object={type:"codec-data",text:want.text,
            numbers:[0,-1,2147483648,1.25,NaN,Infinity,-Infinity,undefined],a:shared,b:shared,
            missing:undefined,callback:function():void {},value:null,yes:true,no:false};
         var packed:ByteArray=BinaryMessageCodec.pack(input),decoded:Object=BinaryMessageCodec.unpack(packed);
         check(packed!=null && decoded!=null,"anonymous native encoding decodes");
         check(same(JSON.parse(JSON.stringify(input)),decoded),"round trip matches existing JSON values and omissions");
         var numeric:Array=[110.39999999999999,36.449999999999996,.9751859364435429,-0,Number.MIN_VALUE,Number.MAX_VALUE];
         var bits:ByteArray=new ByteArray(),seed:uint=2718281;
         for(var j:int=0;j<512;j++) {
            bits.length=0;seed=uint(seed*1664525+1013904223);bits.writeUnsignedInt(seed);
            seed=uint(seed*1664525+1013904223);bits.writeUnsignedInt(seed);bits.position=0;
            numeric.push(bits.readDouble());
         }
         var numericInput:Object={type:"numeric-oracle",numbers:numeric};
         check(same(JSON.parse(JSON.stringify(numericInput)),BinaryMessageCodec.unpack(BinaryMessageCodec.pack(numericInput))),
            "all 518 double boundary/random patterns exactly preserve JSON numeric results without epsilon");
         var integers:Array=[-0,0,-2147483648,2147483647,2147483648,4294967295,4294967296,
            -2147483649,-2147483647.5,2147483647.5,4294967295.5,0.00000000000001,-0.00000000000001];
         for(j=0;j<1024;j++) {
            seed=uint(seed*1664525+1013904223);integers.push(seed,int(seed));
         }
         var integerInput:Object={type:"integer-oracle",numbers:integers};
         check(same(JSON.parse(JSON.stringify(integerInput)),BinaryMessageCodec.unpack(BinaryMessageCodec.pack(integerInput))),
            "2061 signed/unsigned integer and adjacent fractional values exactly preserve JSON results");
         var zero:Object=BinaryMessageCodec.unpack(BinaryMessageCodec.pack({type:"zero",number:-0}));
         check(zero!=null&&1/Number(zero.number)==Number.POSITIVE_INFINITY,"integer shortcut preserves JSON positive zero");
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
         var mod:RConnectMod=RConnectMod.instance;
         if(readyAt==0 && getTimer()-began>120000){check(false,"native connection and room become ready within startup deadline");finish();return;}
         if(readyAt>0 && getTimer()-readyAt>40000){check(false,"codec scenario completes within 40 seconds after room readiness");finish();return;}
         if(started || mod==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         var gameplay:TcpLink=host?(mod.session.peers.length?mod.session.peers[0].link:null):mod.session.link;
         if(gameplay==null)return;
         if(readyAt==0){readyAt=getTimer();Log.d("CODEC READY startupMs="+(readyAt-began));}
         if(gameplay==null || gameplay.binarySent==0 || gameplay.binaryReceived==0)return;
         started=true;check(gameplay.binaryEnabled,"real game connection negotiated codec");
         check(gameplay.binarySent>0 && gameplay.binaryReceived>0,"actual gameplay binary messages flow in both directions");
         try {checks(mod);network();} catch(err:*) {check(false,"exception "+err);finish();}
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
