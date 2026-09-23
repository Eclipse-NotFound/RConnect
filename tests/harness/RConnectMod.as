package {
   import flash.display.Loader;
   import flash.events.Event;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;

   /** Test-copy loader: production bytes live in a sibling domain. The driver
    * inherits that domain, so none of the tested classes are rebuilt with tests. */
   public class RConnectMod {
      private static var production:Loader;
      private static var driver:Loader;
      public static function init(main:Object):void {
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
