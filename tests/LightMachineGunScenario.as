package
{
   import fe.unit.Unit;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Real LMG projectiles, native alicorn defenses and live Session/TCP reports. */
   public class LightMachineGunScenario
   {
      private var host:Boolean;
      private var prepared:Boolean=false;
      private var firing:Boolean=false;
      private var finished:Boolean=false;
      private var enemy:Object;
      private var shieldNumber:Boolean=false;
      private var armorChecked:Boolean=false;
      private var lastHp:Number=NaN;
      private var changedAt:int=0;
      private var burstDone:Boolean=false;
      private var expectedHp:Number=NaN;
      public function LightMachineGunScenario(isHost:Boolean) {host=isHost;}
      private function check(ok:Boolean,label:String):void
      {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"lmg-network "+label);}
      public function tick(mod:RConnectMod,n:int):void
      {
         if(!prepared && n>=30)
         {
            prepared=true;
            mod.main.loaderInfo.applicationDomain.getDefinition("fe.inter.Appear").ggArmorId=host?"power":"assault";
            mod.game.world.showHit=2;
            if(host)
            {
               var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitAlicorn") as Class;
               enemy=new cls("3",100,<unit tr="3"/>,null);
               enemy.putLoc(mod.game.loc,820,640);
               mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
               enemy.hp=enemy.maxhp=2000;enemy.shithp=500;
               enemy.disabled=true;
               Log.d("LMG host native defenses skin="+enemy.skin+" armor="+enemy.armor+" shieldArmor="+enemy.shitArmor);
            }
         }
         if(host && enemy!=null && AppearanceDamageRegression.numbers(mod.game.loc,enemy.X,true)>0) shieldNumber=true;
         if(!host && !firing && n>=35)
         {
            for each(var u:Object in mod.game.loc.units) if(u.id=="alicorn3") enemy=u;
            if(enemy!=null)
            {
               firing=true;
               check(enemy.shithp==500,"native full alicorn shield received");
               var gun:NativeTestGun=new NativeTestGun(mod.game.gg as Unit);
               var timer:Timer=new Timer(100,65);
               var hp:Number=enemy.hp;
               expectedHp=hp;
               var wasTest:Boolean=mod.game.world.testDam;
               mod.game.world.testDam=true;
               timer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void {
                  try
                  {
                     var before:Number=enemy.hp;
                     gun.fireAt(enemy);
                     expectedHp-=Math.max(0,before-Number(enemy.hp));
                     if(AppearanceDamageRegression.numbers(mod.game.loc,enemy.X,true)>0) shieldNumber=true;
                     if(timer.currentCount==65)
                     {
                        check(enemy.shithp<=0 && enemy.hp<hp,"continuous native LMG burst breaks shield then hurts HP");
                        check(shieldNumber,"joiner sees shield hit numbers");
                        mod.game.world.testDam=wasTest;
                        burstDone=true;
                        Log.d("LMG join burst hp="+enemy.hp+" shield="+enemy.shithp);
                     }
                  }
                  catch(err:Error) {timer.stop();mod.game.world.testDam=wasTest;check(false,"burst error "+err);}
               });timer.start();
            }
         }
         if(!armorChecked && n>=45)
         {
            var ghost:Object=mod.game.getRemoteGhost(host?1:0);
            var clips:Array=[];
            if(ghost!=null) AppearanceDamageRegression.armorClips(ghost.vis,clips);
            var good:Boolean=clips.length>0;
            for each(var clip:Object in clips) if(clip.currentLabel!=(host?"assault":"power")) good=false;
            if(good || n>=180)
            {
               armorChecked=true;
               check(good,(host?"host":"joiner")+" renders peer armor different from local armor");
            }
         }
         if(enemy!=null && Number(enemy.hp)!=lastHp) {lastHp=Number(enemy.hp);changedAt=getTimer();}
         if(!finished && ((enemy!=null && enemy.shithp<=0 && enemy.hp<2000 && (host || burstDone)
            && getTimer()-changedAt>=6000) || n>=220))
         {
            finished=true;
            check(enemy!=null && enemy.shithp<=0 && enemy.hp<2000,(host?"host":"joiner")+" converges shield depletion and HP damage");
            if(host) check(shieldNumber,"host sees remote shield hit numbers");
            else check(Math.abs(enemy.hp-expectedHp)<0.01,"host snapshot equals sum of actual local hit losses");
            Log.d("LMG final "+(host?"host":"join")+" hp="+(enemy?enemy.hp:"missing")+" shield="+(enemy?enemy.shithp:"missing"));
            Log.d("COOP LMG NETWORK DONE "+(host?"host":"join"));
         }
      }
   }
}
