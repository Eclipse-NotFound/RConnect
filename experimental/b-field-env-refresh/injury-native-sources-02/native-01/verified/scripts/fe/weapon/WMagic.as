package fe.weapon
{
   import fe.Snd;
   import fe.World;
   import fe.unit.Pers;
   import fe.unit.Unit;
   import fe.unit.UnitPlayer;
   
   public class WMagic extends Weapon
   {
      
      public function WMagic(param1:Unit, param2:String, param3:int = 0)
      {
         super(param1,param2,param3);
         if(prep)
         {
            animated = false;
         }
      }
      
      override public function attack(param1:Boolean = false) : Boolean
      {
         if(!param1 && !World.w.alicorn && !auto && t_auto > 0)
         {
            t_auto = 3;
            return false;
         }
         skillConf = 1;
         if(t_rel > 0)
         {
            return false;
         }
         if(owner.player && (World.w.pers.spellsPoss == 0 || alicorn && !World.w.alicorn))
         {
            World.w.gui.infoText("noSpells");
            World.w.gui.bulb(X,Y);
            Snd.ps("nomagic");
            return false;
         }
         if(owner.player && respect == 1)
         {
            World.w.gui.infoText("disSpell",null,null,false);
            Snd.ps("nomagic");
            return false;
         }
         if(owner.player)
         {
            if(!checkAvail())
            {
               return false;
            }
         }
         is_attack = true;
         if(t_prep < prep + 10)
         {
            t_prep += 2;
         }
         if(t_prep >= prep && t_attack <= 0)
         {
            if(owner.player && dmana > World.w.pers.manaHP)
            {
               t_rel = t_prep * 3;
               World.w.gui.infoText("noMana");
               World.w.gui.bulb(X,Y);
               Snd.ps("nomagic");
            }
            else if(dmagic <= owner.mana || owner.mana >= owner.maxmana * 0.99)
            {
               if(dkol <= 0)
               {
                  t_attack = rapid;
               }
               else
               {
                  t_attack = rapid * (dkol + 1);
               }
            }
            else
            {
               t_rel = t_prep * 3;
               if(owner.player)
               {
                  World.w.gui.infoText("noMana");
                  World.w.gui.bulb(X,Y);
                  Snd.ps("nomagic");
               }
            }
         }
         return true;
      }
      
      override public function setPers(param1:UnitPlayer, param2:Pers) : *
      {
         super.setPers(param1,param2);
         dmana = mana * param2.allDManaMult * param2.warlockDManaMult;
         dmagic = magic * param2.allDManaMult * param2.warlockDManaMult * param2.piFactor("mpCost");
         damMult *= param2.spellsDamMult;
      }
      
      override public function resultDamage(param1:Number, param2:Number = 1) : Number
      {
         return (param1 + damAdd) * damMult * param2;
      }
      
      override public function resultPrec(param1:Number = 1, param2:Number = 1) : Number
      {
         return precision * precMult * param1;
      }
      
      override protected function shoot() : Bullet
      {
         if(super.shoot())
         {
            owner.mana -= dmagic;
            owner.dmana = 0;
            if(owner.player)
            {
               World.w.pers.piEvent("castBegin");
               try
               {
                  World.w.pers.manaDamage(dmana);
               }
               finally
               {
                  World.w.pers.piEvent("castEnd");
               }
            }
         }
         return b;
      }
      
      override public function animate() : *
      {
         if(!vis)
         {
            return;
         }
         vis.x = X;
         vis.y = Y;
         if(prep)
         {
            if(t_prep > 1)
            {
               vis.gotoAndStop(t_prep);
            }
            else
            {
               vis.gotoAndStop(1);
            }
         }
      }
   }
}

