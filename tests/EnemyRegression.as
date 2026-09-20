package
{
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.Shape;
   import flash.events.Event;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   /** M29: native units, screen rebuild, and ordinary unprovoked target selection. */
   public class EnemyRegression
   {
      private static function check(ok:Boolean,name:String):void
      { Log.d("COOP "+(ok ? "PASS " : "FAIL ")+"enemy "+name); }
      public static function pixels(v:DisplayObject):int
      {
         var b:Rectangle=v.getBounds(v);
         if(b.width<1 || b.height<1 || b.width>1000 || b.height>1000) return 0;
         var data:BitmapData=new BitmapData(int(b.width)+2,int(b.height)+2,true,0);
         data.draw(v,new Matrix(1,0,0,1,-b.x,-b.y));
         var rect:Rectangle=data.getColorBoundsRect(0xff000000,0,false);
         var area:int=int(rect.width*rect.height); data.dispose(); return area;
      }
      public static function run(mod:RConnectMod):void
      {
         var real:GameBridge=mod.game;
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main["loaderInfo"]});
         b.world=real.world; b.loc=real.loc; b.gg=real.gg; b.freezeAI=true;
         var snap:Array=b.readUnitsSnapshot();
         var x:Number=Number(real.gg.X)+40, y:Number=Number(real.gg.Y);
         snap.push({k:"test-a",id:"slaver1",cls:"fe.unit::UnitSlaver",tr:1,x:x,y:y,hp:200,sost:1,fraction:1,anim:"stay"});
         snap.push({k:"test-b",id:"slaver1",cls:"fe.unit::UnitSlaver",tr:1,x:x+100,y:y,hp:100,sost:1,fraction:1,anim:"stay"});
         // A naturally placed mine can have tr=0 and identify itself by id.
         snap.push({id:"mine",cls:"fe.unit::Mine",tr:0,x:x+80,y:y,hp:20,sost:1,fraction:1,anim:"stay"});
         b.reconcileWorld(snap); b.applyUnitsSync(snap);
         var enemy:Object=null, mine:Object=null, copies:int=0;
         for each(var u:Object in real.loc.units)
         { if(u.id=="slaver1") { if(enemy==null) enemy=u; copies++; } if(u.id=="mine") mine=u; }
         check(copies==2,"two equal-id enemies remain separate");
         check(mine!=null,"zero variant mine injected");
         check(enemy!=null,"native slaver injected");
         if(enemy!=null)
         {
            enemy.hp-=7;
            var hits:Array=b.scanAndReportDamage();
            check(hits.length==1 && hits[0].k=="test-a" && hits[0].dmg==7,"duplicate enemy damage has unique recipient");
            b.applyUnitsSync(snap);
            var first:Object=enemy, second:Object;
            for each(u in real.loc.units) if(u.id=="slaver1" && u!==first) second=u;
            snap[snap.length-3].x=x+100; snap[snap.length-2].x=x;
            // Identity is independent of motion smoothing, verified separately in CombatRegression.
            b.freezeAI=false;
            b.reconcileWorld(snap); b.applyUnitsSync(snap);
            b.freezeAI=true;
            check(first.X>second.X && first.hp==200 && second.hp==100,"equal-id enemies keep identity when crossing");
            second.unres=false;
            check(b.applyDamage("slaver1",40,null,"test-b") && second.hp<100 && first.hp==200,"host damage reaches keyed duplicate only");
            b.applyUnitsSync(snap);
            b.tickFrozenAnims();
            mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
            Log.d("ENEMY sample initial alpha="+enemy.vis.alpha+" visible="+enemy.vis.visible+" parent="+(enemy.vis.parent!=null)+" pixels="+pixels(enemy.vis));
            check(enemy.vis.parent!=null && enemy.vis.visible && enemy.vis.alpha>0 && pixels(enemy.vis)>0,"native slaver has visible pixels");
            real.world.grafon.drawAllObjs();
            b.tickFrozenAnims();
            mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
            check(enemy.vis.parent!=null && enemy.vis.visible && pixels(enemy.vis)>0,"slaver survives native scene redraw");
            var mask:Shape=new Shape();
            mask.graphics.beginFill(0xffffff); mask.graphics.drawRect(0,0,1,1); mask.graphics.endFill();
            enemy.vis.parent.addChild(mask); enemy.vis.cacheAsBitmap=true; mask.cacheAsBitmap=true;
            enemy.vis.mask=mask;
            mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
            check(enemy.vis.mask==null && !mask.visible && pixels(enemy.vis)>0,"mask removal restores pixels without white overlay");

            // Restore native target eligibility. The ghost is close, host is far.
            enemy.disabled=false;
            var hostX:Number=real.gg.X, hostY:Number=real.gg.Y;
            real.gg.setPos(x+1100,y);
            var player:Object=real.readSnapshot(); player.x=enemy.X+20; player.y=y; player.hp=200;
            b.updateRemote(991,player,"TargetTest");
            var ghost:Object=b.getRemoteGhost(991);
            enemy.storona=1; enemy.eyeX=enemy.X; enemy.eyeY=enemy.Y-30;
            enemy.priorUnit=null; enemy.celUnit=real.gg;
            Log.d("ENEMY perception meet="+enemy.isMeet(ghost)+" look="+enemy.look(ghost,true)+" host="+enemy.look(real.gg,true));
            check(enemy.isMeet(ghost) && enemy.look(ghost,false)>0.5,"near joiner visible to native perception");
            b.redirectNearbyAggro();
            check(enemy.priorUnit===ghost && enemy.celUnit===ghost,"near joiner discovered despite existing far host target");
            enemy.oduplenie=0;
            check(enemy.findCel(true) && enemy.celUnit===ghost,"native AI retains discovered joiner");
            real.gg.setPos(enemy.X+10,y); ghost.setPos(enemy.X+100,y);
            enemy.priorUnit=null; enemy.celUnit=real.gg;
            b.redirectNearbyAggro();
            check(enemy.celUnit===real.gg,"closer host target retained");
            real.gg.setPos(x+1100,y);
            ghost.setPos(enemy.X+20,y); ghost.visibility=0; ghost.demask=0;
            enemy.priorUnit=null; enemy.celUnit=null;
            b.redirectNearbyAggro();
            check(enemy.priorUnit==null,"invisible joiner is not forced as target");
            if(ghost!=null) { ghost.setPos(x+700,y); enemy.priorUnit=null; enemy.celUnit=null; }
            b.redirectNearbyAggro();
            check(enemy.priorUnit==null,"out of range joiner not forced as target");
            real.gg.setPos(hostX,hostY);
         }
         b.endSession();
         if(mask!=null) check(enemy.vis.mask===mask && mask.visible,"leave restores borrowed visibility mask");
         if(mask!=null && mask.parent!=null) mask.parent.removeChild(mask);
         Log.d("COOP ENEMY DONE");
      }
   }
}
