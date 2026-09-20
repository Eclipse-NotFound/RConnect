package {
   import fe.unit.Unit;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import rconnect.game.GameBridge;
   import rconnect.core.Log;
   public class AppearanceDamageRegression {
      private static function check(ok:Boolean,label:String):void { Log.d("COOP "+(ok?"PASS ":"FAIL ")+"appearance-damage "+label); }
      public static function armorClips(node:Object,out:Array):void {
         if(node is MovieClip) {
            var found:int=0;
            for each(var lab:Object in node.currentLabels) if(lab.name=="pip" || lab.name=="power" || lab.name=="assault") found++;
            if(found>=2) out.push(node);
         }
         if(node is DisplayObjectContainer) for(var i:int=0;i<node.numChildren;i++) armorClips(node.getChildAt(i),out);
      }
      public static function numbers(room:Object, x:Number=NaN, shieldOnly:Boolean=false):int {
         var n:int=0;
         for(var p:Object=room.firstObj;p!=null;p=p.nobj) {
            var vis:Object=GameBridge.probe(p,"vis");
            if(GameBridge.probe(vis,"numb")!=null && vis.parent!=null && vis.visible
               && (isNaN(x) || Math.abs(p.X-x)<90)
               && (!shieldOnly || String(vis.numb.text).indexOf("S -")==0)) n++;
         }
         return n;
      }
      public static function run(mod:RConnectMod):void {
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
         b.world=mod.game.world;b.gg=mod.game.gg;b.loc=mod.game.loc;b.freezeAI=true;
         var ad:Object=mod.main.loaderInfo.applicationDomain;
         var ac:Object=ad.getDefinition("fe.inter.Appear");
         var localArmor:String=String(ac.ggArmorId);
         var armorWork:String=String(b.world.armorWork);
         var snap:Object=b.readSnapshot();snap.ap.armor=localArmor=="power"?"assault":"power";
         delete snap.poseFrame;delete snap.bodyFrame;snap.pose="run";
         b.updateRemote(988,snap,"DifferentArmor");
         var ghost:Object=b.getRemoteGhost(988);
         var list:Array=b.readUnitsSnapshot();
         var e:Object={k:"m32-ali",id:"alicorn3",cls:"fe.unit::UnitAlicorn",tr:3,
            x:b.gg.X+180,y:b.gg.Y,hp:2000,sost:1,fraction:1,anim:"stay"};
         list.push(e);b.reconcileWorld(list);b.applyUnitsSync(list);
         var enemy:Object;
         for each(var u:Object in b.loc.units) if(u.id=="alicorn3") enemy=u;
         var gun:NativeTestGun=new NativeTestGun(b.gg as Unit);
         var wasTest:Boolean=b.world.testDam, wasShow:int=b.world.showHit;
         b.world.testDam=true;b.world.showHit=2;
         // Keep actual alicorn defenses and LMG stats. Check shield behavior separately from HP.
         enemy.shithp=24; enemy.shitArmor=50;
         var beforeShield:Number=enemy.shithp;
         var bullet:Object=gun.fireAt(enemy);
         check(enemy.shithp<beforeShield,"native light machine gun consumes alicorn shield");
         Log.d("M32 LMG damage="+bullet.damage+" hp="+enemy.hp+" shield="+enemy.shithp+" numbers="+numbers(b.loc));
         check(numbers(b.loc,enemy.X,true)>0,"shield-only hit has visible feedback");
         enemy.shithp=0;enemy.skin=0;enemy.armor=0;enemy.allVulnerMult=1;
         var hp:Number=enemy.hp;gun.fireAt(enemy);
         check(enemy.hp<hp,"native light machine gun hurts unshielded alicorn");
         var firstNumbers:int=numbers(b.loc);
         check(firstNumbers>0,"first burst has visible damage number");
         var timer:Timer=new Timer(100,35);var good:Boolean=true;var count:int=0;
         timer.addEventListener(TimerEvent.TIMER,function(ev:TimerEvent):void {
            var clips:Array=[];armorClips(ghost.vis,clips);count=Math.max(count,clips.length);
            for each(var clip:Object in clips) if(String(clip.currentLabel)!=String(snap.ap.armor)) good=false;
            if(timer.currentCount==2) {
               var labels:Array=[];for each(clip in clips) labels.push(clip.name+":"+clip.currentLabel);
               Log.d("M32 armor local="+localArmor+" wanted="+snap.ap.armor+" clips="+labels.join(","));
            }
            if(timer.currentCount==10) {b.world.armorWork="pip";snap.pose="jump";b.updateRemote(988,snap,"DifferentArmor");}
            if(timer.currentCount==35) {
               check(count>0 && good,"remote armor survives native animation frame changes");
               check(String(ac.ggArmorId)==localArmor,"remote styling preserves local armor");
               check(numbers(b.loc,enemy.X)==0,"first damage number really expired before second burst");
               hp=enemy.hp;gun.fireAt(enemy);
               check(enemy.hp<hp,"second burst still damages enemy");
               check(numbers(b.loc)>0,"second burst creates number after first number expires");
               b.world.testDam=wasTest;b.world.showHit=wasShow;b.world.armorWork=armorWork;b.endSession();
               Log.d("COOP APPEARANCE DAMAGE DONE");
            }
         });timer.start();
      }
   }
}
