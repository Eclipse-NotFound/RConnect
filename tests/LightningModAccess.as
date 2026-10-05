package {
   import flash.display.Loader;
   /** Test-only access to the existing MSW instance in its own loader domain. */
   public class LightningModAccess {
      public static function instance(main:MainFE):Object {
         for(var entry:Object in main.modEntryByLoader) {
            var loader:Loader=entry as Loader;
            if(loader==null)continue;
            var domain:Object=loader.contentLoaderInfo.applicationDomain;
            if(domain.hasDefinition("MoreSkillsWeaponsMod")) {
               var c:Object=domain.getDefinition("MoreSkillsWeaponsMod");
               return c.testInstance();
            }
         }
         return null;
      }
   }
}
