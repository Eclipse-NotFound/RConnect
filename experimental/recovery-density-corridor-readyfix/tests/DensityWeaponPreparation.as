package {
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   /** External fixture only. Mutations are one-time setup, before ready/timing. */
   public class DensityWeaponPreparation {
      private static var bindings:Dictionary=new Dictionary();
      private static var prepared:Boolean=false;
      public static function configure(gun:Object):void {
         // Exactly the seven constants previously assigned by the host fixture.
         if(gun==null || (gun.id!="lmg" && gun.id!="p308c"))throw new Error("density unexpected fixture weapon");
         gun.hold=10000;gun.damage=1;gun.destroy=0;gun.damageExpl=0;gun.precision=0;gun.deviation=0;gun.critCh=0;
      }
      public static function identity(u:Object):Object {
         var gun:Object=u.currentWeapon;
         if(gun==null)return null;
         var row:Object=DensityFixture.fields(gun,
            ["id","variant","damage","destroy","damageExpl","precision","deviation","critCh","speed","hold"]);
         row.cls=getQualifiedClassName(gun);
         return row;
      }
      private static function attached(u:Object,gun:Object):Boolean {
         return gun==null || (gun.owner===u && u.childObjs is Array && u.childObjs.indexOf(gun)>=0);
      }
      /** Read-only preflight: never force a wrong/still-arriving model to match. */
      public static function modelsMatch(actors:Array,expected:Array):Boolean {
         if(actors.length!=80 || expected==null || expected.length!=80)return false;
         for(var i:int=0;i<actors.length;i++) {
            var u:Object=actors[i],gun:Object=u.currentWeapon,wanted:Object=expected[i].weapon;
            if((gun==null)!=(wanted==null) || !attached(u,gun))return false;
            if(gun!=null && (String(gun.id)!=String(wanted.id) || int(gun.variant)!=int(wanted.variant)
               || getQualifiedClassName(gun)!=String(wanted.cls)))return false;
         }
         return true;
      }
      private static function remember(actors:Array):void {
         if(prepared)throw new Error("density weapons prepared twice");
         var count:int=0;
         for each(var u:Object in actors) {
            var gun:Object=u.currentWeapon;
            if(!attached(u,gun))throw new Error("density weapon owner/child mismatch");
            bindings[u]={weapon:gun};if(gun!=null)count++;
         }
         if(actors.length!=80 || count!=39)throw new Error("density weapon binding roster mismatch");
         prepared=true;
      }
      public static function bindHost(actors:Array):void {remember(actors);}
      public static function prepareMirrors(actors:Array,expected:Array):void {
         if(prepared || !modelsMatch(actors,expected))throw new Error("density mirror model not ready for preparation");
         var before:Array=[];
         for(var i:int=0;i<actors.length;i++)before.push({index:i,weapon:identity(actors[i])});
         // Preserve the actual native state; this is not a product ammo-sync test.
         Log.d("DENSITY WEAPON PREP "+DensityFixture.canonical({role:"join",before:before,
            setupOnly:true,productParameterSyncVerified:false}));
         for each(var u:Object in actors)if(u.currentWeapon!=null)configure(u.currentWeapon);
         remember(actors);
      }
      /** Read-only throughout the stability window and the final commit check. */
      public static function bound(actors:Array):Boolean {
         if(!prepared || actors.length!=80)return false;
         for each(var u:Object in actors) {
            var record:Object=bindings[u];
            if(record==null || record.weapon!==u.currentWeapon || !attached(u,u.currentWeapon))return false;
         }
         return true;
      }
   }
}
