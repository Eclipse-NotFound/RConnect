package {
   import flash.display.Loader;
   import flash.system.ApplicationDomain;

   /** One access point for public classes from sibling mod loaders. */
   public final class RConnectModDomains {
      public static function find(main:*,entry:String):ApplicationDomain {
         var nativeMain:MainFE=main as MainFE;
         if(nativeMain==null||nativeMain.modEntryByLoader==null)return null;
         for(var key:Object in nativeMain.modEntryByLoader) {
            var loader:Loader=key as Loader;if(loader==null)continue;
            var domain:ApplicationDomain=loader.contentLoaderInfo.applicationDomain;
            if(domain.hasDefinition(entry))return domain;
         }
         return null;
      }
   }
}
