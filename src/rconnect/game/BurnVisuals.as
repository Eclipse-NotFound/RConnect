package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Cosmetic copies of the native burning status and fire left by a fire blast.
    * No Effect, Bullet or damage path is run on the receiving world. */
   public class BurnVisuals {
      private var last:Dictionary=new Dictionary(true);
      private var logged:Boolean=false;

      /** Unit.effects is public. A frozen enemy or teammate ghost does not step
       * these effects, so the owner must send the real status explicitly. */
      public static function capture(u:Object):Boolean {
         var effects:Array=GameBridge.probe(u,"effects") as Array;
         if(effects==null)return false;
         for each(var effect:Object in effects)
            if(GameBridge.probe(effect,"id")=="burning"
               && GameBridge.probe(effect,"vse")!==true
               && Number(GameBridge.probe(effect,"t"))>0)return true;
         return false;
      }

      /** Called once per rendered game frame for a mirrored body. The small
       * guard prevents a packet and the regular frame callback from emitting
       * twice in the same frame. Native Effect.stepEffect emits one per frame. */
      public function present(main:Object,u:Object,burning:Boolean,paused:Boolean=false):void {
         if(!burning || paused || main==null || u==null)return;
         var room:Object=GameBridge.probe(u,"loc");
         if(room==null || GameBridge.probe(room,"active")!==true || int(GameBridge.probe(u,"sost"))>=4)return;
         var x:Number=Number(GameBridge.probe(u,"X"));
         var y:Number=Number(GameBridge.probe(u,"Y"))-Number(GameBridge.probe(u,"scY"))/2;
         if(!isFinite(x)||!isFinite(y))return;
         var now:int=getTimer(),prior:*=last[u];
         if(prior!=null && now-int(prior)<25)return;
         last[u]=now;
         try {
            var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
            emitter.emit("flame",room,x,y);
         } catch(error:*) {
            if(!logged){logged=true;Log.d("RConnectGame: burning visual failed: "+error);}
         }
      }

      public function reset():void {last=new Dictionary(true);logged=false;}

      /** Reproduce Bullet.explLiquid("fire",-33)'s *visual* footprint after
       * the native blast changed the source tiles. This reads only the source
       * Location and sends coordinates, so a receiver with a delayed terrain
       * patch still gets the correct fire positions. Native fire Part has no
       * damage or terrain behavior (fe.graph.Part.step). */
      public static function captureGround(b:Object):Array {
         var out:Array=[];
         if(b==null || int(GameBridge.probe(b,"tipDamage"))!=3
            || Number(GameBridge.probe(b,"inWater"))>0)return out;
         var weapon:Object=GameBridge.probe(b,"weap");
         var custom:*=GameBridge.probe(weapon,"visexpl");
         if(custom!=null && String(custom)!="")return out;
         var room:Object=GameBridge.probe(b,"loc");
         var x:Number=Number(GameBridge.probe(b,"X")),y:Number=Number(GameBridge.probe(b,"Y"));
         var radius:Number=Number(GameBridge.probe(b,"explRadius"));
         if(room==null || !isFinite(x) || !isFinite(y) || !isFinite(radius)
            || radius<=0 || radius>800)return out;
         // 1.02 Tile.tileX/tileY are both 40. The integration supports the
         // same 1.02 native geometry as the installed game SWF.
         var x0:int=Math.max(0,Math.floor((x-radius)/40));
         var x1:int=Math.min(int(GameBridge.probe(room,"spaceX"))-1,Math.floor((x+radius)/40));
         var y0:int=Math.max(2,Math.floor((y-radius)/40));
         var y1:int=Math.min(int(GameBridge.probe(room,"spaceY"))-1,Math.floor((y+radius)/40));
         for(var tx:int=x0;tx<=x1;tx++)for(var ty:int=y0;ty<=y1;ty++) {
            var dx:Number=x-(tx+.5)*40,dy:Number=y-(ty+.5)*40;
            if(dx*dx+dy*dy>=radius*radius)continue;
            var tile:Object=room.getTile(tx,ty),above:Object=room.getTile(tx,ty-1);
            if(tile==null || above==null)continue;
            if(!(int(GameBridge.probe(tile,"phis"))>0 || GameBridge.probe(tile,"shelf")===true))continue;
            if(int(GameBridge.probe(tile,"zForm"))==0 && int(GameBridge.probe(above,"phis"))!=0)continue;
            var fireY:Number=Number(GameBridge.probe(tile,"phY1"))-33;
            if(!isFinite(fireY))continue;
            out.push({x:(tx+.5)*40,y:fireY});
            if(out.length>=256)return out;
         }
         return out;
      }

      /** A native Emitter creates Part objects with the game's own lifespan.
       * Never call Bullet.explosion/explLiquid on a remote world. */
      public static function playGround(main:Object,room:Object,points:Array):void {
         if(main==null || room==null || points==null || GameBridge.probe(room,"active")!==true)return;
         var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         var n:int=Math.min(points.length,256);
         var maxX:Number=Number(GameBridge.probe(room,"spaceX"))*40;
         var maxY:Number=Number(GameBridge.probe(room,"spaceY"))*40;
         for(var i:int=0;i<n;i++) {
            var point:Object=points[i];
            if(point==null)continue;
            var x:Number=Number(point.x),y:Number=Number(point.y);
            if(isFinite(x)&&isFinite(y)&&x>=0&&y>=0&&x<=maxX&&y<=maxY)
               emitter.emit("fire",room,x,y);
         }
      }
   }
}
