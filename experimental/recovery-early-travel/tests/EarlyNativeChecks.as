package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import fe.loc.Game;
   /** Executes exact before/after World.step + exitStep bodies. Native services
    * are counters; this is not a game or all-mod freeze test. */
   public class EarlyNativeChecks extends Sprite {
      private var rows:Array=[],held:Boolean=false,cancels:int=0;
      public function EarlyNativeChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function setup(w:Object):Object {
         var c:Object={logic:0,camera:0,gui:0,pip:0,sats:0,sats2:0,events:0,control:0,menus:0,entry:0,hud:0,mass:0};
         w.c=c;w.verror={visible:false};w.ctr={step:function():void{},keyPip:false,keyInvent:false,keyStatus:false,
            keySkills:false,keyMed:false,keyMap:false,keyQuest:false,keySats:false};
         w.ng_wait=0;w.onConsol=false;w.swfStage={focus:null};w.onPause=false;w.allStat=1;
         w.t_exit=20;w.t_die=0;w.t_battle=4;w.t_save=0;w.testMode=true;w.alicorn=false;
         w.clickReq=0;w.calcMass=true;w.calcMassW=true;w.comLoad=-1;w.autoSaveN=0;w.catPause=false;
         w.vblack={alpha:1};w.vgui={visible:true};w.vfon={visible:true};w.visual={visible:true};
         w.gg={ggControl:false,pipOff:0,controlOn:function():void{c.control++;w.gg.ggControl=true;}};
         w.cam={dblack:0,calc:function(p:Object):void{c.camera++;}};
         w.gui={guiPause:false,step:function():void{c.gui++;},allOn:function():void{c.hud++;}};
         w.pip={active:false,noAct:true,step:function():void{c.pip++;},onoff:function(...args):void{c.menus++;}};
         w.sats={active:false,step:function():void{c.sats++;},step2:function():void{c.sats2++;},onoff:function():void{c.menus++;}};
         w.stand={active:false};w.consol=null;
         w.land={step:function():void{c.logic++;}};
         w.pers={piEvent:function(...args):void{c.events++;}};
         w.invent={calcMass:function():void{c.mass++;},calcWeaponMass:function():void{c.mass++;}};
         w.game={enterToCurLand:function():void{c.entry++;}};
         return w;
      }
      private function summary(w:Object):String {
         return JSON.stringify({c:w.c,t_exit:w.t_exit,t_battle:w.t_battle,t_save:w.t_save,
            calcMass:w.calcMass,calcMassW:w.calcMassW,alpha:w.vblack.alpha,dblack:w.cam.dblack,
            control:w.gg.ggControl,noAct:w.pip.noAct,errors:w.errors});
      }
      private function run():void {
         Game.rconnectTravelBridge=null;
         var a:Object=setup(new NativeWorldBefore()),b:Object=setup(new NativeWorldAfter());
         for(var i:int=0;i<21;i++){a.step();b.step();}
         check(summary(a)==summary(b),"offline native countdown/simulation/control effects match exact ACC methods");
         check(b.errors.length==0 && b.c.entry==1 && b.c.control==1,"offline load retains native entry and one controlOn");
         a=setup(new NativeWorldBefore());b=setup(new NativeWorldAfter());a.onPause=b.onPause=true;
         a.step();b.step();check(summary(a)==summary(b),"ordinary pause behavior matches ACC with no owned ticket");
         a=setup(new NativeWorldBefore());b=setup(new NativeWorldAfter());
         a.game.enterToCurLand=function():void{a.c.entry++;a.onPause=true;};
         b.game.enterToCurLand=function():void{b.c.entry++;b.onPause=true;};
         a.step();b.step();
         check(summary(a)==summary(b) && b.c.logic==1 && b.onPause,
            "no-ticket exit callback setting onPause preserves original already-selected simulation frame");
         b=setup(new NativeWorldAfter());held=false;cancels=0;
         Game.rconnectTravelBridge=function(phase:String,g:Object,info:Object):Object {
            if(phase=="cancel-load"){held=false;cancels++;return null;}
            return held?{waiting:true}:null;
         };
         b.game.enterToCurLand=function():void{b.c.entry++;held=true;b.onPause=true;};
         b.step();
         check(b.t_exit==19 && b.c.entry==1 && b.c.logic==0 && b.c.events==0,"constructed during exitStep blocks same-frame Land and scripts");
         check(b.c.sats2==0 && b.c.mass==0 && b.t_save==0 && b.t_battle==4,"held world skips other simulation side effects too");
         check(b.c.camera==1 && b.c.gui==1 && b.c.pip==1 && b.c.sats==1,"native camera and display updates still advance");
         b.ctr.keyPip=b.ctr.keySats=b.ctr.keyMap=true;b.step();
         check(b.t_exit==18 && b.c.menus==0 && !b.ctr.keyPip && !b.ctr.keySats && !b.ctr.keyMap,"owned hold advances exit but discards menu hotkeys");
         b.t_exit=17;b.clickReq=1;b.step();
         check(b.t_exit==17 && b.clickReq==1,"required native loading click is not bypassed or swallowed");
         b.clickReq=0;b.step();
         check(b.t_exit==16 && b.c.control==0 && b.pip.noAct,"exit16 defers native controlOn while retaining visual transition");
         check(b.cam.dblack==-10 && b.visual.visible && b.vblack.alpha==1,"exit16 still performs native fade and visibility work");
         while(b.t_exit>0)b.step();
         check(b.c.logic==0 && b.c.control==0 && b.c.hud==1,"all remaining native countdown work runs without simulation or control");
         check(b.errors.length==0,"extracted native held methods raise no fixture errors");
         // Explicit counterexample: a separate mod callback is outside World.
         b.land.step();check(b.c.logic==1,"counterexample: World hold does not intercept an external direct Land.step");
         b.comLoad=1;b.step();check(cancels==1 && !held,"loadGame path revokes native hold before replacing native state");
         held=true;b.comLoad=-1;b.ng_wait=1;b.step();
         check(cancels==2 && b.newCalls==1,"newGame path revokes native hold before native replacement");
         Game.rconnectTravelBridge=null;
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false,external_mod_freeze_proven:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
