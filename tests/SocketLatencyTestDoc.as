package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.ServerSocketConnectEvent;
   import flash.net.ServerSocket;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Paired, alternating measurements on a disposable loopback connection.
    * Only these test sockets are toggled; gameplay sockets stay production.
    * All timestamps share this process's clock. Timings are diagnostic, not
    * a substitute for unchanged gameplay/animation/density gates. */
   public class SocketLatencyTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),pulse:Timer=new Timer(25);
      private var listener:ServerSocket,sender:TcpLink,receiver:TcpLink;
      private var began:int=getTimer(),phaseAt:int,phase:int=-1,count:int=0;
      private var started:Boolean=false,done:Boolean=false,host:Boolean;
      private var rows:Array=[],seen:Object={},sent:Array=[],latencies:Array=[],arrivals:Array=[];
      private const FLAGS:Array=[false,true,false,true];
      private const COUNT:int=32;

      public function SocketLatencyTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         pulse.addEventListener(TimerEvent.TIMER,send);
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"socket-latency "+s);}
      private function tick(e:TimerEvent):void {
         if(done)return;
         if(getTimer()-began>120000 || started&&phase>=0&&getTimer()-phaseAt>15000) {
            check(false,"all small messages arrive before deadline phase="+phase);finish();return;
         }
         if(started)return;
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null||!mod.session.rooms.ready||mod.session.rooms.busy)return;
         var link:TcpLink=host?(mod.session.peers.length?mod.session.peers[0].link:null):mod.session.link;
         if(link==null||!link.isOpen)return;
         started=true;
         try {
            check("tcpNoDelay" in link.socket,"installed AIR supports per-socket option");
            check(Object(link.socket)["tcpNoDelay"]===true,"production gameplay connection enables option");
            listener=new ServerSocket();listener.bind(0,"127.0.0.1");
            listener.addEventListener(ServerSocketConnectEvent.CONNECT,accepted);listener.listen();
            sender=new TcpLink();sender.addEventListener(TcpLink.CONNECTED,connected);
            sender.addEventListener(TcpLink.FAILED,failed);sender.connect("127.0.0.1",listener.localPort);
         }catch(error:Error){check(false,error.getStackTrace());finish();}
      }
      private function failed(e:Event):void {check(false,"test connection failed");finish();}
      private function accepted(e:ServerSocketConnectEvent):void {
         receiver=new TcpLink(e.socket);
         check(Object(receiver.socket)["tcpNoDelay"]===true,"accepted socket configured before first message");
         receiver.addEventListener(TcpLink.MESSAGE,receive);receiver.addEventListener(TcpLink.FAILED,failed);
         begin();
      }
      private function connected(e:Event):void {
         check(Object(sender.socket)["tcpNoDelay"]===true,"connecting socket configured before CONNECTED callback");begin();
      }
      private function begin():void {
         if(phase>=0||receiver==null||sender==null||!sender.isOpen)return;
         next();
      }
      private function next():void {
         ++phase;if(phase==FLAGS.length){finish();return;}
         Object(sender.socket)["tcpNoDelay"]=FLAGS[phase];
         count=0;sent=[];latencies=[];arrivals=[];seen={};phaseAt=getTimer();pulse.reset();pulse.start();
      }
      private function send(e:TimerEvent):void {
         var at:int=getTimer();sent.push(at);
         sender.send({type:"latency-measurement",phase:phase,seq:count,at:at,text:"小包原样到达"});
         if(++count==COUNT)pulse.stop();
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,now:int=getTimer();
         if(p.type!="latency-measurement")return;
         if(p.phase!==phase || p.seq!==latencies.length || seen[p.seq] || p.text!=="小包原样到达" || p.at!==sent[int(p.seq)]) {
            check(false,"message order/value mismatch phase="+phase);finish();return;
         }
         seen[p.seq]=true;latencies.push(now-int(p.at));arrivals.push(now);
         if(latencies.length!=COUNT)return;
         var sorted:Array=latencies.concat();sorted.sort(Array.NUMERIC);
         rows.push({phase:phase,noDelay:FLAGS[phase],sent:sent,arrivals:arrivals,latencies:latencies,
            median:sorted[int(sorted.length*.5)],p95:sorted[int((sorted.length-1)*.95)]});
         check(true,"all 32 messages arrive exactly once and in order phase="+phase);
         next();
      }
      private function finish():void {
         if(done)return;done=true;timer.stop();pulse.stop();
         Log.d("SOCKET LATENCY "+JSON.stringify({role:host?"host":"join",scope:"same test socket alternating option; local clock; no gameplay override",rows:rows}));
         try {if(sender!=null)sender.close();if(receiver!=null)receiver.close();if(listener!=null)listener.close();}catch(error:*){}
         Log.d("COOP EFFECTS DONE socket-latency "+(host?"host":"join"));
      }
   }
}
