package authority {
   /** Confirmed personal resources. Shared world ownership does not merge bags. */
   public final class CharacterState {
      private static const MAPS:Array=["skills","perks","addictions"];
      private static const BODY:Array=["hp","maxhp","mana","stam","rad","poison","cut","shithp","maxshithp","obs","maxObs","rat","h2o","sost","ggControl","currentPet"];
      public static function capture(actor:PlayerActor):Object {
         var g:Object=actor.unit,result:Object={body:{},pers:NativeFields.capture(g.pers),maps:{},
            inventory:PlainData.copy(g.invent.save()),saveSerial:actor.saveSerial,sats:{od:actor.context.sats.od,limOd:actor.context.sats.limOd}};
         for each(var key:String in BODY)if(key in g)result.body[key]=g[key];
         for each(key in MAPS)result.maps[key]=PlainData.copy(g.pers[key]);
         return result;
      }
      private static function map(target:Object,source:Object):void {
         for(var key:String in target)if(!source.hasOwnProperty(key))delete target[key];
         for(key in source)target[key]=source[key];
      }
      public static function apply(access:NativeAccess,s:Object):void {
         if(s==null)return;
         var w:Object=access.world,g:Object=w.gg,inv:Object=g.invent,data:Object=s.inventory;
         NativeFields.apply(g,s.body);NativeFields.apply(g.pers,s.pers);
         for each(var field:String in MAPS)map(g.pers[field],s.maps[field]);
         var key:String,record:Object,weapon:Object;
         for(key in inv.weapons)if(inv.weapons[key]!=null && !data.weapons.hasOwnProperty(key)) {
            inv.weapons[key].remVisual();inv.weapons[key]=null;
         }
         for(key in data.weapons) {
            record=data.weapons[key];weapon=inv.weapons[key];
            if(weapon==null)weapon=inv.addWeapon(record.id,record.hp,record.hold,record.respect,record.variant);
            if(weapon.variant!=record.variant)weapon.updVariant(record.variant);
            weapon.hp=record.hp;weapon.hold=record.hold;weapon.respect=record.respect;
            if(record.ammo!=null && weapon.ammo!=record.ammo && inv.items[record.ammo]!=null)weapon.setAmmo(record.ammo,inv.items[record.ammo].xml);
         }
         for(key in inv.armors)if(inv.armors[key]!=null && !data.armors.hasOwnProperty(key))inv.armors[key]=null;
         for(key in data.armors) {
            record=data.armors[key];if(inv.armors[key]==null)inv.addArmor(record.id,record.hp,record.lvl);
            inv.armors[key].hp=record.hp;inv.armors[key].lvl=record.lvl;
         }
         for(key in inv.items)if(inv.items[key]!=null) {
            inv.items[key].kol=data.items[key]==null?0:data.items[key];
            inv.items[key].vault=data.vault[key]==null?0:data.vault[key];
         }
         map(inv.fav,data.fav);
         for each(field in ["cWeaponId","cArmorId","cAmulId","cSpellId","prevArmor"])inv[field]=data[field];
         g.currentArmor=data.cArmorId==null?null:inv.armors[data.cArmorId];
         g.currentAmul=data.cAmulId==null?null:inv.armors[data.cAmulId];
         w.sats.od=s.sats.od;w.sats.limOd=s.sats.limOd;
         if(!w.sats.active)w.sats.odv=w.sats.od;
      }
   }
}
