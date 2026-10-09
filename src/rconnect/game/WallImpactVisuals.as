package rconnect.game
{
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import rconnect.net.RoomCodec;

   /** Grafon.dyrka/decal changes frontBmp, including indestructible walls whose
    * HP never changes. Keep the actual pixels: replaying dyrka chooses another
    * random frame/angle, and must never be used to settle damage on a receiver.
    *
    * Native frames call before/observe. Only real projectile contact regions
    * and changed terrain supplied by the existing terrain tracker are compared.
    * A single active-room shadow is the only full-size bitmap copy. Inactive
    * rooms retain compressed sparse cells, not another room-sized bitmap.
    * Room/epoch/term and sender validation belong to Session/RoomSync.
    */
   public class WallImpactVisuals
   {
      private static const CELL:int=40;
      private static const MAX_CELLS:int=64;
      private static const MAX_WIRE:int=48000;
      private static const MARGIN:int=96;
      private var rooms:Dictionary=new Dictionary(true);
      private var active:Object,shadow:BitmapData,bitmap:BitmapData;
      private var scratchA:BitmapData=new BitmapData(CELL,CELL,true,0);
      private var scratchB:BitmapData=new BitmapData(CELL,CELL,true,0);
      private var tracked:Array=[];
      private var contacts:Dictionary=new Dictionary(true);
      private var tileState:Object={};
      private var sequence:int=0,revision:int=0;
      private var domain:Object,margins:Object={};
      /** Receiver pixels changed; GameBridge can refresh a cached SATS raster. */
      public var dirty:Boolean=false;

      public function WallImpactVisuals(main:Object=null)
      {if(main!=null)domain=main.loaderInfo.applicationDomain;}

      /** Actual native asset bounds include random variant frames and the
       * largest native scale. No assumption that every weapon's notch is tiny. */
      private function margin(tip:int):int
      {
         if(margins[String(tip)]!=null)return int(margins[String(tip)]);
         var names:Array;
         if(tip>=1 && tip<=3)names=["bullet_metal","bullet_dyr","bullet_tre","bullet_wood"];
         else if(tip>=4 && tip<=6)names=["punch_tre"];
         else if(tip==9)names=["metal_tre","expl_tre"];
         else if(tip==11)names=["fire_soft"];
         else if(tip==12 || tip==13)names=["fire_soft","laser_tre"];
         else if(tip==15)names=["plasma_soft","plasma_dyr","plasma_tre"];
         else if(tip==16)names=["fire_soft","plasma_dyr","bluplasma_tre"];
         else if(tip==17)names=["fire_soft","plasma_dyr","pinkplasma_tre"];
         else if(tip==18)names=["cryo_soft"];
         else if(tip==19)names=["plaexpl_tre"];
         else names=[];
         var extent:Number=MARGIN,scale:Number=(tip==3 || tip==6)?2:(tip==2 || tip==5)?1.5:1;
         if(domain!=null)for each(var name:String in names)
         {
            try
            {
               var cls:Class=domain.getDefinition(name) as Class,clip:MovieClip=new cls() as MovieClip;
               if(clip==null)continue;
               clip.stop();
               for(var frame:int=1;frame<=clip.totalFrames;frame++)
               {
                  clip.gotoAndStop(frame);var bounds:Rectangle=clip.getBounds(clip);
                  var x:Number=Math.max(Math.abs(bounds.x),Math.abs(bounds.right));
                  var y:Number=Math.max(Math.abs(bounds.y),Math.abs(bounds.bottom));
                  extent=Math.max(extent,Math.sqrt(x*x+y*y)*scale+3);
               }
            }
            catch(e:*) {} // Optional domain is absent only in small isolated grids.
         }
         margins[String(tip)]=Math.ceil(extent);return int(Math.ceil(extent));
      }

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function id(x:int,y:int):String {return x+","+y;}
      private function state(loc:Object):Object
      {
         var s:Object=rooms[loc];
         if(s==null)s=rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},cursor:0};
         return s;
      }
      private function front(loc:Object):BitmapData
      {
         var g:Object=get(loc,"grafon");
         // Grafon is shared by rooms. inRoom(oldRoom) must never paint the new
         // room's bitmap while settling reports on the old-room TCP barrier.
         return loc!=null && get(g,"loc")===loc?get(g,"frontBmp") as BitmapData:null;
      }
      private function solid(loc:Object,x:int,y:int):Boolean
      {
         if(loc==null || x<0 || y<0 || x>=int(loc.spaceX) || y>=int(loc.spaceY))return false;
         return Number(loc.space[x][y].phis)>=1;
      }
      private function rect(x:int,y:int,b:BitmapData):Rectangle
      {return new Rectangle(x*CELL,y*CELL,CELL,CELL).intersection(b.rect);}

      public function before(loc:Object):void
      {
         var b:BitmapData=front(loc);
         if(b==null)return;
         if(active!==loc || bitmap!==b || shadow==null)
         {
            if(shadow!=null)shadow.dispose();
            active=loc;bitmap=b;tracked=[];contacts=new Dictionary(true);tileState={};
            // drawLoc has already rebuilt this room before a normal frame.
            replay(loc,b);shadow=b.clone();
            for(var x:int=0;x<int(loc.spaceX);x++)for(var y:int=0;y<int(loc.spaceY);y++)
               tileState[id(x,y)]={h:Number(loc.space[x][y].hp),p:Number(loc.space[x][y].phis)};
         }
      }

      /** Call after native simulation and before sending the corresponding
       * scene state. An optional existing tile delta covers native body/Area
       * damage which has no persistent linked Bullet to observe. */
      public function observe(loc:Object,tiles:Array=null):void
      {
         before(loc);
         if(loc!==active || shadow==null || front(loc)!==bitmap)return;
         var work:Object={},objects:Array=[],visited:Dictionary=new Dictionary(true);
         for(var o:Object=get(loc,"firstObj"),guard:int=0;o!=null && guard++<10000;o=get(o,"nobj"))
         {
            var cls:String=getQualifiedClassName(o);
            if(cls=="fe.weapon::Bullet" || cls=="fe.weapon::SmartBullet" || cls=="fe.weapon::PhisBullet")
            {objects.push(o);visited[o]=true;}
         }
         // PhisBullet can remove itself in the contact frame. Its real object
         // still gives the endpoint; do not infer an impact from disappearance.
         var candidates:Array=objects.concat();
         for each(o in tracked)if(!visited[o])candidates.push(o);
         for each(o in candidates)
         {
            if(get(o,"loc")!==loc || Number(get(o,"tipDecal"))<=0)continue;
            var old:Object=contacts[o],hit:Boolean=get(o,"tilehit")===true;
            var ended:Boolean=get(o,"babah")===true;
            var radius:Number=Number(get(o,"explRadius"));
            var repeating:Boolean=Number(get(o,"expl_t"))>0 && radius>0;
            if((hit && (old==null || !old.hit)) || (ended && (old==null || !old.ended)) || repeating)
            {
               var px:Number=Number(get(o,"X")),py:Number=Number(get(o,"Y"));
               var pad:int=margin(int(get(o,"tipDecal")));
               if(isFinite(px) && isFinite(py))
                  region(work,px-pad-Math.max(0,radius),py-pad-Math.max(0,radius),
                     px+pad+Math.max(0,radius),py+pad+Math.max(0,radius));
            }
            contacts[o]={hit:hit,ended:ended};
         }
         tracked=objects;
         if(tiles!=null)for each(var t:Object in tiles)
         {
            if(t==null)continue;
            var tx:int=int(t.x),ty:int=int(t.y),k:String=id(tx,ty);
            if(tx<0 || ty<0 || tx>=int(loc.spaceX) || ty>=int(loc.spaceY))continue;
            var now:Object={h:Number(loc.space[tx][ty].hp),p:Number(loc.space[tx][ty].phis)},prior:Object=tileState[k];
            if(prior!=null && (now.h!=prior.h || now.p!=prior.p))
               region(work,tx*CELL-MARGIN,ty*CELL-MARGIN,(tx+1)*CELL+MARGIN,(ty+1)*CELL+MARGIN);
            tileState[k]=now;
         }
         for(k in work)
         {
            var xy:Array=k.split(",");tx=int(xy[0]);ty=int(xy[1]);
            // Entire removed tiles remain TerrainSync's responsibility. In
            // particular an old coating must never fill a destroyed wall back in.
            if(!solid(loc,tx,ty)) {discard(loc,k);shadow.copyPixels(bitmap,rect(tx,ty,bitmap),new Point(tx*CELL,ty*CELL));continue;}
            captureCell(loc,tx,ty);
         }
      }
      private function region(work:Object,x1:Number,y1:Number,x2:Number,y2:Number):void
      {
         if(!isFinite(x1+y1+x2+y2))return;
         var left:int=Math.max(0,int(Math.floor(x1/CELL))),top:int=Math.max(0,int(Math.floor(y1/CELL)));
         var right:int=Math.min(int(Math.ceil(bitmap.width/CELL))-1,int(Math.floor(x2/CELL)));
         var bottom:int=Math.min(int(Math.ceil(bitmap.height/CELL))-1,int(Math.floor(y2/CELL)));
         for(var x:int=left;x<=right;x++)for(var y:int=top;y<=bottom;y++)work[id(x,y)]=true;
      }
      private function captureCell(loc:Object,x:int,y:int):void
      {
         var r:Rectangle=rect(x,y,bitmap);
         if(r.isEmpty())return;
         scratchA.fillRect(scratchA.rect,0);scratchB.fillRect(scratchB.rect,0);
         scratchA.copyPixels(shadow,r,new Point());scratchB.copyPixels(bitmap,r,new Point());
         var difference:*=scratchA.compare(scratchB);
         if(!(difference is BitmapData))return;
         var d:BitmapData=difference as BitmapData;
         var changed:Rectangle=d.getColorBoundsRect(0xffffffff,0,false);d.dispose();
         var old:Vector.<uint>=scratchA.getVector(changed),fresh:Vector.<uint>=scratchB.getVector(changed);
         var s:Object=state(loc),k:String=id(x,y),cell:Object=s.cells[k],q:Object=s.queued[k];
         if(cell==null)cell=s.cells[k]={x:x,y:y,values:{},v:0,wire:null};
         if(q==null)q=s.queued[k]={x:x,y:y,values:{}};
         for(var row:int=0;row<int(changed.height);row++)for(var col:int=0;col<int(changed.width);col++)
         {
            var i:int=row*int(changed.width)+col;
            if(old[i]==fresh[i])continue;
            var offset:int=(int(changed.y)+row)*CELL+int(changed.x)+col;
            cell.values[String(offset)]=fresh[i];q.values[String(offset)]=fresh[i];
         }
         cell.v=++revision;cell.wire=null;
         shadow.copyPixels(bitmap,r,new Point(r.x,r.y));
      }
      private function discard(loc:Object,k:String):void
      {
         var s:Object=state(loc);delete s.cells[k];delete s.queued[k];delete s.incoming[k];
      }
      private function packed(c:Object):Object
      {
         if(c.wire!=null)return c.wire;
         var indices:Array=[];for(var key:String in c.values)indices.push(int(key));indices.sort(Array.NUMERIC);
         var words:Array=[];for each(var i:int in indices)words.push(i,Number(c.values[String(i)]));
         var wire:Object={x:int(c.x),y:int(c.y),v:int(c.v),d:RoomCodec.pack(words)};
         if(c.v!==undefined)c.wire=wire;
         return wire;
      }
      private function queuedBatch(s:Object):Array
      {
         var out:Array=[],size:int=0;
         for(var k:String in s.queued)
         {
            var c:Object=s.queued[k],wire:Object=packed(c);
            if(out.length && (out.length>=MAX_CELLS || size+wire.d.length>MAX_WIRE))break;
            out.push(wire);size+=wire.d.length;delete s.queued[k];
         }
         return out;
      }
      public function report(loc:Object):Object
      {
         observe(loc);
         var s:Object=state(loc);
         if(s.pending!=null)return null;
         var cells:Array=queuedBatch(s);if(!cells.length)return null;
         s.pending={seq:++sequence,cells:cells};return s.pending;
      }
      public function finishReports(loc:Object):Array
      {
         observe(loc);
         var s:Object=state(loc),out:Array=[],cells:Array;
         while((cells=queuedBatch(s)).length)out.push({seq:++sequence,cells:cells});
         // The original pending batch has already been sent on ordered TCP.
         s.pending=null;return out;
      }

      private function decode(loc:Object,list:Array,limit:Boolean=true):Array
      {
         if(list==null || list.length>1200 || (limit && list.length>MAX_CELLS))return null;
         var out:Array=[],bytes:int=0,seen:Object={};
         try
         {
            for each(var c:Object in list)
            {
               if(c==null || !(c.d is String) || !isFinite(Number(c.x)) || !isFinite(Number(c.y)))return null;
               var x:int=int(c.x),y:int=int(c.y),k:String=id(x,y);
               if(x!=Number(c.x) || y!=Number(c.y) || x<0 || y<0 || x>=int(loc.spaceX) || y>=int(loc.spaceY) ||
                  x*CELL>=1920 || y*CELL>=1000 || seen[k])return null;
               if((bytes+=String(c.d).length)>MAX_WIRE && limit)return null;
               // One 40x40 sparse cell has at most 3200 numeric words. Reject
               // expanded data before touching any pixels or accepting a seq.
               var words:Array=RoomCodec.unpack(String(c.d)) as Array;
               if(words==null || words.length>2*CELL*CELL || words.length%2!=0)return null;
               var previous:int=-1;
               for(var i:int=0;i<words.length;i+=2)
               {
                  var index:Number=Number(words[i]),color:Number=Number(words[i+1]);
                  if(!isFinite(index) || index!=int(index) || index<=previous || index>=CELL*CELL ||
                     !isFinite(color) || color<0 || color>4294967295 || color!=Math.floor(color))return null;
                  previous=int(index);
               }
               seen[k]=true;out.push({x:x,y:y,v:int(c.v),words:words});
            }
         }
         catch(e:*) {return null;}
         return out;
      }
      private function protectedPixels(s:Object):Object
      {
         var out:Object={};
         for(var k:String in s.queued)out[k]=s.queued[k].values;
         if(s.pending!=null)
         {
            // Do not mutate queued maps when adding the older pending indices.
            for each(var c:Object in s.pending.cells)
            {
               k=id(c.x,c.y);var merged:Object={};
               if(out[k]!=null)for(var key:String in out[k])merged[key]=true;
               var words:Array=RoomCodec.unpack(String(c.d)) as Array;
               for(var i:int=0;i<words.length;i+=2)merged[String(words[i])]=true;
               out[k]=merged;
            }
         }
         return out;
      }
      private function put(loc:Object,list:Array,protect:Boolean,versions:Boolean):void
      {
         var s:Object=state(loc),b:BitmapData=front(loc),skip:Object=protect?protectedPixels(s):{};
         if(b!=null)b.lock();
         try
         {
            for each(var c:Object in list)
            {
               var k:String=id(c.x,c.y);
               if(!solid(loc,c.x,c.y)) {discard(loc,k);continue;}
               if(versions && s.incoming[k]!=null && int(c.v)<=int(s.incoming[k]))continue;
               var cell:Object=s.cells[k];
               if(cell==null)cell=s.cells[k]={x:c.x,y:c.y,values:{},v:0,wire:null};
               var wrote:Boolean=false;
               for(var i:int=0;i<c.words.length;i+=2)
               {
                  var index:int=int(c.words[i]),key:String=String(index);
                  if(skip[k]!=null && skip[k][key]!==undefined)continue;
                  var color:uint=uint(c.words[i+1]),x:int=int(c.x)*CELL+index%CELL,y:int=int(c.y)*CELL+int(index/CELL);
                  if(cell.values[key]!==color) {cell.values[key]=color;wrote=true;}
                  if(b!=null && x<b.width && y<b.height && b.getPixel32(x,y)!=color)
                  {b.setPixel32(x,y,color);dirty=true;}
               }
               if(wrote) {cell.v=++revision;cell.wire=null;}
               // A skipped predicted pixel needs the same authoritative cell
               // again after ack. Only advance its cursor if nothing was skipped.
               if(versions && skip[k]==null)s.incoming[k]=int(c.v);
               if(loc===active && shadow!=null && b===bitmap)shadow.copyPixels(b,rect(c.x,c.y,b),new Point(c.x*CELL,c.y*CELL));
            }
         }
         finally {if(b!=null)b.unlock();}
      }
      public function receive(loc:Object,list:Array,predict:Boolean=true):void
      {
         // Capture an actual local hit which happened before the next network
         // report. Otherwise an earlier authoritative cell could hide it.
         if(predict)observe(loc);
         var decoded:Array=decode(loc,list);
         if(decoded!=null)put(loc,decoded,predict,true);
      }
      public function settle(loc:Object,peer:String,request:Object):Object
      {
         if(loc==null || request==null || !(request.cells is Array) || int(request.seq)<=0)return null;
         var s:Object=state(loc),last:Object=s.receipts[peer];
         if(last!=null && int(request.seq)<=int(last.seq))return int(request.seq)==int(last.seq)?last:null;
         var decoded:Array=decode(loc,request.cells as Array);
         if(decoded==null)return null;
         put(loc,decoded,false,false);
         // ACK the accepted changed pixels, rather than rerunning random native
         // graphics. Disjoint host/client markings merge; last arrival decides
         // the genuinely overlapping pixels on the room owner.
         var accepted:Array=[];
         for each(var c:Object in request.cells)if(solid(loc,int(c.x),int(c.y)))accepted.push(c);
         var receipt:Object={seq:int(request.seq),cells:accepted};s.receipts[peer]=receipt;return receipt;
      }
      public function acknowledge(loc:Object,receipt:Object):void
      {
         var s:Object=state(loc);
         if(s.pending==null || receipt==null || int(receipt.seq)!=int(s.pending.seq))return;
         observe(loc);var decoded:Array=decode(loc,receipt.cells as Array);
         if(decoded==null)return;
         s.pending=null;put(loc,decoded,true,false);
      }

      /** Rotating cumulative cells repair old/later peer views without a full
       * foreground bitmap on every unitsync. No new native projectile is made. */
      public function snapshot(loc:Object):Array
      {
         observe(loc);var s:Object=state(loc),keys:Array=[],out:Array=[],size:int=0;
         for(var k:String in s.cells)
         {
            var c:Object=s.cells[k];if(!solid(loc,c.x,c.y))discard(loc,k);else keys.push(k);
         }
         keys.sort();if(!keys.length)return null;
         var cursor:int=int(s.cursor)%keys.length;
         for(var i:int=0;i<keys.length && out.length<MAX_CELLS;i++)
         {
            c=s.cells[keys[cursor]];var wire:Object=packed(c);
            if(out.length && size+wire.d.length>MAX_WIRE)break;
            out.push(wire);size+=wire.d.length;cursor=(cursor+1)%keys.length;
         }
         s.cursor=cursor;return out;
      }
      public function checkpoint(loc:Object):Array
      {
         if(front(loc)!=null)observe(loc);
         var s:Object=state(loc),out:Array=[];
         for(var k:String in s.cells)
         {
            var c:Object=s.cells[k];if(solid(loc,c.x,c.y))out.push(packed(c));else discard(loc,k);
         }
         return out;
      }
      public function restore(loc:Object,list:Array):void
      {
         var decoded:Array=decode(loc,list || [],false);
         if(decoded==null)throw new Error("Invalid wall appearance checkpoint");
         rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},cursor:0};
         put(loc,decoded,false,false);redraw(loc);
      }
      private function replay(loc:Object,b:BitmapData):void
      {
         var s:Object=state(loc);b.lock();
         try
         {
            for(var k:String in s.cells)
            {
               var c:Object=s.cells[k];if(!solid(loc,c.x,c.y)) {discard(loc,k);continue;}
               for(var key:String in c.values)
               {
                  var i:int=int(key),x:int=int(c.x)*CELL+i%CELL,y:int=int(c.y)*CELL+int(i/CELL);
                  if(x<b.width && y<b.height)b.setPixel32(x,y,uint(c.values[key]));
               }
            }
         }
         finally {b.unlock();}
      }
      /** Immediately after native redrawLoc, before final RENDER/SATS capture. */
      public function redraw(loc:Object):void
      {
         var b:BitmapData=front(loc);if(b==null)return;
         replay(loc,b);
         if(active===loc) {if(shadow!=null)shadow.dispose();bitmap=b;shadow=b.clone();}
      }
      /** Ownership changes invalidate only transport cursors, not room marks. */
      public function roleChanged(loc:Object):void
      {
         var s:Object=state(loc);s.queued={};s.pending=null;s.receipts={};s.incoming={};
         tracked=[];contacts=new Dictionary(true);
      }
      public function reset():void
      {
         if(shadow!=null)shadow.dispose();shadow=null;bitmap=null;active=null;
         rooms=new Dictionary(true);tracked=[];contacts=new Dictionary(true);tileState={};dirty=false;
      }
   }
}
