package fe.graph
{
   import fe.*;
   import fe.loc.*;
   import fl.motion.Color;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.BitmapDataChannel;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.events.DataEvent;
   import flash.events.Event;
   import flash.filters.BitmapFilter;
   import flash.filters.BlurFilter;
   import flash.filters.ColorMatrixFilter;
   import flash.filters.DropShadowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.ui.Mouse;
   import flash.ui.MouseCursorData;
   import flash.utils.*;
   
   public class Grafon
   {
      
      public static var rconnectRasterBridge:Function = null;
      
      public static var spriteLists:Array = new Array();
      
      public static var texUrl:Array = ["texture.swf","texture1.swf","sprite.swf","sprite1.swf"];
      
      public static const numbMat:* = 0;
      
      public static const numbFon:* = 0;
      
      public static const numbBack:* = 1;
      
      public static const numbObj:* = 1;
      
      public static const numbSprite:* = 2;
      
      public var loc:Location;
      
      public var visual:Sprite;
      
      public var visBack:Sprite;
      
      public var visBack2:Sprite;
      
      public var visObjs:Array;
      
      internal const kolObjs:* = 6;
      
      public var visVoda:Sprite;
      
      public var visFront:Sprite;
      
      public var visLight:Sprite;
      
      public var visSats:Sprite;
      
      public var visFon:MovieClip;
      
      internal var resX:int;
      
      internal var resY:int;
      
      internal var kusokX:int = 48;
      
      internal var kusokY:int = 25;
      
      public var frontBmp:BitmapData;
      
      internal var frontBitmap:Bitmap;
      
      internal var vodaBmp:BitmapData;
      
      internal var vodaBitmap:Bitmap;
      
      internal var backBmp:BitmapData;
      
      internal var backBitmap:Bitmap;
      
      internal var backBmp2:BitmapData;
      
      internal var backBitmap2:Bitmap;
      
      public var lightBmp:BitmapData;
      
      internal var lightBitmap:Bitmap;
      
      public var satsBmp:BitmapData;
      
      internal var satsBitmap:Bitmap;
      
      internal var shadBmp:BitmapData;
      
      internal var colorBmp:BitmapData;
      
      internal var dsFilter:DropShadowFilter;
      
      internal var infraTransform:ColorTransform;
      
      internal var defTransform:ColorTransform;
      
      public var pa:MovieClip;
      
      public var pb:MovieClip;
      
      public var brTrans:ColorTransform;
      
      public var brColor:Color;
      
      internal var brData:BitmapData;
      
      internal var brPoint:Point;
      
      internal var brRect:Rectangle;
      
      internal var pm:Matrix;
      
      internal var voda:*;
      
      internal var m:Matrix;
      
      public var ramT:MovieClip;
      
      public var ramB:MovieClip;
      
      public var ramL:MovieClip;
      
      public var ramR:MovieClip;
      
      internal var arrFront:Array;
      
      internal var arrBack:Array;
      
      internal var rectX:int = 1920;
      
      internal var rectY:int = 1000;
      
      internal var allRect:Rectangle;
      
      internal var lightX:int = 49;
      
      internal var lightY:int = 28;
      
      internal var lightRect:Rectangle;
      
      public var resIsLoad:Boolean = false;
      
      public var progressLoad:Number = 0;
      
      public var grLoaders:Array;
      
      internal var nn:int = 0;
      
      public var sceneX:int = 0;
      
      public var sceneY:int = 0;
      
      public var sceneLarge:Boolean = false;
      
      public var sceneReuseIdleFrame:Boolean = true;
      
      public var scenePauseDistant:Boolean = true;
      
      public var sceneChunkSide:int = 320;
      
      public var sceneRedraws:int = 0;
      
      public var sceneDrawMs:int = 0;
      
      public var sceneMaxDrawMs:int = 0;
      
      public var sceneResident:int = 0;
      
      public var sceneEvictions:int = 0;
      
      public var sceneMisses:int = 0;
      
      public var scenePreload:Boolean = false;
      
      public const sceneSynchronousRedraw:Boolean = true;
      
      public var sceneLastDirtyCount:int = 0;
      
      private var sceneRepaint:Boolean = false;
      
      private var sceneRasterizing:Boolean = false;
      
      private var sceneHistory:Dictionary = new Dictionary(true);
      
      private var sceneMarks:Array = [];
      
      private var sceneStamp:Array;
      
      private var sceneChunks:Object = {};
      
      private var sceneScratch:Array;
      
      private var sceneSide:int = 320;
      
      private var sceneGutter:int = 40;
      
      private var sceneMaskPool:Dictionary = new Dictionary();
      
      private var sceneMaskCursor:Dictionary = new Dictionary();
      
      private var sceneBackdropLocation:Location;
      
      private var sceneBackdropBuckets:Object = {};
      
      private var sceneBackdropBounds:Dictionary = new Dictionary(true);
      
      public var sceneBackdropTotal:int = 0;
      
      public var sceneBackdropReferences:int = 0;
      
      public var sceneBackdropFallbacks:int = 0;
      
      public var sceneCullRender:Boolean = true;
      
      private var sceneCullKey:String = "";
      
      public var sceneCompactImpacts:Boolean = true;
      
      private var sceneGame:Object;
      
      private var sceneLocations:Array = [];
      
      private var sceneSaved:Object = {};
      
      private var sceneFields:Array = ["front","phis","opac","vid","vid2","hp","water","t_ghost"];
      
      private var sceneRegionData:Dictionary = new Dictionary(true);
      
      private var sceneRegionComposite:Array;
      
      private var sceneRegionPassActive:Boolean = false;
      
      public var sceneRegionPasses:int = 0;
      
      private var sceneEntityColors:Dictionary = new Dictionary(true);
      
      private var sceneEntityLocationTokens:Dictionary = new Dictionary(true);
      
      public var sceneEntityTintChanges:int = 0;
      
      private var sceneBatch:Boolean = false;
      
      private const sceneBatchCells:int = 3;
      
      private var scenePreloadWidth:int = 0;
      
      private var scenePreloadHeight:int = 0;
      
      private var sceneNativeEnvironments:Dictionary = new Dictionary(true);
      
      private var sceneNativeLast:Object;
      
      private var sceneRasterRegion:Object;
      
      private var sceneUpcomingReady:Boolean = false;
      
      private var sceneNextWarm:int = 0;
      
      public var sceneWarmMaxMs:int = 0;
      
      public var sceneWarmCount:int = 0;
      
      public var sceneAsyncWarm:Boolean = true;
      
      public var sceneWarmSlices:int = 0;
      
      public var sceneWarmForced:int = 0;
      
      public var sceneWarmVerify:Boolean = false;
      
      public var sceneWarmComparisons:Array = [];
      
      public var sceneWarmBudget:int = 8;
      
      private var sceneWarmMean:Number = 48;
      
      private var sceneWarmViewX:Number = NaN;
      
      private var sceneWarmViewY:Number = NaN;
      
      private var sceneWarmJob:Object;
      
      private var sceneWarmBuffers:Array;
      
      private const sceneWarmFields:Array = ["frontBmp","backBmp","backBmp2","vodaBmp","satsBmp","colorBmp","shadBmp","rectX","rectY","allRect","sceneX","sceneY","sceneScratch","sceneRasterizing","sceneRepaint","sceneRegionPassActive","sceneRasterRegion","sceneMaskCursor","m"];
      
      private const sceneWarmStyleFields:Array = ["backwall","color","cTransform","darkness","backform","transpFon","tipWater","gas","homeStable"];
      
      private var rconnectRasterTicket:Object;
      
      public function Grafon(param1:Sprite)
      {
         var _loc2_:* = undefined;
         var _loc3_:String = null;
         this.dsFilter = new DropShadowFilter(7,90,0,0.75,16,16,1,3,false,false,true);
         this.infraTransform = new ColorTransform(1,1,1,1,100);
         this.defTransform = new ColorTransform();
         this.pa = new paintaero();
         this.pb = new paintbrush();
         this.brTrans = new ColorTransform();
         this.brColor = new Color();
         this.brData = new BitmapData(100,100,false,0);
         this.brPoint = new Point(0,0);
         this.brRect = new Rectangle(0,0,50,50);
         this.pm = new Matrix();
         this.voda = new tileVoda();
         this.allRect = new Rectangle(0,0,this.rectX,this.rectY);
         this.lightRect = new Rectangle(0,0,this.lightX,this.lightY);
         super();
         this.visual = param1;
         this.visBack = new Sprite();
         this.visBack2 = new Sprite();
         this.visVoda = new Sprite();
         this.visVoda.alpha = 0.6;
         this.visFront = new Sprite();
         this.visLight = new Sprite();
         this.visSats = new Sprite();
         this.visSats.visible = false;
         this.visSats.filters = [new BlurFilter(3,3,1)];
         this.visObjs = new Array();
         _loc2_ = 0;
         while(_loc2_ < this.kolObjs)
         {
            this.visObjs.push(new Sprite());
            _loc2_++;
         }
         this.visual.addChild(this.visBack);
         this.visual.addChild(this.visBack2);
         this.visual.addChild(this.visObjs[0]);
         this.visual.addChild(this.visObjs[1]);
         this.visual.addChild(this.visObjs[2]);
         this.visual.addChild(this.visFront);
         this.visual.addChild(this.visObjs[3]);
         this.visual.addChild(this.visVoda);
         this.visual.addChild(this.visLight);
         this.visual.addChild(this.visObjs[4]);
         this.visual.addChild(this.visSats);
         this.visual.addChild(this.visObjs[5]);
         this.visLight.x = -Tile.tileX / 2;
         this.visLight.y = -Tile.tileY / 2 - Tile.tileY;
         this.visLight.scaleX = Tile.tileX;
         this.visLight.scaleY = Tile.tileY;
         this.frontBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.frontBitmap = new Bitmap(this.frontBmp);
         this.visFront.addChild(this.frontBitmap);
         this.backBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.backBitmap = new Bitmap(this.backBmp);
         this.visBack.addChild(this.backBitmap);
         this.backBmp2 = new BitmapData(this.rectX,this.rectY,true,0);
         this.backBitmap2 = new Bitmap(this.backBmp2);
         this.visBack2.addChild(this.backBitmap2);
         this.vodaBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.vodaBitmap = new Bitmap(this.vodaBmp);
         this.visVoda.addChild(this.vodaBitmap);
         this.satsBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.satsBitmap = new Bitmap(this.satsBmp,"auto",true);
         this.visSats.addChild(this.satsBitmap);
         this.colorBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.shadBmp = new BitmapData(this.rectX,this.rectY,true,0);
         this.lightBmp = new BitmapData(this.lightX,this.lightY,true,4278190080);
         this.lightBitmap = new Bitmap(this.lightBmp,"auto",true);
         this.visLight.addChild(this.lightBitmap);
         this.ramT = new visBlack();
         this.ramB = new visBlack();
         this.ramR = new visBlack();
         this.ramL = new visBlack();
         this.ramT.cacheAsBitmap = this.ramB.cacheAsBitmap = this.ramR.cacheAsBitmap = this.ramL.cacheAsBitmap = true;
         this.visual.addChild(this.ramT);
         this.visual.addChild(this.ramB);
         this.visual.addChild(this.ramR);
         this.visual.addChild(this.ramL);
         this.grLoaders = new Array();
         for(_loc2_ in texUrl)
         {
            _loc3_ = texUrl[_loc2_];
            if(World.w.playerMode == "PlugIn")
            {
               _loc3_ += "?u=" + World.w.fileVersion;
            }
            this.grLoaders[_loc2_] = new GrLoader(_loc2_,_loc3_,this);
         }
         this.createCursors();
      }
      
      public function sceneSurfaces() : Array
      {
         var result:Array = [];
         for each(var entry in this.sceneChunks)
         {
            result.push(entry);
         }
         return result;
      }
      
      private function sceneMask(factory:Class) : MovieClip
      {
         if(!this.sceneLarge)
         {
            return new factory();
         }
         var list:Array = this.sceneMaskPool[factory];
         if(list == null)
         {
            this.sceneMaskPool[factory] = list = [];
         }
         var index:int = int(this.sceneMaskCursor[factory]);
         this.sceneMaskCursor[factory] = index + 1;
         if(index == list.length)
         {
            list.push(new factory());
         }
         var result:MovieClip = list[index];
         result.scaleX = result.scaleY = 1;
         return result;
      }
      
      private function sceneMatrix(value:Matrix = null) : Matrix
      {
         var result:Matrix = value == null ? new Matrix() : value.clone();
         result.tx -= this.sceneX;
         result.ty -= this.sceneY;
         return result;
      }
      
      private function scenePrepare(value:Location) : void
      {
         if(!this.sceneRasterizing)
         {
            this.sceneClear();
            this.sceneLarge = false;
            this.sceneX = this.sceneY = 0;
         }
         var width:int = this.scenePreloadWidth > 0 ? this.scenePreloadWidth : (this.sceneLarge ? this.sceneSide * (this.sceneBatch ? this.sceneBatchCells : 1) + this.sceneGutter * 2 : 1920);
         var height:int = this.scenePreloadHeight > 0 ? this.scenePreloadHeight : (this.sceneLarge ? width : 1000);
         if(width != this.rectX || height != this.rectY)
         {
            this.frontBmp.dispose();
            this.backBmp.dispose();
            this.backBmp2.dispose();
            this.vodaBmp.dispose();
            this.satsBmp.dispose();
            this.colorBmp.dispose();
            this.shadBmp.dispose();
            this.rectX = width;
            this.rectY = height;
            this.allRect = new Rectangle(0,0,width,height);
            this.frontBmp = new BitmapData(width,height,true,0);
            this.backBmp = new BitmapData(width,height,true,0);
            this.backBmp2 = new BitmapData(width,height,true,0);
            this.vodaBmp = new BitmapData(width,height,true,0);
            this.satsBmp = new BitmapData(width,height,true,0);
            this.colorBmp = new BitmapData(width,height,true,0);
            this.shadBmp = new BitmapData(width,height,true,0);
            this.frontBitmap.bitmapData = this.frontBmp;
            this.backBitmap.bitmapData = this.backBmp;
            this.backBitmap2.bitmapData = this.backBmp2;
            this.vodaBitmap.bitmapData = this.vodaBmp;
            this.satsBitmap.bitmapData = this.satsBmp;
         }
         this.sceneScratch = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
         this.frontBitmap.visible = this.backBitmap.visible = this.backBitmap2.visible = this.vodaBitmap.visible = this.satsBitmap.visible = !this.sceneLarge;
         this.kusokX = value.spaceX;
         this.kusokY = value.spaceY;
         if(this.lightX != value.spaceX + 1 || this.lightY != value.spaceY + 3)
         {
            this.lightBmp.dispose();
            this.lightX = value.spaceX + 1;
            this.lightY = value.spaceY + 3;
            this.lightRect = new Rectangle(0,0,this.lightX,this.lightY);
            this.lightBmp = new BitmapData(this.lightX,this.lightY,true,4278190080);
            this.lightBitmap.bitmapData = this.lightBmp;
            this.lightBitmap.smoothing = true;
         }
      }
      
      private function sceneClear() : void
      {
         this.sceneClearWarm();
         this.sceneWarmViewX = this.sceneWarmViewY = NaN;
         this.sceneWarmMean = 48;
         World.w.main.dispatchEvent(new Event("continuousSceneBeforeRasterClear"));
         for each(var entry in this.sceneChunks)
         {
            this.sceneDrop(entry);
         }
         this.sceneChunks = {};
         this.sceneResident = 0;
         this.sceneRegionClearScratch();
         this.sceneBackdropLocation = null;
         this.sceneBackdropBuckets = {};
         this.sceneBackdropBounds = new Dictionary(true);
         this.sceneBackdropTotal = this.sceneBackdropReferences = this.sceneBackdropFallbacks = 0;
         this.sceneCullKey = "";
         this.sceneUpcomingReady = false;
         this.sceneNextWarm = 0;
         this.sceneMaskPool = new Dictionary();
         this.sceneMaskCursor = new Dictionary();
      }
      
      private function sceneDrop(entry:Object) : void
      {
         for each(var nativeBuffer in entry.nativeBuffers)
         {
            nativeBuffer.dispose();
         }
         for each(var bitmap in entry.bitmaps)
         {
            if(bitmap.parent)
            {
               bitmap.parent.removeChild(bitmap);
            }
            bitmap.bitmapData = null;
         }
         if(entry.sats)
         {
            if(entry.sats.parent)
            {
               entry.sats.parent.removeChild(entry.sats);
            }
            entry.sats.bitmapData.dispose();
         }
         --this.sceneResident;
         ++this.sceneEvictions;
      }
      
      public function sceneBackdropObjects(x:Number, y:Number, width:Number, height:Number) : Array
      {
         if(!this.sceneLarge || this.sceneBackdropLocation !== this.loc)
         {
            return this.loc.backobjs;
         }
         var cx:int = int(Math.round((x + this.sceneGutter) / this.sceneSide));
         var cy:int = int(Math.round((y + this.sceneGutter) / this.sceneSide));
         if(x == cx * this.sceneSide - this.sceneGutter && y == cy * this.sceneSide - this.sceneGutter && width == this.sceneSide + this.sceneGutter * 2 && height == width)
         {
            var bucket:Array = this.sceneBackdropBuckets[cx + ":" + cy];
            return bucket == null ? [] : bucket;
         }
         var region:Rectangle = new Rectangle(x,y,width,height);
         var result:Array = [];
         for each(var backdrop in this.loc.backobjs)
         {
            var bounds:Rectangle = this.sceneBackdropBounds[backdrop];
            if(bounds != null && bounds.intersects(region))
            {
               result.push(backdrop);
            }
         }
         return result;
      }
      
      private function sceneIndexBackdrops() : void
      {
         this.sceneBackdropBuckets = {};
         this.sceneBackdropBounds = new Dictionary(true);
         this.sceneBackdropTotal = this.loc.backobjs.length;
         this.sceneBackdropReferences = this.sceneBackdropFallbacks = 0;
         var columns:int = int(Math.ceil(this.loc.limX / this.sceneSide));
         var rows:int = int(Math.ceil(this.loc.limY / this.sceneSide));
         for each(var backdrop in this.loc.backobjs)
         {
            var bounds:Rectangle = this.sceneBackdropObjectBounds(backdrop);
            this.sceneBackdropBounds[backdrop] = bounds;
            if(!bounds.isEmpty())
            {
               var minX:int = Math.max(0,Math.floor((bounds.left - this.sceneGutter) / this.sceneSide));
               var minY:int = Math.max(0,Math.floor((bounds.top - this.sceneGutter) / this.sceneSide));
               var maxX:int = Math.min(columns - 1,Math.floor((bounds.right + this.sceneGutter) / this.sceneSide));
               var maxY:int = Math.min(rows - 1,Math.floor((bounds.bottom + this.sceneGutter) / this.sceneSide));
               var cx:int = minX;
               while(cx <= maxX)
               {
                  var cy:int = minY;
                  while(cy <= maxY)
                  {
                     var region:Rectangle = new Rectangle(cx * this.sceneSide - this.sceneGutter,cy * this.sceneSide - this.sceneGutter,this.sceneSide + this.sceneGutter * 2,this.sceneSide + this.sceneGutter * 2);
                     if(bounds.intersects(region))
                     {
                        var key:String = cx + ":" + cy;
                        var bucket:Array = this.sceneBackdropBuckets[key];
                        if(bucket == null)
                        {
                           this.sceneBackdropBuckets[key] = bucket = [];
                        }
                        bucket.push(backdrop);
                        ++this.sceneBackdropReferences;
                     }
                     cy++;
                  }
                  cx++;
               }
            }
         }
         this.sceneBackdropLocation = this.loc;
      }
      
      private function sceneBackdropObjectBounds(backdrop:BackObj) : Rectangle
      {
         var transform:Matrix;
         var result:Rectangle;
         var art:DisplayObject;
         var local:Rectangle;
         var bounds:Rectangle;
         var padding:Number;
         try
         {
            transform = new Matrix();
            transform.scale(backdrop.scX,backdrop.scY);
            transform.tx = backdrop.X;
            transform.ty = backdrop.Y;
            result = null;
            for each(art in [backdrop.vis,backdrop.erase,backdrop.light])
            {
               if(art != null)
               {
                  local = this.sceneBackdropArtBounds(art);
                  if(!local.isEmpty())
                  {
                     bounds = this.sceneBackdropTransformBounds(local,transform);
                     result = result == null ? bounds : result.union(bounds);
                  }
               }
            }
            if(result == null)
            {
               return new Rectangle();
            }
            padding = 4 + 2 * Math.max(Math.abs(backdrop.scX),Math.abs(backdrop.scY));
            result.inflate(padding,padding);
            if(!isFinite(result.x) || !isFinite(result.y) || !isFinite(result.width) || !isFinite(result.height))
            {
               throw new Error("Non-finite backdrop bounds");
            }
            return result;
         }
         catch(error:Error)
         {
            ++this.sceneBackdropFallbacks;
            return new Rectangle(-this.sceneGutter,-this.sceneGutter,this.loc.limX + this.sceneGutter * 2,this.loc.limY + this.sceneGutter * 2);
         }
      }
      
      private function sceneBackdropArtBounds(art:DisplayObject) : Rectangle
      {
         var bounds:Rectangle = art.getBounds(art);
         var container:DisplayObjectContainer = art as DisplayObjectContainer;
         if(container != null)
         {
            var index:int = 0;
            while(index < container.numChildren)
            {
               var child:DisplayObject = container.getChildAt(index);
               var childBounds:Rectangle = this.sceneBackdropArtBounds(child);
               if(!childBounds.isEmpty())
               {
                  childBounds = this.sceneBackdropTransformBounds(childBounds,child.transform.matrix);
                  bounds = bounds.isEmpty() ? childBounds : bounds.union(childBounds);
               }
               index++;
            }
         }
         if(!bounds.isEmpty())
         {
            for each(var filter in art.filters)
            {
               bounds = bounds.union(this.frontBmp.generateFilterRect(bounds,filter));
            }
         }
         return bounds;
      }
      
      private function sceneBackdropTransformBounds(bounds:Rectangle, transform:Matrix) : Rectangle
      {
         var a:Point = transform.transformPoint(new Point(bounds.left,bounds.top));
         var b:Point = transform.transformPoint(new Point(bounds.right,bounds.top));
         var c:Point = transform.transformPoint(new Point(bounds.left,bounds.bottom));
         var d:Point = transform.transformPoint(new Point(bounds.right,bounds.bottom));
         var left:Number = Math.min(a.x,b.x,c.x,d.x);
         var top:Number = Math.min(a.y,b.y,c.y,d.y);
         return new Rectangle(left,top,Math.max(a.x,b.x,c.x,d.x) - left,Math.max(a.y,b.y,c.y,d.y) - top);
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
         if(this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true && !this.rconnectRasterWaiting() && this.sceneResident > 0 && this.sceneViewReady())
         {
            this.rconnectRasterTicket.unpainted = false;
         }
      }
      
      private function sceneOpen(value:Location) : void
      {
         var ticket:Object = null;
         if(rconnectRasterBridge != null)
         {
            try
            {
               ticket = rconnectRasterBridge(World.w,value,this);
               if(ticket == null || !(ticket.waiting is Boolean) || !(ticket.unpainted is Boolean))
               {
                  ticket = null;
               }
            }
            catch(error:*)
            {
               ticket = null;
               trace("RConnect first raster fallback: " + error);
            }
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
      
      private function sceneRender(cx:int, cy:int) : void
      {
         var parents:Array;
         var buffers:Array;
         var bitmaps:Array;
         var nativeBuffers:Array;
         var n:int;
         var data:BitmapData;
         var bitmap:Bitmap;
         var key:String = cx + ":" + cy;
         if(this.sceneChunks[key])
         {
            return;
         }
         this.sceneX = cx * this.sceneSide - this.sceneGutter;
         this.sceneY = cy * this.sceneSide - this.sceneGutter;
         this.sceneRasterizing = true;
         this.sceneRepaint = true;
         this.sceneMaskCursor = new Dictionary();
         try
         {
            this.sceneDrawRegionChunk();
         }
         finally
         {
            this.sceneRepaint = false;
            this.sceneRasterizing = false;
         }
         parents = [this.visFront,this.visBack,this.visBack2,this.visVoda];
         buffers = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
         bitmaps = [];
         nativeBuffers = [];
         n = 0;
         while(n < 4)
         {
            data = buffers[n].clone();
            bitmap = new Bitmap(data);
            bitmap.scrollRect = new Rectangle(this.sceneGutter,this.sceneGutter,this.sceneSide,this.sceneSide);
            bitmap.x = cx * this.sceneSide;
            bitmap.y = cy * this.sceneSide;
            parents[n].addChild(bitmap);
            bitmaps.push(bitmap);
            nativeBuffers.push(data);
            n++;
         }
         this.sceneChunks[key] = {
            "cx":cx,
            "cy":cy,
            "bitmaps":bitmaps,
            "sats":null,
            "nativeBuffers":nativeBuffers,
            "revision":0,
            "backobjs":this.sceneBackdropObjects(this.sceneX,this.sceneY,this.rectX,this.rectY),
            "x":cx * this.sceneSide - this.sceneGutter,
            "y":cy * this.sceneSide - this.sceneGutter,
            "side":this.sceneSide,
            "gutter":this.sceneGutter
         };
         ++this.sceneResident;
         this.sceneX = this.sceneY = 0;
      }
      
      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void
      {
         if(this.rconnectRasterWaiting())
         {
            return;
         }
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
         if(this.rconnectRasterWaiting())
         {
            return;
         }
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
      
      public function sceneViewport() : Rectangle
      {
         if(!this.sceneCullRender)
         {
            return null;
         }
         var scale:Number = Number(World.w.cam.scaleV > 0 ? World.w.cam.scaleV : 1);
         var guard:int = this.scenePreload ? 80 : 0;
         return new Rectangle((-World.w.cam.vx - World.w.cam.quakeX) / scale - guard,(-World.w.cam.vy - World.w.cam.quakeY) / scale - guard,World.w.cam.screenX / scale + 2 * guard,World.w.cam.screenY / scale + 2 * guard);
      }
      
      private function sceneCullSurfaces() : void
      {
         var view:Rectangle = this.sceneViewport();
         var key:String = view == null ? "all" : int(Math.floor(view.left / this.sceneSide)) + ":" + int(Math.floor(view.top / this.sceneSide)) + ":" + int(Math.ceil(view.right / this.sceneSide)) + ":" + int(Math.ceil(view.bottom / this.sceneSide));
         key += ":" + this.sceneResident;
         if(key == this.sceneCullKey)
         {
            return;
         }
         this.sceneCullKey = key;
         for each(var surface in this.sceneChunks)
         {
            var visible:Boolean = view == null || view.intersects(new Rectangle(surface.cx * this.sceneSide,surface.cy * this.sceneSide,this.sceneSide,this.sceneSide));
            for each(var bitmap in surface.bitmaps)
            {
               if(bitmap.visible != visible)
               {
                  bitmap.visible = visible;
               }
            }
         }
      }
      
      private function sceneApplyCompactDecal(args:Array, affected:Rectangle) : void
      {
         var previous:BitmapData;
         var ox:int;
         var oy:int;
         var width:int;
         var height:int;
         var local:Rectangle;
         var temporary:BitmapData;
         var area:Rectangle = affected.intersection(new Rectangle(this.sceneX,this.sceneY,this.frontBmp.width,this.frontBmp.height));
         if(area.isEmpty())
         {
            return;
         }
         area = new Rectangle(Math.floor(area.x),Math.floor(area.y),Math.ceil(area.right) - Math.floor(area.x),Math.ceil(area.bottom) - Math.floor(area.y));
         if(!this.sceneCompactImpacts || area.width > this.sceneSide || area.height > this.sceneSide)
         {
            this.sceneApplyRegionAction("decal",args,affected);
            return;
         }
         previous = this.frontBmp;
         ox = this.sceneX;
         oy = this.sceneY;
         width = this.rectX;
         height = this.rectY;
         local = area.clone();
         local.offset(-ox,-oy);
         temporary = new BitmapData(int(local.right),int(local.bottom),true,0);
         temporary.copyPixels(previous,local,local.topLeft);
         try
         {
            this.frontBmp = temporary;
            this.rectX = temporary.width;
            this.rectY = temporary.height;
            this.sceneApplyRegionAction("decal",args,affected);
            previous.copyPixels(temporary,local,local.topLeft);
         }
         finally
         {
            this.frontBmp = previous;
            this.sceneX = ox;
            this.sceneY = oy;
            this.rectX = width;
            this.rectY = height;
            temporary.dispose();
         }
      }
      
      private function sceneDecalBounds(args:Array, stamp:Array) : Rectangle
      {
         var transform:Matrix;
         var index:int;
         var factory:Class;
         var art:MovieClip;
         var local:Rectangle;
         var bounds:Rectangle;
         var width:int;
         var height:int;
         var alpha:Rectangle;
         var padding:Number;
         var result:Rectangle = null;
         try
         {
            transform = new Matrix();
            if(Number(args[4]) != 1)
            {
               transform.scale(Number(args[4]),Number(args[4]));
            }
            if(Number(args[5]) != 0)
            {
               transform.rotate(Number(args[5]));
            }
            transform.tx = Number(args[2]);
            transform.ty = Number(args[3]);
            index = 0;
            while(index < 2)
            {
               factory = args[index] as Class;
               if(factory != null)
               {
                  art = new factory();
                  if(art.totalFrames > 1)
                  {
                     art.gotoAndStop(Math.floor(Number(stamp[index]) * art.totalFrames + 1));
                  }
                  local = this.sceneDecalArtBounds(art);
                  if(!local.isEmpty())
                  {
                     bounds = this.sceneDecalTransformBounds(local,transform);
                     result = result == null ? bounds : result.union(bounds);
                  }
                  if(index == 1)
                  {
                     art.scaleX = art.scaleY = Number(args[4]);
                     art.rotation = Number(args[5]);
                     width = Math.round(art.width / 2 + 2) * 2;
                     height = Math.round(art.height / 2 + 2) * 2;
                     alpha = this.sceneDecalAlphaBounds(Number(args[2]),Number(args[3]),width,height);
                     result = result == null ? alpha : result.union(alpha);
                  }
               }
               index++;
            }
            if(result == null)
            {
               return new Rectangle();
            }
            padding = 4 + Math.abs(Number(args[4])) * 2;
            result.inflate(padding,padding);
            if(!isFinite(result.x) || !isFinite(result.y) || !isFinite(result.width) || !isFinite(result.height))
            {
               throw new Error("Non-finite decal bounds");
            }
            return result;
         }
         catch(error:Error)
         {
            return new Rectangle(-this.sceneGutter,-this.sceneGutter,this.loc.limX + this.sceneGutter * 2,this.loc.limY + this.sceneGutter * 2);
         }
      }
      
      private function sceneDecalAlphaBounds(x:Number, y:Number, width:int, height:int) : Rectangle
      {
         return new Rectangle(int(Math.max(x - width / 2,0)),int(Math.max(y - height / 2,0)),width,height);
      }
      
      private function sceneDecalSourcePixel(value:Number) : int
      {
         var lower:Number = Math.floor(value);
         var fraction:Number = value - lower;
         return int(fraction < 0.5 ? lower : (fraction > 0.5 ? lower + 1 : (lower % 2 == 0 ? lower : lower + 1)));
      }
      
      private function sceneDecalPaint(art:MovieClip, x:Number, y:Number, width:int, height:int, blend:String) : void
      {
         var alpha:BitmapData;
         var sample:Rectangle;
         var destination:Rectangle = this.sceneDecalAlphaBounds(x,y,width,height);
         var dx:int = this.sceneDecalSourcePixel(Math.max(x - width / 2,0)) - destination.x;
         var dy:int = this.sceneDecalSourcePixel(Math.max(y - height / 2,0)) - destination.y;
         var area:Rectangle = destination.intersection(new Rectangle(this.sceneX,this.sceneY,this.frontBmp.width,this.frontBmp.height));
         area.offset(-this.sceneX,-this.sceneY);
         alpha = null;
         try
         {
            if(!area.isEmpty())
            {
               alpha = new BitmapData(int(area.width),int(area.height),false,0);
               sample = area.clone();
               sample.offset(dx,dy);
               alpha.copyChannel(this.frontBmp,sample,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.GREEN);
            }
            this.frontBmp.draw(art,this.m,blend == "normal" ? World.w.loc.cTransform : null,blend,null,true);
            if(alpha != null)
            {
               this.frontBmp.copyChannel(alpha,alpha.rect,area.topLeft,BitmapDataChannel.GREEN,BitmapDataChannel.ALPHA);
            }
         }
         finally
         {
            if(alpha != null)
            {
               alpha.dispose();
            }
         }
      }
      
      private function sceneDecalArtBounds(art:DisplayObject) : Rectangle
      {
         var bounds:Rectangle = art.getBounds(art);
         var container:DisplayObjectContainer = art as DisplayObjectContainer;
         if(container != null)
         {
            var index:int = 0;
            while(index < container.numChildren)
            {
               var child:DisplayObject = container.getChildAt(index);
               var childBounds:Rectangle = this.sceneDecalArtBounds(child);
               if(!childBounds.isEmpty())
               {
                  childBounds = this.sceneDecalTransformBounds(childBounds,child.transform.matrix);
                  bounds = bounds.isEmpty() ? childBounds : bounds.union(childBounds);
               }
               index++;
            }
         }
         if(!bounds.isEmpty())
         {
            for each(var filter in art.filters)
            {
               bounds = this.frontBmp.generateFilterRect(bounds,filter);
            }
         }
         return bounds;
      }
      
      private function sceneDecalTransformBounds(bounds:Rectangle, transform:Matrix) : Rectangle
      {
         var a:Point = transform.transformPoint(new Point(bounds.left,bounds.top));
         var b:Point = transform.transformPoint(new Point(bounds.right,bounds.top));
         var c:Point = transform.transformPoint(new Point(bounds.left,bounds.bottom));
         var d:Point = transform.transformPoint(new Point(bounds.right,bounds.bottom));
         var left:Number = Math.min(a.x,b.x,c.x,d.x);
         var top:Number = Math.min(a.y,b.y,c.y,d.y);
         return new Rectangle(left,top,Math.max(a.x,b.x,c.x,d.x) - left,Math.max(a.y,b.y,c.y,d.y) - top);
      }
      
      private function sceneApply(kind:String, args:Array) : void
      {
         var stamp:Array;
         var ox:int;
         var oy:int;
         var affected:Rectangle;
         var entry:Object;
         this.sceneLastDirtyCount = 0;
         if(kind == "decal" && args[0] == null && args[1] == null)
         {
            return;
         }
         stamp = kind == "decal" ? [Math.random(),Math.random()] : null;
         ox = this.sceneX;
         oy = this.sceneY;
         if(kind == "decal")
         {
            affected = this.sceneDecalBounds(args,stamp);
         }
         else if(kind == "paint")
         {
            affected = new Rectangle(Math.min(args[0],args[2]) - 50,Math.min(args[1],args[3]) - 50,Math.abs(args[2] - args[0]) + 100,Math.abs(args[3] - args[1]) + 100);
         }
         else if(kind == "gwall")
         {
            affected = new Rectangle(int(args[0]) * 40,int(args[1]) * 40,40,40);
         }
         else if(kind == "drawWater")
         {
            affected = new Rectangle(args[0].X * 40,args[0].Y * 40,40,80);
         }
         this.sceneCancelWarm(affected);
         if(kind == "decal" || kind == "paint" || kind == "gwall")
         {
            this.sceneMarks.push([kind,args,stamp,affected]);
         }
         this.sceneRasterizing = true;
         this.sceneStamp = stamp;
         try
         {
            for each(entry in this.sceneChunks)
            {
               if(!(affected && !affected.intersects(new Rectangle(entry.x,entry.y,this.rectX,this.rectY))))
               {
                  this.frontBmp = entry.nativeBuffers[0];
                  this.backBmp = entry.nativeBuffers[1];
                  this.backBmp2 = entry.nativeBuffers[2];
                  this.vodaBmp = entry.nativeBuffers[3];
                  this.sceneX = entry.x;
                  this.sceneY = entry.y;
                  if(kind == "decal")
                  {
                     this.sceneApplyCompactDecal(args,affected);
                  }
                  else
                  {
                     this.sceneApplyRegionAction(kind,args,affected);
                  }
                  ++entry.revision;
                  ++this.sceneLastDirtyCount;
               }
            }
         }
         finally
         {
            this.frontBmp = this.sceneScratch[0];
            this.backBmp = this.sceneScratch[1];
            this.backBmp2 = this.sceneScratch[2];
            this.vodaBmp = this.sceneScratch[3];
            this.sceneX = ox;
            this.sceneY = oy;
            this.sceneRasterizing = false;
            this.sceneStamp = null;
         }
      }
      
      private function sceneRestoreMarks() : void
      {
         var item:Array;
         if(!this.sceneLarge)
         {
            return;
         }
         try
         {
            for each(item in this.sceneMarks)
            {
               this.sceneStamp = item[2];
               if(item[0] == "decal")
               {
                  if(item.length < 4 || !(item[3] is Rectangle))
                  {
                     item[3] = this.sceneDecalBounds(item[1],item[2]);
                  }
                  if(!Rectangle(item[3]).intersects(new Rectangle(this.sceneX,this.sceneY,this.rectX,this.rectY)))
                  {
                     continue;
                  }
               }
               this.sceneApplyRegionAction(String(item[0]),item[1],item.length > 3 ? item[3] as Rectangle : null);
            }
         }
         finally
         {
            this.sceneStamp = null;
         }
      }
      
      private function sceneSats() : void
      {
         var surface:Object;
         var raster:Bitmap;
         var parent:Sprite;
         var i:int;
         var entry:Object;
         var data:BitmapData;
         var bitmap:Bitmap;
         var sceneHidden:Array = [];
         for each(surface in this.sceneChunks)
         {
            for each(raster in surface.bitmaps)
            {
               if(!raster.visible)
               {
                  sceneHidden.push(raster);
                  raster.visible = true;
               }
            }
         }
         for each(parent in [this.visFront,this.visBack])
         {
            i = 0;
            while(i < parent.numChildren)
            {
               raster = parent.getChildAt(i) as Bitmap;
               if(raster != null && !raster.visible && (raster.name == "WallBlendSceneFront" || raster.name == "WallBlendSceneBack"))
               {
                  sceneHidden.push(raster);
                  raster.visible = true;
               }
               i++;
            }
         }
         try
         {
            for each(entry in this.sceneChunks)
            {
               if(entry.sats)
               {
                  if(entry.sats.parent)
                  {
                     entry.sats.parent.removeChild(entry.sats);
                  }
                  entry.sats.bitmapData.dispose();
               }
               data = new BitmapData(this.sceneSide,this.sceneSide,true,0);
               data.draw(this.visual,new Matrix(1,0,0,1,-entry.cx * this.sceneSide,-entry.cy * this.sceneSide));
               bitmap = new Bitmap(data,"auto",true);
               bitmap.x = entry.cx * this.sceneSide;
               bitmap.y = entry.cy * this.sceneSide;
               this.visSats.addChild(bitmap);
               entry.sats = bitmap;
            }
         }
         finally
         {
            for each(raster in sceneHidden)
            {
               raster.visible = false;
            }
         }
      }
      
      public function sceneTrack(value:Location, revision:String) : void
      {
         if(value.spaceX <= World.cellsX && value.spaceY <= World.cellsY)
         {
            return;
         }
         if(this.sceneGame !== World.w.game)
         {
            this.sceneGame = World.w.game;
            this.sceneLocations = [];
            this.sceneSaved = {};
            this.sceneHistory = new Dictionary(true);
            var encoded:* = this.sceneGame.triggers["continuous_scene.terrain.v1"];
            if(encoded is String && encoded.length)
            {
               var decoded:Object = JSON.parse(encoded);
               if(decoded.version == 1)
               {
                  this.sceneSaved = decoded.locations;
               }
            }
         }
         var base:Array = [];
         var y:int = 0;
         while(y < value.spaceY)
         {
            var x:int = 0;
            while(x < value.spaceX)
            {
               var tile:Tile = value.space[x][y];
               var row:Array = [];
               for each(var field in this.sceneFields)
               {
                  row.push(tile[field]);
               }
               base.push(row);
               x++;
            }
            y++;
         }
         var key:String = value.land.act.id + ":" + revision;
         var saved:Object = this.sceneSaved[key];
         if(saved && saved.width == value.spaceX && saved.height == value.spaceY)
         {
            for each(var change in saved.tiles)
            {
               var index:int = int(change[0]);
               if(!(index < 0 || index >= base.length || change.length != this.sceneFields.length + 1))
               {
                  tile = value.space[index % value.spaceX][int(index / value.spaceX)];
                  var i:int = 0;
                  while(i < this.sceneFields.length)
                  {
                     tile[this.sceneFields[i]] = change[i + 1];
                     i++;
                  }
               }
            }
            var marks:Array = [];
            for each(var mark in saved.marks)
            {
               if(mark[0] == "decal")
               {
                  mark[1][0] = mark[1][0] ? getDefinitionByName(mark[1][0]) as Class : null;
                  mark[1][1] = mark[1][1] ? getDefinitionByName(mark[1][1]) as Class : null;
               }
               marks.push(mark);
            }
            this.sceneHistory[value] = marks;
         }
         this.sceneLocations.push({
            "loc":value,
            "base":base,
            "key":key
         });
      }
      
      public function sceneSave(game:Object) : void
      {
         if(game !== this.sceneGame)
         {
            return;
         }
         for each(var entry in this.sceneLocations)
         {
            var value:Location = entry.loc;
            var changes:Array = [];
            var y:int = 0;
            while(y < value.spaceY)
            {
               var x:int = 0;
               while(x < value.spaceX)
               {
                  var index:int = y * value.spaceX + x;
                  var tile:Tile = value.space[x][y];
                  var row:Array = [index];
                  var changed:Boolean = false;
                  var i:int = 0;
                  while(i < this.sceneFields.length)
                  {
                     var current:* = tile[this.sceneFields[i]];
                     row.push(current);
                     if(current !== entry.base[index][i])
                     {
                        changed = true;
                     }
                     i++;
                  }
                  if(changed)
                  {
                     changes.push(row);
                  }
                  x++;
               }
               y++;
            }
            var marks:Array = [];
            for each(var mark in this.sceneHistory[value])
            {
               var args:Array = mark[1].concat();
               if(mark[0] == "decal")
               {
                  args[0] = args[0] ? getQualifiedClassName(args[0]) : null;
                  args[1] = args[1] ? getQualifiedClassName(args[1]) : null;
               }
               marks.push([mark[0],args,mark[2]]);
            }
            this.sceneSaved[entry.key] = {
               "width":value.spaceX,
               "height":value.spaceY,
               "tiles":changes,
               "marks":marks
            };
         }
         game.triggers["continuous_scene.terrain.v1"] = JSON.stringify({
            "version":1,
            "locations":this.sceneSaved
         });
      }
      
      public function sceneSetRegions(value:Location, metadata:XML) : void
      {
         delete this.sceneRegionData[value];
         if(value.spaceX <= World.cellsX && value.spaceY <= World.cellsY)
         {
            return;
         }
         if(metadata == null || metadata.sceneRegions.region.length() == 0)
         {
            return;
         }
         var regions:Array = [];
         var world:Rectangle = new Rectangle(0,0,value.spaceX * Tile.tileX,value.spaceY * Tile.tileY);
         for each(var node in metadata.sceneRegions.region)
         {
            var bounds:Rectangle = new Rectangle(Number(node.@x) * Tile.tileX,Number(node.@y) * Tile.tileY,Number(node.@width) * Tile.tileX,Number(node.@height) * Tile.tileY);
            if(!isFinite(bounds.x) || !isFinite(bounds.y) || !isFinite(bounds.width) || !isFinite(bounds.height) || bounds.width <= 0 || bounds.height <= 0 || !world.containsRect(bounds))
            {
               throw new Error("ContinuousScene region is outside its map");
            }
            for each(var prior in regions)
            {
               if(bounds.intersects(prior.bounds))
               {
                  throw new Error("ContinuousScene regions overlap");
               }
            }
            var color:String = node.@color.length() ? String(node.@color) : value.color;
            var darkness:Number = node.@dark.length() ? Number(node.@dark) : value.darkness;
            if(!isFinite(darkness))
            {
               throw new Error("ContinuousScene region darkness is invalid");
            }
            var style:Object = {
               "bounds":bounds,
               "backwall":(node.@backwall.length() ? String(node.@backwall) : value.backwall),
               "color":color,
               "cTransform":value.colorFilter(color),
               "darkness":int(darkness),
               "backform":(node.@backform.length() ? int(node.@backform) : value.backform),
               "transpFon":(node.@transpFon.length() ? String(node.@transpFon) == "true" : value.transpFon),
               "tipWater":(node.@tipWater.length() ? int(node.@tipWater) : value.tipWater),
               "gas":(node.@gas.length() ? int(node.@gas) : value.gas),
               "homeStable":(node.@homeStable.length() ? String(node.@homeStable) == "true" : value.homeStable),
               "nativeRegion":String(node.@nativeRegion) == "true"
            };
            style.key = this.sceneRegionStyleKey(style);
            regions.push(style);
         }
         this.sceneRegionData[value] = regions;
         this.sceneSyncRegionLighting(value);
      }
      
      private function sceneSyncRegionLighting(value:Location) : void
      {
         if(value.lightOn == 0)
         {
            return;
         }
         var regions:Array = this.sceneRegionData[value];
         if(regions == null)
         {
            return;
         }
         for each(var style in regions)
         {
            style.color = value.color;
            style.cTransform = value.cTransform;
            style.darkness = value.darkness;
            style.key = this.sceneRegionStyleKey(style);
         }
      }
      
      public function sceneRegionStyle(value:Location, worldX:Number, worldY:Number) : Object
      {
         var regions:Array = this.sceneRegionData[value];
         if(regions == null)
         {
            return null;
         }
         for each(var style in regions)
         {
            if(style.bounds.contains(worldX,worldY))
            {
               return style;
            }
         }
         return null;
      }
      
      public function sceneRegionSlices(value:Location, worldBounds:Rectangle) : Array
      {
         var result:Array = [];
         var regions:Array = this.sceneRegionData[value];
         if(regions == null)
         {
            return result;
         }
         for each(var style in regions)
         {
            var clip:Rectangle = worldBounds.intersection(style.bounds);
            if(!clip.isEmpty())
            {
               result.push({
                  "bounds":clip,
                  "style":style
               });
            }
         }
         return result;
      }
      
      private function sceneRegionStyleKey(style:Object) : String
      {
         return style.backwall + ":" + style.darkness + ":" + this.sceneRegionColorKey(style.cTransform) + ":" + style.backform + ":" + style.transpFon + ":" + style.tipWater + ":" + style.gas + ":" + style.homeStable + (style.nativeRegion && (style.backform != 0 || style.gas > 0) ? ":" + style.bounds.x + ":" + style.bounds.y : "");
      }
      
      private function sceneRegionColorKey(ct:ColorTransform) : String
      {
         return [ct == null ? 1 : ct.redMultiplier,ct == null ? 1 : ct.greenMultiplier,ct == null ? 1 : ct.blueMultiplier,ct == null ? 1 : ct.alphaMultiplier,ct == null ? 0 : ct.redOffset,ct == null ? 0 : ct.greenOffset,ct == null ? 0 : ct.blueOffset,ct == null ? 0 : ct.alphaOffset].join(":");
      }
      
      private function sceneRegionClearScratch() : void
      {
         if(this.sceneRegionComposite != null)
         {
            for each(var data in this.sceneRegionComposite)
            {
               data.dispose();
            }
         }
         this.sceneRegionComposite = null;
      }
      
      private function sceneRegionDrawPass(style:Object) : void
      {
         var prior:Boolean;
         this.loc.backwall = style.backwall;
         this.loc.color = style.color;
         this.loc.cTransform = style.cTransform;
         this.loc.darkness = style.darkness;
         this.loc.backform = style.backform;
         this.loc.transpFon = style.transpFon;
         this.loc.tipWater = style.tipWater;
         this.loc.gas = style.gas;
         this.loc.homeStable = style.homeStable;
         this.sceneRasterRegion = style.nativeRegion ? style : null;
         this.sceneMaskCursor = new Dictionary();
         ++this.sceneRegionPasses;
         prior = this.sceneRegionPassActive;
         this.sceneRegionPassActive = true;
         try
         {
            this.drawLoc(this.loc);
         }
         finally
         {
            this.sceneRegionPassActive = prior;
            this.sceneRasterRegion = null;
         }
      }
      
      private function sceneRegionEnsureScratch() : void
      {
         if(this.sceneRegionComposite != null && this.sceneRegionComposite[0].width == this.rectX && this.sceneRegionComposite[0].height == this.rectY)
         {
            return;
         }
         this.sceneRegionClearScratch();
         this.sceneRegionComposite = [];
         var n:int = 0;
         while(n < 4)
         {
            this.sceneRegionComposite.push(new BitmapData(this.rectX,this.rectY,true,0));
            n++;
         }
      }
      
      private function sceneApplyRegionAction(kind:String, args:Array, affected:Rectangle = null) : void
      {
         var viewport:Rectangle;
         var work:Rectangle;
         var original:ColorTransform;
         var originalKey:String;
         var groups:Array;
         var byKey:Object;
         var styledArea:Number;
         var slice:Object;
         var key:String;
         var group:Object;
         var target:BitmapData;
         var before:BitmapData;
         var output:BitmapData;
         var local:Rectangle;
         var origin:Point;
         var complete:Boolean;
         var firstGroup:int;
         var gi:int;
         var worldClip:Rectangle;
         var localClip:Rectangle;
         var action:Function = this[kind];
         if(this.sceneRegionPassActive || this.sceneRegionData[this.loc] == null || kind != "decal" && kind != "drawWater" || kind == "decal" && (args[1] == null || args[6] != "normal"))
         {
            action.apply(this,args);
            return;
         }
         viewport = new Rectangle(this.sceneX,this.sceneY,this.rectX,this.rectY);
         if(affected == null)
         {
            affected = kind == "decal" ? this.sceneDecalBounds(args,this.sceneStamp) : new Rectangle(args[0].X * Tile.tileX,args[0].Y * Tile.tileY,Tile.tileX,Tile.tileY * 2);
         }
         work = viewport.intersection(affected);
         if(work.isEmpty())
         {
            return;
         }
         work = new Rectangle(Math.floor(work.left),Math.floor(work.top),Math.ceil(work.right) - Math.floor(work.left),Math.ceil(work.bottom) - Math.floor(work.top));
         original = this.loc.cTransform;
         originalKey = this.sceneRegionColorKey(original);
         groups = [];
         byKey = {};
         styledArea = 0;
         for each(slice in this.sceneRegionSlices(this.loc,work))
         {
            key = this.sceneRegionColorKey(slice.style.cTransform);
            if(key != originalKey)
            {
               group = byKey[key];
               if(group == null)
               {
                  group = {
                     "ct":slice.style.cTransform,
                     "clips":[],
                     "area":0
                  };
                  byKey[key] = group;
                  groups.push(group);
               }
               group.clips.push(slice.bounds);
               group.area += slice.bounds.width * slice.bounds.height;
               styledArea += slice.bounds.width * slice.bounds.height;
            }
         }
         if(groups.length == 0)
         {
            action.apply(this,args);
            return;
         }
         target = kind == "decal" ? this.frontBmp : this.vodaBmp;
         local = work.clone();
         local.offset(-this.sceneX,-this.sceneY);
         origin = local.topLeft;
         complete = false;
         try
         {
            if(groups.length == 1 && groups[0].area == work.width * work.height)
            {
               this.loc.cTransform = groups[0].ct;
               action.apply(this,args);
               return;
            }
            this.sceneRegionEnsureScratch();
            before = this.sceneRegionComposite[0];
            output = this.sceneRegionComposite[1];
            before.copyPixels(target,local,origin);
            firstGroup = styledArea == work.width * work.height ? 1 : 0;
            this.loc.cTransform = firstGroup ? groups[0].ct : original;
            action.apply(this,args);
            output.copyPixels(target,local,origin);
            gi = firstGroup;
            while(gi < groups.length)
            {
               group = groups[gi];
               target.copyPixels(before,local,origin);
               this.loc.cTransform = group.ct;
               action.apply(this,args);
               for each(worldClip in group.clips)
               {
                  localClip = worldClip.clone();
                  localClip.offset(-this.sceneX,-this.sceneY);
                  output.copyPixels(target,localClip,localClip.topLeft);
               }
               gi++;
            }
            target.copyPixels(output,local,origin);
            complete = true;
         }
         finally
         {
            this.loc.cTransform = original;
            if(before != null && !complete)
            {
               target.copyPixels(before,local,origin);
            }
         }
      }
      
      private function sceneDrawRegionChunk() : void
      {
         var started:int;
         var original:Object;
         var originalKey:String;
         var viewport:Rectangle;
         var inWorld:Rectangle;
         var groups:Array;
         var byKey:Object;
         var styledArea:Number;
         var slice:Object;
         var group:Object;
         var firstGroup:int;
         var buffers:Array;
         var n:int;
         var origin:Point;
         var gi:int;
         var worldClip:Rectangle;
         var localClip:Rectangle;
         var destination:Point;
         var regions:Array = this.sceneRegionData[this.loc];
         if(regions == null || regions.length == 0)
         {
            this.drawLoc(this.loc);
            return;
         }
         started = int(getTimer());
         original = {
            "backwall":this.loc.backwall,
            "color":this.loc.color,
            "cTransform":this.loc.cTransform,
            "darkness":this.loc.darkness,
            "backform":this.loc.backform,
            "transpFon":this.loc.transpFon,
            "tipWater":this.loc.tipWater,
            "gas":this.loc.gas,
            "homeStable":this.loc.homeStable
         };
         originalKey = this.sceneRegionStyleKey(original);
         viewport = new Rectangle(this.sceneX,this.sceneY,this.rectX,this.rectY);
         inWorld = viewport.intersection(new Rectangle(0,0,this.loc.spaceX * Tile.tileX,this.loc.spaceY * Tile.tileY));
         groups = [];
         byKey = {};
         styledArea = 0;
         for each(slice in this.sceneRegionSlices(this.loc,viewport))
         {
            if(slice.style.key != originalKey)
            {
               group = byKey[slice.style.key];
               if(group == null)
               {
                  group = {
                     "style":slice.style,
                     "clips":[],
                     "area":0
                  };
                  byKey[slice.style.key] = group;
                  groups.push(group);
               }
               group.clips.push(slice.bounds);
               group.area += slice.bounds.width * slice.bounds.height;
               styledArea += slice.bounds.width * slice.bounds.height;
            }
         }
         try
         {
            if(groups.length == 0)
            {
               this.sceneRegionDrawPass(original);
               return;
            }
            if(groups.length == 1 && groups[0].area == inWorld.width * inWorld.height)
            {
               this.sceneRegionDrawPass(groups[0].style);
               return;
            }
            firstGroup = styledArea == inWorld.width * inWorld.height ? 1 : 0;
            this.sceneRegionDrawPass(firstGroup ? groups[0].style : original);
            buffers = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
            origin = new Point(0,0);
            this.sceneRegionEnsureScratch();
            n = 0;
            while(n < 4)
            {
               this.sceneRegionComposite[n].copyPixels(buffers[n],this.allRect,origin);
               n++;
            }
            gi = firstGroup;
            while(gi < groups.length)
            {
               group = groups[gi];
               this.sceneRegionDrawPass(group.style);
               for each(worldClip in group.clips)
               {
                  localClip = worldClip.clone();
                  localClip.offset(-this.sceneX,-this.sceneY);
                  destination = localClip.topLeft;
                  n = 0;
                  while(n < 4)
                  {
                     this.sceneRegionComposite[n].copyPixels(buffers[n],localClip,destination);
                     n++;
                  }
               }
               gi++;
            }
            n = 0;
            while(n < 4)
            {
               buffers[n].copyPixels(this.sceneRegionComposite[n],this.allRect,origin);
               n++;
            }
         }
         finally
         {
            this.loc.backwall = original.backwall;
            this.loc.color = original.color;
            this.loc.cTransform = original.cTransform;
            this.loc.darkness = original.darkness;
            this.loc.backform = original.backform;
            this.loc.transpFon = original.transpFon;
            this.loc.tipWater = original.tipWater;
            this.loc.gas = original.gas;
            this.loc.homeStable = original.homeStable;
            this.sceneDrawMs = getTimer() - started;
            this.sceneMaxDrawMs = Math.max(this.sceneMaxDrawMs,this.sceneDrawMs);
         }
      }
      
      public function sceneUpdateEntityColor(target:Obj, eligible:Boolean = true) : void
      {
         if(!this.sceneLarge || target == null || target.loc == null || target.loc !== this.loc || this.sceneRegionData[target.loc] == null)
         {
            return;
         }
         if(!eligible)
         {
            delete this.sceneEntityColors[target];
            return;
         }
         var locationToken:Object = this.sceneEntityLocationTokens[target.loc];
         if(locationToken == null)
         {
            this.sceneEntityLocationTokens[target.loc] = locationToken = {};
         }
         var previous:Object = this.sceneEntityColors[target];
         var original:ColorTransform = target.cTransform;
         if(original !== target.loc.cTransform && (previous == null || previous.locationToken !== locationToken || original !== previous.base))
         {
            return;
         }
         var worldX:Number = target.X;
         var worldY:Number = target.Y - target.scY / 2;
         var region:Object = previous != null && previous.locationToken === locationToken ? previous.region : null;
         if(region == null || !region.bounds.contains(worldX,worldY))
         {
            region = this.sceneRegionStyle(target.loc,worldX,worldY);
         }
         var desired:ColorTransform = region == null ? target.loc.cTransform : region.cTransform;
         if(previous == null || previous.locationToken !== locationToken)
         {
            this.sceneEntityColors[target] = previous = {
               "locationToken":locationToken,
               "base":original,
               "region":region
            };
         }
         previous.region = region;
         if(original === desired)
         {
            previous.base = desired;
            return;
         }
         var highlighted:Boolean = World.w.shineObjs && World.w.gui != null && World.w.gui.celObj === target;
         var displayOwned:Boolean = target.vis != null && (target.levit == 0 || target === World.w.gg) && !highlighted && this.sceneEntitySameColor(target.vis.transform.colorTransform,original);
         target.cTransform = desired;
         previous.base = desired;
         ++this.sceneEntityTintChanges;
         if(displayOwned)
         {
            target.vis.transform.colorTransform = desired;
         }
         var object:* = target;
         if("currentWeapon" in object)
         {
            var weapon:* = object.currentWeapon;
            if(weapon != null && weapon.tip != 5 && weapon.vis != null && this.sceneEntitySameColor(weapon.vis.transform.colorTransform,original))
            {
               weapon.vis.transform.colorTransform = desired;
            }
         }
      }
      
      private function sceneEntitySameColor(a:ColorTransform, b:ColorTransform):Boolean
{
    if(a == null || b == null) return false;
    if(a.redMultiplier == b.redMultiplier && a.greenMultiplier == b.greenMultiplier
        && a.blueMultiplier == b.blueMultiplier && a.alphaMultiplier == b.alphaMultiplier
        && a.redOffset == b.redOffset && a.greenOffset == b.greenOffset
        && a.blueOffset == b.blueOffset && a.alphaOffset == b.alphaOffset) return true;
    if(!isFinite(b.redMultiplier) || !isFinite(b.greenMultiplier)
        || !isFinite(b.blueMultiplier) || !isFinite(b.alphaMultiplier)
        || !isFinite(b.redOffset) || !isFinite(b.greenOffset)
        || !isFinite(b.blueOffset) || !isFinite(b.alphaOffset)) return false;
    var normalizer:Sprite = new Sprite();
    normalizer.transform.colorTransform = b;
    b = normalizer.transform.colorTransform;
    return a.redMultiplier == b.redMultiplier && a.greenMultiplier == b.greenMultiplier
        && a.blueMultiplier == b.blueMultiplier && a.alphaMultiplier == b.alphaMultiplier
        && a.redOffset == b.redOffset && a.greenOffset == b.greenOffset
        && a.blueOffset == b.blueOffset && a.alphaOffset == b.alphaOffset;
}
      
      private function scenePreloadAll() : void
      {
         var columns:int;
         var rows:int;
         var size:int;
         var parents:Array;
         var bx:int;
         var by:int;
         var buffers:Array;
         var cx:int;
         var cy:int;
         var key:String;
         var nativeBuffers:Array;
         var bitmaps:Array;
         var source:Rectangle;
         var n:int;
         var data:BitmapData;
         var bitmap:Bitmap;
         var x:int;
         var y:int;
         if(this.scenePreloadRegions())
         {
            return;
         }
         columns = Math.ceil(this.loc.limX / this.sceneSide);
         rows = Math.ceil(this.loc.limY / this.sceneSide);
         size = this.sceneSide + 2 * this.sceneGutter;
         parents = [this.visFront,this.visBack,this.visBack2,this.visVoda];
         this.sceneBatch = true;
         this.sceneRasterizing = true;
         this.sceneRepaint = true;
         try
         {
            this.scenePrepare(this.loc);
            bx = 0;
            while(bx < columns)
            {
               by = 0;
               while(by < rows)
               {
                  this.sceneX = bx * this.sceneSide - this.sceneGutter;
                  this.sceneY = by * this.sceneSide - this.sceneGutter;
                  this.sceneDrawRegionChunk();
                  buffers = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
                  cx = bx;
                  while(cx < Math.min(columns,bx + this.sceneBatchCells))
                  {
                     cy = by;
                     while(cy < Math.min(rows,by + this.sceneBatchCells))
                     {
                        key = cx + ":" + cy;
                        if(!this.sceneChunks[key])
                        {
                           nativeBuffers = [];
                           bitmaps = [];
                           source = new Rectangle((cx - bx) * this.sceneSide,(cy - by) * this.sceneSide,size,size);
                           n = 0;
                           while(n < 4)
                           {
                              data = new BitmapData(size,size,true,0);
                              data.copyPixels(buffers[n],source,new Point());
                              bitmap = new Bitmap(data);
                              bitmap.scrollRect = new Rectangle(this.sceneGutter,this.sceneGutter,this.sceneSide,this.sceneSide);
                              bitmap.x = cx * this.sceneSide;
                              bitmap.y = cy * this.sceneSide;
                              parents[n].addChild(bitmap);
                              bitmaps.push(bitmap);
                              nativeBuffers.push(data);
                              n++;
                           }
                           x = cx * this.sceneSide - this.sceneGutter;
                           y = cy * this.sceneSide - this.sceneGutter;
                           this.sceneChunks[key] = {
                              "cx":cx,
                              "cy":cy,
                              "bitmaps":bitmaps,
                              "sats":null,
                              "nativeBuffers":nativeBuffers,
                              "revision":0,
                              "backobjs":this.sceneBackdropObjects(x,y,size,size),
                              "x":x,
                              "y":y,
                              "side":this.sceneSide,
                              "gutter":this.sceneGutter
                           };
                           ++this.sceneResident;
                        }
                        cy++;
                     }
                     cx++;
                  }
                  by += this.sceneBatchCells;
               }
               bx += this.sceneBatchCells;
            }
         }
         catch(error:*)
         {
            this.sceneFinishBatch();
            throw error;
         }
         this.sceneFinishBatch();
      }
      
      private function sceneFinishBatch() : void
      {
         this.sceneBatch = false;
         this.scenePreloadWidth = this.scenePreloadHeight = 0;
         this.sceneX = this.sceneY = 0;
         this.sceneRepaint = false;
         this.scenePrepare(this.loc);
         this.sceneRegionClearScratch();
         this.sceneRasterizing = false;
      }
      
      private function scenePreloadRegions() : Boolean
      {
         var area:Number;
         var style:Object;
         var original:Object;
         var columns:int;
         var rows:int;
         var size:int;
         var parents:Array;
         var n:int;
         var cx:int;
         var cy:int;
         var key:String;
         var buffers:Array;
         var bitmaps:Array;
         var data:BitmapData;
         var bitmap:Bitmap;
         var x:int;
         var y:int;
         var clip:Rectangle;
         var draw:Rectangle;
         var surface:Object;
         var worldClip:Rectangle;
         var source:Rectangle;
         var point:Point;
         var field:String;
         var regions:Array = this.sceneRegionData[this.loc];
         if(regions == null || regions.length == 0)
         {
            return false;
         }
         area = 0;
         for each(style in regions)
         {
            area += style.bounds.width * style.bounds.height;
         }
         if(area != this.loc.limX * this.loc.limY)
         {
            return false;
         }
         original = {
            "backwall":this.loc.backwall,
            "color":this.loc.color,
            "cTransform":this.loc.cTransform,
            "darkness":this.loc.darkness,
            "backform":this.loc.backform,
            "transpFon":this.loc.transpFon,
            "tipWater":this.loc.tipWater,
            "gas":this.loc.gas,
            "homeStable":this.loc.homeStable
         };
         columns = Math.ceil(this.loc.limX / this.sceneSide);
         rows = Math.ceil(this.loc.limY / this.sceneSide);
         size = this.sceneSide + 2 * this.sceneGutter;
         parents = [this.visFront,this.visBack,this.visBack2,this.visVoda];
         this.sceneRasterizing = true;
         this.sceneRepaint = true;
         try
         {
            cx = 0;
            while(cx < columns)
            {
               cy = 0;
               while(cy < rows)
               {
                  key = cx + ":" + cy;
                  if(!this.sceneChunks[key])
                  {
                     buffers = [];
                     bitmaps = [];
                     n = 0;
                     while(n < 4)
                     {
                        data = new BitmapData(size,size,true,0);
                        bitmap = new Bitmap(data);
                        bitmap.scrollRect = new Rectangle(this.sceneGutter,this.sceneGutter,this.sceneSide,this.sceneSide);
                        bitmap.x = cx * this.sceneSide;
                        bitmap.y = cy * this.sceneSide;
                        parents[n].addChild(bitmap);
                        bitmaps.push(bitmap);
                        buffers.push(data);
                        n++;
                     }
                     x = cx * this.sceneSide - this.sceneGutter;
                     y = cy * this.sceneSide - this.sceneGutter;
                     this.sceneChunks[key] = {
                        "cx":cx,
                        "cy":cy,
                        "bitmaps":bitmaps,
                        "sats":null,
                        "nativeBuffers":buffers,
                        "revision":0,
                        "backobjs":this.sceneBackdropObjects(x,y,size,size),
                        "x":x,
                        "y":y,
                        "side":this.sceneSide,
                        "gutter":this.sceneGutter
                     };
                     ++this.sceneResident;
                  }
                  cy++;
               }
               cx++;
            }
            for each(style in regions)
            {
               clip = style.bounds.clone();
               if(clip.left == 0)
               {
                  clip.left = -this.sceneGutter;
               }
               if(clip.top == 0)
               {
                  clip.top = -this.sceneGutter;
               }
               if(clip.right == this.loc.limX)
               {
                  clip.right = columns * this.sceneSide + this.sceneGutter;
               }
               if(clip.bottom == this.loc.limY)
               {
                  clip.bottom = rows * this.sceneSide + this.sceneGutter;
               }
               draw = clip.clone();
               draw.inflate(this.sceneGutter,this.sceneGutter);
               this.sceneX = draw.x;
               this.sceneY = draw.y;
               this.scenePreloadWidth = draw.width;
               this.scenePreloadHeight = draw.height;
               this.scenePrepare(this.loc);
               this.sceneRegionDrawPass(style);
               buffers = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
               for each(surface in this.sceneChunks)
               {
                  worldClip = clip.intersection(new Rectangle(surface.x,surface.y,size,size));
                  if(!worldClip.isEmpty())
                  {
                     source = worldClip.clone();
                     source.offset(-this.sceneX,-this.sceneY);
                     point = new Point(worldClip.x - surface.x,worldClip.y - surface.y);
                     n = 0;
                     while(n < 4)
                     {
                        surface.nativeBuffers[n].copyPixels(buffers[n],source,point);
                        n++;
                     }
                  }
               }
            }
         }
         catch(error:*)
         {
            for(field in original)
            {
               this.loc[field] = original[field];
            }
            this.sceneFinishBatch();
            throw error;
         }
         for(field in original)
         {
            this.loc[field] = original[field];
         }
         this.sceneFinishBatch();
         return true;
      }
      
      private function sceneNativeBackwall(id:String, form:int) : Boolean
      {
         if(this.sceneRasterRegion == null || form == 0)
         {
            return false;
         }
         if(id == "sky")
         {
            return true;
         }
         var bounds:Rectangle = this.sceneRasterRegion.bounds;
         var texture:BitmapData = this.getObj(id);
         if(texture == null)
         {
            texture = this.getObj("tBackWall");
         }
         var sprite:Sprite = new Sprite();
         sprite.graphics.beginBitmapFill(texture);
         if(form == 1)
         {
            sprite.graphics.drawRect(bounds.x,bounds.y,11 * Tile.tileX - 10,bounds.height);
            sprite.graphics.drawRect(bounds.x + 37 * Tile.tileX + 10,bounds.y,bounds.width - 37 * Tile.tileX - 10,bounds.height);
         }
         else
         {
            var top:int = form == 2 ? 16 * Tile.tileY + 10 : 24 * Tile.tileY + 10;
            sprite.graphics.drawRect(bounds.x,bounds.y + top,bounds.width,Math.max(0,bounds.height - top));
         }
         this.backBmp.draw(sprite,this.sceneMatrix(),null,null,null,false);
         return true;
      }
      
      public function sceneNativeCall(kind:String, args:Array) : *
      {
         var carrier:Object = World.w.main.getChildByName("ContinuousSceneCarrier");
         if(carrier == null || carrier["nativeAPI"] == null)
         {
            return null;
         }
         var action:Function = carrier["nativeAPI"][kind];
         return action == null ? null : action.apply(null,args);
      }
      
      public function sceneSetNativeEnvironment(value:Location, state:Object) : void
      {
         for(var prior in this.sceneNativeEnvironments)
         {
            if(prior.land.act.id == value.land.act.id && prior !== value)
            {
               delete this.sceneNativeEnvironments[prior];
            }
         }
         this.sceneNativeEnvironments[value] = state;
         this.sceneNativeLast = null;
      }
      
      public function sceneNativeEnvironment(value:Location, x:Number, y:Number) : void
      {
         var state:Object = this.sceneNativeEnvironments[value];
         if(state == null)
         {
            return;
         }
         var region:Object = state.byCell[value.land.minLocX + int(Math.max(0,x) / 1920) + ":" + (value.land.minLocY + int(Math.max(0,y) / 1000))];
         if(region == null || region === this.sceneNativeLast)
         {
            return;
         }
         for(var field in region.environment)
         {
            value[field] = region.environment[field];
         }
         this.sceneNativeLast = region;
      }
      
      public function sceneForgetLand(land:Object) : void
      {
         var i:int = this.sceneLocations.length - 1;
         while(i >= 0)
         {
            var entry:Object = this.sceneLocations[i];
            if(entry.loc.land.act.id == land.act.id && entry.loc.land !== land)
            {
               delete this.sceneHistory[entry.loc];
               delete this.sceneSaved[entry.key];
               this.sceneLocations.splice(i,1);
            }
            i--;
         }
      }
      
      public function sceneResetGeneration(id:String) : void
      {
         World.w.main.dispatchEvent(new DataEvent("continuousSceneResetGeneration",false,false,id));
         var i:int = this.sceneLocations.length - 1;
         while(i >= 0)
         {
            if(this.sceneLocations[i].loc.land.act.id == id)
            {
               delete this.sceneHistory[this.sceneLocations[i].loc];
               this.sceneLocations.splice(i,1);
            }
            i--;
         }
         for(var key in this.sceneSaved)
         {
            if(key.indexOf(id + ":") == 0)
            {
               delete this.sceneSaved[key];
            }
         }
      }
      
      private function sceneMaterialFill(fill:Sprite, mask:Sprite, texture:BitmapData, clip:Rectangle) : void
      {
         var bounds:Rectangle = mask.getBounds(mask);
         fill.graphics.clear();
         if(bounds.isEmpty())
         {
            return;
         }
         bounds = new Rectangle(Math.floor(bounds.left) - 1,Math.floor(bounds.top) - 1,Math.ceil(bounds.right) - Math.floor(bounds.left) + 2,Math.ceil(bounds.bottom) - Math.floor(bounds.top) + 2).intersection(clip);
         if(bounds.isEmpty())
         {
            return;
         }
         if(texture == null)
         {
            fill.graphics.beginFill(6710886);
         }
         else
         {
            fill.graphics.beginBitmapFill(texture);
         }
         fill.graphics.drawRect(bounds.x,bounds.y,bounds.width,bounds.height);
      }
      
      private function sceneConfigureBorders() : void
      {
         this.ramT.x = this.ramB.x = -50;
         this.ramR.y = this.ramL.y = 0;
         this.ramT.y = 0;
         this.ramL.x = 0;
         this.ramB.y = this.loc.limY - 1;
         this.ramR.x = this.loc.limX - 1;
         this.ramT.scaleX = this.ramB.scaleX = this.loc.limX / 100 + 1;
         this.ramT.scaleY = this.ramB.scaleY = 2;
         this.ramR.scaleY = this.ramL.scaleY = this.loc.limY / 100;
         this.ramR.scaleX = this.ramL.scaleX = 2;
      }
      
      public function sceneViewReady() : Boolean
      {
         if(this.rconnectRasterWaiting())
         {
            return false;
         }
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
      
      private function sceneEnsureUpcoming(left:Number, top:Number, width:Number, height:Number) : void
      {
         var minX:int = Math.max(0,Math.floor(left / this.sceneSide));
         var minY:int = Math.max(0,Math.floor(top / this.sceneSide));
         var maxX:int = Math.min(Math.ceil(this.loc.limX / this.sceneSide) - 1,Math.ceil((left + width) / this.sceneSide) - 1);
         var maxY:int = Math.min(Math.ceil(this.loc.limY / this.sceneSide) - 1,Math.ceil((top + height) / this.sceneSide) - 1);
         var travelX:Number = isNaN(this.sceneWarmViewX) ? 0 : left - this.sceneWarmViewX;
         var travelY:Number = isNaN(this.sceneWarmViewY) ? 0 : top - this.sceneWarmViewY;
         this.sceneWarmViewX = left;
         this.sceneWarmViewY = top;
         travelX = Math.abs(travelX) > 80 ? 0 : travelX;
         travelY = Math.abs(travelY) > 80 ? 0 : travelY;
         if(Math.abs(travelX) < 0.5)
         {
            travelX = this.loc.gg.dx;
         }
         if(Math.abs(travelY) < 0.5)
         {
            travelY = this.loc.gg.dy;
         }
         var demand:Number = (Math.abs(travelX) * (maxY - minY + 1) + Math.abs(travelY) * (maxX - minX + 1)) / this.sceneSide;
         this.sceneWarmBudget = Math.max(2,Math.min(24,Math.ceil(this.sceneWarmMean * demand * 1.35 + 1)));
         if(!this.sceneUpcomingReady)
         {
            this.sceneUpcomingReady = true;
            if(this.sceneRegionData[this.loc] != null)
            {
               this.sceneFirstWindow(minX,minY,maxX,maxY);
            }
         }
         var x:int = minX;
         while(x <= maxX)
         {
            var y:int = minY;
            while(y <= maxY)
            {
               if(!this.sceneChunks[x + ":" + y])
               {
                  ++this.sceneMisses;
                  if(this.sceneWarmJob && this.sceneWarmJob.cx == x && this.sceneWarmJob.cy == y)
                  {
                     this.sceneAdvanceWarm(true);
                  }
                  if(!this.sceneChunks[x + ":" + y])
                  {
                     this.sceneRender(x,y);
                  }
               }
               y++;
            }
            x++;
         }
         if(World.w.t_exit != 0)
         {
            this.sceneNextWarm = getTimer() + 250;
            return;
         }
         if(this.sceneWarmJob)
         {
            this.sceneAdvanceWarm();
            return;
         }
         if(getTimer() < this.sceneNextWarm)
         {
            return;
         }
         var centerX:Number = left + width / 2;
         var centerY:Number = top + height / 2;
         var dx:Number = travelX;
         var dy:Number = travelY;
         centerX += Math.max(-640,Math.min(640,dx * 60));
         centerY += Math.max(-640,Math.min(640,dy * 60));
         var bestX:int = -1;
         var bestY:int = -1;
         var best:Number = Number.MAX_VALUE;
         var moving:Boolean = Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5;
         var warmLeft:int = minX - (!moving || dx < -0.5 ? 2 : 0);
         var warmRight:int = maxX + (!moving || dx > 0.5 ? 2 : 0);
         var warmTop:int = minY - (!moving || dy < -0.5 ? 2 : 0);
         var warmBottom:int = maxY + (!moving || dy > 0.5 ? 2 : 0);
         x = Math.max(0,warmLeft);
         while(x <= Math.min(Math.ceil(this.loc.limX / this.sceneSide) - 1,warmRight))
         {
            y = Math.max(0,warmTop);
            while(y <= Math.min(Math.ceil(this.loc.limY / this.sceneSide) - 1,warmBottom))
            {
               if(!this.sceneChunks[x + ":" + y])
               {
                  var score:Number = Math.abs((x + 0.5) * this.sceneSide - centerX) + Math.abs((y + 0.5) * this.sceneSide - centerY);
                  if(dx > 0.5 && x > maxX && y >= minY && y <= maxY || dx < -0.5 && x < minX && y >= minY && y <= maxY || dy > 0.5 && y > maxY && x >= minX && x <= maxX || dy < -0.5 && y < minY && x >= minX && x <= maxX)
                  {
                     score -= 100000;
                  }
                  if(score < best)
                  {
                     best = score;
                     bestX = x;
                     bestY = y;
                  }
               }
               y++;
            }
            x++;
         }
         if(bestX >= 0)
         {
            var started:int = int(getTimer());
            if(this.sceneAsyncWarm)
            {
               this.sceneBeginWarm(bestX,bestY);
               this.sceneAdvanceWarm();
               return;
            }
            this.sceneRender(bestX,bestY);
            var elapsed:int = getTimer() - started;
            this.sceneWarmMaxMs = Math.max(this.sceneWarmMaxMs,elapsed);
            ++this.sceneWarmCount;
            this.sceneNextWarm = getTimer() + 100;
         }
      }
      
      private function sceneFirstWindow(minX:int, minY:int, maxX:int, maxY:int) : void
      {
         var region:Object;
         var original:Object;
         var size:int;
         var parents:Array;
         var requested:Rectangle;
         var made:Array;
         var cx:int;
         var cy:int;
         var key:String;
         var buffers:Array;
         var bitmaps:Array;
         var n:int;
         var data:BitmapData;
         var bitmap:Bitmap;
         var x:int;
         var y:int;
         var surface:Object;
         var style:Object;
         var clip:Rectangle;
         var draw:Rectangle;
         var worldClip:Rectangle;
         var source:Rectangle;
         var point:Point;
         var field:String;
         var regions:Array = this.sceneRegionData[this.loc];
         var area:Number = 0;
         for each(region in regions)
         {
            area += region.bounds.width * region.bounds.height;
         }
         if(area != this.loc.limX * this.loc.limY)
         {
            return;
         }
         original = {
            "backwall":this.loc.backwall,
            "color":this.loc.color,
            "cTransform":this.loc.cTransform,
            "darkness":this.loc.darkness,
            "backform":this.loc.backform,
            "transpFon":this.loc.transpFon,
            "tipWater":this.loc.tipWater,
            "gas":this.loc.gas,
            "homeStable":this.loc.homeStable
         };
         size = this.sceneSide + 2 * this.sceneGutter;
         parents = [this.visFront,this.visBack,this.visBack2,this.visVoda];
         requested = new Rectangle(minX * this.sceneSide - this.sceneGutter,minY * this.sceneSide - this.sceneGutter,(maxX - minX + 1) * this.sceneSide + 2 * this.sceneGutter,(maxY - minY + 1) * this.sceneSide + 2 * this.sceneGutter);
         made = [];
         this.sceneRasterizing = true;
         this.sceneRepaint = true;
         try
         {
            cx = minX;
            while(cx <= maxX)
            {
               cy = minY;
               while(cy <= maxY)
               {
                  key = cx + ":" + cy;
                  if(!this.sceneChunks[key])
                  {
                     buffers = [];
                     bitmaps = [];
                     n = 0;
                     while(n < 4)
                     {
                        data = new BitmapData(size,size,true,0);
                        bitmap = new Bitmap(data);
                        bitmap.scrollRect = new Rectangle(this.sceneGutter,this.sceneGutter,this.sceneSide,this.sceneSide);
                        bitmap.x = cx * this.sceneSide;
                        bitmap.y = cy * this.sceneSide;
                        parents[n].addChild(bitmap);
                        bitmaps.push(bitmap);
                        buffers.push(data);
                        n++;
                     }
                     x = cx * this.sceneSide - this.sceneGutter;
                     y = cy * this.sceneSide - this.sceneGutter;
                     surface = {
                        "cx":cx,
                        "cy":cy,
                        "bitmaps":bitmaps,
                        "sats":null,
                        "nativeBuffers":buffers,
                        "revision":0,
                        "backobjs":this.sceneBackdropObjects(x,y,size,size),
                        "x":x,
                        "y":y,
                        "side":this.sceneSide,
                        "gutter":this.sceneGutter
                     };
                     this.sceneChunks[key] = surface;
                     made.push(surface);
                     ++this.sceneResident;
                  }
                  cy++;
               }
               cx++;
            }
            for each(style in regions)
            {
               clip = style.bounds.clone();
               if(clip.left == 0)
               {
                  clip.left = -this.sceneGutter;
               }
               if(clip.top == 0)
               {
                  clip.top = -this.sceneGutter;
               }
               if(clip.right == this.loc.limX)
               {
                  clip.right = Math.ceil(this.loc.limX / this.sceneSide) * this.sceneSide + this.sceneGutter;
               }
               if(clip.bottom == this.loc.limY)
               {
                  clip.bottom = Math.ceil(this.loc.limY / this.sceneSide) * this.sceneSide + this.sceneGutter;
               }
               clip = clip.intersection(requested);
               if(!clip.isEmpty())
               {
                  draw = clip.clone();
                  draw.inflate(this.sceneGutter,this.sceneGutter);
                  this.sceneX = draw.x;
                  this.sceneY = draw.y;
                  this.scenePreloadWidth = draw.width;
                  this.scenePreloadHeight = draw.height;
                  this.scenePrepare(this.loc);
                  this.sceneRegionDrawPass(style);
                  buffers = [this.frontBmp,this.backBmp,this.backBmp2,this.vodaBmp];
                  for each(surface in made)
                  {
                     worldClip = clip.intersection(new Rectangle(surface.x,surface.y,size,size));
                     if(!worldClip.isEmpty())
                     {
                        source = worldClip.clone();
                        source.offset(-this.sceneX,-this.sceneY);
                        point = new Point(worldClip.x - surface.x,worldClip.y - surface.y);
                        n = 0;
                        while(n < 4)
                        {
                           surface.nativeBuffers[n].copyPixels(buffers[n],source,point);
                           n++;
                        }
                     }
                  }
               }
            }
         }
         finally
         {
            for(field in original)
            {
               this.loc[field] = original[field];
            }
            this.sceneFinishBatch();
         }
      }
      
      private function sceneDrawSteps(param1:Location) : Array
      {
         var layer:int;
         var transpFon:Boolean = false;
         var darkness:int = 0;
         var tile:MovieClip = null;
         var t:Tile = null;
         var front:Sprite = null;
         var back:Sprite = null;
         var back2:Sprite = null;
         var voda:Sprite = null;
         var mat:Material = null;
         var gret:int = 0;
         var i:* = undefined;
         var e:* = undefined;
         var darkness2:* = undefined;
         var ct:ColorTransform = null;
         var j:* = undefined;
         var bo:BackObj = null;
         var nloc:Location = param1;
         var self:Grafon = this;
         var steps:Array = [];
         steps.push(function():void
         {
            self.loc = nloc;
            self.loc.grafon = self;
            self.resX = self.loc.spaceX * Tile.tileX;
            self.resY = self.loc.spaceY * Tile.tileY;
            transpFon = nloc.transpFon;
            if(nloc.backwall == "sky")
            {
               transpFon = true;
            }
         });
         steps.push(function():void
         {
            if(!self.sceneRepaint)
            {
               self.sceneConfigureBorders();
            }
         });
         steps.push(function():void
         {
            self.frontBmp.lock();
            self.backBmp.lock();
            self.backBmp2.lock();
            self.vodaBmp.lock();
            self.frontBmp.fillRect(self.allRect,0);
            self.backBmp.fillRect(self.allRect,0);
            self.backBmp2.fillRect(self.allRect,0);
            self.vodaBmp.fillRect(self.allRect,0);
            self.satsBmp.fillRect(self.allRect,0);
            if(!self.sceneRepaint)
            {
               self.lightBmp.fillRect(self.lightRect,4278190080);
               self.setLight();
            }
            darkness = 170 + self.loc.darkness;
            if(darkness > 255)
            {
               darkness = 255;
            }
            if(darkness < 0)
            {
               darkness = 0;
            }
            self.colorBmp.fillRect(self.allRect,darkness * 16777216);
            self.shadBmp.fillRect(self.allRect,4294967295);
         });
         steps.push(function():void
         {
            self.m = new Matrix();
            front = new Sprite();
            back = new Sprite();
            back2 = new Sprite();
            voda = new Sprite();
            for each(mat in self.arrFront)
            {
               mat.used = false;
            }
            for each(mat in self.arrBack)
            {
               mat.used = false;
            }
            gret = 0;
         });
         steps.push(function():void
         {
            i = Math.max(0,self.sceneX / Tile.tileX - 2);
            while(i < Math.min(self.loc.spaceX,(self.sceneX + self.rectX) / Tile.tileX + 2))
            {
               j = Math.max(0,self.sceneY / Tile.tileY - 2);
               while(j < Math.min(self.loc.spaceY,(self.sceneY + self.rectY) / Tile.tileY + 2))
               {
                  t = self.loc.getTile(i,j);
                  self.loc.tileKontur(i,j,t);
                  if(self.arrFront[t.front])
                  {
                     self.arrFront[t.front].used = true;
                  }
                  if(self.arrBack[t.back])
                  {
                     self.arrBack[t.back].used = true;
                  }
                  if(t.vid > 0)
                  {
                     tile = new tileFront();
                     tile.gotoAndStop(t.vid);
                     if(t.vRear)
                     {
                        back2.addChild(tile);
                     }
                     else
                     {
                        front.addChild(tile);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                  }
                  if(t.vid2 > 0)
                  {
                     tile = new tileFront();
                     tile.gotoAndStop(t.vid2);
                     if(t.v2Rear)
                     {
                        back2.addChild(tile);
                     }
                     else
                     {
                        front.addChild(tile);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                  }
                  if(t.water)
                  {
                     tile = new tileVoda();
                     tile.gotoAndStop(self.loc.tipWater + 1);
                     if(self.loc.getTile(i,j - 1).water == 0 && self.loc.getTile(i,j - 1).phis == 0)
                     {
                        tile.voda.gotoAndStop(2);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                     voda.addChild(tile);
                  }
                  j++;
               }
               i++;
            }
         });
         steps.push(function():void
         {
            self.vodaBmp.draw(voda,self.sceneMatrix(),null,null,null,false);
            self.frontBmp.draw(front,self.sceneMatrix(),null,null,null,false);
         });
         steps.push(function():void
         {
            self.drawBackWall(nloc.backwall,nloc.backform);
         });
         steps.push((function():Function
         {
            var remaining:Array = null;
            var next:int = 0;
            return function():Boolean
            {
               if(remaining == null)
               {
                  remaining = [];
                  for each(var material in self.arrFront)
                  {
                     if(material.used)
                     {
                        remaining.push(material);
                     }
                  }
               }
               if(next < remaining.length)
               {
                  self.drawKusok(remaining[next++],true);
               }
               return next >= remaining.length;
            };
         })());
         steps.push((function():Function
         {
            var remaining:Array = null;
            var next:int = 0;
            return function():Boolean
            {
               if(remaining == null)
               {
                  remaining = [];
                  for each(var material in self.arrBack)
                  {
                     if(material.used)
                     {
                        remaining.push(material);
                     }
                  }
               }
               if(next < remaining.length)
               {
                  self.drawKusok(remaining[next++],false);
               }
               return next >= remaining.length;
            };
         })());
         steps.push(function():void
         {
            self.satsBmp.copyChannel(self.backBmp,self.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            darkness2 = 1 - (255 - darkness) / 150;
            ct = new ColorTransform();
         });
         layer = -2;
         while(layer <= 3)
         {
            steps.push((function(layerId:int):Function
            {
               return function():void
               {
                  j = layerId;
                  if(j == -1)
                  {
                     self.backBmp.copyChannel(self.satsBmp,self.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
                  }
                  for each(bo in self.sceneBackdropObjects(self.sceneX,self.sceneY,self.rectX,self.rectY))
                  {
                     if(bo.sloy == j && !bo.er || j == -2 && bo.er)
                     {
                        self.m = new Matrix();
                        self.m.scale(bo.scX,bo.scY);
                        self.m.tx = bo.X;
                        self.m.ty = bo.Y;
                        ct.alphaMultiplier = bo.alpha;
                        if(bo.vis)
                        {
                           if(j <= 0)
                           {
                              ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                              self.backBmp.draw(bo.vis,self.sceneMatrix(self.m),ct,bo.blend,null,true);
                           }
                           else
                           {
                              if(bo.light)
                              {
                                 if(darkness2 >= 0.43)
                                 {
                                    ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                                 }
                                 else
                                 {
                                    ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 0.55 + darkness2;
                                 }
                              }
                              else
                              {
                                 ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = darkness2;
                              }
                              self.backBmp2.draw(bo.vis,self.sceneMatrix(self.m),ct,bo.blend,null,true);
                              if(bo.light)
                              {
                                 ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                              }
                              else
                              {
                                 ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = darkness2;
                              }
                           }
                        }
                        if(bo.erase)
                        {
                           self.satsBmp.draw(bo.erase,self.sceneMatrix(self.m),null,"erase",null,true);
                        }
                        if(bo.light)
                        {
                           self.colorBmp.draw(bo.light,self.sceneMatrix(self.m),ct,"normal",null,true);
                        }
                     }
                  }
               };
            })(layer));
            layer++;
         }
         steps.push(function():void
         {
            self.m = new Matrix();
            if(nloc.cTransform)
            {
               self.frontBmp.colorTransform(self.frontBmp.rect,nloc.cTransform);
               self.vodaBmp.colorTransform(self.vodaBmp.rect,nloc.cTransform);
            }
            self.shadBmp.applyFilter(self.frontBmp,self.frontBmp.rect,new Point(0,0),self.dsFilter);
         });
         steps.push(function():void
         {
            if(nloc.cTransform)
            {
               self.backBmp.colorTransform(self.backBmp.rect,nloc.cTransform);
               ct = new ColorTransform();
               darkness2 = 1 + (170 - darkness) / 33;
               ct.concat(nloc.cTransform);
               if(darkness2 > 1)
               {
                  ct.redMultiplier *= darkness2;
                  ct.greenMultiplier *= darkness2;
                  ct.blueMultiplier *= darkness2;
               }
               self.backBmp2.colorTransform(self.backBmp2.rect,ct);
            }
         });
         steps.push(function():void
         {
            self.backBmp2.draw(back,self.sceneMatrix(),nloc.cTransform,null,null,false);
         });
         steps.push(function():void
         {
            if(transpFon)
            {
               self.satsBmp.copyChannel(self.backBmp,self.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            }
            self.backBmp.draw(self.colorBmp,null,null,"hardlight");
            self.backBmp.draw(self.shadBmp);
            if(transpFon)
            {
               self.backBmp.copyChannel(self.satsBmp,self.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            }
         });
         steps.push(function():void
         {
            if(self.loc.gas > 0)
            {
               self.m = new Matrix();
               self.m.ty = 520;
               if(self.sceneRasterRegion != null)
               {
                  self.m.tx += self.sceneRasterRegion.bounds.x;
                  self.m.ty += self.sceneRasterRegion.bounds.y;
               }
               self.backBmp2.draw(self.getObj("back_pink_t",numbBack),self.sceneMatrix(self.m),new ColorTransform(1,1,1,0.3));
            }
         });
         steps.push((function():Function
         {
            var remaining:Array = null;
            var next:int = 0;
            return function():Boolean
            {
               if(remaining == null)
               {
                  remaining = [];
                  for each(var material in self.arrFront)
                  {
                     if(material.used)
                     {
                        remaining.push(material);
                     }
                  }
               }
               if(next < remaining.length)
               {
                  self.drawKusok(remaining[next++],false,true);
               }
               return next >= remaining.length;
            };
         })());
         steps.push(function():void
         {
            self.backBmp2.draw(back2,self.sceneMatrix(),nloc.cTransform,null,null,false);
         });
         steps.push(function():void
         {
            self.frontBmp.unlock();
            self.backBmp.unlock();
            self.backBmp2.unlock();
            self.vodaBmp.unlock();
         });
         steps.push(function():void
         {
            self.sceneRestoreMarks();
            ++self.sceneRedraws;
         });
         return steps;
      }
      
      private function sceneCancelWarm(affected:Rectangle = null) : void
      {
         var job:Object = this.sceneWarmJob;
         if(job == null)
         {
            return;
         }
         var support:Rectangle = job.bounds.clone();
         support.inflate(80,80);
         if(affected != null && !affected.intersects(support))
         {
            return;
         }
         this.sceneWarmJob = null;
         for each(var data in job.buffers)
         {
            data.unlock();
         }
         for each(data in job.output)
         {
            data.dispose();
         }
         job.steps = null;
      }
      
      private function sceneClearWarm() : void
      {
         this.sceneCancelWarm();
         if(this.sceneWarmBuffers)
         {
            for each(var data in this.sceneWarmBuffers)
            {
               data.dispose();
            }
         }
         this.sceneWarmBuffers = null;
      }
      
      private function sceneBeginWarm(cx:int, cy:int) : void
      {
         var size:int = this.sceneSide + 2 * this.sceneGutter;
         var bounds:Rectangle = new Rectangle(cx * this.sceneSide - this.sceneGutter,cy * this.sceneSide - this.sceneGutter,size,size);
         var original:Object = {};
         for each(var field in this.sceneWarmStyleFields)
         {
            original[field] = this.loc[field];
         }
         var originalKey:String = this.sceneRegionStyleKey(original);
         var groups:Array = [];
         var byKey:Object = {};
         var area:Number = 0;
         var inWorld:Rectangle = bounds.intersection(new Rectangle(0,0,this.loc.limX,this.loc.limY));
         for each(var slice in this.sceneRegionSlices(this.loc,bounds))
         {
            if(slice.style.key != originalKey)
            {
               var group:Object = byKey[slice.style.key];
               if(group == null)
               {
                  group = {
                     "style":slice.style,
                     "clips":[],
                     "area":0
                  };
                  byKey[slice.style.key] = group;
                  groups.push(group);
               }
               group.clips.push(slice.bounds);
               group.area += slice.bounds.width * slice.bounds.height;
               area += slice.bounds.width * slice.bounds.height;
            }
         }
         if(groups.length == 0)
         {
            groups.push({
               "style":original,
               "clips":[bounds]
            });
         }
         else if(groups.length == 1 && area == inWorld.width * inWorld.height)
         {
            groups[0].clips = [bounds];
         }
         else if(area == inWorld.width * inWorld.height)
         {
            groups[0].clips = [bounds];
         }
         else
         {
            groups.unshift({
               "style":original,
               "clips":[bounds]
            });
         }
         var job:Object = {
            "cx":cx,
            "cy":cy,
            "bounds":bounds,
            "buffers":[],
            "output":[],
            "groups":groups,
            "group":0,
            "steps":null,
            "at":0,
            "work":0,
            "cursor":new Dictionary(),
            "matrix":new Matrix(),
            "usedFront":[],
            "usedBack":[]
         };
         if(this.sceneWarmBuffers == null)
         {
            this.sceneWarmBuffers = [];
            var n:int = 0;
            while(n < 7)
            {
               this.sceneWarmBuffers.push(new BitmapData(size,size,true,0));
               n++;
            }
         }
         job.buffers = this.sceneWarmBuffers;
         n = 0;
         while(n < 4)
         {
            job.output.push(new BitmapData(size,size,true,0));
            n++;
         }
         this.sceneWarmJob = job;
      }
      
      private function sceneAdvanceWarm(force:Boolean = false) : void
      {
         var prior:Object;
         var style:Object;
         var usedFront:Array;
         var usedBack:Array;
         var field:String;
         var mat:Material;
         var n:int;
         var start:int;
         var complete:Boolean;
         var group:Object;
         var clip:Rectangle;
         var local:Rectangle;
         var elapsed:int;
         var reference:Object;
         var comparison:Object;
         var debugGroup:Object;
         var layerStats:Object;
         var actual:Vector.<uint>;
         var expected:Vector.<uint>;
         var p:int;
         var shift:int;
         var parents:Array;
         var bitmaps:Array;
         var bitmap:Bitmap;
         var job:Object = this.sceneWarmJob;
         if(job == null)
         {
            return;
         }
         prior = {};
         style = {};
         usedFront = [];
         usedBack = [];
         for each(field in this.sceneWarmFields)
         {
            prior[field] = this[field];
         }
         for each(field in this.sceneWarmStyleFields)
         {
            style[field] = this.loc[field];
         }
         for each(mat in this.arrFront)
         {
            if(mat.used)
            {
               usedFront.push(mat);
            }
            mat.used = false;
         }
         for each(mat in this.arrBack)
         {
            if(mat.used)
            {
               usedBack.push(mat);
            }
            mat.used = false;
         }
         for each(mat in job.usedFront)
         {
            mat.used = true;
         }
         for each(mat in job.usedBack)
         {
            mat.used = true;
         }
         start = int(getTimer());
         complete = false;
         if(force)
         {
            ++this.sceneWarmForced;
         }
         try
         {
            this.frontBmp = job.buffers[0];
            this.backBmp = job.buffers[1];
            this.backBmp2 = job.buffers[2];
            this.vodaBmp = job.buffers[3];
            this.satsBmp = job.buffers[4];
            this.colorBmp = job.buffers[5];
            this.shadBmp = job.buffers[6];
            this.rectX = this.rectY = job.bounds.width;
            this.allRect = new Rectangle(0,0,this.rectX,this.rectY);
            this.sceneScratch = job.buffers;
            this.sceneX = job.bounds.x;
            this.sceneY = job.bounds.y;
            this.sceneRasterizing = this.sceneRepaint = this.sceneRegionPassActive = true;
            this.sceneMaskCursor = job.cursor;
            this.m = job.matrix;
            while(force || getTimer() - start < this.sceneWarmBudget)
            {
               group = job.groups[job.group];
               for each(field in this.sceneWarmStyleFields)
               {
                  this.loc[field] = group.style[field];
               }
               this.sceneRasterRegion = group.style.nativeRegion ? group.style : null;
               if(job.steps == null)
               {
                  this.sceneMaskCursor = new Dictionary();
                  job.steps = this.sceneDrawSteps(this.loc);
                  job.at = 0;
                  ++this.sceneRegionPasses;
               }
               if(job.at < job.steps.length)
               {
                  if(job.steps[job.at].call(null) !== false)
                  {
                     ++job.at;
                  }
               }
               else
               {
                  for each(clip in group.clips)
                  {
                     local = clip.clone();
                     local.offset(-this.sceneX,-this.sceneY);
                     n = 0;
                     while(n < 4)
                     {
                        job.output[n].copyPixels(job.buffers[n],local,local.topLeft);
                        n++;
                     }
                  }
                  job.steps = null;
                  if(++job.group == job.groups.length)
                  {
                     complete = true;
                     break;
                  }
               }
            }
            job.cursor = this.sceneMaskCursor;
            job.matrix = this.m;
            job.usedFront = [];
            job.usedBack = [];
            for each(mat in this.arrFront)
            {
               if(mat.used)
               {
                  job.usedFront.push(mat);
               }
            }
            for each(mat in this.arrBack)
            {
               if(mat.used)
               {
                  job.usedBack.push(mat);
               }
            }
         }
         catch(error:*)
         {
            this.sceneCancelWarm();
            throw error;
         }
         finally
         {
            for each(field in this.sceneWarmFields)
            {
               this[field] = prior[field];
            }
            for each(field in this.sceneWarmStyleFields)
            {
               this.loc[field] = style[field];
            }
            for each(mat in this.arrFront)
            {
               mat.used = false;
            }
            for each(mat in this.arrBack)
            {
               mat.used = false;
            }
            for each(mat in usedFront)
            {
               mat.used = true;
            }
            for each(mat in usedBack)
            {
               mat.used = true;
            }
            World.w.gr_stage = 0;
         }
         elapsed = getTimer() - start;
         job.work += elapsed;
         ++this.sceneWarmSlices;
         this.sceneWarmMaxMs = Math.max(this.sceneWarmMaxMs,elapsed);
         if(!complete)
         {
            return;
         }
         if(this.sceneWarmVerify)
         {
            this.sceneRender(job.cx,job.cy);
            reference = this.sceneChunks[job.cx + ":" + job.cy];
            comparison = {
               "cx":job.cx,
               "cy":job.cy,
               "equal":true,
               "changed":0,
               "max":0,
               "layers":[],
               "groups":[]
            };
            for each(debugGroup in job.groups)
            {
               comparison.groups.push({
                  "key":this.sceneRegionStyleKey(debugGroup.style),
                  "clips":String(debugGroup.clips)
               });
            }
            n = 0;
            while(n < 4)
            {
               layerStats = {
                  "layer":n,
                  "changed":0,
                  "max":0,
                  "examples":[]
               };
               actual = job.output[n].getVector(job.output[n].rect);
               expected = reference.nativeBuffers[n].getVector(reference.nativeBuffers[n].rect);
               p = 0;
               while(p < actual.length)
               {
                  if(actual[p] != expected[p])
                  {
                     comparison.equal = false;
                     ++comparison.changed;
                     ++layerStats.changed;
                     if(layerStats.examples.length < 3)
                     {
                        layerStats.examples.push({
                           "x":p % job.bounds.width,
                           "y":int(p / job.bounds.width),
                           "actual":actual[p].toString(16),
                           "expected":expected[p].toString(16)
                        });
                     }
                     shift = 0;
                     while(shift <= 24)
                     {
                        layerStats.max = Math.max(layerStats.max,Math.abs((actual[p] >>> shift & 0xFF) - (expected[p] >>> shift & 0xFF)));
                        shift += 8;
                     }
                  }
                  p++;
               }
               comparison.max = Math.max(comparison.max,layerStats.max);
               comparison.layers.push(layerStats);
               n++;
            }
            this.sceneWarmComparisons.push(comparison);
            this.sceneDrop(reference);
            delete this.sceneChunks[job.cx + ":" + job.cy];
         }
         parents = [this.visFront,this.visBack,this.visBack2,this.visVoda];
         bitmaps = [];
         n = 0;
         while(n < 4)
         {
            bitmap = new Bitmap(job.output[n]);
            bitmap.scrollRect = new Rectangle(this.sceneGutter,this.sceneGutter,this.sceneSide,this.sceneSide);
            bitmap.x = job.cx * this.sceneSide;
            bitmap.y = job.cy * this.sceneSide;
            parents[n].addChild(bitmap);
            bitmaps.push(bitmap);
            n++;
         }
         this.sceneChunks[job.cx + ":" + job.cy] = {
            "cx":job.cx,
            "cy":job.cy,
            "bitmaps":bitmaps,
            "sats":null,
            "nativeBuffers":job.output,
            "revision":0,
            "backobjs":this.sceneBackdropObjects(job.bounds.x,job.bounds.y,job.bounds.width,job.bounds.height),
            "x":job.bounds.x,
            "y":job.bounds.y,
            "side":this.sceneSide,
            "gutter":this.sceneGutter
         };
         ++this.sceneResident;
         ++this.sceneWarmCount;
         this.sceneDrawMs = job.work;
         this.sceneMaxDrawMs = Math.max(this.sceneMaxDrawMs,job.work);
         this.sceneWarmMean = this.sceneWarmMean * 0.8 + Math.min(200,job.work) * 0.2;
         this.sceneWarmJob = null;
         this.sceneNextWarm = getTimer();
      }
      
      public function checkLoaded(param1:int) : *
      {
         var _loc2_:XML = null;
         if(param1 == 0)
         {
            this.arrFront = new Array();
            this.arrBack = new Array();
            for each(_loc2_ in AllData.d.mat)
            {
               if(_loc2_.@vid.length() == 0)
               {
                  if(_loc2_.@ed == "2")
                  {
                     this.arrBack[_loc2_.@id] = new Material(_loc2_);
                  }
                  else
                  {
                     this.arrFront[_loc2_.@id] = new Material(_loc2_);
                  }
               }
            }
         }
         this.resIsLoad = GrLoader.kolIsLoad >= GrLoader.kol;
      }
      
      public function allProgress() : *
      {
         var _loc1_:* = undefined;
         this.progressLoad = 0;
         for(_loc1_ in this.grLoaders)
         {
            this.progressLoad += this.grLoaders[_loc1_].progressLoad;
         }
         this.progressLoad /= GrLoader.kol;
      }
      
      internal function createCursors() : *
      {
         this.createCursor(visCurArrow,"arrow");
         this.createCursor(visCurTarget,"target",13,13);
         this.createCursor(visCurTarget1,"combat",13,13);
         this.createCursor(visCurTarget2,"action",13,13);
      }
      
      internal function createCursor(param1:Class, param2:String, param3:int = 0, param4:int = 0) : *
      {
         var _loc5_:Vector.<BitmapData> = null;
         var _loc6_:MouseCursorData = null;
         _loc5_ = new Vector.<BitmapData>();
         _loc5_.push(new param1());
         _loc6_ = new MouseCursorData();
         _loc6_.data = _loc5_;
         _loc6_.hotSpot = new Point(param3,param4);
         Mouse.registerCursor(param2,_loc6_);
      }
      
      public function getObj(param1:String, param2:int = 0) : *
      {
         return this.grLoaders[param2].res.getObj(param1);
      }
      
      public function drawFon(param1:MovieClip, param2:String) : *
      {
         if(param2 == "" || param2 == null)
         {
            param2 = "fonDefault";
         }
         if(Boolean(this.visFon) && param1.contains(this.visFon))
         {
            param1.removeChild(this.visFon);
         }
         this.visFon = this.getObj(param2);
         if(this.visFon)
         {
            param1.addChild(this.visFon);
         }
      }
      
      public function setFonSize(param1:Number, param2:Number) : *
      {
         var _loc3_:* = undefined;
         if(this.visFon)
         {
            if(!this.sceneLarge && param1 > this.rectX && param2 > this.rectY)
            {
               this.visFon.x = this.visual.x;
               this.visFon.y = this.visual.y;
               this.visFon.width = this.rectX;
               this.visFon.height = this.rectY;
            }
            else
            {
               _loc3_ = this.visFon.width / this.visFon.height;
               this.visFon.x = this.visFon.y = 0;
               if(param1 >= param2 * _loc3_)
               {
                  this.visFon.width = param1;
                  this.visFon.height = param1 / _loc3_;
               }
               else
               {
                  this.visFon.height = param2;
                  this.visFon.width = param2 * _loc3_;
               }
            }
         }
      }
      
      public function warShadow() : *
      {
         if(World.w.pers.infravis)
         {
            this.visLight.transform.colorTransform = this.infraTransform;
            this.visLight.blendMode = "multiply";
         }
         else
         {
            this.visLight.transform.colorTransform = this.defTransform;
            this.visLight.blendMode = "normal";
         }
      }
      
      public function drawLoc(param1:Location) : *
      {
         var sceneStarted:int;
         var transpFon:Boolean;
         var darkness:int;
         var tile:MovieClip;
         var t:Tile;
         var front:Sprite;
         var back:Sprite;
         var back2:Sprite;
         var voda:Sprite;
         var mat:Material;
         var gret:int;
         var i:*;
         var e:*;
         var darkness2:*;
         var ct:ColorTransform;
         var j:*;
         var bo:BackObj;
         var nloc:Location;
         if(!this.sceneRasterizing && (param1.spaceX > World.cellsX || param1.spaceY > World.cellsY))
         {
            this.sceneOpen(param1);
            return;
         }
         if(!this.sceneRasterizing)
         {
            this.rconnectRasterTicket = null;
         }
         sceneStarted = int(getTimer());
         this.scenePrepare(param1);
         transpFon = false;
         darkness = 0;
         tile = null;
         t = null;
         front = null;
         back = null;
         back2 = null;
         voda = null;
         mat = null;
         gret = 0;
         i = undefined;
         e = undefined;
         darkness2 = undefined;
         ct = null;
         j = undefined;
         bo = null;
         nloc = param1;
         try
         {
            World.w.gr_stage = 1;
            this.loc = nloc;
            this.loc.grafon = this;
            this.resX = this.loc.spaceX * Tile.tileX;
            this.resY = this.loc.spaceY * Tile.tileY;
            transpFon = nloc.transpFon;
            if(nloc.backwall == "sky")
            {
               transpFon = true;
            }
            World.w.gr_stage = 2;
            if(!this.sceneRepaint)
            {
               this.sceneConfigureBorders();
            }
            World.w.gr_stage = 3;
            this.frontBmp.lock();
            this.backBmp.lock();
            this.backBmp2.lock();
            this.vodaBmp.lock();
            this.frontBmp.fillRect(this.allRect,0);
            this.backBmp.fillRect(this.allRect,0);
            this.backBmp2.fillRect(this.allRect,0);
            this.vodaBmp.fillRect(this.allRect,0);
            this.satsBmp.fillRect(this.allRect,0);
            if(!this.sceneRepaint)
            {
               this.lightBmp.fillRect(this.lightRect,4278190080);
               this.setLight();
            }
            this.visLight.visible = this.loc.black && World.w.black;
            this.warShadow();
            darkness = 170 + this.loc.darkness;
            if(darkness > 255)
            {
               darkness = 255;
            }
            if(darkness < 0)
            {
               darkness = 0;
            }
            this.colorBmp.fillRect(this.allRect,darkness * 16777216);
            this.shadBmp.fillRect(this.allRect,4294967295);
            World.w.gr_stage = 4;
            this.m = new Matrix();
            front = new Sprite();
            back = new Sprite();
            back2 = new Sprite();
            voda = new Sprite();
            for each(mat in this.arrFront)
            {
               mat.used = false;
            }
            for each(mat in this.arrBack)
            {
               mat.used = false;
            }
            gret = 0;
            World.w.gr_stage = 5;
            i = Math.max(0,this.sceneX / Tile.tileX - 2);
            while(i < Math.min(this.loc.spaceX,(this.sceneX + this.rectX) / Tile.tileX + 2))
            {
               j = Math.max(0,this.sceneY / Tile.tileY - 2);
               while(j < Math.min(this.loc.spaceY,(this.sceneY + this.rectY) / Tile.tileY + 2))
               {
                  t = this.loc.getTile(i,j);
                  this.loc.tileKontur(i,j,t);
                  if(this.arrFront[t.front])
                  {
                     this.arrFront[t.front].used = true;
                  }
                  if(this.arrBack[t.back])
                  {
                     this.arrBack[t.back].used = true;
                  }
                  if(t.vid > 0)
                  {
                     tile = new tileFront();
                     tile.gotoAndStop(t.vid);
                     if(t.vRear)
                     {
                        back2.addChild(tile);
                     }
                     else
                     {
                        front.addChild(tile);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                  }
                  if(t.vid2 > 0)
                  {
                     tile = new tileFront();
                     tile.gotoAndStop(t.vid2);
                     if(t.v2Rear)
                     {
                        back2.addChild(tile);
                     }
                     else
                     {
                        front.addChild(tile);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                  }
                  if(t.water)
                  {
                     tile = new tileVoda();
                     tile.gotoAndStop(this.loc.tipWater + 1);
                     if(this.loc.getTile(i,j - 1).water == 0 && this.loc.getTile(i,j - 1).phis == 0)
                     {
                        tile.voda.gotoAndStop(2);
                     }
                     tile.x = i * Tile.tileX;
                     tile.y = j * Tile.tileY;
                     voda.addChild(tile);
                  }
                  j++;
               }
               i++;
            }
            World.w.gr_stage = 6;
            this.vodaBmp.draw(voda,this.sceneMatrix(),null,null,null,false);
            this.frontBmp.draw(front,this.sceneMatrix(),null,null,null,false);
            World.w.gr_stage = 7;
            this.drawBackWall(nloc.backwall,nloc.backform);
            World.w.gr_stage = 8;
            for each(mat in this.arrFront)
            {
               try
               {
                  this.drawKusok(mat,true);
               }
               catch(err:*)
               {
                  World.w.showError(err,"Ошибка рисования слоя " + mat.id);
               }
            }
            World.w.gr_stage = 9;
            for(e in this.arrBack)
            {
               try
               {
                  this.drawKusok(this.arrBack[e],false);
               }
               catch(err:*)
               {
                  World.w.showError(err,"Ошибка рисования слоя " + arrBack[e].id);
               }
            }
            World.w.gr_stage = 10;
            this.satsBmp.copyChannel(this.backBmp,this.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            darkness2 = 1 - (255 - darkness) / 150;
            ct = new ColorTransform();
            World.w.gr_stage = 11;
            j = -2;
            while(j <= 3)
            {
               if(j == -1)
               {
                  this.backBmp.copyChannel(this.satsBmp,this.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
               }
               for each(bo in this.sceneBackdropObjects(this.sceneX,this.sceneY,this.rectX,this.rectY))
               {
                  if(bo.sloy == j && !bo.er || j == -2 && bo.er)
                  {
                     this.m = new Matrix();
                     this.m.scale(bo.scX,bo.scY);
                     this.m.tx = bo.X;
                     this.m.ty = bo.Y;
                     ct.alphaMultiplier = bo.alpha;
                     if(bo.vis)
                     {
                        if(j <= 0)
                        {
                           ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                           this.backBmp.draw(bo.vis,this.sceneMatrix(this.m),ct,bo.blend,null,true);
                        }
                        else
                        {
                           if(bo.light)
                           {
                              if(darkness2 >= 0.43)
                              {
                                 ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                              }
                              else
                              {
                                 ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 0.55 + darkness2;
                              }
                           }
                           else
                           {
                              ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = darkness2;
                           }
                           this.backBmp2.draw(bo.vis,this.sceneMatrix(this.m),ct,bo.blend,null,true);
                           if(bo.light)
                           {
                              ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1;
                           }
                           else
                           {
                              ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = darkness2;
                           }
                        }
                     }
                     if(bo.erase)
                     {
                        this.satsBmp.draw(bo.erase,this.sceneMatrix(this.m),null,"erase",null,true);
                     }
                     if(bo.light)
                     {
                        this.colorBmp.draw(bo.light,this.sceneMatrix(this.m),ct,"normal",null,true);
                     }
                  }
               }
               j++;
            }
            World.w.gr_stage = 12;
            this.m = new Matrix();
            if(nloc.cTransform)
            {
               this.frontBmp.colorTransform(this.frontBmp.rect,nloc.cTransform);
               this.vodaBmp.colorTransform(this.vodaBmp.rect,nloc.cTransform);
            }
            this.shadBmp.applyFilter(this.frontBmp,this.frontBmp.rect,new Point(0,0),this.dsFilter);
            World.w.gr_stage = 13;
            if(nloc.cTransform)
            {
               this.backBmp.colorTransform(this.backBmp.rect,nloc.cTransform);
               ct = new ColorTransform();
               darkness2 = 1 + (170 - darkness) / 33;
               ct.concat(nloc.cTransform);
               if(darkness2 > 1)
               {
                  ct.redMultiplier *= darkness2;
                  ct.greenMultiplier *= darkness2;
                  ct.blueMultiplier *= darkness2;
               }
               this.backBmp2.colorTransform(this.backBmp2.rect,ct);
            }
            World.w.gr_stage = 14;
            this.backBmp2.draw(back,this.sceneMatrix(),nloc.cTransform,null,null,false);
            World.w.gr_stage = 15;
            if(transpFon)
            {
               this.satsBmp.copyChannel(this.backBmp,this.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            }
            this.backBmp.draw(this.colorBmp,null,null,"hardlight");
            this.backBmp.draw(this.shadBmp);
            if(transpFon)
            {
               this.backBmp.copyChannel(this.satsBmp,this.backBmp.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
            }
            World.w.gr_stage = 16;
            if(this.loc.gas > 0)
            {
               this.m = new Matrix();
               this.m.ty = 520;
               if(this.sceneRasterRegion != null)
               {
                  this.m.tx += this.sceneRasterRegion.bounds.x;
                  this.m.ty += this.sceneRasterRegion.bounds.y;
               }
               this.backBmp2.draw(this.getObj("back_pink_t",numbBack),this.sceneMatrix(this.m),new ColorTransform(1,1,1,0.3));
            }
            World.w.gr_stage = 17;
            for each(mat in this.arrFront)
            {
               this.drawKusok(mat,false,true);
            }
            this.backBmp2.draw(back2,this.sceneMatrix(),nloc.cTransform,null,null,false);
            World.w.gr_stage = 18;
            this.frontBmp.unlock();
            this.backBmp.unlock();
            this.backBmp2.unlock();
            this.vodaBmp.unlock();
            if(Boolean(nloc.cTransform) && Boolean(nloc.cTransformFon))
            {
               this.visFon.transform.colorTransform = nloc.cTransformFon;
            }
            else if(this.visFon.transform.colorTransform != this.defTransform)
            {
               this.visFon.transform.colorTransform = this.defTransform;
            }
         }
         catch(err:*)
         {
            World.w.showError(err);
         }
         World.w.gr_stage = 19;
         this.sceneRestoreMarks();
         if(!this.sceneRepaint)
         {
            this.drawAllObjs();
         }
         this.sceneDrawMs = getTimer() - sceneStarted;
         if(this.sceneLarge)
         {
            this.sceneMaxDrawMs = Math.max(this.sceneMaxDrawMs,this.sceneDrawMs);
         }
         ++this.sceneRedraws;
         World.w.gr_stage = 0;
      }
      
      public function setLight() : *
      {
         var _loc2_:* = undefined;
         this.lightBmp.lock();
         var _loc1_:* = 1;
         while(_loc1_ < this.loc.spaceX)
         {
            _loc2_ = 1;
            while(_loc2_ < this.loc.spaceY)
            {
               this.lightBmp.setPixel32(_loc1_,_loc2_ + 1,Math.floor((1 - this.loc.space[_loc1_][_loc2_].visi) * 255) * 16777216);
               _loc2_++;
            }
            _loc1_++;
         }
         this.lightBmp.unlock();
      }
      
      public function drawAllObjs() : *
      {
         var _loc3_:* = undefined;
         var _loc1_:* = 0;
         while(_loc1_ < this.kolObjs)
         {
            _loc3_ = this.visual.getChildIndex(this.visObjs[_loc1_]);
            this.visual.removeChild(this.visObjs[_loc1_]);
            this.visObjs[_loc1_] = new Sprite();
            this.visual.addChildAt(this.visObjs[_loc1_],_loc3_);
            _loc1_++;
         }
         var _loc2_:Pt = this.loc.firstObj;
         while(_loc2_)
         {
            _loc2_.addVisual();
            _loc2_ = _loc2_.nobj;
         }
         this.loc.gg.addVisual();
         for(_loc1_ in this.loc.signposts)
         {
            this.visObjs[3].addChild(this.loc.signposts[_loc1_]);
         }
      }
      
      public function drawBackWall(param1:String, param2:int = 0) : *
      {
         if(this.sceneNativeBackwall(param1,param2))
         {
            return;
         }
         if(param1 == "sky")
         {
            return;
         }
         this.m = new Matrix();
         var _loc3_:BitmapData = this.getObj(param1);
         if(_loc3_ == null)
         {
            _loc3_ = this.getObj("tBackWall");
         }
         var _loc4_:Sprite = new Sprite();
         _loc4_.graphics.beginBitmapFill(_loc3_);
         if(param2 == 0)
         {
            _loc4_.graphics.drawRect(0,0,this.kusokX * Tile.tileX,this.kusokY * Tile.tileY);
         }
         else if(param2 == 1)
         {
            _loc4_.graphics.drawRect(0,0,11 * Tile.tileX - 10,this.kusokY * Tile.tileY);
            _loc4_.graphics.drawRect(37 * Tile.tileX + 10,0,this.kusokX * Tile.tileX,this.kusokY * Tile.tileY);
         }
         else if(param2 == 2)
         {
            _loc4_.graphics.drawRect(0,16 * Tile.tileY + 10,this.kusokX * Tile.tileX,this.kusokY * Tile.tileY);
         }
         else if(param2 == 3)
         {
            _loc4_.graphics.drawRect(0,24 * Tile.tileY + 10,this.kusokX * Tile.tileX,this.kusokY * Tile.tileY);
         }
         this.backBmp.draw(_loc4_,this.sceneMatrix(this.m),null,null,null,false);
      }
      
      internal function setMCT(param1:MovieClip, param2:Tile, param3:Boolean) : *
      {
         if(param1.c1)
         {
            if(param3)
            {
               param1.c1.gotoAndStop(param2.kont1 + 1);
               param1.c2.gotoAndStop(param2.kont2 + 1);
               param1.c3.gotoAndStop(param2.kont3 + 1);
               param1.c4.gotoAndStop(param2.kont4 + 1);
            }
            else
            {
               param1.c1.gotoAndStop(param2.pont1 + 1);
               param1.c2.gotoAndStop(param2.pont2 + 1);
               param1.c3.gotoAndStop(param2.pont3 + 1);
               param1.c4.gotoAndStop(param2.pont4 + 1);
            }
         }
      }
      
      public function drawKusok(param1:Material, param2:Boolean, param3:Boolean = false) : *
      {
         var _loc4_:Tile = null;
         var _loc5_:MovieClip = null;
         var _loc15_:* = undefined;
         if(!param1.used)
         {
            return;
         }
         if(param1.rear == param2)
         {
            return;
         }
         var _loc6_:Sprite = new Sprite();
         var _loc7_:Sprite = new Sprite();
         var _loc8_:Sprite = new Sprite();
         var _loc9_:Sprite = new Sprite();
         var _loc10_:Sprite = new Sprite();
         var _loc11_:Sprite = new Sprite();
         var _loc12_:Sprite = new Sprite();
         if(param1.texture == null)
         {
            _loc7_.graphics.beginFill(6710886);
         }
         else if(this.loc.homeStable && param1.alttexture != null)
         {
            _loc7_.graphics.beginBitmapFill(param1.alttexture);
         }
         else
         {
            _loc7_.graphics.beginBitmapFill(param1.texture);
         }
         _loc7_.graphics.drawRect(Math.max(0,this.sceneX - 80),Math.max(0,this.sceneY - 80),this.rectX + 160,this.rectY + 160);
         _loc6_.addChild(_loc7_);
         _loc6_.addChild(_loc8_);
         if(param1.border)
         {
            _loc9_.graphics.beginBitmapFill(param1.border);
            _loc9_.graphics.drawRect(Math.max(0,this.sceneX - 80),Math.max(0,this.sceneY - 80),this.rectX + 160,this.rectY + 160);
            _loc6_.addChild(_loc9_);
            _loc6_.addChild(_loc10_);
         }
         if(param1.floor)
         {
            _loc11_.graphics.beginBitmapFill(param1.floor);
            _loc11_.graphics.drawRect(Math.max(0,this.sceneX - 80),Math.max(0,this.sceneY - 80),this.rectX + 160,this.rectY + 160);
            _loc6_.addChild(_loc11_);
            _loc6_.addChild(_loc12_);
         }
         var _loc13_:Boolean = false;
         var _loc14_:* = Math.max(0,this.sceneX / Tile.tileX - 2);
         while(_loc14_ < Math.min(this.loc.spaceX,(this.sceneX + this.rectX) / Tile.tileX + 2))
         {
            _loc15_ = Math.max(0,this.sceneY / Tile.tileY - 2);
            while(_loc15_ < Math.min(this.loc.spaceY,(this.sceneY + this.rectY) / Tile.tileY + 2))
            {
               _loc4_ = this.loc.getTile(_loc14_,_loc15_);
               if(_loc4_.front == param1.id && (param2 || param3) || _loc4_.back == param1.id && !param2)
               {
                  _loc13_ = true;
                  _loc5_ = this.sceneMask(param1.textureMask);
                  this.setMCT(_loc5_,_loc4_,param2);
                  _loc5_.x = (_loc14_ + 0.5) * Tile.tileX;
                  _loc5_.y = (_loc15_ + 0.5) * Tile.tileY;
                  _loc8_.addChild(_loc5_);
                  if(Boolean(_loc4_.zForm) && param2)
                  {
                     _loc5_.scaleY = (_loc4_.phY2 - _loc4_.phY1) / Tile.tileY;
                     _loc5_.y = (_loc4_.phY2 + _loc4_.phY1) / 2;
                  }
                  if(param1.borderMask)
                  {
                     _loc5_ = this.sceneMask(param1.borderMask);
                     this.setMCT(_loc5_,_loc4_,param2);
                     _loc5_.x = (_loc14_ + 0.5) * Tile.tileX;
                     _loc5_.y = (_loc15_ + 0.5) * Tile.tileY;
                     _loc10_.addChild(_loc5_);
                     if(Boolean(_loc4_.zForm) && param2)
                     {
                        _loc5_.scaleY = (_loc4_.phY2 - _loc4_.phY1) / Tile.tileY;
                        _loc5_.y = (_loc4_.phY2 + _loc4_.phY1) / 2;
                     }
                  }
                  if(param1.floorMask)
                  {
                     _loc5_ = this.sceneMask(param1.floorMask);
                     if(_loc5_.c1)
                     {
                        _loc5_.c1.gotoAndStop(_loc4_.kont1 + 1);
                        _loc5_.c2.gotoAndStop(_loc4_.kont2 + 1);
                     }
                     _loc12_.addChild(_loc5_);
                     _loc5_.x = (_loc14_ + 0.5) * Tile.tileX;
                     _loc5_.y = (_loc15_ + 0.5 + _loc4_.zForm / 4) * Tile.tileY;
                  }
               }
               _loc15_++;
            }
            _loc14_++;
         }
         if(!_loc13_)
         {
            return;
         }
         this.m.tx = 0;
         this.m.ty = 0;
         if(this.sceneLarge)
         {
            var scenePaintRect:Rectangle = new Rectangle(Math.max(0,this.sceneX - 80),Math.max(0,this.sceneY - 80),this.rectX + 160,this.rectY + 160);
            this.sceneMaterialFill(_loc7_,_loc8_,this.loc.homeStable && param1.alttexture != null ? param1.alttexture : param1.texture,scenePaintRect);
            if(param1.border)
            {
               this.sceneMaterialFill(_loc9_,_loc10_,param1.border,scenePaintRect);
            }
            if(param1.floor)
            {
               this.sceneMaterialFill(_loc11_,_loc12_,param1.floor,scenePaintRect);
            }
         }
         _loc7_.cacheAsBitmap = _loc8_.cacheAsBitmap = _loc9_.cacheAsBitmap = _loc10_.cacheAsBitmap = _loc11_.cacheAsBitmap = _loc12_.cacheAsBitmap = true;
         _loc7_.mask = _loc8_;
         _loc9_.mask = _loc10_;
         _loc11_.mask = _loc12_;
         if(param1.F)
         {
            _loc6_.filters = param1.F;
         }
         if(param2)
         {
            this.frontBmp.draw(_loc6_,this.sceneMatrix(this.m),null,null,null,false);
         }
         else if(param3)
         {
            this.backBmp2.draw(_loc6_,this.sceneMatrix(this.m),this.loc.cTransform,null,null,false);
         }
         else
         {
            this.backBmp.draw(_loc6_,this.sceneMatrix(this.m),null,null,null,false);
         }
         if(this.sceneLarge)
         {
            _loc7_.mask = null;
            _loc9_.mask = null;
            _loc11_.mask = null;
            _loc6_.filters = [];
            for each(var sceneLayer in [_loc7_,_loc8_,_loc9_,_loc10_,_loc11_,_loc12_])
            {
               sceneLayer.cacheAsBitmap = false;
               sceneLayer.graphics.clear();
               while(sceneLayer.numChildren > 0)
               {
                  sceneLayer.removeChildAt(sceneLayer.numChildren - 1);
               }
            }
            while(_loc6_.numChildren > 0)
            {
               _loc6_.removeChildAt(_loc6_.numChildren - 1);
            }
         }
      }
      
      public function getSpriteList(param1:String, param2:int = 0) : BitmapData
      {
         if(spriteLists[param1] == null)
         {
            if(param2 > 0)
            {
               spriteLists[param1] = this.getObj(param1,numbSprite + param2);
            }
            else
            {
               spriteLists[param1] = this.getObj(param1,numbSprite);
               if(spriteLists[param1] == null)
               {
                  spriteLists[param1] = this.getObj(param1,numbSprite + 1);
               }
            }
         }
         if(spriteLists[param1] == null)
         {
            trace("нет спрайтов",param1);
         }
         return spriteLists[param1];
      }
      
      public function drawSats() : *
      {
         if(this.sceneLarge)
         {
            this.sceneSats();
            return;
         }
         this.satsBmp.fillRect(this.satsBmp.rect,0);
         this.satsBmp.draw(this.visual,new Matrix());
      }
      
      public function onSats(param1:Boolean) : *
      {
         this.visSats.visible = param1;
         this.visObjs[2].visible = !param1;
      }
      
      public function drawWater(param1:Tile, param2:Boolean = true) : *
      {
         if(this.sceneLarge && !this.sceneRasterizing)
         {
            this.sceneApply("drawWater",[param1,param2]);
            return;
         }
         this.m = new Matrix();
         this.m.tx = param1.X * Tile.tileX;
         this.m.ty = param1.Y * Tile.tileY;
         this.voda.gotoAndStop(this.loc.tipWater + 1);
         if(this.loc.getTile(param1.X,param1.Y - 1).water == 0 && this.loc.getTile(param1.X,param1.Y - 1).phis == 0)
         {
            this.voda.voda.gotoAndStop(2);
         }
         else
         {
            this.voda.voda.gotoAndStop(1);
         }
         this.vodaBmp.draw(this.voda,this.sceneMatrix(this.m),this.loc.cTransform,param1.water > 0 ? "normal" : "erase",null,false);
         if(param2)
         {
            this.drawWater(this.loc.getTile(param1.X,param1.Y + 1),false);
         }
      }
      
      public function tileDie(param1:Tile, param2:int) : *
      {
         var _loc3_:Class = block_dyr;
         var _loc4_:Class = block_tre;
         var _loc5_:* = (param1.X + 0.5) * Tile.tileX;
         var _loc6_:* = (param1.Y + 0.5) * Tile.tileY;
         if(param1.fake)
         {
            Emitter.emit("fake",this.loc,_loc5_,_loc6_);
            _loc4_ = block_bur;
         }
         else if(param1.mat == 7)
         {
            Emitter.emit("fake",this.loc,_loc5_,_loc6_);
            Emitter.emit("pole",this.loc,_loc5_,_loc6_,{
               "kol":10,
               "rx":Tile.tileX,
               "ry":Tile.tileY
            });
            _loc3_ = TileMask;
            _loc4_ = null;
         }
         else if(param2 < 10)
         {
            if(param1.mat == 1)
            {
               Emitter.emit("metal",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
            else if(param1.mat == 2)
            {
               Emitter.emit("kusok",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
            else if(param1.mat == 3)
            {
               Emitter.emit("schep",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
            else if(param1.mat == 4)
            {
               Emitter.emit("kusokB",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
            else if(param1.mat == 5)
            {
               Emitter.emit("steklo",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
            else if(param1.mat == 6)
            {
               Emitter.emit("kusokD",this.loc,_loc5_,_loc6_,{
                  "kol":6,
                  "rx":Tile.tileX,
                  "ry":Tile.tileY
               });
            }
         }
         else if(param2 >= 15)
         {
            Emitter.emit("plav",this.loc,_loc5_,_loc6_);
            _loc3_ = block_plav;
            _loc4_ = block_pla;
         }
         else if(param2 >= 11 && param2 <= 13)
         {
            Emitter.emit("bur",this.loc,_loc5_,_loc6_);
            _loc4_ = block_bur;
         }
         this.decal(_loc3_,_loc4_,_loc5_,_loc6_,1,0,"hardlight");
      }
      
      public function dyrka(param1:int, param2:int, param3:int, param4:int, param5:Boolean = false, param6:Number = 1) : *
      {
         var _loc7_:Class = null;
         var _loc8_:Class = null;
         var _loc9_:String = "normal";
         var _loc10_:Boolean = false;
         var _loc11_:* = Math.random() * 0.5 + 0.5;
         var _loc12_:* = Math.random() * 360;
         if(param3 == 0 || param4 == 0)
         {
            return;
         }
         if(param4 == 1)
         {
            if(param3 >= 1 && param3 <= 6)
            {
               _loc8_ = bullet_metal;
            }
            else if(param3 == 9)
            {
               if(!param5 && Math.random() * 0.5 < param6)
               {
                  _loc8_ = metal_tre;
               }
               _loc10_ = true;
            }
         }
         else if(param4 == 2 || param4 == 4 || param4 == 6)
         {
            if(param3 >= 1 && param3 <= 3)
            {
               if(param3 > 1 && Math.random() > 0.5)
               {
                  _loc7_ = bullet_dyr;
               }
               _loc8_ = bullet_tre;
               if(param3 == 2)
               {
                  _loc11_ += 0.5;
               }
               if(param3 == 3)
               {
                  _loc11_ += 1;
               }
            }
            else if(param3 >= 4 && param3 <= 6)
            {
               if(!param5)
               {
                  _loc8_ = punch_tre;
               }
               if(param3 == 5)
               {
                  _loc11_ += 0.5;
               }
               if(param3 == 6)
               {
                  _loc11_ += 1;
               }
            }
            else if(param3 == 9)
            {
               if(!param5 && Math.random() * 0.5 < param6)
               {
                  _loc8_ = expl_tre;
               }
               _loc10_ = true;
            }
            if(param3 < 10 && !param5)
            {
               if(param4 == 2)
               {
                  Emitter.emit("kusoch",this.loc,param1,param2,{"kol":3});
               }
               else
               {
                  Emitter.emit("kusochB",this.loc,param1,param2,{"kol":3});
               }
            }
         }
         else if(param4 == 3)
         {
            if(param3 >= 1 && param3 <= 3)
            {
               _loc7_ = bullet_dyr;
               _loc8_ = bullet_wood;
               _loc12_ = 0;
               if(param3 == 2)
               {
                  _loc11_ += 0.5;
               }
               if(param3 == 3)
               {
                  _loc11_ += 1;
               }
            }
            else if(param3 >= 4 && param3 <= 6)
            {
               if(!param5)
               {
                  _loc8_ = punch_tre;
               }
               if(param3 == 5)
               {
                  _loc11_ += 0.5;
               }
               if(param3 == 6)
               {
                  _loc11_ += 1;
               }
            }
            else if(param3 == 9)
            {
               if(!param5 && Math.random() * 0.5 < param6)
               {
                  _loc8_ = expl_tre;
               }
               _loc10_ = true;
            }
            if(param3 < 10 && !param5)
            {
               Emitter.emit("schepoch",this.loc,param1,param2,{"kol":3});
            }
         }
         else if(param4 == 7)
         {
            Emitter.emit("pole",this.loc,param1,param2,{"kol":5});
         }
         if(param3 == 11)
         {
            if(Math.random() < 0.1)
            {
               _loc8_ = fire_soft;
            }
         }
         else if(param3 == 12 || param3 == 13)
         {
            if(param5 && Math.random() * 0.2 > param6)
            {
               _loc8_ = fire_soft;
            }
            else
            {
               _loc8_ = laser_tre;
            }
            if(param3 == 13)
            {
               _loc11_ *= 0.6;
            }
            _loc9_ = "hardlight";
         }
         else if(param3 == 15)
         {
            if(param5)
            {
               _loc8_ = plasma_soft;
            }
            else
            {
               _loc7_ = plasma_dyr;
               _loc8_ = plasma_tre;
            }
            _loc9_ = "hardlight";
         }
         else if(param3 == 16)
         {
            if(param5)
            {
               _loc8_ = fire_soft;
            }
            else
            {
               _loc7_ = plasma_dyr;
               _loc8_ = bluplasma_tre;
            }
            _loc9_ = "hardlight";
         }
         else if(param3 == 17)
         {
            if(param5)
            {
               _loc8_ = fire_soft;
            }
            else
            {
               _loc7_ = plasma_dyr;
               _loc8_ = pinkplasma_tre;
            }
            _loc9_ = "hardlight";
         }
         else if(param3 == 18)
         {
            _loc8_ = cryo_soft;
            _loc9_ = "hardlight";
         }
         else if(param3 == 19)
         {
            if(!param5 && Math.random() * 0.5 < param6)
            {
               _loc8_ = plaexpl_tre;
            }
            _loc10_ = true;
         }
         this.decal(_loc7_,_loc8_,param1,param2,_loc11_,_loc12_,_loc9_);
      }
      
      public function decal(param1:Class, param2:Class, param3:Number, param4:Number, param5:Number = 1, param6:Number = 0, param7:String = "normal") : *
      {
         if(this.sceneLarge && !this.sceneRasterizing)
         {
            this.sceneApply("decal",[param1,param2,param3,param4,param5,param6,param7]);
            return;
         }
         param3 -= this.sceneX;
         param4 -= this.sceneY;
         var _loc8_:MovieClip = null;
         var _loc9_:MovieClip = null;
         var _loc10_:* = undefined;
         var _loc11_:* = undefined;
         var _loc12_:BitmapData = null;
         var _loc13_:* = undefined;
         var _loc14_:* = undefined;
         var _loc15_:Rectangle = null;
         var _loc16_:Point = null;
         this.m = new Matrix();
         if(param5 != 1)
         {
            this.m.scale(param5,param5);
         }
         if(param6 != 0)
         {
            this.m.rotate(param6);
         }
         this.m.tx = param3;
         this.m.ty = param4;
         if(param1)
         {
            _loc8_ = new param1();
            if(_loc8_.totalFrames > 1)
            {
               _loc8_.gotoAndStop(Math.floor((this.sceneStamp != null ? Number(this.sceneStamp[0]) : Math.random()) * _loc8_.totalFrames + 1));
            }
            this.frontBmp.draw(_loc8_,this.m,null,"erase",null,true);
         }
         if(param2)
         {
            _loc9_ = new param2();
            if(_loc9_.totalFrames > 1)
            {
               _loc9_.gotoAndStop(Math.floor((this.sceneStamp != null ? Number(this.sceneStamp[1]) : Math.random()) * _loc9_.totalFrames + 1));
            }
            _loc9_.scaleX = _loc9_.scaleY = param5;
            _loc9_.rotation = param6;
            _loc10_ = Math.round(_loc9_.width / 2 + 2) * 2;
            _loc11_ = Math.round(_loc9_.height / 2 + 2) * 2;
            if(this.sceneLarge)
            {
               this.sceneDecalPaint(_loc9_,param3 + this.sceneX,param4 + this.sceneY,int(_loc10_),int(_loc11_),param7);
               return;
            }
            _loc12_ = new BitmapData(_loc10_,_loc11_,false,0);
            _loc13_ = 0;
            _loc14_ = 0;
            if(param3 - _loc10_ / 2 < 0)
            {
               _loc13_ = -(param3 - _loc10_ / 2);
            }
            if(param4 - _loc11_ / 2 < 0)
            {
               _loc14_ = -(param4 - _loc11_ / 2);
            }
            _loc15_ = new Rectangle(param3 - _loc10_ / 2 + _loc13_,param4 - _loc11_ / 2 + _loc14_,param3 + _loc10_ / 2 + _loc13_,param4 + _loc11_ / 2 + _loc14_);
            _loc16_ = new Point(0,0);
            _loc12_.copyChannel(this.frontBmp,_loc15_,_loc16_,BitmapDataChannel.ALPHA,BitmapDataChannel.GREEN);
            this.frontBmp.draw(_loc9_,this.m,param7 == "normal" ? World.w.loc.cTransform : null,param7,null,true);
            _loc15_ = new Rectangle(0,0,_loc10_,_loc11_);
            _loc16_ = new Point(param3 - _loc10_ / 2 + _loc13_,param4 - _loc11_ / 2 + _loc14_);
            this.frontBmp.copyChannel(_loc12_,_loc15_,_loc16_,BitmapDataChannel.GREEN,BitmapDataChannel.ALPHA);
         }
      }
      
      public function gwall(param1:int, param2:int) : *
      {
         if(this.sceneLarge && !this.sceneRasterizing)
         {
            this.sceneApply("gwall",[param1,param2]);
            return;
         }
         var _loc3_:Matrix = new Matrix();
         _loc3_.tx = param1 * Tile.tileX;
         _loc3_.ty = param2 * Tile.tileY;
         var _loc4_:MovieClip = new tileGwall();
         this.frontBmp.draw(_loc4_,this.sceneMatrix(_loc3_));
      }
      
      public function paint(param1:int, param2:int, param3:int, param4:int, param5:Boolean = false) : *
      {
         if(this.sceneLarge && !this.sceneRasterizing)
         {
            this.sceneApply("paint",[param1,param2,param3,param4,param5]);
            return;
         }
         param1 -= this.sceneX;
         param3 -= this.sceneX;
         param2 -= this.sceneY;
         param4 -= this.sceneY;
         if(this.sceneLarge && (Math.max(param1,param3) < -50 || Math.max(param2,param4) < -50 || Math.min(param1,param3) > this.rectX + 50 || Math.min(param2,param4) > this.rectY + 50))
         {
            return;
         }
         var _loc6_:MovieClip = null;
         var _loc11_:int = 0;
         var _loc12_:int = 0;
         var _loc13_:int = 0;
         var _loc14_:int = 0;
         if(param5)
         {
            _loc6_ = this.pa;
         }
         else
         {
            _loc6_ = this.pb;
         }
         var _loc7_:Number = Math.sqrt((param3 - param1) * (param3 - param1) + (param4 - param2) * (param4 - param2));
         var _loc8_:int = Math.ceil(_loc7_ / 3);
         var _loc9_:Number = (param3 - param1) / _loc8_;
         var _loc10_:Number = (param4 - param2) / _loc8_;
         if(param1 < param3)
         {
            _loc11_ = param1 - 25;
            _loc12_ = param3 + 25;
         }
         else
         {
            _loc11_ = param3 - 25;
            _loc12_ = param1 + 25;
         }
         if(param2 < param4)
         {
            _loc13_ = param2 - 25;
            _loc14_ = param4 + 25;
         }
         else
         {
            _loc13_ = param4 - 25;
            _loc14_ = param2 + 25;
         }
         this.brPoint.x = 0;
         this.brPoint.y = 0;
         this.brRect.left = _loc11_;
         this.brRect.right = _loc12_;
         this.brRect.top = _loc13_;
         this.brRect.bottom = _loc14_;
         this.brData.copyChannel(this.backBmp,this.brRect,this.brPoint,BitmapDataChannel.ALPHA,BitmapDataChannel.GREEN);
         var _loc15_:* = 1;
         while(_loc15_ <= _loc8_)
         {
            this.pm.tx = param1 + _loc9_ * _loc15_;
            this.pm.ty = param2 + _loc10_ * _loc15_;
            this.backBmp.draw(_loc6_,this.pm,this.brTrans,"normal",null,false);
            _loc15_++;
         }
         this.brPoint.x = _loc11_;
         this.brPoint.y = _loc13_;
         this.brRect.left = 0;
         this.brRect.right = _loc12_ - _loc11_;
         this.brRect.top = 0;
         this.brRect.bottom = _loc14_ - _loc13_;
         this.backBmp.copyChannel(this.brData,this.brRect,this.brPoint,BitmapDataChannel.GREEN,BitmapDataChannel.ALPHA);
      }
      
      public function specEffect(param1:Number = 0) : *
      {
         if(param1 == 0)
         {
            this.visual.filters = [];
            this.visFon.filters = [];
         }
         else if(param1 == 1)
         {
            this.visual.filters = [new ColorMatrixFilter([2,-0.9,-0.1,0,0,-0.4,1.5,-0.1,0,0,-0.4,-0.9,2,0,0,0,0,0,1,0])];
         }
         else if(param1 == 2)
         {
            this.visual.filters = [new ColorMatrixFilter([-0.574,1.43,0.144,0,0,0.426,0.43,0.144,0,0,0.426,1.43,-0.856,0,0,0,0,0,1,0])];
         }
         else if(param1 == 3)
         {
            this.visual.filters = [new ColorMatrixFilter([0,1,0,0,0,1,0,0,0,0,0,0,-0.2,0,100,0,0,0,1,0])];
         }
         else if(param1 == 4)
         {
            this.visual.filters = [new ColorMatrixFilter([0,-0.5,-0.5,0,255,-0.5,0,-0.5,0,255,-0.5,-0.5,0,0,255,0,0,0,1,0])];
         }
         else if(param1 == 5)
         {
            this.visual.filters = [new ColorMatrixFilter([3.4,6.7,0.9,0,-635,3.4,6.75,0.9,0,-635,3.4,6.7,0.9,0,-635,0,0,0,1,0])];
         }
         else if(param1 == 6)
         {
            this.visual.filters = [new ColorMatrixFilter([0.33,0.33,0.33,0,0,0.33,0.33,0.33,0,0,0.33,0.33,0.33,0,0,0,0,0,1,0])];
         }
         else if(param1 > 100)
         {
            this.visual.filters = [new BlurFilter(param1 - 100,param1 - 100)];
            this.visFon.filters = [new BlurFilter(param1 - 100,param1 - 100)];
         }
      }
   }
}

