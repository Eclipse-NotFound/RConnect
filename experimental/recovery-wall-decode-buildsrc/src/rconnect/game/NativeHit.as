package rconnect.game {
   import fe.weapon.Bullet;
   /** Only data consumed by Unit/UnitPlayer.damage, with no projectile replay. */
   public class NativeHit {
      private static const BULLET:Array=["armorMult","pier","critCh","critDamMult","critInvis",
         "desintegr","probiv","weapId","dx","dy","vel","damage"];
      private static const WEAPON:Array=["id","variant","dopEffect","dopCh","dopDamage"];
      private var source:Object;
      private var weapons:Object={};
      private static function fields(o:Object,names:Array):Object {
         var out:Object={};
         for each(var name:String in names) {
            var value:*=GameBridge.probe(o,name);
            if(value is String || value is Boolean || (value is Number && isFinite(value)))out[name]=value;
         }
         return out;
      }
      public static function capture(amount:Number,type:int,bullet:Bullet,periodic:Boolean):Object {
         var hit:Object={amount:amount,kind:type,periodic:periodic};
         if(bullet!=null) {
            hit.bullet=fields(bullet,BULLET);
            var w:Object=GameBridge.probe(bullet,"weap");
            if(w!=null)hit.weapon=fields(w,WEAPON);
         }
         return hit;
      }
      public function apply(player:Object,hit:Object,main:Object):Number {
         if(player==null || hit==null || !isFinite(Number(hit.amount)) || Math.abs(Number(hit.amount))>1e8)return 0;
         var ad:Object=main.loaderInfo.applicationDomain,bullet:Object=null;
         if(hit.bullet!=null) {
            if(source==null) {
               var unitClass:Class=ad.getDefinition("fe.unit.Unit") as Class;
               source=new unitClass();source.fraction=1;
            }
            source.loc=player.loc;
            var bulletClass:Class=ad.getDefinition("fe.weapon.Bullet") as Class;
            bullet=new bulletClass(source,player.X,player.Y-player.scY/2,null,false);
            for each(var name:String in BULLET)if(hit.bullet[name]!=null)bullet[name]=hit.bullet[name];
            bullet.tipDamage=int(hit.kind);
            if(hit.weapon!=null && String(hit.weapon.id)!="") {
               var key:String=String(hit.weapon.id)+"/"+int(hit.weapon.variant),weapon:Object=weapons[key];
               if(weapon==null) {
                  var weaponClass:Class=ad.getDefinition("fe.weapon.Weapon") as Class;
                  weapons[key]=weapon=new weaponClass(source,String(hit.weapon.id),int(hit.weapon.variant));
               }
               for each(name in WEAPON)if(hit.weapon[name]!=null)weapon[name]=hit.weapon[name];
               bullet.weap=weapon;
            }
         }
         return Number(player.damage(Number(hit.amount),int(hit.kind),bullet,hit.periodic==true));
      }
   }
}
