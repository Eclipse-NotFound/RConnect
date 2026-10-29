package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.events.TimerEvent;
 import flash.events.MouseEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.media.SoundMixer;
 import flash.system.ApplicationDomain;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 public class TunnelProbe extends Sprite {
  private var timer:Timer=new Timer(100),start:int=getTimer(),readyAt:int=0;
  private var mod:Object,host:Boolean,checks:Array=[],packets:Object={},watch:Object,clicked:Boolean=false,parsed:Boolean=false,done:Boolean=false;
  private var expectedPort:int=0,sent:int=0;
  public function TunnelProbe(){host=NativeApplication.nativeApplication.applicationID.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,tick);timer.start();}
  private function ok(value:Boolean,label:String):void{checks.push({ok:value,label:label});}
  private function parseTests():void {
   var parser:Object=loaderInfo.applicationDomain.getDefinition("rconnect.net.ConnectAddress");
   var good:Array=[["  example.org:45678 ",23456,"example.org",45678],["TCP://example.org:443",1,"example.org",443],
    ["127.0.0.1",23456,"127.0.0.1",23456],["localhost:1","","localhost",1],["a.example",65535,"a.example",65535],
    ["[::1]:34567",123,"::1",34567],["[::1]",23456,"::1",23456],["::1",23456,"::1",23456]];
   for each(var row:Array in good){var result:Object=parser.parse(row[0],row[1]);ok(result!=null&&result.host==row[2]&&result.port==row[3],"parse "+row[0]);}
   for each(var bad:String in [""," ","tcp://","http://example.org:80","https://example.org","example.org/path","a@b:2","host:0","host:65536","host:-1","host:1.5","host:1e2","host:2junk","host:","[::1]:","[localhost]:23456","host?x=1","host#x","a b:123","a\\b:123"])
    ok(parser.parse(bad,23456)==null,"reject "+bad);
   ok(parser.port(" 23456 ")==23456 && parser.port("65536")==0 && parser.port("3.5")==0,"strict local port");
   parsed=true;
  }
  private function receive(e:Event):void{var p:Object=Object(e).data;packets[p.type]=int(packets[p.type])+1;}
  private function tick(e:TimerEvent):void {
   try {
    mod=loaderInfo.applicationDomain.getDefinition("RConnectMod").instance;if(mod==null)return;
    if(!parsed)parseTests();
    if(getTimer()-start>90000){finish(false,"timeout");return;}
    var game:Object=mod.game,session:Object=mod.session;
    if(!host && !clicked && game.gg!=null && !game.isTransitioning()) {
     var endpoint:Object=loaderInfo.applicationDomain.getDefinition("rconnect.net.ConnectAddress").parse(String(mod.config.getValue("hostIp")),1);
     expectedPort=endpoint.port;
     mod.hud.visible=true;mod.hud.openPage("connect");
     mod.hud.tfIp.text="https://invalid.example/";
     mod.hud.getChildByName("rconnect-join").dispatchEvent(new MouseEvent(MouseEvent.CLICK));
     ok(session.mode=="offline","web link rejected before connecting");
     mod.hud.tfIp.text="  tcp://"+endpoint.host+":"+expectedPort+"  ";mod.hud.tfPort.text="1";
     mod.hud.getChildByName("rconnect-join").dispatchEvent(new MouseEvent(MouseEvent.CLICK));clicked=true;
     ok(mod.hud.tfIp.text==endpoint.host&&mod.hud.tfPort.text==String(expectedPort),"UI splits pasted tunnel endpoint");
     ok(mod.config.getValue("hostIp")==endpoint.host&&mod.config.getValue("port")==expectedPort,"normalized endpoint persisted");
    }
    var current:Object=host?(session.peers.length>0?session.peers[0].link:null):session.link;
    if(current!=null && current!==watch){watch=current;watch.addEventListener("message",receive);}
    if(game.gg==null||!session.rooms.ready||session.rooms.busy||current==null||!current.isOpen)return;
    if(readyAt==0)readyAt=getTimer();
    if(sent<5 && getTimer()-readyAt>=sent*1000){session.sendChat((host?"tunnel-host":"tunnel-join")+" α 中文 "+sent);sent++;}
    if(getTimer()-readyAt<14000)return;
    ok(session.mode==(host?"hosting":"connected"),"connected through relay");
    ok(mod.hud.chatLog.text.indexOf((host?"tunnel-join":"tunnel-host")+" α 中文 4")>=0,"bidirectional native Unicode chat");
    ok(int(packets[host?"playerstate":"worldstate"])>10,"native live state packets received");
    ok(watch.binarySent>0&&watch.binaryReceived>0,"binary negotiation and two-way traffic");
    if(!host)ok(watch.socket.remotePort==expectedPort,"socket uses external tunnel port");
    finish(true);
   }catch(error:*){finish(false,String(error));}
  }
  private function finish(passed:Boolean,error:String=""):void {
   if(done)return;done=true;timer.stop();for each(var c:Object in checks)if(!c.ok)passed=false;
   var s:FileStream=new FileStream();s.open(File.applicationStorageDirectory.resolvePath("stutter-result.json"),FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({completed:passed,error:error,checks:checks,packets:packets,audioVolume:SoundMixer.soundTransform.volume}));s.close();NativeApplication.nativeApplication.exit(passed?0:1);
  }
 }
}
