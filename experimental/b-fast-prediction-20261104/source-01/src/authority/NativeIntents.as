package authority {
   import fe.inter.AuthorityMenus;
   import fe.inter.AuthorityPip;
   /** Native menus submit named, bounded requests; only the host mutates resources. */
   public final class NativeIntents {
      public static var replaying:int=0;
      public static const CLASSES:Array=["fe.unit.UnitPlayer","fe.unit.Invent","fe.unit.Pers","fe.weapon.Weapon","fe.loc.Game"];
      private var access:NativeAccess,input:InputSource,previous:Array=[];
      public function NativeIntents(access:NativeAccess,input:InputSource) {
         this.access=access;this.input=input;
         for each(var name:String in CLASSES) {
            var type:Class=access.definition(name);previous.push(type["rconnectIntent"]);
            if(type["rconnectIntent"]!=null)throw new Error("Native intent seam already occupied");
            type["rconnectIntent"]=receive;
         }
      }
      private function receive(target:Object,key:String,args:Array):Boolean {
         if(replaying>0)return false;
         var w:Object=access.world;
         if(target===w.game) {
            w.gui.infoText("整张地图旅行由宿主发起。");return true;
         }
         if(target!==w.gg && target!==w.invent && target!==w.pers && target!==w.gg.currentWeapon)return false;
         if(!valid(key,args))throw new Error("Unsupported native UI request "+key);
         input.enqueue({type:"native",key:key,args:args});return true;
      }
      public static function valid(key:String,args:*):Boolean {
         if(!(args is Array) || args.length>3)return false;
         if(key=="menuClose" || key=="menuStandClose")return args.length==0;
         if(key=="mswFlashGive")return args.length==0;
         if(key=="addonAction")return args.length==1 && AddonsBridge.validAction(args[0]);
         if(key=="sandyToggle")return args.length==0;
         if(key=="advanceDialog")return args.length==1 && args[0] is Boolean;
         if(key=="menuAppearance")return args.length==1 && AuthorityMenus.validAppearance(args[0]);
         if(key=="menuWork")return args.length==3 && integer(args[0],1,12) && nullableId(args[1]) && nullableId(args[2]);
         if(key=="menuVault")return args.length==3 && integer(args[0],1,3) && nullableId(args[1]) && integer(args[2],0,int.MAX_VALUE);
         if(key=="menuVaultAll")return args.length==1 && integer(args[0],1,3);
         if(key=="menuMedical")return args.length==2 && integer(args[0],1,2) && nullableId(args[1]);
         if(key=="menuRepair" || key=="menuAmmo")return args.length==2 && integer(args[0],1,5) && nullableId(args[1]);
         if(key=="menuVendor") {
            if(args.length!=2 || !integer(args[0],1,2) || !(args[1] is Array) || args[1].length>128)return false;
            var seen:Object={};
            for each(var line:Object in args[1]) {
               if(line==null || !(line.id is String) || !nullableId(line.id) || seen[line.id] || !integer(line.count,1,999999))return false;
               seen[line.id]=true;
            }
            return true;
         }
         if(["changeWeapon","changeArmor","changeSpell","callPet","usePotion"].indexOf(key)>=0)
            return args.length==2 && nullableId(args[0]) && (key=="usePotion"?integer(args[1],0,3):args[1] is Boolean);
         if(["useItem","respectWeapon","initReload"].indexOf(key)>=0)return args.length==1 && nullableId(args[0]);
         if(key=="uncallPet")return args.length==1 && args[0] is Boolean;
         if(key=="armorAbil" || key=="meetPeer")return args.length==0;
         if(key=="nextItem")return args.length==1 && integer(args[0],-1,1);
         if(key=="save")return args.length==1 && integer(args[0],-2,100);
         if(key=="favItem")return args.length==2 && nullableId(args[0]) && integer(args[1],0,40);
         if(key=="drop")return args.length==2 && nullableId(args[0]) && integer(args[1],1,999999);
         if(key=="addSkill")return args.length==3 && nullableId(args[0]) && integer(args[1],0,1000) && args[2]===true;
         if(key=="addPerk")return args.length==2 && nullableId(args[0]) && args[1]===true;
         return false;
      }
      private static function nullableId(value:*):Boolean{return value==null || value is String && value.length<=80;}
      private static function integer(value:*,lo:int,hi:int):Boolean{return value is Number && value==int(value) && value>=lo && value<=hi;}
      public static function execute(actor:PlayerActor,key:String,args:Array):Boolean {
         if(!valid(key,args))return false;
         if(key=="sandyToggle")return actor.access.time!=null && actor.access.time.execute(actor);
         if(actor.access.time!=null && actor.access.time.phase=="replay" && key!="menuClose" && key!="menuStandClose")return false;
         if(key=="mswFlashGive")return actor.access.weapons!=null && actor.access.weapons.execute(actor,"flashGive");
         if(key=="addonAction")return actor.access.addons!=null && actor.access.addons.execute(actor,args[0]);
         if(key=="advanceDialog") {
            actor.context.ctr.keyPressed=true;actor.context.ctr.keyPressed2=args[0];actor.context.ctr.active=true;return true;
         }
         if(key.indexOf("menu")==0) {
            try {return AuthorityMenus.execute(actor,key,args);}
            finally {if(actor.context.pip is AuthorityPip)++AuthorityPip(actor.context.pip).revision;}
         }
         var g:Object=actor.unit,inv:Object=g.invent,p:Object=g.pers,id:String=args.length>0?args[0]:null;
         if(key=="save"){actor.requestSave(args[0]);return true;}
         if(key=="meetPeer"){if(actor.requestMeet==null)return false;actor.requestMeet(actor);return true;}
         if(key=="changeWeapon") {if(id!="not" && inv.weapons[id]==null)return false;g.changeWeapon(id);}
         else if(key=="changeArmor") {if(id!="" && inv.armors[id]==null)return false;g.changeArmor(id,args[1]);}
         else if(key=="changeSpell") {if(id!="" && inv.spells[id]==null)return false;g.changeSpell(id,args[1]);}
         else if(key=="armorAbil")g.armorAbil();
         else if(key=="callPet")g.callPet(id,args[1]);
         else if(key=="uncallPet")g.uncallPet(args[0]);
         else if(key=="initReload") {if(g.currentWeapon==null || id!="" && inv.items[id]==null)return false;g.currentWeapon.initReload(id);}
         else if(key=="useItem")inv.useItem(id);
         else if(key=="usePotion")inv.usePotion(id,args[1]);
         else if(key=="nextItem")inv.nextItem(args[0]);
         else if(key=="respectWeapon") {if(inv.weapons[id]==null)return false;inv.respectWeapon(id);}
         else if(key=="favItem") {if(id!=null && id!="" && inv.weapons[id]==null && inv.items[id]==null && inv.armors[id]==null && inv.spells[id]==null)return false;inv.favItem(id,args[1]);}
         else if(key=="drop") {if(inv.items[id]==null || inv.items[id].kol<int(args[1]) || g.loc.base)return false;inv.drop(id,args[1]);}
         else if(key=="addSkill") {
            if(p.skills[id]==null || p.skillPoint<int(args[1]))return false;
            p.addSkill(id,args[1],true);p.setParameters();
         }
         else if(key=="addPerk") {if(p.perkPoint<=0 || p.perkPoss(id)!=1)return false;p.addPerk(id,true);}
         else return false;
         if(actor.context.pip is AuthorityPip)++AuthorityPip(actor.context.pip).revision;
         return true;
      }
      public function dispose():void {for(var i:int=0;i<CLASSES.length;i++)access.definition(CLASSES[i])["rconnectIntent"]=previous[i];}
   }
}
