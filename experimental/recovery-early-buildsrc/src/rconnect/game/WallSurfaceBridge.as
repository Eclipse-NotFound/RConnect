package rconnect.game
{
   import flash.display.BitmapData;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;

   /** Local native paint observations, never a room/chunk-sized persistent shadow.
    * The host supplies the ACTUAL composited pass clips. Native mark identity
    * prevents a reconstructed older local decal from undoing a peer's newer ink. */
   public final class WallSurfaceBridge
   {
      private var changed:Function, raster:Function, born:Function;
      private var marks:Dictionary=new Dictionary(true);
      private var lifetimes:Dictionary=new Dictionary(true);
      private var generation:uint=0;
      private var hostType:Object,listener:Function,enabled:Boolean=false;
      public function WallSurfaceBridge(changed:Function,raster:Function,born:Function,main:Object=null)
      {
         this.changed=changed;this.raster=raster;this.born=born;
         listener=onNative;
         if(main!=null)try {
            var type:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
            if("rconnectWallBridge" in type)hostType=type;
         }catch(unavailable:*) {} // Older hosts retain ordinary-room support.
      }
      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      public function set networkActive(value:Boolean):void
      {
         if(enabled==value)return;
         enabled=value;reset();
         if(hostType==null)return;
         // Disabling an older bridge must never clear a later owner's callback.
         if(value)hostType.rconnectWallBridge=listener;
         else if(hostType.rconnectWallBridge===listener)hostType.rconnectWallBridge=null;
      }
      public function reset():void {marks=new Dictionary(true);lifetimes=new Dictionary(true);generation++;}
      public function restored(loc:Object):void {lifetimes[loc]={};}
      private static function cut(source:Array,r:Rectangle):Array
      {
         var out:Array=[];
         for each(var a:Rectangle in source) {
            var i:Rectangle=a.intersection(r);
            if(i.isEmpty()){out.push(a);continue;}
            if(i.top>a.top)out.push(new Rectangle(a.x,a.y,a.width,i.top-a.top));
            if(i.bottom<a.bottom)out.push(new Rectangle(a.x,i.bottom,a.width,a.bottom-i.bottom));
            if(i.left>a.left)out.push(new Rectangle(a.x,i.y,i.left-a.left,i.height));
            if(i.right<a.right)out.push(new Rectangle(i.right,i.y,a.right-i.right,i.height));
         }
         return out;
      }
      private static function areas(b:BitmapData,ox:int,oy:int,affected:Rectangle,clips:Array):Array
      {
         var bounds:Rectangle=new Rectangle(ox,oy,b.width,b.height);
         if(affected!=null)bounds=bounds.intersection(affected);
         if(bounds.isEmpty())return [];
         bounds=new Rectangle(Math.floor(bounds.x),Math.floor(bounds.y),Math.ceil(bounds.right)-Math.floor(bounds.x),Math.ceil(bounds.bottom)-Math.floor(bounds.y));
         if(clips==null)return [bounds];
         var result:Array=[];
         for each(var clip:Rectangle in clips) {
            var r:Rectangle=bounds.intersection(clip);
            if(!r.isEmpty())result.push(r);
         }
         return result;
      }
      /** Signature is private to the isolated Grafon bridge; no wire changes. */
      private function onNative(kind:String,g:Object,loc:Object,b:BitmapData,ox:int,oy:int,
         affected:Rectangle,mark:Object,token:Object,clips:Array):Object
      {
         if(!enabled || g==null || loc==null || get(g,"loc")!==loc || get(g,"sceneLarge")!==true)return null;
         if(kind=="mark") {
            if(lifetimes[loc]==null)lifetimes[loc]={};
            // No loc/mark reference in the weak value: loc -> native history
            // -> mark would otherwise keep the supposedly weak key alive.
            if(mark!=null && marks[mark]==null)marks[mark]={life:lifetimes[loc],covered:[],order:born()};
            return null;
         }
         if(kind=="raster") {
            if(b!=null)raster(loc,b,ox,oy,clips);
            return null;
         }
         if(kind=="before") {
            var entry:Object=marks[mark];
            // Only marks born while this bridge was active are local changes.
            // Unknown saved/native history is baseline, not a new network hit.
            if(entry==null || entry.life!==lifetimes[loc] || b==null || affected==null)return null;
            var pieces:Array=[],regions:Array=areas(b,ox,oy,affected,clips);
            for each(var r:Rectangle in regions) {
               var pending:Array=[r];
               for each(var covered:Rectangle in entry.covered)pending=cut(pending,covered);
               for each(var part:Rectangle in pending) {
                  var local:Rectangle=part.clone();local.offset(-ox,-oy);
                  pieces.push({world:part,local:local,words:b.getVector(local)});
               }
            }
            return pieces.length?{epoch:generation,loc:loc,bitmap:b,entry:entry,pieces:pieces}:null;
         }
         if(kind=="after") {
            if(token==null || token.epoch!==generation || token.loc!==loc || token.bitmap!==b || token.entry.life!==lifetimes[loc])return null;
            var cells:Object={};
            for each(var piece:Object in token.pieces) {
               var fresh:Vector.<uint>=b.getVector(piece.local),old:Vector.<uint>=piece.words;
               var width:int=int(piece.world.width);
               for(var i:int=0;i<fresh.length;i++)if(fresh[i]!=old[i]) {
                  var x:int=int(piece.world.x)+i%width,y:int=int(piece.world.y)+int(i/width);
                  if(x<0 || y<0 || x>=int(loc.spaceX)*40 || y>=int(loc.spaceY)*40)continue;
                  var tx:int=int(x/40),ty:int=int(y/40),key:String=tx+","+ty;
                  var c:Object=cells[key];if(c==null)c=cells[key]={x:tx,y:ty,values:{}};
                  c.values[String((y%40)*40+x%40)]=fresh[i];
               }
               token.entry.covered.push(piece.world);
               piece.words=null;
            }
            changed(loc,cells,Number(token.entry.order));
         }
         return null;
      }
      public function surfaces(loc:Object):Array
      {
         var g:Object=get(loc,"grafon");
         if(loc==null || get(g,"loc")!==loc || get(g,"sceneLarge")!==true || get(g,"rconnectRasterPending")===true)return null;
         try{return g.sceneSurfaces() as Array;}catch(unavailable:*){}return null;
      }
      /** Each cell carries only accepted sparse pixels (prediction mask applied).
       * A gutter pixel is written to every overlapping resident buffer. */
      public function paint(loc:Object,list:Array):Boolean
      {
         var resident:Array=surfaces(loc);if(resident==null)return false;
         var any:Boolean=false;
         for each(var s:Object in resident) {
            var b:BitmapData=s.nativeBuffers[0] as BitmapData;if(b==null)continue;
            var wrote:Boolean=false; b.lock();
            try {
               for each(var c:Object in list) {
                  var cx:int=int(c.x)*40-int(s.x),cy:int=int(c.y)*40-int(s.y);
                  if(cx>=b.width || cy>=b.height || cx+40<=0 || cy+40<=0)continue;
                  for(var i:int=0;i<c.words.length;i+=2) {
                     var index:int=int(c.words[i]),x:int=cx+index%40,y:int=cy+int(index/40);
                     if(x<0 || y<0 || x>=b.width || y>=b.height)continue;
                     var color:uint=uint(c.words[i+1]);
                     if(b.getPixel32(x,y)!=color){b.setPixel32(x,y,color);wrote=true;}
                  }
               }
            }finally{b.unlock();}
            if(wrote){s.revision=int(s.revision)+1;any=true;}
         }
         return any;
      }
      /** Reapply retained logical pixels to the actual raster pass BEFORE its
       * output is copied/cloned into a new chunk, including async warm groups. */
      public function replay(loc:Object,b:BitmapData,ox:int,oy:int,cells:Object,clips:Array):Boolean
      {
         var regions:Array=areas(b,ox,oy,null,clips),wrote:Boolean=false;
         b.lock();
         try {
            for each(var c:Object in cells) {
               if(int(c.x)<0 || int(c.y)<0 || int(c.x)>=int(loc.spaceX) || int(c.y)>=int(loc.spaceY))continue;
               if(Number(loc.space[c.x][c.y].phis)<1)continue;
               var world:Rectangle=new Rectangle(int(c.x)*40,int(c.y)*40,40,40);
               for each(var r:Rectangle in regions) {
                  if(!r.intersects(world))continue;
                  for(var key:String in c.values) {
                     var index:int=int(key),x:int=int(world.x)+index%40,y:int=int(world.y)+int(index/40);
                     if(!r.contains(x,y))continue;
                     var color:uint=uint(c.values[key]);x-=ox;y-=oy;
                     if(b.getPixel32(x,y)!=color){b.setPixel32(x,y,color);wrote=true;}
                  }
               }
            }
         }finally{b.unlock();}
         return wrote;
      }
   }
}
