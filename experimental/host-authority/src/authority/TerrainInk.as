package authority {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   /** Native bullet holes, burns and blood are baked into room bitmaps.
    * Observe only changed 64px blocks; no full-screen or per-frame bitmap scan. */
   public final class TerrainInk {
      private static const SIZE:int=64;
      private var rooms:Dictionary=new Dictionary(true),received:Dictionary=new Dictionary(true);
      public var captures:uint=0,applications:uint=0;
      public function TerrainInk(access:NativeAccess) {
         var Grafon:Class=access.definition("fe.graph.Grafon");
         if(Grafon["rconnectInk"]!=null)throw new Error("Native terrain ink seam occupied");
         Grafon["rconnectInk"]=changed;
      }
      private function record(grafon:Object):Object {
         var value:Object=rooms[grafon];
         if(value==null)value=rooms[grafon]={epoch:0,front:{},back:{},dirty:{front:{},back:{}},surfaces:{},snapshot:null};
         return value;
      }
      private function changed(grafon:Object,layer:String,surface:BitmapData,rect:Rectangle=null,clip:DisplayObject=null,matrix:Matrix=null):void {
         if(layer=="reset") {
            var old:Object=rooms[grafon];
            rooms[grafon]={epoch:old==null?1:old.epoch+1,front:{},back:{},dirty:{front:{},back:{}},surfaces:{},snapshot:null};return;
         }
         if(layer!="front" && layer!="back")throw new Error("Unknown native ink layer");
         if(surface==null)return;
         if(rect==null) {
            if(clip==null || matrix==null)return;
            var bounds:Rectangle=clip.getBounds(clip),a:Point=matrix.transformPoint(bounds.topLeft),b:Point=matrix.transformPoint(bounds.bottomRight);
            var c:Point=matrix.transformPoint(new Point(bounds.left,bounds.bottom)),d:Point=matrix.transformPoint(new Point(bounds.right,bounds.top));
            var left:Number=Math.min(a.x,b.x,c.x,d.x)-2,top:Number=Math.min(a.y,b.y,c.y,d.y)-2;
            rect=new Rectangle(left,top,Math.max(a.x,b.x,c.x,d.x)+2-left,Math.max(a.y,b.y,c.y,d.y)+2-top);
         }
         rect=rect.intersection(surface.rect);if(rect.isEmpty())return;
         var rec:Object=record(grafon);rec.surfaces[layer]=surface;
         for(var x:int=int(rect.left/SIZE);x<=int((Math.ceil(rect.right)-1)/SIZE);x++)
            for(var y:int=int(rect.top/SIZE);y<=int((Math.ceil(rect.bottom)-1)/SIZE);y++)rec.dirty[layer][x+":"+y]={x:x*SIZE,y:y*SIZE};
      }
      public function snapshot(grafon:Object):Object {
         var rec:Object=record(grafon),changedAny:Boolean=rec.snapshot==null;
         for each(var layer:String in ["front","back"]) {
            var next:Object=null;
            for(var key:String in rec.dirty[layer]) {
               if(next==null)next=PoseTween.copy(rec[layer]);
               var at:Object=rec.dirty[layer][key],surface:BitmapData=rec.surfaces[layer];
               var area:Rectangle=new Rectangle(at.x,at.y,Math.min(SIZE,surface.width-at.x),Math.min(SIZE,surface.height-at.y));
               var block:BitmapData=new BitmapData(area.width,area.height,true,0);
               try {block.copyPixels(surface,area,new Point());next[key]={x:at.x,y:at.y,pixels:PixelSurface.capture(block)};}
               finally {block.dispose();}
               ++captures;
            }
            if(next!=null){rec[layer]=next;changedAny=true;rec.dirty[layer]={};}
         }
         if(changedAny)rec.snapshot={epoch:rec.epoch,front:rec.front,back:rec.back};
         return rec.snapshot;
      }
      public function needsRedraw(grafon:Object,state:Object):Boolean {
         var prior:Object=received[grafon];return prior!=null && state!=null && prior.epoch!=state.epoch;
      }
      public function apply(grafon:Object,state:Object,rebuilt:Boolean):void {
         if(state==null)return;
         var prior:Object=received[grafon];
         for each(var layer:String in ["front","back"]) {
            var surface:BitmapData=grafon.rconnectSurface(layer);
            for(var key:String in state[layer]) {
               var block:Object=state[layer][key];
               if(!rebuilt && prior!=null && prior[layer][key]===block)continue;
               var restored:BitmapData=PixelSurface.restore(block.pixels);
               try {surface.copyPixels(restored,restored.rect,new Point(block.x,block.y));}
               finally {restored.dispose();}
               ++applications;
            }
         }
         received[grafon]=state;
      }
      public function reset():void {rooms=new Dictionary(true);received=new Dictionary(true);}
   }
}
