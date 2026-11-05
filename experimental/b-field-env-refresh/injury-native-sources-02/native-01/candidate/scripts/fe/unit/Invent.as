package fe.unit
{
   // PI_HOOK_V1: PermanentInjury optional exact-event bridge.
   import fe.*;
   import fe.loc.Loot;
   import fe.serv.Item;
   import fe.serv.LootGen;
   import fe.serv.Script;
   import fe.weapon.*;
   
   public class Invent
   {
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectIntent:Function = null;
      
      public var gg:UnitPlayer;
      
      public var owner:Unit;
      
      public var weapons:Array;
      
      public var fav:Array;
      
      public var favIds:Array;
      
      public var cWeaponId:String = "";
      
      public var armors:Array;
      
      public var cArmorId:String = "";
      
      public var cAmulId:String = "";
      
      public var prevArmor:String = "";
      
      public var spells:Array;
      
      public var cSpellId:String = "";
      
      public var items:Array;
      
      public var eqip:Array;
      
      public var ammos:Array;
      
      public var money:Item;
      
      public var pin:Item;
      
      public var gel:Item;
      
      public var good:Item;
      
      public var itemsId:Array;
      
      public var cItem:int = -1;
      
      public var cItemMax:int;
      
      public var mass:Array;
      
      public var massW:int = 0;
      
      public var massM:int = 0;
      
      public function Invent(param1:Unit, param2:Object = null, param3:Object = null)
      {
         var _loc4_:* = undefined;
         var _loc5_:Item = null;
         this.mass = [0,0,0,0];
         super();
         this.owner = param1;
         this.weapons = new Array();
         this.favIds = new Array();
         this.armors = new Array();
         this.spells = new Array();
         this.items = new Array();
         this.eqip = new Array();
         this.ammos = new Array();
         this.fav = new Array();
         this.itemsId = new Array();
         for each(_loc4_ in AllData.d.item)
         {
            _loc5_ = new Item(_loc4_.@tip,_loc4_.@id,0,0,_loc4_);
            this.items[_loc4_.@id] = _loc5_;
            if(_loc4_.@us >= 2)
            {
               this.itemsId.push(_loc4_.@id);
            }
            if(_loc5_.invCat == 1 && _loc5_.mass > 0 && _loc4_.@perk.length() == 0)
            {
               this.eqip.push(_loc4_.@id);
            }
            if(_loc4_.@base.length())
            {
               this.ammos[_loc4_.@base] = 0;
            }
         }
         this.money = this.items["money"];
         this.pin = this.items["pin"];
         this.gel = this.items["gel"];
         this.good = this.items["good"];
         this.items[""] = new Item("","",0,0,<item/>);
         if(param2 == null)
         {
            if(Boolean(param3) && Boolean(param3.propusk))
            {
               this.addMin();
            }
            else
            {
               this.addBegin();
            }
         }
         else
         {
            this.addLoad(param2);
         }
         this.cItemMax = this.itemsId.length;
      }
      
      private static function rconnectXmlFind(nodes:XMLList, key:String, expected:*) : XMLList
      {
         var result:XMLList = new XMLList();
         for each(var node in nodes)
         {
            if(node.attribute(key) == expected)
            {
               result += node;
            }
         }
         return result;
      }
      
      public function nextItem(param1:int = 1) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"nextItem",[param1])))
         {
            return;
         }
         var _loc2_:* = this.cItem + param1;
         if(_loc2_ >= this.cItemMax)
         {
            _loc2_ = 0;
         }
         if(_loc2_ < 0)
         {
            _loc2_ = this.cItemMax - 1;
         }
         var _loc3_:* = 0;
         while(_loc3_ < this.cItemMax)
         {
            if(this.items[this.itemsId[_loc2_]].kol > 0)
            {
               this.cItem = _loc2_;
               break;
            }
            _loc2_ += param1;
            if(_loc2_ >= this.cItemMax)
            {
               _loc2_ = 0;
            }
            if(_loc2_ < 0)
            {
               _loc2_ = this.cItemMax - 1;
            }
            _loc3_++;
         }
         World.w.gui.setItems();
      }
      
      public function getMed(param1:int) : String
      {
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         var _loc2_:Number = 0;
         if(param1 == 1)
         {
            _loc2_ = this.gg.pers.inMaxHP - this.gg.pers.headHP;
         }
         else if(param1 == 2)
         {
            _loc2_ = this.gg.pers.inMaxHP - this.gg.pers.torsHP;
         }
         else
         {
            if(param1 != 3)
            {
               return "";
            }
            _loc2_ = this.gg.pers.inMaxHP - this.gg.pers.legsHP;
         }
         var _loc3_:XMLList = AllData.d.item;
         var _loc4_:Number = 10000;
         var _loc5_:String = "";
         for each(_loc6_ in _loc3_)
         {
            if(_loc6_.@heal == "organ" && this.items[_loc6_.@id].kol > 0 && (_loc6_.@minmed.length() == 0 || _loc6_.@minmed <= this.gg.pers.medic))
            {
               _loc7_ = 0;
               if(_loc6_.@horgan.length())
               {
                  _loc7_ = _loc6_.@horgan;
               }
               _loc8_ = Math.abs(_loc7_ - _loc2_ + 25);
               if(_loc8_ < _loc4_)
               {
                  _loc4_ = _loc8_;
                  _loc5_ = _loc6_.@id;
               }
            }
         }
         return _loc5_;
      }
      
      public function usePotion(param1:String = null, param2:int = 0) : Boolean
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"usePotion",[param1,param2])))
         {
            return false;
         }
         var pot:* = undefined;
         var pet:UnitPet = null;
         var list:XMLList = null;
         var minRazn:Number = Number(NaN);
         var nci:String = null;
         var razn:* = undefined;
         var limAddict:int = 0;
         var j:* = undefined;
         var eff:Effect = null;
         var ad:* = undefined;
         var redAddict:* = undefined;
         var n1:int = 0;
         var n2:int = 0;
         var n:int = 0;
         var prev:int = 0;
         var ci:String = param1;
         var norgan:int = param2;
         var hhp:Number = 0;
         var hhplong:Number = 0;
         var need1:* = this.gg.maxhp - this.gg.hp - this.gg.rad;
         var need2:* = need1 - this.gg.healhp;
         if(ci != null && ci != "mana" && this.items[ci].kol <= 0)
         {
            return false;
         }
         if(ci == null && need2 < 1)
         {
            World.w.gui.infoText("noHeal");
            if(this.gg.rad > 1)
            {
               World.w.gui.infoText("useAntirad");
            }
            return false;
         }
         if(ci == null)
         {
            list = AllData.d.item;
            minRazn = 10000;
            nci = "";
            for each(pot in list)
            {
               if(pot.@heal == "hp" && this.items[pot.@id].kol > 0)
               {
                  hhp = 0;
                  if(pot.@hhp.length())
                  {
                     hhp += pot.@hhp * this.gg.pers.healMult;
                  }
                  if(pot.@hhplong.length())
                  {
                     hhp += pot.@hhplong * this.gg.pers.healMult;
                  }
                  razn = Math.abs(hhp - need2);
                  if(razn < minRazn)
                  {
                     minRazn = razn;
                     nci = pot.@id;
                  }
               }
            }
            if(nci == "")
            {
               World.w.gui.infoText("noSuitablePot");
               return false;
            }
            ci = nci;
         }
         if(ci == "mana")
         {
            list = AllData.d.item;
            minRazn = 10000;
            need1 = this.gg.pers.inMaxMana - this.gg.pers.manaHP;
            if(need1 < 1)
            {
               return false;
            }
            nci = "";
            for each(pot in list)
            {
               if(pot.@heal == "mana" && this.items[pot.@id].kol > 0)
               {
                  hhp = 0;
                  if(pot.@hmana.length())
                  {
                     hhp = Number(pot.@hmana);
                  }
                  razn = Math.abs(hhp - need1);
                  if(razn < minRazn)
                  {
                     minRazn = razn;
                     nci = pot.@id;
                  }
               }
            }
            if(nci == "")
            {
               World.w.gui.infoText("noSuitablePot");
               return false;
            }
            ci = nci;
         }
         if(ci == "potion_swim")
         {
            this.gg.h2o = 1000;
         }
         pot = rconnectXmlFind(AllData.d.item,"id",ci);
         if(pot.length() == 0)
         {
            return false;
         }
         if(World.w.alicorn)
         {
            if(pot.@tip == "pot" || pot.@tip == "him" || pot.@tip == "food")
            {
               World.w.gui.infoText("alicornNot",null,null,false);
               return false;
            }
         }
         if(pot.@heal == "rad" && this.gg.rad < 1)
         {
            World.w.gui.infoText("noMedic",Res.txt("i",ci));
            return false;
         }
         if(pot.@heal == "poison" && this.gg.poison < 0.1)
         {
            World.w.gui.infoText("noMedic",Res.txt("i",ci));
            return false;
         }
         if(pot.@heal == "blood" && this.gg.pers.inMaxHP - this.gg.pers.bloodHP < 1)
         {
            World.w.gui.infoText("noMedic",Res.txt("i",ci));
            return false;
         }
         if(pot.@heal == "organ" && this.gg.pers.inMaxHP - this.gg.pers.headHP < 1 && this.gg.pers.inMaxHP - this.gg.pers.torsHP < 1 && this.gg.pers.inMaxHP - this.gg.pers.legsHP < 1)
         {
            World.w.gui.infoText("noHeal");
            return false;
         }
         if(pot.@heal == "mana" && this.gg.pers.inMaxMana - this.gg.pers.manaHP < 1)
         {
            World.w.gui.infoText("noMedic",Res.txt("i",ci));
            return false;
         }
         if(pot.@heal == "pet")
         {
            pet = this.gg.pets[pot.@pet];
            if(pet == null || pet.maxhp - pet.hp < 1)
            {
               World.w.gui.infoText("noMedic",Res.txt("i",ci));
               return false;
            }
         }
         if(Boolean(pot.@minmed.length()) && pot.@minmed > this.gg.pers.medic)
         {
            World.w.gui.infoText("needSkill",Res.txt("e","medic"),pot.@minmed);
            return false;
         }
         if(pot.@heal == "detoxin")
         {
            limAddict = int(pot.@detox);
            j = 0;
            while(j < 5)
            {
               for(ad in World.w.pers.addictions)
               {
                  if(World.w.pers.addictions[ad] > 0)
                  {
                     redAddict = Math.round(Math.random() * 50 + 25);
                     if(redAddict > World.w.pers.addictions[ad])
                     {
                        limAddict -= World.w.pers.addictions[ad];
                        World.w.pers.addictions[ad] = 0;
                     }
                     else
                     {
                        limAddict -= redAddict;
                        World.w.pers.addictions[ad] -= redAddict;
                     }
                  }
                  if(limAddict <= 0)
                  {
                     break;
                  }
               }
               if(limAddict <= 0)
               {
                  break;
               }
               j++;
            }
            for each(eff in this.owner.effects)
            {
               if(eff.him == 1 || eff.him == 2)
               {
                  eff.unsetEff(false,true,false);
               }
            }
            this.gg.setAddictions();
            this.gg.pers.setParameters();
         }
         hhp = hhplong = 0;
         if(pot.@hhp.length())
         {
            hhp = pot.@hhp * this.gg.pers.healMult * this.gg.pers.piFactor("hpYield");
         }
         if(pot.@hhplong.length())
         {
            hhplong = pot.@hhplong * this.gg.pers.healMult * this.gg.pers.piFactor("hpYield");
         }
         this.gg.heal(hhp,0,false);
         this.gg.heal(hhplong,1,false);
         if(hhp + hhplong > 0)
         {
            this.gg.numbEmit.cast(this.gg.loc,this.gg.X,this.gg.Y - this.gg.scY / 2,{
               "txt":Math.round(hhp + hhplong),
               "frame":4,
               "rx":20,
               "ry":20
            });
         }
         if(pot.@hrad.length())
         {
            this.gg.heal(pot.@hrad * this.gg.pers.healMult,2);
         }
         if(pot.@hpoison.length())
         {
            this.gg.heal(pot.@hpoison,4,false);
         }
         if(pot.@hcut.length())
         {
            this.gg.heal(pot.@hcut,3,false);
         }
         if(pot.@horgan.length())
         {
            this.gg.pers.heal(pot.@horgan,norgan);
         }
         if(pot.@horgans.length())
         {
            this.gg.pers.heal(pot.@horgans,4);
         }
         if(pot.@hblood.length())
         {
            this.gg.pers.heal(pot.@hblood * this.gg.pers.piFactor("bloodYield"),5);
         }
         if(pot.@hmana.length())
         {
            this.gg.pers.heal(pot.@hmana,6);
         }
         if(pot.@hpurif.length())
         {
            for each(eff in this.owner.effects)
            {
               if(eff.tip == 4)
               {
                  eff.unsetEff(false,true,false);
               }
            }
            this.gg.remEffect("curse");
            World.w.game.triggers["curse"] = 0;
            this.gg.pers.setParameters();
         }
         if(pot.@hpet.length())
         {
            pet = this.gg.pets[pot.@pet];
            pet.heal(pot.@hpet,0);
         }
         if(pot.@perk.length())
         {
            this.gg.pers.addPerk(pot.@perk);
         }
         if(pot.@effect.length())
         {
            eff = this.gg.addEffect(pot.@effect);
            if(pot.@tip == "him")
            {
               if(this.gg.pers.himLevel > 0)
               {
                  eff.lvl = this.gg.pers.himLevel;
                  this.gg.pers.setParameters();
               }
               eff.t *= this.gg.pers.himTimeMult;
            }
         }
         if(pot.@alc.length())
         {
            this.gg.addEffect("drunk",0,pot.@alc * 10);
         }
         if(pot.@rad.length())
         {
            this.gg.drad2 += pot.@rad * 1;
            trace(pot.@rad,this.gg.drad2);
         }
         if(pot.@ad.length())
         {
            n1 = int(pot.@admin);
            n2 = int(pot.@admax);
            n = Math.round(Math.random() * (n2 - n1) + n1) * this.gg.pers.himBadMult * this.gg.pers.himBadDif;
            if(this.gg.pers.addictions[pot.@ad] == null)
            {
               this.gg.pers.addictions[pot.@ad] = 0;
            }
            prev = int(this.gg.pers.addictions[pot.@ad]);
            this.gg.pers.addictions[pot.@ad] += n;
            if(this.gg.pers.addictions[pot.@ad] > this.gg.pers.admax)
            {
               this.gg.pers.addictions[pot.@ad] = this.gg.pers.admax;
            }
            if(prev < this.gg.pers.ad3 && prev + n >= this.gg.pers.ad3)
            {
               World.w.gui.infoText("addiction3",Res.txt("i",ci));
            }
            else if(prev < this.gg.pers.ad2 && prev + n >= this.gg.pers.ad2)
            {
               World.w.gui.infoText("addiction2",Res.txt("i",ci));
            }
            else if(prev < this.gg.pers.ad1 && prev + n >= this.gg.pers.ad1)
            {
               World.w.gui.infoText("addiction1",Res.txt("i",ci));
            }
         }
         if(pot.@tip == "food")
         {
            if(pot.@ftip == "1")
            {
               World.w.gui.infoText("usedfood2",Res.txt("i",ci));
            }
            else
            {
               World.w.gui.infoText("usedfood",Res.txt("i",ci));
            }
         }
         else if(pot.@heal == "organ")
         {
            World.w.gui.infoText("usedheal",Res.txt("i",ci));
         }
         else
         {
            World.w.gui.infoText("heal",Res.txt("i",ci));
         }
         if(pot.@inf > 0)
         {
            return true;
         }
         this.minusItem(ci);
         if(ci == "potHP") this.gg.pers.piEvent("potion");
         return true;
      }
      
      public function useItem(param1:String = null) : Boolean
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"useItem",[param1])))
         {
            return false;
         }
         if(param1 == null)
         {
            if(this.cItem < 0)
            {
               return false;
            }
            if(World.w.gui.t_item <= 0)
            {
               World.w.gui.setItems();
               return false;
            }
            param1 = this.itemsId[this.cItem];
         }
         if(param1 == "mworkbench" || param1 == "mworkexpl" || param1 == "mworklab")
         {
            if(World.w.t_battle > 0)
            {
               World.w.gui.infoText("noUseCombat",null,null,false);
               return false;
            }
            World.w.pip.workTip = param1;
            World.w.pip.onoff(7);
            return false;
         }
         if(this.items[param1].kol <= 0)
         {
            return false;
         }
         var _loc2_:* = this.items[param1].xml;
         if(_loc2_ == null)
         {
            return false;
         }
         var _loc3_:String = _loc2_.@tip;
         if(_loc2_.@paint.length())
         {
            this.gg.changePaintWeapon(_loc2_.@id,_loc2_.@paint,_loc2_.@blend);
            World.w.gui.infoText("inUse",this.items[param1].nazv);
            return true;
         }
         if(_loc2_.@text.length())
         {
            if(World.w.t_battle > 0)
            {
               World.w.gui.infoText("noUseCombat",null,null,false);
               return false;
            }
            World.w.pip.onoff(-1);
            World.w.gui.dialog(_loc2_.@text);
            if(_loc2_.@perk.length())
            {
               this.gg.pers.addPerk(_loc2_.@perk);
            }
            return true;
         }
         if(param1 == "rollup")
         {
            if(!this.useRollup())
            {
               return false;
            }
         }
         else
         {
            if(_loc3_ == "med" || _loc3_ == "him" || _loc3_ == "pot")
            {
               return this.usePotion(param1);
            }
            if(_loc3_ == "food")
            {
               if(World.w.alicorn)
               {
                  World.w.gui.infoText("alicornNot",null,null,false);
                  return false;
               }
               if(World.w.t_battle > 0)
               {
                  World.w.gui.infoText("noUseCombat",null,null,false);
                  return false;
               }
               return this.usePotion(param1);
            }
            if(_loc3_ == "spell")
            {
               if(World.w.alicorn)
               {
                  World.w.gui.infoText("alicornNot",null,null,false);
                  return false;
               }
               this.gg.changeSpell(param1);
               return false;
            }
            if(_loc3_ == "book")
            {
               if(World.w.t_battle > 0)
               {
                  World.w.gui.infoText("noUseCombat",null,null,false);
                  return false;
               }
               if(World.w.hardInv && !World.w.loc.base)
               {
                  World.w.gui.infoText("noBase");
                  return false;
               }
               if(_loc2_.@perk.length())
               {
                  this.gg.pers.addPerk(_loc2_.@perk);
               }
               else
               {
                  this.gg.pers.upSkill(param1);
               }
               ++this.items["lbook"].kol;
            }
            else if(param1 == "sphera")
            {
               if(World.w.t_battle > 0)
               {
                  World.w.gui.infoText("noUseCombat",null,null,false);
                  return false;
               }
               if(World.w.hardInv && !World.w.loc.base)
               {
                  World.w.gui.infoText("noBase");
                  return false;
               }
               this.gg.pers.addSkillPoint(1,true);
            }
            else
            {
               if(param1 == "runa" || param1 == "reboot")
               {
                  return false;
               }
               if(param1 == "rep")
               {
                  if(!this.repWeapon(this.gg.currentWeapon))
                  {
                     return false;
                  }
               }
               else if(param1 == "stealth")
               {
                  if(World.w.alicorn)
                  {
                     World.w.gui.infoText("alicornNot",null,null,false);
                     return false;
                  }
                  this.gg.addEffect("stealth");
               }
               else
               {
                  if(_loc2_.@pet.length())
                  {
                     if(World.w.alicorn)
                     {
                        World.w.gui.infoText("alicornNot",null,null,false);
                        return false;
                     }
                     this.gg.callPet(_loc2_.@pet);
                     return true;
                  }
                  if(!_loc2_.@chdif.length())
                  {
                     return false;
                  }
                  if(!World.w.game.changeDif(_loc2_.@chdif))
                  {
                     return false;
                  }
                  World.w.gui.infoText("changeDif",Res.guiText("dif" + _loc2_.@chdif));
               }
            }
         }
         this.minusItem(param1);
         if(param1 == this.itemsId[this.cItem] && World.w.gui.t_item > 0)
         {
            World.w.gui.setItems();
         }
         World.w.calcMass = true;
         return true;
      }
      
      public function useFav(param1:int) : *
      {
         var ci:String = null;
         var n:int = param1;
         ci = this.fav[n];
         if(ci == null)
         {
            return;
         }
         var item:* = rconnectXmlFind(AllData.d.weapon,"id",ci);
         if(item.length())
         {
            this.gg.changeWeapon(ci);
            return;
         }
         item = rconnectXmlFind(AllData.d.armor,"id",ci);
         if(item.length())
         {
            this.gg.changeArmor(ci);
            return;
         }
         item = rconnectXmlFind(AllData.d.item,"id",ci);
         if(item.length())
         {
            this.useItem(ci);
         }
      }
      
      public function addWeapon(param1:String, param2:int = 16777215, param3:int = 0, param4:int = 0, param5:int = 0) : Weapon
      {
         if(param1 == null)
         {
            return null;
         }
         if(this.weapons[param1])
         {
            this.weapons[param1].repair(param2);
            return this.weapons[param1];
         }
         var _loc6_:Weapon = Weapon.create(this.owner,param1,param5);
         if(_loc6_ == null)
         {
            return null;
         }
         if(_loc6_.tip == 5 || param2 == 16777215)
         {
            _loc6_.hp = _loc6_.maxhp;
         }
         else
         {
            _loc6_.hp = param2;
         }
         if(param3 > 0)
         {
            _loc6_.hold = param3;
         }
         if(_loc6_.tip == 4 && param4 == 3)
         {
            param4 = 0;
         }
         _loc6_.respect = param4;
         this.weapons[param1] = _loc6_;
         return _loc6_;
      }
      
      public function remWeapon(param1:String) : *
      {
         if(this.weapons[param1])
         {
            if(this.weapons[param1] == this.gg.currentWeapon)
            {
               this.gg.changeWeapon(param1,true);
            }
            if(this.weapons[param1].hold > 0)
            {
               this.items[this.weapons[param1].ammo].kol += this.weapons[param1].hold;
               this.weapons[param1].hold = 0;
            }
            if(Boolean(this.items["s_" + param1]) && this.items["s_" + param1].kol > 0)
            {
               this.weapons[param1].respect = 3;
            }
            else
            {
               this.weapons[param1] = null;
            }
         }
      }
      
      public function updWeapon(param1:String, param2:int) : *
      {
         if(this.weapons[param1] == null)
         {
            this.addWeapon(param1);
         }
         this.weapons[param1].updVariant(param2);
      }
      
      public function respectWeapon(param1:String) : int
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"respectWeapon",[param1])))
         {
            return 0;
         }
         var _loc2_:Weapon = this.weapons[param1];
         if(_loc2_ == null)
         {
            return 2;
         }
         if(_loc2_.respect == 0 || _loc2_.respect == 2)
         {
            _loc2_.respect = 1;
         }
         else
         {
            _loc2_.respect = 2;
         }
         if(Boolean(this.gg.currentWeapon) && this.gg.currentWeapon.respect == 1)
         {
            this.gg.changeWeapon(this.gg.currentWeapon.id);
         }
         if(_loc2_.respect == 1 && Boolean(this.gg.currentSpell) && this.gg.currentSpell.id == _loc2_.id)
         {
            this.gg.changeSpell("");
         }
         this.calcWeaponMass();
         return _loc2_.respect;
      }
      
      public function repWeapon(param1:Weapon, param2:Number = 1) : Boolean
      {
         var _loc3_:* = undefined;
         if(param1 && param1.tip > 0 && param1.tip < 4 && param1.rep_eff > 0)
         {
            if(param1.hp < param1.maxhp)
            {
               _loc3_ = param1.maxhp * this.gg.pers.repairMult * param1.rep_eff * param2;
               param1.repair(_loc3_);
               World.w.gui.infoText("repairWeapon",param1.nazv,Math.round(param1.hp / param1.maxhp * 100));
               World.w.gui.setWeapon();
               return true;
            }
            World.w.gui.infoText("noRepair");
            return false;
         }
         World.w.gui.infoText("noRepair2");
         return false;
      }
      
      public function repairWeapon(param1:String, param2:int) : *
      {
         var _loc5_:Number = Number(NaN);
         if(param2 == undefined || isNaN(param2))
         {
            return;
         }
         var _loc3_:* = (this.weapons[param1] as Weapon).hp;
         var _loc4_:* = Math.round(param2 * this.gg.pers.repairMult);
         if(_loc3_ < param2)
         {
            _loc4_ = Math.round(param2 - _loc3_ + _loc3_ * this.gg.pers.repairMult);
         }
         (this.weapons[param1] as Weapon).repair(_loc4_);
         if(this.gg.pers.barahlo)
         {
            _loc5_ = param2 / (this.weapons[param1] as Weapon).maxhp / (this.weapons[param1] as Weapon).rep_eff;
            if((this.weapons[param1] as Weapon).rep_eff <= 0)
            {
               return;
            }
            if(_loc5_ < 0.3)
            {
               _loc5_ = 0.3;
            }
            if(_loc5_ < 1 && _loc5_ < Math.random())
            {
               return;
            }
            _loc5_ = Math.round(_loc5_);
            this.items["frag"].kol += _loc5_;
            if(!World.w.testLoot)
            {
               World.w.gui.infoText("take",Res.txt("i","frag") + (_loc5_ > 1 ? " (" + _loc5_ + ")" : ""));
            }
         }
      }
      
      public function favItem(param1:String, param2:int) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"favItem",[param1,param2])))
         {
            return;
         }
         var xml:* = undefined;
         var id:String = param1;
         var cell:int = param2;
         if(Boolean(this.gg) && (cell == 29 || cell == 30))
         {
            if(this.weapons[id] == null || this.weapons[id].tip != 4 && this.weapons[id].tip != 5 || Boolean(this.weapons[id].spell))
            {
               World.w.gui.infoText("onlyExpl");
               return;
            }
            if(cell == 29)
            {
               if(Boolean(this.gg.throwWeapon) && id == this.gg.throwWeapon.id)
               {
                  this.gg.throwWeapon = null;
               }
               else
               {
                  this.gg.throwWeapon = this.weapons[id];
                  this.gg.throwWeapon.setNull();
                  this.gg.throwWeapon.setPers(this.gg,this.gg.pers);
                  this.gg.throwWeapon.addVisual();
                  if(this.gg.throwWeapon.tip == 4)
                  {
                     this.gg.throwWeapon.remVisual();
                  }
               }
            }
            if(cell == 30)
            {
               if(Boolean(this.gg.magicWeapon) && id == this.gg.magicWeapon.id)
               {
                  this.gg.magicWeapon = null;
               }
               else
               {
                  this.gg.magicWeapon = this.weapons[id];
                  this.gg.magicWeapon.setNull();
                  this.gg.magicWeapon.setPers(this.gg,this.gg.pers);
                  this.gg.magicWeapon.addVisual();
                  if(this.gg.magicWeapon.tip == 4)
                  {
                     this.gg.magicWeapon.remVisual();
                  }
               }
            }
         }
         if(cell < 29 && cell >= 25)
         {
            xml = rconnectXmlFind(AllData.d.item,"id",id);
            if(xml.length() == 0 || xml.@tip != "spell")
            {
               World.w.gui.infoText("onlySpell");
               return;
            }
         }
         var prevCell:* = this.favIds[id];
         var prevId:* = this.fav[cell];
         if(this.fav[prevCell])
         {
            this.fav[prevCell] = null;
         }
         if(this.favIds[prevId])
         {
            this.favIds[prevId] = null;
         }
         if(prevCell != cell)
         {
            this.fav[cell] = id;
            this.favIds[id] = cell;
         }
      }
      
      public function addArmor(param1:String, param2:int = 16777215, param3:int = 0) : Armor
      {
         var w:Armor = null;
         var id:String = param1;
         var hp:int = param2;
         var nlvl:int = param3;
         if(this.armors[id])
         {
            return null;
         }
         var node:* = rconnectXmlFind(AllData.d.armor,"id",id);
         if(!node)
         {
            return null;
         }
         w = new Armor(id,nlvl);
         w.hp = hp;
         if(w.hp > w.maxhp)
         {
            w.hp = w.maxhp;
         }
         this.armors[id] = w;
         return w;
      }
      
      public function addSpell(param1:String) : Spell
      {
         if(param1 == null)
         {
            return null;
         }
         if(this.spells[param1])
         {
            return this.spells[param1];
         }
         var _loc2_:Spell = new Spell(this.owner,param1);
         if(_loc2_ == null)
         {
            return null;
         }
         this.spells[param1] = _loc2_;
         var _loc3_:Weapon = this.addWeapon(param1);
         _loc3_.spell = true;
         _loc3_.nazv = _loc2_.nazv;
         return _loc2_;
      }
      
      public function addAllSpells() : *
      {
         var sp:* = undefined;
         for each(sp in rconnectXmlFind(AllData.d.item,"tip","spell"))
         {
            this.addSpell(sp.@id);
         }
      }
      
      public function take(param1:Item, param2:int = 0) : *
      {
         var res:String = null;
         var patron:* = undefined;
         var hp:int = 0;
         var l:Item = param1;
         var tr:int = param2;
         var kol:int = 0;
         var color:int = -1;
         try
         {
            if(l.tip == Item.L_WEAPON)
            {
               patron = l.xml.a[0];
               if(tr == 0 && Boolean(patron) && patron != "recharg")
               {
                  kol = Math.floor(Math.random() * rconnectXmlFind(AllData.d.item,"id",patron).@kol) + 1;
                  this.items[patron].kol += kol;
               }
               if(l.variant > 0 && Boolean(l.xml.char[l.variant].@maxhp.length()))
               {
                  hp = Math.round(l.xml.char[l.variant].@maxhp * l.sost * l.multHP);
               }
               else
               {
                  hp = Math.round(l.xml.char[0].@maxhp * l.sost * l.multHP);
               }
               if(this.weapons[l.id])
               {
                  if(this.weapons[l.id].variant < l.variant)
                  {
                     if(tr == 0 && !World.w.testLoot)
                     {
                        World.w.gui.infoText("takeWeapon",l.nazv,Math.round(l.sost * l.multHP * 100));
                     }
                     this.updWeapon(l.id,l.variant);
                  }
                  if(this.weapons[l.id].tip != 5)
                  {
                     this.repairWeapon(l.id,hp);
                     if(!World.w.testLoot)
                     {
                        World.w.gui.infoText("repairWeapon",this.weapons[l.id].nazv,Math.round(this.weapons[l.id].hp / this.weapons[l.id].maxhp * 100));
                     }
                  }
               }
               else
               {
                  if(tr == 0 && !World.w.testLoot)
                  {
                     World.w.gui.infoText("takeWeapon",l.nazv,Math.round(l.sost * l.multHP * 100));
                  }
                  this.addWeapon(l.id,hp,0,0,l.variant);
                  this.takeScript(l.id);
                  if(this.owner.player && this.gg.currentWeapon == null)
                  {
                     this.gg.changeWeapon(l.id);
                  }
               }
               if(l.shpun == 2)
               {
                  this.weapons[l.id].respect = 0;
               }
               World.w.gui.setWeapon();
               World.w.calcMassW = true;
               color = 5;
            }
            else if(l.tip == Item.L_ARMOR)
            {
               hp = Math.round(l.xml.@hp * l.sost * l.multHP);
               this.addArmor(l.id,hp);
               color = 3;
            }
            else if(l.tip == Item.L_SPELL)
            {
               this.plus(l,tr);
               World.w.calcMassW = true;
               color = 5;
            }
            else if(l.tip == Item.L_SCHEME)
            {
               if(this.items[l.id].kol == 0)
               {
                  this.takeScript(l.id);
               }
               this.plus(l,tr);
               if(tr <= 1 && !World.w.testLoot)
               {
                  World.w.gui.infoText("take",l.nazv);
               }
               if(Boolean(l.xml) && l.xml.@cat == "weapon" && this.weapons[l.id.substr(2)] == null)
               {
                  this.addWeapon(l.id.substr(2),16777215,0,3);
               }
               if(Boolean(l.xml) && l.xml.@cat == "armor" && this.armors[l.id.substr(2)] == null)
               {
                  this.addArmor(l.id.substr(2),16777215,-1);
               }
               color = 7;
            }
            else if(l.tip == Item.L_EXPL)
            {
               this.plus(l,tr);
               if(!this.weapons[l.id])
               {
                  this.addWeapon(l.id);
               }
               if(tr == 0 && !World.w.testLoot)
               {
                  World.w.gui.infoText("take",l.nazv + (l.kol > 1 ? " (" + l.kol + ")" : ""));
               }
               color = 3;
            }
            else if(l.tip == Item.L_AMMO)
            {
               this.plus(l,tr);
               if(tr == 0 && !World.w.testLoot)
               {
                  World.w.gui.infoText("takeAmmo",l.nazv,l.kol);
               }
               color = 3;
            }
            else if(l.tip == Item.L_MED)
            {
               this.plus(l,tr);
               if(tr == 0 && !World.w.testLoot)
               {
                  World.w.gui.infoText("takeMed",l.nazv);
               }
               if(this.cItem < 0)
               {
                  this.nextItem(1);
               }
               else
               {
                  World.w.gui.setItems();
               }
               color = 1;
            }
            else if(l.tip == Item.L_BOOK)
            {
               if(this.items[l.id].kol == 0)
               {
                  this.takeScript(l.id);
               }
               this.plus(l,tr);
               if(tr <= 1 && !World.w.testLoot)
               {
                  World.w.gui.infoText("takeBook",l.nazv);
               }
               if(this.cItem < 0)
               {
                  this.nextItem(1);
               }
               else
               {
                  World.w.gui.setItems();
               }
               color = 4;
            }
            else if(l.tip == Item.L_INSTR || l.tip == Item.L_ART || l.tip == Item.L_IMPL || Boolean(l.xml) && Boolean(l.xml.sk.length()))
            {
               if(this.items[l.id].kol == 0)
               {
                  this.takeScript(l.id);
               }
               this.plus(l,tr);
               if(tr == 0 && !World.w.testLoot)
               {
                  World.w.gui.infoText("take",l.nazv);
               }
               this.gg.pers.setParameters();
               color = 6;
            }
            else
            {
               if(this.items[l.id].kol == 0)
               {
                  this.takeScript(l.id);
               }
               this.plus(l,tr);
               if(tr == 0 && !World.w.testLoot)
               {
                  if(l.id == "money")
                  {
                     World.w.gui.infoText("takeMoney",l.kol);
                  }
                  else
                  {
                     World.w.gui.infoText("take",l.nazv + (l.kol > 1 ? " (" + l.kol + ")" : ""));
                  }
               }
               if(this.cItem < 0)
               {
                  this.nextItem(1);
               }
               else
               {
                  World.w.gui.setItems();
               }
               if(l.tip == "valuables")
               {
                  color = 2;
               }
               else if(l.tip == Item.L_HIM || l.tip == Item.L_POT)
               {
                  color = 1;
               }
               else if(l.tip == Item.L_KEY || l.tip == Item.L_SPEC)
               {
                  color = 6;
               }
               else if(l.tip == "equip")
               {
                  color = 8;
               }
               else
               {
                  color = 0;
               }
            }
            if(tr == 2)
            {
               if(l.kol > 1)
               {
                  World.w.gui.infoText("reward",l.nazv,l.kol);
               }
               else
               {
                  World.w.gui.infoText("reward2",l.nazv);
               }
            }
            if(tr == 0 && l.imp == 0 && Boolean(l.xml.@limit.length()))
            {
               World.w.game.addLimit(l.xml.@limit,2);
            }
            if(!World.w.testLoot && (tr == 0 || tr == 2))
            {
               if(l.fc >= 0)
               {
                  color = l.fc;
               }
               World.w.gui.floatText(l.nazv + (l.kol > 1 ? " (" + l.kol + ")" : ""),this.gg.X,this.gg.Y,color);
            }
            if(World.w.helpMess || l.tip == "art")
            {
               if(l.mess != null && World.w.game.triggers["mess_" + l.mess] <= 0)
               {
                  World.w.game.triggers["mess_" + l.mess] = 1;
                  World.w.gui.impMess(Res.txt("i",l.mess),Res.txt("i",l.mess,2),l.mess);
               }
            }
            if(l.imp == 2 && Boolean(l.cont))
            {
               l.cont.receipt();
            }
            res = World.w.game.checkQuests(l.id);
            if(res != null)
            {
               World.w.gui.infoText("collect",res);
            }
         }
         catch(err:*)
         {
            World.w.showError(err,"Loot error. tip:" + l.tip + " id:" + l.id);
         }
         if(World.w.hardInv)
         {
            this.mass[l.invCat] += l.mass * l.kol;
         }
         World.w.calcMass = true;
      }
      
      internal function plus(param1:Item, param2:int = 0) : *
      {
         if(param1.id != "money")
         {
            if(this.items[param1.id].kol == 0)
            {
               this.items[param1.id].nov = 1;
            }
            else if(this.items[param1.id].nov == 0)
            {
               this.items[param1.id].nov = 2;
            }
            this.items[param1.id].dat = new Date().getTime();
         }
         if(param2 == 1)
         {
            this.items[param1.id].kol += param1.bou;
            param1.trade();
         }
         else
         {
            this.items[param1.id].kol += param1.kol;
         }
         if(param1.tip == Item.L_SCHEME || param1.tip == Item.L_SPELL)
         {
            this.items[param1.id].kol = 1;
         }
      }
      
      public function plusItem(param1:String, param2:int = 1) : *
      {
         if(this.items[param1] == null)
         {
            trace("Ошибка увеличения количества",param1);
            return;
         }
         if(param1 != "money")
         {
            if(this.items[param1].kol == 0)
            {
               this.items[param1].nov = 1;
            }
            else if(this.items[param1].nov == 0)
            {
               this.items[param1].nov = 2;
            }
            this.items[param1].dat = new Date().getTime();
         }
         this.items[param1].kol += param2;
      }
      
      public function minusItem(param1:String, param2:int = 1, param3:Boolean = true) : *
      {
         if(this.items[param1] == null)
         {
            trace("Ошибка уменьшения количества",param1);
            return;
         }
         if(this.items[param1].kol >= param2)
         {
            this.items[param1].kol -= param2;
         }
         else
         {
            this.items[param1].vault -= param2 - this.items[param1].kol;
            this.items[param1].kol = 0;
            if(this.items[param1].vault < 0)
            {
               this.items[param1].vault = 0;
            }
         }
         if(this.items[param1].kol == 0)
         {
            this.nextItem(1);
         }
         try
         {
            if(Boolean(this.items[this.itemsId[this.cItem]]) && this.items[this.itemsId[this.cItem]].kol == 0)
            {
               this.cItem = -1;
            }
         }
         catch(err:*)
         {
         }
         if(param3 && Boolean(this.items[param1].xml) && Boolean(this.items[param1].xml.@uses.length()))
         {
            Snd.ps(this.items[param1].xml.@uses,this.owner.X,this.owner.Y);
         }
      }
      
      public function checkKol(param1:String, param2:int = 1) : Boolean
      {
         if(Boolean(World.w.loc) && World.w.loc.base)
         {
            if(this.items[param1].kol + this.items[param1].vault >= param2)
            {
               return true;
            }
            return false;
         }
         if(this.items[param1].kol >= param2)
         {
            return true;
         }
         return false;
      }
      
      public function calcMass() : *
      {
         var _loc1_:Item = null;
         this.mass[1] = this.mass[2] = this.mass[3] = 0;
         for each(_loc1_ in this.items)
         {
            this.mass[_loc1_.invCat] += _loc1_.mass * _loc1_.kol;
         }
         World.w.checkLoot = true;
         World.w.pers.invMassParam();
      }
      
      public function calcWeaponMass() : *
      {
         var _loc1_:Weapon = null;
         this.massW = this.massM = 0;
         for each(_loc1_ in this.weapons)
         {
            if(_loc1_ != null)
            {
               if(_loc1_.tip > 0 && _loc1_.tip < 4 && (_loc1_.respect == 0 || _loc1_.respect == 2))
               {
                  this.massW += _loc1_.mass;
               }
               if(_loc1_.tip == 5 && (_loc1_.respect == 0 || _loc1_.respect == 2) && (!_loc1_.spell || this.items[_loc1_.id] && this.items[_loc1_.id].kol > 0))
               {
                  this.massM += _loc1_.mass;
               }
            }
         }
         World.w.checkLoot = true;
         World.w.pers.invMassParam();
      }
      
      public function damageItems(param1:Number, param2:Boolean = true) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         if(!param2 && !World.w.loc.base && !World.w.alicorn)
         {
            param1 = 5;
         }
         if(this.mass[1] <= World.w.pers.maxm1 || param1 <= 0)
         {
            return;
         }
         var _loc3_:* = param1 * (this.mass[1] - World.w.pers.maxm1) / 800;
         if(_loc3_ >= 1 || Math.random() < _loc3_)
         {
            _loc3_ = Math.ceil(_loc3_ * Math.random());
            _loc4_ = 1;
            while(_loc4_ < 20)
            {
               _loc5_ = this.eqip[Math.floor(Math.random() * this.eqip.length)];
               if(this.items[_loc5_].kol > 0)
               {
                  if(param2)
                  {
                     this.minusItem(_loc5_,_loc3_,false);
                     World.w.gui.infoText("itemDestr",this.items[_loc5_].nazv,_loc3_);
                  }
                  else
                  {
                     this.drop(_loc5_,_loc3_);
                     World.w.gui.infoText("itemLose",this.items[_loc5_].nazv,_loc3_);
                  }
                  World.w.calcMass = true;
                  return;
               }
               _loc4_++;
            }
         }
      }
      
      public function retMass(param1:int) : String
      {
         var _loc2_:String = null;
         var _loc4_:Number = Number(NaN);
         var _loc5_:Number = Number(NaN);
         var _loc3_:String = "mass";
         if(param1 >= 1 && param1 <= 3)
         {
            _loc2_ = "allmass" + param1;
            _loc4_ = Number(this.mass[param1]);
            _loc5_ = Number(this.gg.pers["maxm" + param1]);
         }
         else if(param1 == 4)
         {
            _loc2_ = "allweap";
            _loc4_ = this.massW;
            _loc5_ = this.gg.pers.maxmW;
         }
         else if(param1 == 5)
         {
            _loc2_ = "allmagic";
            _loc4_ = this.massM;
            _loc5_ = this.gg.pers.maxmM;
         }
         if(_loc4_ > _loc5_)
         {
            _loc3_ = "red";
         }
         return Res.pipText(_loc2_) + ": <span class = \'" + _loc3_ + "\'>" + Res.numb(_loc4_) + "/" + Math.round(_loc5_) + "</span>";
      }
      
      public function drop(param1:String, param2:int = 1) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"drop",[param1,param2])))
         {
            return;
         }
         if(World.w.loc.base || World.w.alicorn)
         {
            return;
         }
         if(param2 > this.items[param1].kol)
         {
            param2 = int(this.items[param1].kol);
         }
         if(param2 <= 0)
         {
            return;
         }
         var _loc3_:Item = new Item(null,param1,param2);
         var _loc4_:Loot = new Loot(World.w.loc,_loc3_,this.owner.X,this.owner.Y - this.owner.scY / 2,true,false,false);
         this.minusItem(param1,param2,false);
      }
      
      public function takeScript(param1:String) : *
      {
         if(World.w.land.itemScripts[param1])
         {
            World.w.land.itemScripts[param1].start();
         }
      }
      
      public function getKolAmmos() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:Item = null;
         for(_loc1_ in this.ammos)
         {
            this.ammos[_loc1_] = 0;
         }
         for each(_loc2_ in this.items)
         {
            if(_loc2_.base != "")
            {
               this.ammos[_loc2_.base] += _loc2_.kol;
            }
         }
      }
      
      internal function useRollup() : Boolean
      {
         var xml1:* = undefined;
         var smokeScr:Script = null;
         if(!World.w.loc.base)
         {
            World.w.gui.infoText("noBase");
            return false;
         }
         World.w.pip.onoff(-1);
         xml1 = rconnectXmlFind(GameData.d.scr,"id","smokeRollup");
         if(xml1.length())
         {
            xml1 = xml1[0];
            smokeScr = new Script(xml1,World.w.loc.land,this.gg);
            smokeScr.start();
            World.w.game.triggers["rollup"] = 1;
         }
         return true;
      }
      
      public function addMin() : *
      {
         this.addWeapon("r32");
         this.addWeapon("rech");
         this.addWeapon("mont");
         this.addWeapon("bat");
         this.cWeaponId = "r32";
         this.addArmor("pip");
         this.cArmorId = "pip";
         this.items["p32"].kol = 16;
         this.items["money"].kol = 50;
         this.items["pot0"].kol = 1;
         this.items["pot1"].kol = 1;
         this.items["screwdriver"].kol = 1;
         this.favItem("mont",1);
         this.favItem("r32",2);
      }
      
      public function addBegin() : *
      {
         this.addArmor("pip");
         this.cArmorId = "pip";
      }
      
      public function addAllWeapon() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in LootGen.arr["weapon"])
         {
            this.addWeapon(_loc1_.id);
         }
         for each(_loc1_ in LootGen.arr["e"])
         {
            this.addWeapon(_loc1_.id);
         }
         for each(_loc1_ in LootGen.arr["magic"])
         {
            this.addWeapon(_loc1_.id);
         }
      }
      
      public function addAllAmmo() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in LootGen.arr["a"])
         {
            this.items[_loc1_.id].kol = 10000;
         }
         for each(_loc1_ in LootGen.arr["e"])
         {
            this.items[_loc1_.id].kol = 10000;
         }
      }
      
      public function addAllItem() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in LootGen.arr["med"])
         {
            this.items[_loc1_.id].kol = 1000;
         }
         for each(_loc1_ in LootGen.arr["compa"])
         {
            this.items[_loc1_.id].kol = 1000;
         }
         for each(_loc1_ in LootGen.arr["him"])
         {
            this.items[_loc1_.id].kol = 1000;
         }
         for each(_loc1_ in LootGen.arr["book"])
         {
            this.items[_loc1_.id].kol = 10;
         }
         for each(_loc1_ in LootGen.arr["scheme"])
         {
            this.take(new Item(Item.L_SCHEME,_loc1_.id));
         }
         for each(_loc1_ in LootGen.arr["spell"])
         {
            this.take(new Item(Item.L_SPELL,_loc1_.id));
         }
         for each(_loc1_ in LootGen.arr["compw"])
         {
            this.items[_loc1_.id].kol = 100;
         }
         for each(_loc1_ in LootGen.arr["compe"])
         {
            this.items[_loc1_.id].kol = 100;
         }
         for each(_loc1_ in LootGen.arr["compm"])
         {
            this.items[_loc1_.id].kol = 100;
         }
         for each(_loc1_ in LootGen.arr["compp"])
         {
            this.items[_loc1_.id].kol = 1000;
         }
         for each(_loc1_ in LootGen.arr["stuff"])
         {
            this.items[_loc1_.id].kol = 1000;
         }
         for each(_loc1_ in LootGen.arr["paint"])
         {
            this.items[_loc1_.id].kol = 1;
         }
         for each(_loc1_ in LootGen.arr["pot"])
         {
            this.items[_loc1_.id].kol = 100;
         }
         for each(_loc1_ in LootGen.arr["food"])
         {
            this.items[_loc1_.id].kol = 100;
         }
         this.items["stealth"].kol = 1000;
         this.items["potHP"].kol = 1000;
         this.items["rep"].kol = 1000;
         this.items["sphera"].kol = 100;
         this.items["screwdriver"].kol = 1;
      }
      
      public function addAllArmor() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in AllData.d.armor)
         {
            this.addArmor(_loc1_.@id);
         }
      }
      
      public function addAll() : *
      {
         this.addAllWeapon();
         this.addAllAmmo();
         this.addAllItem();
         this.addAllArmor();
      }
      
      public function addLoad(param1:Object) : *
      {
         var _loc2_:* = undefined;
         var _loc3_:Weapon = null;
         if(param1 == null)
         {
            return;
         }
         for each(_loc2_ in param1.weapons)
         {
            _loc3_ = this.addWeapon(_loc2_.id,_loc2_.hp,_loc2_.hold,_loc2_.respect,_loc2_.variant);
            if(_loc2_.ammo)
            {
               _loc3_.setAmmo(_loc2_.ammo,this.items[_loc2_.ammo].xml);
            }
         }
         for each(_loc2_ in param1.armors)
         {
            this.addArmor(_loc2_.id,_loc2_.hp,_loc2_.lvl);
         }
         for(_loc2_ in param1.items)
         {
            if(this.items[_loc2_])
            {
               this.items[_loc2_].kol = param1.items[_loc2_];
            }
            if(isNaN(this.items[_loc2_].kol))
            {
               this.items[_loc2_].kol = 0;
            }
            if(Boolean(param1.vault) && param1.vault[_loc2_] > 0)
            {
               this.items[_loc2_].vault = param1.vault[_loc2_];
            }
         }
         for(_loc2_ in param1.fav)
         {
            this.favItem(param1.fav[_loc2_],_loc2_);
         }
         this.cWeaponId = param1.cWeaponId;
         this.cArmorId = param1.cArmorId;
         this.cAmulId = param1.cAmulId;
         this.cSpellId = param1.cSpellId;
         this.prevArmor = param1.prevArmor;
         if(this.prevArmor == null)
         {
            this.prevArmor = "";
         }
      }
      
      public function save() : Object
      {
         var _loc2_:* = undefined;
         var _loc1_:Object = new Object();
         _loc1_.weapons = new Array();
         _loc1_.armors = new Array();
         _loc1_.fav = new Array();
         _loc1_.items = new Array();
         _loc1_.vault = new Array();
         for(_loc2_ in this.weapons)
         {
            if(this.weapons[_loc2_] is Weapon)
            {
               _loc1_.weapons[_loc2_] = {
                  "id":this.weapons[_loc2_].id,
                  "hp":this.weapons[_loc2_].hp,
                  "hold":this.weapons[_loc2_].hold,
                  "ammo":this.weapons[_loc2_].ammo,
                  "respect":this.weapons[_loc2_].respect,
                  "variant":this.weapons[_loc2_].variant
               };
            }
         }
         for(_loc2_ in this.armors)
         {
            if(this.armors[_loc2_] is Armor)
            {
               _loc1_.armors[_loc2_] = {
                  "id":this.armors[_loc2_].id,
                  "hp":this.armors[_loc2_].hp,
                  "lvl":this.armors[_loc2_].lvl
               };
            }
         }
         for(_loc2_ in this.fav)
         {
            _loc1_.fav[_loc2_] = this.fav[_loc2_];
         }
         for(_loc2_ in this.items)
         {
            if(_loc2_ != "")
            {
               _loc1_.items[_loc2_] = this.items[_loc2_].kol;
               if(this.items[_loc2_].vault > 0)
               {
                  _loc1_.vault[_loc2_] = this.items[_loc2_].vault;
               }
            }
         }
         if(this.gg.currentWeapon)
         {
            _loc1_.cWeaponId = this.gg.currentWeapon.id;
         }
         else
         {
            _loc1_.cWeaponId = "";
         }
         if(this.gg.currentArmor)
         {
            _loc1_.cArmorId = this.gg.currentArmor.id;
         }
         else
         {
            _loc1_.cArmorId = "";
         }
         if(this.gg.currentAmul)
         {
            _loc1_.cAmulId = this.gg.currentAmul.id;
         }
         else
         {
            _loc1_.cAmulId = "";
         }
         if(this.gg.currentSpell)
         {
            _loc1_.cSpellId = this.gg.currentSpell.id;
         }
         else
         {
            _loc1_.cSpellId = "";
         }
         _loc1_.prevArmor = this.gg.prevArmor;
         return _loc1_;
      }
   }
}

