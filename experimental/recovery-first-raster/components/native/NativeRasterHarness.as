package {
   import flash.events.Event;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import fe.World;
   import fe.loc.Location;
   public class NativeRasterHarness {
      public static var rconnectRasterBridge:Function=null;
      private var rconnectRasterTicket:Object;
      public var loc:Location,sceneLarge:Boolean=false,sceneSide:int=320,sceneChunkSide:int=320;
      public var sceneHistory:Dictionary=new Dictionary(),sceneMarks:Array,sceneRasterizing:Boolean=false;
      public var scenePreload:Boolean=true,sceneResident:int=0,sceneChunks:Object={};
      public var lightRect:Rectangle=new Rectangle(),lightBmp:Object={fillRect:function(r:Object,c:uint):void{}};
      public var order:Array=[],ensureCount:int=0,readyScans:int=0,lastLeft:Number=0,lastTop:Number=0;
      public function open(l:Location):void{sceneOpen(l);}
      private function sceneSyncRegionLighting(l:Location):void{order.push("lighting");}
      private function sceneClear():void{order.push("clear");sceneResident=0;sceneChunks={};}
      private function sceneConfigureBorders():void{order.push("borders");}
      private function scenePrepare(l:Location):void{order.push("prepare");}
      private function setLight():void{order.push("setLight");}
      private function sceneIndexBackdrops():void{order.push("backdrops");}
      private function drawAllObjs():void{order.push("objects");}
      private function sceneCullSurfaces():void{}
      private function sceneViewport():Rectangle {
         // Only the exact sceneViewReady body calls this substituted helper.
         // Count scan entry without instrumenting any extracted native method.
         readyScans++;
         var c:Object=World.w.cam;return new Rectangle(-c.vx,-c.vy,c.screenX,c.screenY);
      }
      private function scenePreloadAll():void{fill(0,0,loc.limX,loc.limY);}
      private function sceneEnsureUpcoming(x:Number,y:Number,w:Number,h:Number):void{fill(x,y,w,h);}
      private function fill(x:Number,y:Number,w:Number,h:Number):void {
         ensureCount++;lastLeft=x;lastTop=y;
         for(var cx:int=int(x/sceneSide);cx<int(Math.ceil((x+w)/sceneSide));cx++)
            for(var cy:int=int(y/sceneSide);cy<int(Math.ceil((y+h)/sceneSide));cy++)
               if(sceneChunks[cx+":"+cy]==null){sceneChunks[cx+":"+cy]={};sceneResident++;}
      }
      public function get rconnectRasterPending() : Boolean
      {
         return this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true;
      }

      private function rconnectRasterWaiting() : Boolean
      {
         return this.rconnectRasterTicket != null && this.rconnectRasterTicket.waiting === true;
      }

      private function rconnectRasterPainted() : void
      {
         if(this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true
            && !this.rconnectRasterWaiting() && this.sceneResident > 0 && this.sceneViewReady())
         {
            this.rconnectRasterTicket.unpainted = false;
         }
      }

      private function sceneOpen(value:Location) : void
      {
         var ticket:Object = null;
         if(rconnectRasterBridge != null)
         {
            try {
               ticket = rconnectRasterBridge(World.w,value,this);
               if(ticket == null || !(ticket.waiting is Boolean) || !(ticket.unpainted is Boolean))ticket = null;
            }
            catch(error:*) { ticket = null;trace("RConnect first raster fallback: " + error); }
         }
         this.rconnectRasterTicket = ticket;
         this.sceneSyncRegionLighting(value);
         this.sceneClear();
         this.sceneSide = this.sceneChunkSide == 640 ? 640 : 320;
         this.loc = value;
         value.grafon = this;
         this.sceneLarge = true;
         World.w.main.dispatchEvent(new Event("continuousSceneBeforeRaster"));
         this.sceneConfigureBorders();
         if(this.sceneHistory[value] == null)
         {
            this.sceneHistory[value] = [];
         }
         this.sceneMarks = this.sceneHistory[value];
         this.sceneRasterizing = true;
         this.scenePrepare(value);
         this.sceneRasterizing = false;
         this.lightBmp.fillRect(this.lightRect,4278190080);
         this.setLight();
         this.sceneIndexBackdrops();
         var px:Number = value.spawnPoints.length ? (value.spawnPoints[0].x + 1) * 40 : value.gg.X;
         var py:Number = value.spawnPoints.length ? (value.spawnPoints[0].y + 1) * 40 : value.gg.Y;
         var left:Number = Math.max(0,Math.min(value.limX - World.w.swfStage.stageWidth,px - World.w.swfStage.stageWidth / 2));
         var top:Number = Math.max(0,Math.min(value.limY - World.w.swfStage.stageHeight,py - World.w.swfStage.stageHeight / 2 + 100));
         if(this.scenePreload)
         {
            this.sceneEnsure(left,top,World.w.swfStage.stageWidth,World.w.swfStage.stageHeight,true);
         }
         this.drawAllObjs();
         this.rconnectRasterPainted();
      }

      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void
      {
         if(this.rconnectRasterWaiting())return;
         if(this.scenePreload && this.sceneResident == Math.ceil(this.loc.limX / this.sceneSide) * Math.ceil(this.loc.limY / this.sceneSide))
         {
            return;
         }
         if(this.scenePreload)
         {
            this.scenePreloadAll();
            return;
         }
         this.sceneEnsureUpcoming(left,top,width,height);
      }

      public function sceneTick() : void
      {
         if(this.rconnectRasterWaiting())return;
         if(!this.sceneLarge || this.loc == null)
         {
            return;
         }
         var camera:* = World.w.cam;
         var scale:Number = Number(camera.scaleV > 0 ? camera.scaleV : 1);
         this.sceneEnsure((-camera.vx - camera.quakeX) / scale,(-camera.vy - camera.quakeY) / scale,camera.screenX / scale,camera.screenY / scale);
         this.sceneCullSurfaces();
         this.rconnectRasterPainted();
      }

      public function sceneViewReady() : Boolean
      {
         if(this.rconnectRasterWaiting())return false;
         if(!this.sceneLarge)
         {
            return true;
         }
         var view:Rectangle = this.sceneViewport();
         if(view == null)
         {
            view = new Rectangle(0,0,this.loc.limX,this.loc.limY);
         }
         var minX:int = Math.max(0,Math.floor(view.left / this.sceneSide));
         var minY:int = Math.max(0,Math.floor(view.top / this.sceneSide));
         var maxX:int = Math.min(Math.ceil(this.loc.limX / this.sceneSide) - 1,Math.floor((view.right - 1) / this.sceneSide));
         var maxY:int = Math.min(Math.ceil(this.loc.limY / this.sceneSide) - 1,Math.floor((view.bottom - 1) / this.sceneSide));
         var x:int = minX;
         while(x <= maxX)
         {
            var y:int = minY;
            while(y <= maxY)
            {
               if(!this.sceneChunks[x + ":" + y])
               {
                  return false;
               }
               y++;
            }
            x++;
         }
         return true;
      }
   }
}
