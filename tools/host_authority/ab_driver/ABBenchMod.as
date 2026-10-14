package {
 import flash.display.Sprite; import flash.display.Loader; import flash.events.Event;
 import flash.filesystem.*; import flash.net.URLRequest; import flash.system.*; import flash.desktop.NativeApplication;
 public class ABBenchMod extends Sprite {
  public static function init(main:*):void {
   var id:String=NativeApplication.nativeApplication.applicationID;
   if(id.indexOf("pfe-modsettings-rconnect-ab-")!=0 && id.indexOf("pfe-modsettings-rconnect-b-ab-")!=0)throw new Error("Isolated A/B profile required");
   var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("ab-bench.json"),FileMode.READ);
   var cfg:Object=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();
   var domain:ApplicationDomain=ApplicationDomain.currentDomain,context:LoaderContext=new LoaderContext(false,domain);context.allowCodeImport=true;
   var loader:Loader=new Loader();loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
    try {
     var entry:Object=domain.getDefinition("RConnectMod");entry.init(main);var mod:Object=entry.instance;
     var payload:Loader=new Loader();payload.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
      try{domain.getDefinition(cfg.variant=="B"?"ABPayloadB":"ABPayloadA")["install"](mod,main,cfg);}
      catch(error:*){ABBench.log("fatal",{error:String(error),stack:error.getStackTrace()});}
     });
     payload.load(new URLRequest("app:/mods/ABBench/release/ABPayload"+cfg.variant+".swf"),context);
    }catch(error:*){ABBench.log("fatal",{error:String(error),stack:error.getStackTrace()});}
   });loader.load(new URLRequest("app:/mods/Rconnect/release/RConnectMod.swf"),context);
  }
 }
}
