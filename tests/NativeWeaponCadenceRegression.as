package {
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import fe.unit.Unit;
   import rconnect.game.UnitPresentation;
   import rconnect.core.Log;

   /** Compare presentation against the real Weapon.step/shoot cooldown. These
    * detached native owners never enter the room's simulation or sync lists.
    * Each real reference bullet is removed before the world can advance it. */
   public class NativeWeaponCadenceRegression {
      private var mod:RConnectMod,check:Function,complete:Function;
      private var timer:Timer=new Timer(50),owners:Array=[],guns:Array=[];
      private var display:UnitPresentation=new UnitPresentation(),round:int=0;
      public function NativeWeaponCadenceRegression(m:RConnectMod,c:Function,done:Function) {
         mod=m;check=c;complete=done;
         try {
            var factory:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
            for(var i:int=0;i<2;i++) {
               var owner:Object=new factory("1",10,<unit weap="lmg"/>,null);
               owner.putLoc(mod.game.loc,mod.game.gg.X+40,mod.game.gg.Y);
               owner.doop=true;owner.disabled=true;owner.xp=0;
               if(owner.currentWeapon!=null)owner.currentWeapon.remVisual();
               owners.push(owner);
               var gun:Object=new NativeTestGun(owner as Unit);guns.push(gun);
               owner.currentWeapon=gun;owner.childObjs=[gun];
               gun.loc=mod.game.loc;gun.X=owner.X;gun.Y=owner.Y-20;gun.rot=0;
               // Constructor attack flags stay at their native false defaults;
               // these protected fields cannot be set through dynamic access.
               gun.addVisual();
            }
            check(guns[0].vis!=null && guns[0].vis.totalFrames>1
               && guns[0].vis.totalFrames==guns[1].vis.totalFrames,
               "native cadence oracle uses matching animated LMG clips");
            apply(0);display.tick(owners[1],false);
            timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         }catch(error:Error){check(false,"native cadence setup "+error.getStackTrace());finish();}
      }
      private function apply(shots:int):void {
         display.apply(owners[1],{sost:1,anim:String(owners[1].animState),weapons:[{
            slot:0,id:"lmg",variant:0,main:true,shots:shots,ox:0,oy:-20,rot:0,
            prep:0,reload:0,cadence:16}]},mod.main,null,false,true);
      }
      private function tick(e:TimerEvent):void {
         try {
            var nativeGun:Object=guns[0],mirror:Object=guns[1];
            nativeGun.step();
            var before:int=nativeGun.t_shoot;
            var bullet:Object=NativeTestGun(nativeGun).emitLive();
            if(bullet!=null && bullet.in_chain)mod.game.loc.remObj(bullet);
            apply(++round);display.tick(owners[1],false);
            Log.d("NATIVE WEAPON CADENCE "+JSON.stringify({round:round,before:before,
               nativeFlash:nativeGun.t_shoot,mirrorFlash:mirror.t_shoot,
               nativeFrame:nativeGun.vis.currentFrame,mirrorFrame:mirror.vis.currentFrame,
               nativeShots:nativeGun.kol_shoot}));
            check(mirror.t_shoot==nativeGun.t_shoot,
               "continuous fire preserves native muzzle cooldown round="+round);
            check(mirror.vis.currentFrame==nativeGun.vis.currentFrame,
               "continuous fire preserves actual native clip frame round="+round);
            if(round>=8)finish();
         }catch(error:Error){check(false,"native cadence tick "+error.getStackTrace());finish();}
      }
      private function finish():void {
         timer.stop();timer.removeEventListener(TimerEvent.TIMER,tick);
         try {display.reset();}catch(error:*){}
         for each(var gun:Object in guns)try {gun.remVisual();}catch(ignore:*){}
         for each(var owner:Object in owners)try {owner.remVisual();}catch(ignored:*){}
         var done:Function=complete;complete=null;if(done!=null)done();
      }
   }
}
