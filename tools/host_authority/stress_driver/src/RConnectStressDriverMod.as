package {
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.desktop.NativeApplication;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.net.URLRequest;
   import flash.system.LoaderContext;
   import flash.system.ApplicationDomain;
   import flash.utils.getTimer;
   /** Test-only bootstrap. Load a typed probe into the existing B domain. */
   public class RConnectStressDriverMod extends Sprite {
      private static var root:Object,started:int,loader:Loader;
      private static function log(kind:String,data:Object=null):void {
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("RConnectStressDriver.log"),FileMode.APPEND);
         f.writeUTFBytes(JSON.stringify({kind:kind,data:data,at:getTimer()})+"\n");f.close();
      }
      public static function init(main:*):void {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-b-")!=0)throw new Error("Isolated B test profile required");
         var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("mods/Rconnect/release/config.txt"),FileMode.READ);
         var config:Object=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();
         if(config.experimental!==true || config.probe!==true || config.scenario!=="stress" || config.stressExternal!==true)
            throw new Error("Explicit isolated continuous stress fixture required");
         root=main;started=getTimer();loader=new Loader();
         var domain:ApplicationDomain=ApplicationDomain.currentDomain;
         var context:LoaderContext=new LoaderContext(false,domain);context.allowCodeImport=true;
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(event:Event):void {
            try {
               var entry:Class=domain.getDefinition("RConnectMod") as Class;entry["init"](main);
               var mod:Object=entry["instance"];
               if(mod==null)throw new Error("Frozen B did not initialize");
               var payload:Loader=new Loader();
               payload.contentLoaderInfo.addEventListener(Event.COMPLETE,function(done:Event):void {
                  try {
                     domain.getDefinition("ContinuousStressDoc")["install"](mod,StressDriverInfo.SOURCE);
                     log("installed",{source:StressDriverInfo.SOURCE,bSource:domain.getDefinition("authority.BuildInfo")["SOURCE"],
                        capability:mod.access.definition("fe.World")["RCONNECT_AUTHORITY_HOOKS"],probe:mod.config.scenario,originalBBytes:true});
                  }catch(error:*){log("error",{message:String(error),stack:error.getStackTrace()});}
               });
               payload.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(error:IOErrorEvent):void{log("error",{message:error.text});});
               payload.load(new URLRequest("app:/mods/RConnectStressDriver/release/ContinuousStressDoc.swf"),context);
            }catch(error:*){log("error",{message:String(error),stack:error.getStackTrace()});}
         });
         loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(error:IOErrorEvent):void{log("error",{message:error.text});});
         log("loading-original-b");
         loader.load(new URLRequest("app:/mods/Rconnect/release/RConnectMod.swf"),context);
      }
   }
}
