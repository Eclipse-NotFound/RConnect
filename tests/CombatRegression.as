package
{
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Timer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   public class CombatRegression
   {
      private static function check(ok:Boolean,name:String):void
      { Log.d("COOP "+(ok ? "PASS " : "FAIL ")+"combat "+name); }
      private static function frameHash(u:Object):uint
      {
         var bounds:Rectangle=u.vis.getBounds(u.vis);
         var bitmap:BitmapData=new BitmapData(int(bounds.width)+2,int(bounds.height)+2,true,0);
         bitmap.draw(u.vis,new Matrix(1,0,0,1,-bounds.x,-bounds.y));
         var hash:uint=2166136261;
         for each(var pixel:uint in bitmap.getVector(bitmap.rect)) hash=(hash^pixel)*16777619;
         bitmap.dispose(); return hash;
      }
      public static function shoot(mod:RConnectMod,x:Number,y:Number,damage:Number=40):void
      {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var bullet:Object=new cls(mod.game.gg,x,y,null,false);
         bullet.damage=damage; bullet.precision=0; bullet.partEmit=false;
         bullet.run();
         Log.d("COMBAT projectile off="+bullet.off+" hit="+bullet.babah+" at="+bullet.X+","+bullet.Y);
         for each(var struck:Object in bullet.parr) Log.d("COMBAT struck="+struck.id+" hp="+struck.hp);
      }
      public static function run(mod:RConnectMod):void
      {
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
         b.world=mod.game.world; b.loc=mod.game.loc; b.gg=mod.game.gg; b.freezeAI=true;
         var list:Array=b.readUnitsSnapshot();
         var e:Object={k:"combat-a",id:"slaver2",cls:"fe.unit::UnitSlaver",tr:2,
            x:b.gg.X+45,y:b.gg.Y,hp:500,maxhp:500,sost:1,fraction:1,anim:"run",dx:5,dy:0,stay:true};
         var vulnerable:Array=[]; for(var v:int=0;v<20;v++) vulnerable.push(1);
         e.defense={maxhp:500,skin:10,armor:20,marmor:20,armor_hp:500,armor_qual:1,
            shithp:0,allVulnerMult:1,vulner:vulnerable,opt:{},invulner:false};
         list.push(e); b.reconcileWorld(list); b.applyUnitsSync(list);
         var enemy:Object;
         for each(var u:Object in b.loc.units) if(u.id=="slaver2") enemy=u;
         var proxy:Object;
         for each(u in b.loc.units) if(u.id=="rconnect_hit_slaver2") proxy=u;
         check(proxy!=null && !proxy.disabled && !proxy.in_chain,"collision receiver active without local AI");
         if(proxy!=null) Log.d("COMBAT proxy hp="+proxy.hp+" fraction="+proxy.fraction+" loc="+(proxy.loc===b.loc)
            +" player="+(proxy.loc.gg===b.gg)+" bounds="+[proxy.X1,proxy.X2,proxy.Y1,proxy.Y2]+" invulner="+proxy.invulner);
         var before:Number=enemy.hp;
         check(Math.abs(enemy.X-Number(e.x))<0.01,"valid position keeps sub-tile precision");
         var oldTestDam:Boolean=b.world.testDam; b.world.testDam=true;
         shoot(mod,enemy.X,enemy.Y-enemy.scY*0.5,60);
         b.world.testDam=oldTestDam;
         check(enemy.hp<before,"native projectile hits mirrored enemy");
         check(Math.abs(enemy.hp-(before-30))<0.01,"native armor reduces projectile exactly once");
         // Isolate the overwrite race even while the old collision path fails.
         b.scanAndReportDamage(); enemy.hp-=7;
         b.applyUnitsSync(list);
         var hits:Array=b.scanAndReportDamage();
         check(hits.length>0 && Number(hits[0].dmg)>=7,"hit survives a newer host snapshot before report");
         check(b.scanAndReportDamage().length==0,"damage report is drained once");
         var firstX:Number=enemy.X;
         e.x+=90; b.applyUnitsSync(list);
         check(enemy.X==firstX && enemy.X<Number(e.x)-1,"new position snapshot does not jump to endpoint");
         var states:Object={}, frames:Object={}, samples:int=0;
         var onFrame:Function=function(ev:Event):void
         {
            samples++; states[String(enemy.X)+"/"+String(enemy.animState)]=true;
            frames[String(frameHash(enemy))]=true;
         };
         mod.stage.addEventListener(Event.ENTER_FRAME,onFrame,false,-20000);
         var timer:Timer=new Timer(250,1);
         timer.addEventListener(TimerEvent.TIMER,function(ev:TimerEvent):void
         {
            mod.stage.removeEventListener(Event.ENTER_FRAME,onFrame);
            var n:int=0; for(var k:String in states) n++;
            check(samples>=2 && n>=2,"positions advance between network snapshots");
            check(enemy.dx==5 && enemy.stay==true,"native animation receives host movement state");
            var nf:int=0; for(k in frames) nf++;
            check(nf>=2,"native animation renders changing sprite pixels");
            check(Math.abs(enemy.X-Number(e.x))<0.1,"movement reaches exact snapshot endpoint");
            b.endSession();
            var remains:int=0; for each(var obj:Object in b.loc.units) if(obj.id.indexOf("rconnect_hit_")==0) remains++;
            check(remains==0,"leave removes collision receivers");
            Log.d("COOP COMBAT DONE");
         });
         timer.start();
      }
   }
}
