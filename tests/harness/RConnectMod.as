package {
   import flash.display.Loader;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.filesystem.File;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   import flash.utils.Timer;

   /** Test-copy loader: production bytes live in a sibling domain. The driver
    * inherits that domain, so none of the tested classes are rebuilt with tests. */
   public class RConnectMod {
      private static var production:Loader;
      private static var driver:Loader;
      private static var windowReady:Timer;
      public static function init(main:Object):void {
         if(File.applicationDirectory.resolvePath('tests/show-window-when-ready.flag').exists) {
            windowReady=new Timer(50);
            windowReady.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void {
               var world:*=main.loaderInfo.applicationDomain.getDefinition('fe.World')['w'];
               if(world==null || world.pip==null || world.grafon==null || world.vblack==null)return;
               windowReady.stop();main.stage.nativeWindow.visible=true;
               trace('RConnectHarness: visible after native UI initialization');
            });
            windowReady.start();
         }
         production=new Loader();
         production.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
            var domain:ApplicationDomain=production.contentLoaderInfo.applicationDomain;
            var entry:Object=domain.getDefinition("RConnectMod");entry.init(main);
            driver=new Loader();
            driver.load(new URLRequest("app:/tests/EffectsDriver.swf"),new LoaderContext(false,new ApplicationDomain(domain)));
         });
         production.load(new URLRequest("app:/tests/RConnectProduction.swf"),
            new LoaderContext(false,new ApplicationDomain(main.loaderInfo.applicationDomain)));
      }
   }
}
