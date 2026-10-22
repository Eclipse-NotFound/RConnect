package {
   import flash.ui.Mouse;
   import fe.loc.Game;
   public dynamic class NativeWorldBefore {
      public static var fps:Number=30;
      public var errors:Array=[],saves:int=0,loads:int=0,newCalls:int=0,dieCalls:int=0;
      public function showError(e:*):void{errors.push(String(e));}
      public function cur(s:String):void{}
      public function getLoadScreen():Object{return null;}
      public function setLoadScreen(s:Object=null):void{}
      public function offLoadScreen():void{}
      public function waitLoadClick():void{this.clickReq=1;}
      public function newGame1():void{newCalls++;}
      public function newGame2():void{newCalls++;}
      public function saveGame():void{saves++;}
      public function loadGame(n:int):void{loads++;}
      public function ggDieStep():void{dieCalls++;}
      public function exitStep() : *
      {
         try
         {
            --this.t_exit;
            if(this.t_exit == 99)
            {
               this.cam.dblack = 1.5;
            }
            if(this.t_exit == 20)
            {
               this.vblack.alpha = 0;
               this.cam.dblack = 0;
               this.setLoadScreen(this.getLoadScreen());
               Snd.off = true;
            }
            if(this.t_exit == 19)
            {
               this.cur("arrow");
               this.game.enterToCurLand();
            }
            if(this.t_exit == 18 && this.clickReq > 0)
            {
               this.waitLoadClick();
            }
            if(this.t_exit == 16)
            {
               Mouse.show();
               Snd.off = false;
               this.offLoadScreen();
               this.vgui.visible = this.vfon.visible = this.visual.visible = true;
               this.vblack.alpha = 1;
               this.cam.dblack = -10;
               this.gg.controlOn();
               this.pip.noAct = false;
            }
            if(this.t_exit == 1)
            {
               this.gui.allOn();
            }
         }
         catch(err:*)
         {
            showError(err);
         }
      }

      public function step() : *
      {
         try
         {
            if(this.verror.visible)
            {
               return;
            }
            this.ctr.step();
            Snd.step();
            if(this.ng_wait > 0)
            {
               if(this.ng_wait == 1)
               {
                  this.newGame1();
               }
               else if(this.ng_wait == 2)
               {
                  if(this.clickReq != 1)
                  {
                     this.newGame2();
                  }
               }
               return;
            }
            if(!this.onConsol && !this.pip.active)
            {
               this.swfStage.focus = this.swfStage;
            }
            if(this.allStat == 1 && !this.onPause)
            {
               if(this.t_exit > 0)
               {
                  if(!(this.t_exit == 17 && this.clickReq == 1))
                  {
                     this.exitStep();
                  }
               }
               Emitter.kol2 = Emitter.kol1;
               Emitter.kol1 = 0;
               if(this.t_exit != 17)
               {
                  if(this.pers != null)
                  {
                     this.pers.piEvent("tick",1 / fps);
                  }
                  this.land.step();
                  if(this.pers != null)
                  {
                     this.pers.piEvent("flush");
                  }
               }
               if(this.t_die > 0)
               {
                  this.ggDieStep();
               }
               if(this.t_battle > 0)
               {
                  --this.t_battle;
               }
               this.sats.step2();
               if(this.calcMass)
               {
                  this.invent.calcMass();
                  this.calcMass = false;
               }
               if(this.calcMassW)
               {
                  this.invent.calcWeaponMass();
                  this.calcMassW = false;
               }
               ++this.t_save;
               if(this.t_save > 5000 && !this.testMode && !this.alicorn)
               {
                  this.saveGame();
               }
               this.checkLoot = false;
            }
            if(this.comLoad >= 0)
            {
               if(this.comLoad >= 100)
               {
                  if(this.autoSaveN > 0)
                  {
                     this.saveGame();
                  }
                  this.loadGame(this.comLoad - 100);
               }
               else
               {
                  this.pip.onoff(-1);
                  this.comLoad += 100;
                  this.setLoadScreen();
               }
            }
            if(this.allStat >= 1)
            {
               this.cam.calc(this.gg);
               this.gui.step();
               this.pip.step();
               this.sats.step();
               if(this.ctr.keyPip)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff();
                  }
                  this.ctr.keyPip = false;
               }
               if(this.ctr.keyInvent)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(2);
                  }
                  this.ctr.keyInvent = false;
               }
               if(this.ctr.keyStatus)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,1);
                  }
                  this.ctr.keyStatus = false;
               }
               if(this.ctr.keySkills)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,2);
                  }
                  this.ctr.keySkills = false;
               }
               if(this.ctr.keyMed)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,5);
                  }
                  this.ctr.keyMed = false;
               }
               if(this.ctr.keyMap)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(3,1);
                  }
                  this.ctr.keyMap = false;
               }
               if(this.ctr.keyQuest)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(3,2);
                  }
                  this.ctr.keyQuest = false;
               }
               if(this.ctr.keySats)
               {
                  if(this.gg.ggControl && !this.pip.active && this.gg && this.gg.pipOff <= 0 && !this.catPause)
                  {
                     this.sats.onoff();
                  }
                  this.ctr.keySats = false;
               }
               this.allStat = this.pip.active || this.sats.active || this.stand.active || this.gui.guiPause ? 2 : 1;
               if(Boolean(this.consol) && Boolean(this.consol.visoff))
               {
                  this.onConsol = this.consol.vis.visible = this.consol.visoff = false;
               }
            }
         }
         catch(err:*)
         {
            showError(err);
         }
      }
   }
}
