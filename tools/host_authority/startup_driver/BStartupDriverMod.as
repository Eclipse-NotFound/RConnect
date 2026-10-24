package {
 import flash.display.Sprite;
 import flash.display.Loader;
 import flash.display.DisplayObject;
 import flash.desktop.NativeApplication;
 import flash.events.Event;
 import flash.events.MouseEvent;
 import flash.events.IOErrorEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.net.URLRequest;
 import flash.system.ApplicationDomain;
 import flash.system.LoaderContext;
 import flash.utils.ByteArray;
 import flash.utils.getTimer;
 /** External manual-start regression driver. Never embedded in the playable SWF. */
 public class BStartupDriverMod extends Sprite {
  private static var root:Object,mod:Object,domain:ApplicationDomain,cfg:Object;
  private static var phase:int=0,round:int=0,at:int=0,began:int,booted:Boolean=false,done:Boolean=false;
  private static var good:int=0,bad:int=0,ownSave:Object,firstFrames:uint=0,role:String;
  private static function log(kind:String,data:Object=null):void {
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("BStartupDriver.log"),FileMode.APPEND);
   f.writeUTFBytes(JSON.stringify({kind:kind,data:data,at:getTimer()})+"\n");f.close();
  }
  private static function check(ok:Boolean,name:String,data:Object=null):void {if(ok)good++;else bad++;log(ok?"PASS":"FAIL",{name:name,details:data});}
  private static function finish():void {done=true;log("DONE",{passed:good,failed:bad});}
  public static function init(main:*):void {
   var id:String=NativeApplication.nativeApplication.applicationID;
   if(id.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)throw new Error("Unique B startup test profile required");
   root=main;domain=ApplicationDomain.currentDomain;began=getTimer();
   var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("startup-test.json"),FileMode.READ);
   cfg=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();role=id.indexOf("-join-")>=0?"join":"host";
   var loader:Loader=new Loader(),context:LoaderContext=new LoaderContext(false,domain);context.allowCodeImport=true;
   loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
    try {
     var entry:Object=domain.getDefinition("RConnectMod");entry.init(root);mod=entry.instance;
     if(mod==null)throw new Error("B failed to initialize");
     mod.preferences.setValue("port",String(cfg.port));mod.preferences.setValue("hostIp","127.0.0.1");
     log("installed",{version:entry.VERSION,source:domain.getDefinition("authority.BuildInfo")["SOURCE"],scenario:cfg.scenario,role:role});
     root.stage.addEventListener(Event.ENTER_FRAME,step,false,-100000);
    }catch(error:*){check(false,"driver initialized",String(error));finish();}
   });
   loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void {check(false,"B loaded",e.text);finish();});
   loader.load(new URLRequest("app:/mods/Rconnect/release/RConnectMod.swf"),context);
  }
  private static function click(name:String):void {
   var button:DisplayObject=mod.hud.getChildByName("rconnect-"+name);
   if(button==null)throw new Error("Native HUD button missing: "+name);
   button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
  }
  private static function count(v:*,depth:int=0):uint {
   if(depth>100)throw new Error("Unexpected cyclic save");var n:uint=1;
   if(v!=null && typeof(v)=="object")for(var k:String in v)n+=count(v[k],depth+1);
   return n;
  }
  private static function equal(a:*,b:*):Boolean {
   if(a==null || typeof(a)!="object")return a===b;
   if(b==null || (a is Array)!=(b is Array))return false;
   if(a is Array && a.length!==b.length)return false;
   var key:String,na:int=0,nb:int=0;
   for(key in a){na++;if(!b.hasOwnProperty(key) || !equal(a[key],b[key]))return false;}
   for(key in b)nb++;return na==nb;
  }
  private static function contracts(w:Object):void {
   var plain:Object=domain.getDefinition("authority.PlainData"),data:Object={};w.saveToObj(data);ownSave=data;
   log("save-shape",{nodes:count(data),gameNodes:count(data.game),profileNodes:count({pers:data.pers,inventory:data.invent,appearance:data.app})});
   try {var copy:Object=plain.nativeCopy(data);check(equal(data,copy),"full native save copied without data loss");}
   catch(e:*){check(false,"full native save copied without data loss",String(e));}
   var named:Array=new Array(4);named[2]=[1,2];named["named"]={value:7};
   var clone:Object=plain.nativeCopy({values:named});clone.values.named.value=9;
   check(clone.values is Array && clone.values.length==4 && clone.values[2] is Array && named.named.value==7,
    "local copy preserves sparse and associative Arrays and is independent");
   var huge:Array=[];for(var i:int=0;i<24010;i++)huge.push(i);
   var rejected:Boolean=false;try{plain.copy(huge);}catch(limit:*){rejected=String(limit).indexOf("data budget")>=0;}
   check(rejected,"network profile budget is still enforced");
  }
  private static function step(e:Event):void {
   if(done)return;
   try {
    if(getTimer()-began>int(cfg.timeout)*1000){check(false,"scenario completed before timeout",{phase:phase,round:round});finish();return;}
    var w:Object=mod.access.world;
    if(w.verror.visible){check(false,"no native error",String(w.verror.txt.text));finish();return;}
    if(!booted && w.landData!=null && w.allLandsLoaded){booted=true;w.mm.active=false;w.newGame(0,"B Startup Test",null);return;}
    if(!mod.access.ready())return;
    if(mod.role=="") {
     if(w.pip.active)w.pip.onoff(-1);
     if(w.clickReq==1)w.ctr.onMouseDown1(new MouseEvent(MouseEvent.MOUSE_DOWN));
     if(w.t_exit>0 || w.t_die>0 || !w.gg.ggControl || w.gg.work=="res" || w.gg.work=="change")return;
    }
    if(getTimer()-at<450)return;at=getTimer();
    if(phase==0){contracts(w);phase=1;}
    if(cfg.scenario=="host-cancel" || cfg.scenario=="host-bind-failure") {
     if(phase==1) {
      click("host");
      var msg:String=String(mod.ui.session.error);
      if(cfg.scenario=="host-cancel")check(mod.mode=="hosting" && msg=="","manual host starts round "+round,msg);
      else check(msg!="" && msg.indexOf("already attached")<0 && mod.tactics==null,"bind failure releases TDFC round "+round,msg);
      phase=2;return;
     }
     if(cfg.scenario=="host-cancel")click("leave");
     check(mod.role=="" && mod.tactics==null && mod.host==null && mod.access.time==null && mod.access.weapons==null && mod.access.view==null,
      "cancel releases all session interfaces round "+round);
     if(++round==3){finish();return;}phase=1;return;
    }
    if(cfg.scenario=="join-refused") {
     if(phase==1){click("join");phase=2;return;}
     msg=String(mod.ui.session.error);
     if(mod.role=="") {
      check(msg!="" && msg.indexOf("already attached")<0 && msg.indexOf("data budget")<0,"connection refusal preserves original error round "+round,msg);
      check(mod.tactics==null && mod.replica==null && !w.onPause,"failed join releases interfaces and local pause round "+round);
      if(++round==3){finish();return;}phase=1;
     }
     return;
    }
    if(cfg.scenario=="pair") {
     if(phase==1){click(role);phase=2;return;}
     if(phase==2 && mod.welcomed) {
      var frames:uint=role=="host"?mod.host.runtime.tick:mod.replica.frames;
      if(firstFrames==0){firstFrames=frames;return;}
      if(frames<firstFrames+25)return;
      check(mod.ui.session.error=="","loaded save reaches live double-player session",mod.ui.session.error);
      check(role=="host"?mod.host.actors.length==2:mod.replica.displayFrame!=null,"native session frames continue",{frames:frames,round:round});
      log("connected-round",{round:round,frames:frames});
      if(role=="host") {
       var marker:FileStream=new FileStream();
       marker.open(new File(String(cfg.evidenceDirectory)).resolvePath("host-live-"+round+".json"),FileMode.WRITE);
       marker.writeUTFBytes(JSON.stringify({round:round,frames:frames}));marker.close();
      }
      phase=3;return;
     }
     if(phase==3) {
      // Host waits; the joiner performs the normal Leave flow, without forced cleanup.
      if(role=="join") {
       // Independent frame counters can finish at different times. Wait for
       // the host's own 25-tick check before ending this real connection.
       if(!new File(String(cfg.evidenceDirectory)).resolvePath("host-live-"+round+".json").exists)return;
       click("leave");phase=4;
      }
      else if(mod.role=="")phase=4;
      return;
     }
     if(phase==4 && mod.role=="") {
      check(mod.tactics==null && mod.access.time==null && mod.access.view==null && mod.access.weapons==null,"normal leave releases all interfaces");
      if(role=="join") {
       var returned:Object={};w.saveToObj(returned);
       check(equal(ownSave.game.lands,returned.game.lands),"join returns to its own saved journey");
       check(w.gg.ggControl && !w.onPause,"join local controls resume after leave");
      }
      if(++round==2){finish();return;}firstFrames=0;phase=1;
     }
    }
   }catch(error:*){check(false,"driver scenario executed",{message:String(error),stack:error.getStackTrace()});finish();}
  }
 }
}
