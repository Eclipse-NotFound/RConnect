package fe.inter
{
   // PI_HOOK_V1: PermanentInjury optional exact-event bridge.
   import fe.*;
   import fe.serv.Item;
   import fe.unit.Pers;
   import flash.display.MovieClip;
   import flash.events.MouseEvent;
   
   public class PipPageMed extends PipPage
   {
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      internal var pers:Pers;
      
      internal var infoItemId:String = "";
      
      internal var priceHP:Number = 0.5;
      
      internal var priceBlood:Number = 0.5;
      
      internal var priceRad:Number = 1;
      
      internal var priceOrgan:Number = 0.5;
      
      internal var priceCut:Number = 4;
      
      internal var pricePoison:Number = 4;
      
      internal var priceMana:Number = 1;
      
      internal var raz:int = 200;
      
      internal var razMana:int = 100;
      
      internal var plata:Item;
      
      public function PipPageMed(param1:PipBuck, param2:String)
      {
         isLC = true;
         itemClass = visPipMedItem;
         super(param1,param2);
         vis.but3.visible = vis.but4.visible = vis.but5.visible = false;
      }
      
      override internal function setSubPages() : *
      {
         var _loc1_:Number = Number(NaN);
         setIco();
         if(pip.npcInter == "adoc")
         {
            vis.but2.visible = false;
            this.plata = inv.gel;
         }
         else if(pip.npcInter == "vdoc")
         {
            vis.but2.visible = false;
            this.plata = inv.good;
         }
         else
         {
            vis.but2.visible = true;
            this.plata = inv.money;
         }
         this.pers = World.w.pers;
         this.priceHP = this.pers.priceHP;
         this.priceBlood = this.pers.priceBlood;
         this.priceRad = this.pers.priceRad;
         this.priceOrgan = this.pers.priceOrgan;
         this.priceCut = this.pers.priceCut;
         this.pricePoison = this.pers.pricePoison;
         this.priceMana = this.pers.priceMana;
         statHead.hpbar.visible = false;
         statHead.nazv.text = "";
         statHead.numb.text = "";
         statHead.price.text = Res.pipText("medprice");
         vis.butOk.visible = vis.butDef.visible = false;
         if(page2 == 1)
         {
            gg.pers.checkHP();
            setTopText("usemed2");
            _loc1_ = (gg.maxhp - gg.hp - gg.rad) * this.priceHP;
            if(_loc1_ < 0)
            {
               _loc1_ = 0;
            }
            arr.push({
               "id":"hp",
               "nazv":Res.pipText("hp"),
               "lvl":Math.round(gg.hp) + "/" + Math.round(gg.maxhp),
               "bar":gg.hp / gg.maxhp,
               "price":_loc1_
            });
            arr.push({
               "id":"organism",
               "nazv":Res.pipText("organism") + ":",
               "lvl":""
            });
            if(gg.pers.inMaxHP - gg.pers.headHP > this.raz)
            {
               _loc1_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc1_ = (gg.pers.inMaxHP - gg.pers.headHP) * this.priceOrgan;
            }
            arr.push({
               "id":"statHead" + gg.pers.headSt,
               "nazv":"   " + Res.pipText("head"),
               "lvl":Math.round(gg.pers.headHP) + "/" + Math.round(gg.pers.inMaxHP),
               "bar":gg.pers.headHP / gg.pers.inMaxHP,
               "price":_loc1_
            });
            if(gg.pers.inMaxHP - gg.pers.torsHP > this.raz)
            {
               _loc1_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc1_ = (gg.pers.inMaxHP - gg.pers.torsHP) * this.priceOrgan;
            }
            arr.push({
               "id":"statTors" + gg.pers.torsSt,
               "nazv":"   " + Res.pipText("tors"),
               "lvl":Math.round(gg.pers.torsHP) + "/" + Math.round(gg.pers.inMaxHP),
               "bar":gg.pers.torsHP / gg.pers.inMaxHP,
               "price":_loc1_
            });
            if(gg.pers.inMaxHP - gg.pers.legsHP > this.raz)
            {
               _loc1_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc1_ = (gg.pers.inMaxHP - gg.pers.legsHP) * this.priceOrgan;
            }
            arr.push({
               "id":"statLegs" + gg.pers.legsSt,
               "nazv":"   " + Res.pipText("legs"),
               "lvl":Math.round(gg.pers.legsHP) + "/" + Math.round(gg.pers.inMaxHP),
               "bar":gg.pers.legsHP / gg.pers.inMaxHP,
               "price":_loc1_
            });
            if(gg.pers.inMaxHP - gg.pers.bloodHP > this.raz)
            {
               _loc1_ = this.raz * this.priceBlood;
            }
            else
            {
               _loc1_ = (gg.pers.inMaxHP - gg.pers.bloodHP) * this.priceBlood;
            }
            arr.push({
               "id":"statBlood" + gg.pers.bloodSt,
               "nazv":"   " + Res.pipText("blood"),
               "lvl":Math.round(gg.pers.bloodHP) + "/" + Math.round(gg.pers.inMaxHP),
               "bar":gg.pers.bloodHP / gg.pers.inMaxHP,
               "price":_loc1_
            });
            if(gg.pers.inMaxMana - gg.pers.manaHP > this.razMana)
            {
               _loc1_ = this.razMana * this.priceMana;
            }
            else
            {
               _loc1_ = (gg.pers.inMaxMana - gg.pers.manaHP) * this.priceMana;
            }
            arr.push({
               "id":"statMana" + gg.pers.manaSt,
               "nazv":"   " + Res.pipText("mana"),
               "lvl":Math.round(gg.pers.manaHP) + "/" + Math.round(gg.pers.inMaxMana),
               "bar":gg.pers.manaHP / gg.pers.inMaxMana,
               "price":_loc1_
            });
            _loc1_ = gg.rad * this.priceRad;
            arr.push({
               "id":"rad",
               "nazv":Res.pipText("rad"),
               "lvl":Math.round(gg.rad),
               "price":_loc1_
            });
            _loc1_ = gg.cut * this.priceCut;
            arr.push({
               "id":"cut",
               "nazv":Res.pipText("cut"),
               "lvl":Math.round(gg.cut * 10) / 10,
               "price":_loc1_
            });
            _loc1_ = gg.poison * this.pricePoison;
            arr.push({
               "id":"poison",
               "nazv":Res.pipText("poison"),
               "lvl":Math.round(gg.poison * 10) / 10,
               "price":_loc1_
            });
         }
         if(page2 == 1) {
            var piRows:* = this.pers.piEvent("doctorRows",{currency:this.plata});
            if(piRows != null) for each(var piRow:Object in piRows) arr.push(piRow);
         }
         this.showBottext();
      }

      override internal function setStatItem(param1:MovieClip, param2:Object) : *
      {
         if(param2.id != null)
         {
            param1.id.text = param2.id;
         }
         else
         {
            param1.id.text = "";
         }
         param1.id.visible = false;
         param1.hpbar.visible = false;
         param1.nazv.text = param2.nazv;
         param1.numb.text = param2.lvl;
         if(param2.price != null)
         {
            param1.price.text = Math.round(param2.price);
         }
         else
         {
            param1.price.text = "";
         }
         if(param2.bar != null)
         {
            param1.hpbar.visible = true;
            param1.hpbar.bar.scaleX = param2.bar;
         }
      }
      
      override internal function statInfo(param1:MouseEvent) : *
      {
         var _loc2_:String = null;
         if(param1.currentTarget.id.text != "")
         {
            if(String(param1.currentTarget.id.text).indexOf("pi:")==0) { vis.nazv.text="永久伤残医疗"; vis.info.text=this.pers.piEvent("describe",String(param1.currentTarget.id.text)); return; }
            vis.nazv.text = Res.pipText(param1.currentTarget.id.text);
            _loc2_ = Res.txt("p",param1.currentTarget.id.text,1);
            vis.info.htmlText = _loc2_;
         }
         else
         {
            vis.nazv.text = vis.info.htmlText = "";
         }
      }
      
      override public function page2Click(param1:MouseEvent) : *
      {
         if(World.w.ctr.setkeyOn)
         {
            return;
         }
         page2 = int(param1.currentTarget.id.text);
         pip.snd(2);
         if(page2 == 2)
         {
            page2 = 1;
            pip.onoff(4);
            pip.currentPage.page2 = 1;
            pip.currentPage.setStatus();
         }
         else
         {
            setStatus();
         }
      }
      
      internal function showBottext() : *
      {
         if(pip.npcInter == "adoc")
         {
            vis.bottext.htmlText = Res.txt("i","gel") + ": " + yel(this.plata.kol);
         }
         else if(pip.npcInter == "vdoc")
         {
            vis.bottext.htmlText = Res.txt("i","good") + ": " + yel(this.plata.kol);
         }
         else
         {
            vis.bottext.htmlText = Res.pipText("caps") + ": " + yel(this.plata.kol);
         }
      }
      
      override internal function itemClick(param1:MouseEvent) : *
      {
         if(PipBuck.rconnectMenu != null && Boolean(PipBuck.rconnectMenu(this,"menuMedical",[page2,String(param1.currentTarget.id.text)])))
         {
            return;
         }
         var _loc2_:Number = Number(NaN);
         var _loc3_:String = null;
         if(pip.noAct)
         {
            World.w.gui.infoText("noAct");
            return;
         }
         this.infoItemId = param1.currentTarget.id.text;
         if(this.infoItemId.indexOf("pi:") == 0) {
            var piResult:* = this.pers.piEvent("doctor",{id:this.infoItemId,currency:this.plata});
            if(piResult != null) { if(piResult.ok && this.plata.id=="money" && pip.vendor) pip.vendor.money+=piResult.cost; setStatus(); this.showBottext(); pip.setRPanel(); vis.info.text=piResult.message; }
            return;
         }
         var _loc4_:* = this.plata.kol;
         if(this.infoItemId == "hp")
         {
            _loc2_ = (gg.maxhp - gg.hp - gg.rad) * this.priceHP;
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            gg.heal(_loc2_ / this.priceHP,0,false);
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId == "rad")
         {
            _loc2_ = gg.rad * this.priceRad;
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            gg.heal(_loc2_ / this.priceRad,2,false);
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId == "cut")
         {
            _loc2_ = gg.cut * this.priceCut;
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            gg.heal(_loc2_ / this.priceCut,3,false);
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId == "poison")
         {
            _loc2_ = gg.poison * this.pricePoison;
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            gg.heal(_loc2_ / this.pricePoison,4,false);
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId.substr(0,9) == "statBlood")
         {
            if(gg.pers.inMaxHP - gg.pers.bloodHP > this.raz)
            {
               _loc2_ = this.raz * this.priceBlood;
            }
            else
            {
               _loc2_ = (gg.pers.inMaxHP - gg.pers.bloodHP) * this.priceBlood;
            }
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            if(gg.pers.bloodHP <= 2 && this.plata.kol <= 0 && gg.pers.level < 6)
            {
               gg.pers.heal(49,5);
            }
            else
            {
               gg.pers.heal(_loc2_ / this.priceBlood,5);
            }
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId.substr(0,8) == "statMana")
         {
            if(gg.pers.inMaxMana - gg.pers.manaHP > this.razMana)
            {
               _loc2_ = this.razMana * this.priceMana;
            }
            else
            {
               _loc2_ = (gg.pers.inMaxMana - gg.pers.manaHP) * this.priceMana;
            }
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            gg.pers.heal(_loc2_ / this.priceMana,6);
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId.substr(0,8) == "statHead")
         {
            if(gg.pers.inMaxHP - gg.pers.headHP > this.raz)
            {
               _loc2_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc2_ = (gg.pers.inMaxHP - gg.pers.headHP) * this.priceOrgan;
            }
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            if(gg.pers.headHP <= 2 && this.plata.kol <= 0 && gg.pers.level < 6)
            {
               gg.pers.heal(49,1);
            }
            else
            {
               gg.pers.heal(_loc2_ / this.priceOrgan,1);
            }
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId.substr(0,8) == "statTors")
         {
            if(gg.pers.inMaxHP - gg.pers.torsHP > this.raz)
            {
               _loc2_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc2_ = (gg.pers.inMaxHP - gg.pers.torsHP) * this.priceOrgan;
            }
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            if(gg.pers.torsHP <= 2 && this.plata.kol <= 0 && gg.pers.level < 6)
            {
               gg.pers.heal(49,2);
            }
            else
            {
               gg.pers.heal(_loc2_ / this.priceOrgan,2);
            }
            this.plata.kol -= Math.round(_loc2_);
         }
         else if(this.infoItemId.substr(0,8) == "statLegs")
         {
            if(gg.pers.inMaxHP - gg.pers.legsHP > this.raz)
            {
               _loc2_ = this.raz * this.priceOrgan;
            }
            else
            {
               _loc2_ = (gg.pers.inMaxHP - gg.pers.legsHP) * this.priceOrgan;
            }
            if(_loc2_ > this.plata.kol)
            {
               _loc2_ = this.plata.kol;
            }
            if(gg.pers.legsHP <= 2 && this.plata.kol <= 0 && gg.pers.level < 6)
            {
               gg.pers.heal(49,3);
            }
            else
            {
               gg.pers.heal(_loc2_ / this.priceOrgan,3);
            }
            this.plata.kol -= Math.round(_loc2_);
         }
         if(this.plata.id == "money" && this.plata.kol < _loc4_ && Boolean(pip.vendor))
         {
            pip.vendor.money += _loc4_ - this.plata.kol;
         }
         pip.snd(1);
         setStatus();
         this.showBottext();
         pip.setRPanel();
      }
   }
}

