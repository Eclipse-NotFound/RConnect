package rconnect.game
{
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.system.System;
   import rconnect.core.Log;
   import rconnect.net.RoomCodec;
   import rconnect.net.WallCellCodec;
   import rconnect.net.TcpLink;

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
      // Cache only validated, numeric sparse words; room/version checks stay
      // outside this cache. Three independent bounds limit retained memory.
      private static const WORD_CACHE_ENTRIES:int=128;
      private static const WORD_CACHE_WORDS:int=131072;
      private static const WORD_CACHE_CHARS:int=524288;
      private var wordCache:Dictionary=new Dictionary();
      private var wordOrder:Array=[];
      private var wordCount:int=0,wordChars:int=0;
      private var rooms:Dictionary=new Dictionary(true);
      private var active:Object,shadow:BitmapData,bitmap:BitmapData;
      private var surfaces:WallSurfaceBridge;
      private var surfaceOrder:Number=0;
      private var scratchA:BitmapData=new BitmapData(CELL,CELL,true,0);
      private var scratchB:BitmapData=new BitmapData(CELL,CELL,true,0);
      private var tracked:Array=[];
      private var contacts:Dictionary=new Dictionary(true);
      private var tileState:Object={};
      private var sequence:int=0,revision:int=0;
      private var domain:Object,margins:Object={};
      private var bitmapDiagnostics:int=0;
      /** Receiver pixels changed; GameBridge can refresh a cached SATS raster. */
      public var dirty:Boolean=false;

      public function WallImpactVisuals(main:Object=null)
      {
         if(main!=null)domain=main.loaderInfo.applicationDomain;
         surfaces=new WallSurfaceBridge(surfaceChanges,surfaceRaster,surfaceBorn,main,ordinaryNative);
      }
      public function set networkActive(value:Boolean):void {surfaces.networkActive=value;}
      private function surfaceBorn():Number {return ++surfaceOrder;}
      private function surfaceChanges(loc:Object,list:Object,order:Number):void
      {
         var s:Object=state(loc);
         for(var k:String in list) {
            var incoming:Object=list[k];
            if(!solid(loc,int(incoming.x),int(incoming.y))){discard(loc,k);continue;}
            var cell:Object=s.cells[k],q:Object=s.queued[k],wrote:Boolean=false;
            if(cell==null)cell=s.cells[k]={x:incoming.x,y:incoming.y,values:{},v:0,wire:null};
            if(cell.paintOrder==null)cell.paintOrder={};
            for(var index:String in incoming.values) {
               // A mark can first rasterize long after its native birth. Its
               // old pixels must not supersede a newer accepted local/peer ink.
               // This local-only order never changes wire versions or ACKs.
               if(Number(cell.paintOrder[index])>order)continue;
               cell.paintOrder[index]=order;
               var color:uint=uint(incoming.values[index]);
               if(cell.values[index]===color)continue;
               if(q==null)q=s.queued[k]={x:incoming.x,y:incoming.y,values:{}};
               cell.values[index]=color;q.values[index]=color;wrote=true;
            }
            if(wrote){cell.v=++revision;cell.wire=null;}
         }
      }
      private function surfaceRaster(loc:Object,b:BitmapData,x:int,y:int,clips:Array):void
      {
         if(surfaces.replay(loc,b,x,y,state(loc).cells,clips))dirty=true;
      }

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
         if(s==null)s=rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},sent:{},cursor:0};
         return s;
      }
      private function front(loc:Object):BitmapData
      {
         var g:Object=get(loc,"grafon");
         // Grafon is shared by rooms. inRoom(oldRoom) must never paint the new
         // room's bitmap while settling reports on the old-room TCP barrier.
         return loc!=null && get(g,"loc")===loc && get(g,"sceneLarge")!==true && get(g,"rconnectRasterPending")!==true
            ?get(g,"frontBmp") as BitmapData:null;
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
         // Large scenes have no persistent full-surface shadow. Their actual
         // paint passes report bounded changed regions through the host bridge.
         if(get(get(loc,"grafon"),"sceneLarge")===true) {
            if(shadow!=null){shadow.dispose();shadow=null;}
            active=loc;bitmap=null;return;
         }
         var b:BitmapData=front(loc);
         if(b==null)return;
         if(active!==loc || bitmap!==b || shadow==null)
         {
            if(shadow!=null){shadow.dispose();shadow=null;}
            active=loc;bitmap=b;tracked=[];contacts=new Dictionary(true);tileState={};
            // drawLoc has already rebuilt this room before a normal frame.
            replay(loc,b);shadow=copyFront(loc,b,"before");
            for(var x:int=0;x<int(loc.spaceX);x++)for(var y:int=0;y<int(loc.spaceY);y++)
               tileState[id(x,y)]={h:Number(loc.space[x][y].hp),p:Number(loc.space[x][y].phis)};
         }
      }

      private function copyFront(loc:Object,b:BitmapData,where:String):BitmapData
      {
         try {return b.clone();}
         catch(error:Error)
         {
            if(bitmapDiagnostics++<4)
            {
               var g:Object=get(loc,"grafon"),info:Object={where:where,error:error.toString(),
                  heap:System.totalMemory,privateBytes:System.privateMemory,freeBytes:System.freeMemory,
                  current:b===front(loc),grafonRoom:get(g,"loc")===loc,sceneLarge:get(g,"sceneLarge"),
                  sceneX:get(g,"sceneX"),sceneY:get(g,"sceneY"),spaceX:get(loc,"spaceX"),spaceY:get(loc,"spaceY")};
               try {info.width=b.width;info.height=b.height;info.pixel=b.getPixel32(0,0);}catch(invalid:Error){info.pixelError=invalid.toString();}
               Log.d("RConnectWall: bitmap copy failed "+JSON.stringify(info));
            }
            throw error;
         }
         return null;
      }

      /** Call after native simulation and before sending the corresponding
       * scene state. An optional existing tile delta covers native body/Area
       * damage which has no persistent linked Bullet to observe. */
      public function observe(loc:Object,tiles:Array=null):void
      {
         before(loc);
         // The installed ordinary host hook reports the actual decal bounds.
         // Do not classify unrelated gwall/structural writes inside a broad
         // projectile margin as ordinary ink. Old hosts retain the fallback.
         if(ordinary(loc) && surfaces.ordinaryAvailable)return;
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
            if(!ordinary(loc) && !solid(loc,tx,ty)) {discard(loc,k);shadow.copyPixels(bitmap,rect(tx,ty,bitmap),new Point(tx*CELL,ty*CELL));continue;}
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
         if(ordinary(loc)) {
            ordinaryCapture(loc,x,y,changed,old,fresh);
            shadow.copyPixels(bitmap,r,new Point(r.x,r.y));return;
         }
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
         var s:Object=state(loc);delete s.cells[k];delete s.queued[k];delete s.incoming[k];delete s.sent[k];
      }
      private function packed(c:Object):Object
      {
         if(c.wire!=null)return c.wire;
         var wire:Object={x:int(c.x),y:int(c.y),v:int(c.v),d:WallCellCodec.pack(c.values)};
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
      public function report(loc:Object,observeNow:Boolean=true):Object
      {
         // The fast transport drains changes already observed after the native
         // frame. It must not add another projectile/bitmap walk every tick.
         if(observeNow)observe(loc);
         var s:Object=state(loc);
         if(s.pending!=null)return null;
         var cells:Array=ordinary(loc)?ordinaryQueued(s):queuedBatch(s);if(!cells.length)return null;
         s.pending={seq:++sequence,cells:cells};return s.pending;
      }
      public function finishReports(loc:Object):Array
      {
         observe(loc);
         var s:Object=state(loc),out:Array=[],cells:Array;
         while((cells=ordinary(loc)?ordinaryQueued(s):queuedBatch(s)).length)out.push({seq:++sequence,cells:cells});
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
                  seen[k])return null;
               if((bytes+=String(c.d).length)>MAX_WIRE && limit)return null;
               // One 40x40 sparse cell has at most 3200 numeric words. Reject
               // expanded data before touching any pixels or accepting a seq.
               var words:Array=decodeWords(String(c.d));
               if(words==null)return null;
               seen[k]=true;out.push({x:x,y:y,v:int(c.v),words:words});
            }
         }
         catch(e:*) {return null;}
         return out;
      }
      /** The payload alone determines these words. Cache hits still return a
       * fresh array, so later consumers cannot mutate the retained value. */
      private function decodeWords(data:String):Array
      {
         var cached:Object=wordCache[data];
         if(cached!=null && cached.data===data)return cached.words.concat();
         var binary:Boolean=WallCellCodec.isCell(data);
         var words:Array=binary?WallCellCodec.unpack(data):RoomCodec.unpack(data) as Array;
         if(words==null || words.length>2*CELL*CELL || words.length%2!=0)return null;
         var previous:int=-1,numeric:Boolean=true;
         // W1 already validates count, strictly increasing offsets and uint colors.
         // Keep legacy coercion/type validation unchanged; it is not W1.
         if(!binary)for(var i:int=0;i<words.length;i+=2)
         {
            var index:Number=Number(words[i]),color:Number=Number(words[i+1]);
            if(!isFinite(index) || index!=int(index) || index<=previous || index>=CELL*CELL ||
               !isFinite(color) || color<0 || color>4294967295 || color!=Math.floor(color))return null;
            previous=int(index);
            // Preserve legacy Number coercion for unusual payloads, but never
            // retain nested mutable arrays/objects or change returned types.
            if(!(words[i] is Number) || !(words[i+1] is Number))numeric=false;
         }
         if(numeric && data.length<=WORD_CACHE_CHARS)rememberWords(data,words);
         return words;
      }
      private function rememberWords(data:String,words:Array):void
      {
         while(wordOrder.length && (wordOrder.length>=WORD_CACHE_ENTRIES ||
            wordCount+words.length>WORD_CACHE_WORDS || wordChars+data.length>WORD_CACHE_CHARS))
         {
            var old:Object=wordOrder.shift();delete wordCache[old.data];
            wordCount-=old.words.length;wordChars-=old.data.length;
         }
         var entry:Object={data:data,words:words.concat()};
         wordCache[data]=entry;wordOrder.push(entry);
         wordCount+=words.length;wordChars+=data.length;
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
               var words:Array=decodeWords(String(c.d));
               for(var i:int=0;i<words.length;i+=2)merged[String(words[i])]=true;
               out[k]=merged;
            }
         }
         return out;
      }
      private function put(loc:Object,list:Array,protect:Boolean,versions:Boolean):void
      {
         var s:Object=state(loc),b:BitmapData=front(loc),skip:Object=protect?protectedPixels(s):{};
         var large:Boolean=get(get(loc,"grafon"),"sceneLarge")===true,painted:Array=large?[]:null;
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
               var wrote:Boolean=false;var visible:Array=large?[]:null;
               for(var i:int=0;i<c.words.length;i+=2)
               {
                  var index:int=int(c.words[i]),key:String=String(index);
                  if(skip[k]!=null && skip[k][key]!==undefined)continue;
                  var color:uint=uint(c.words[i+1]),x:int=int(c.x)*CELL+index%CELL,y:int=int(c.y)*CELL+int(index/CELL);
                  if(visible!=null)visible.push(index,color);
                  // Accepted equal-color writes still establish a newer local
                  // order; stale versions and protected pixels already skipped.
                  if(large) {
                     if(cell.paintOrder==null)cell.paintOrder={};
                     cell.paintOrder[key]=++surfaceOrder;
                  }
                  if(cell.values[key]!==color) {
                     cell.values[key]=color;wrote=true;
                  }
                  if(b!=null && x<b.width && y<b.height && b.getPixel32(x,y)!=color)
                  {b.setPixel32(x,y,NativeWallColor.setter(color));dirty=true;}
               }
               if(visible!=null && visible.length)painted.push({x:c.x,y:c.y,words:visible});
               if(wrote) {cell.v=++revision;cell.wire=null;}
               // A skipped predicted pixel needs the same authoritative cell
               // again after ack. Only advance its cursor if nothing was skipped.
               if(versions && skip[k]==null)s.incoming[k]=int(c.v);
               if(loc===active && shadow!=null && b===bitmap)shadow.copyPixels(b,rect(c.x,c.y,b),new Point(c.x*CELL,c.y*CELL));
            }
         }
         finally {if(b!=null)b.unlock();}
         if(painted!=null && painted.length && surfaces.paint(loc,painted))dirty=true;
      }
      public function receive(loc:Object,list:Array,predict:Boolean=true):void
      {
         // Capture an actual local hit which happened before the next network
         // report. Otherwise an earlier authoritative cell could hide it.
         if(predict)observe(loc);
         if(ordinary(loc)) {
            var accepted:Array=ordinaryDecode(loc,list,"receive");
            if(accepted!=null)ordinaryCompose(loc,ordinaryIngest(loc,accepted));return;
         }
         var decoded:Array=decode(loc,list);
         if(decoded!=null)put(loc,decoded,predict,true);
      }
      public function settle(loc:Object,peer:String,request:Object):Object
      {
         if(loc!=null && ordinary(loc))return ordinarySettle(loc,peer,request);
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
         if(ordinary(loc)){ordinaryAck(loc,receipt);return;}
         var s:Object=state(loc);
         if(s.pending==null || receipt==null || int(receipt.seq)!=int(s.pending.seq))return;
         observe(loc);var decoded:Array=decode(loc,receipt.cells as Array);
         if(decoded==null)return;
         s.pending=null;put(loc,decoded,true,false);
      }

      /** Only changed cell revisions enter the fast player-state channel.
       * GameBridge already observes every native frame. Selection neither
       * scans projectiles nor advances the sent cursor before transmission. */
      public function updates(loc:Object):Array
      {
         if(ordinary(loc))return ordinaryList(loc,"updates");
         var s:Object=state(loc),keys:Array=[],out:Array=[],size:int=0;
         for(var k:String in s.cells)
         {
            var c:Object=s.cells[k];
            if(!solid(loc,c.x,c.y))discard(loc,k);
            else if(s.sent[k]==null || int(c.v)>int(s.sent[k]))keys.push(k);
         }
         keys.sort();
         for each(k in keys)
         {
            c=s.cells[k];var wire:Object=packed(c);
            if(out.length && (out.length>=MAX_CELLS || size+wire.d.length>MAX_WIRE))break;
            out.push(wire);size+=wire.d.length;
         }
         return out.length?out:null;
      }
      /** Called only after the selected batch was handed to the TCP sender.
       * A newer local revision remains eligible for the next fast packet. */
      public function sentUpdates(loc:Object,list:Array):void
      {
         if(list==null)return;
         var s:Object=state(loc);
         for each(var c:Object in list)
         {
            var k:String=id(int(c.x),int(c.y));
            if(s.cells[k]!=null && (s.sent[k]==null || int(c.v)>int(s.sent[k])))s.sent[k]=int(c.v);
         }
      }

      /** Rotating cumulative cells repair old/later peer views without a full
       * foreground bitmap on every unitsync. No new native projectile is made. */
      public function snapshot(loc:Object,observeNow:Boolean=true):Array
      {
         if(observeNow)observe(loc);if(ordinary(loc))return ordinaryList(loc,"snapshot");
         var s:Object=state(loc),keys:Array=[],out:Array=[],size:int=0;
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
         if(ordinary(loc))return ordinaryList(loc,"checkpoint");
         var s:Object=state(loc),out:Array=[];
         for(var k:String in s.cells)
         {
            var c:Object=s.cells[k];if(solid(loc,c.x,c.y))out.push(packed(c));else discard(loc,k);
         }
         return out;
      }
      public function restore(loc:Object,list:Array):void
      {
         if(ordinary(loc)){prepareRestore(loc,list,state(loc).authority!==false);finishRestore(loc);return;}
         var decoded:Array=decode(loc,list || [],false);
         if(decoded==null)throw new Error("Invalid wall appearance checkpoint");
         surfaces.restored(loc);
         rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},sent:{},cursor:0};
         put(loc,decoded,false,false);redraw(loc);
      }
      private function replay(loc:Object,b:BitmapData):void
      {
         if(ordinary(loc)){ordinaryCompose(loc,null,b);return;}
         var s:Object=state(loc);b.lock();
         try
         {
            for(var k:String in s.cells)
            {
               var c:Object=s.cells[k];if(!solid(loc,c.x,c.y)) {discard(loc,k);continue;}
               for(var key:String in c.values)
               {
                  var i:int=int(key),x:int=int(c.x)*CELL+i%CELL,y:int=int(c.y)*CELL+int(i/CELL);
                  if(x<b.width && y<b.height)b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));
               }
            }
         }
         finally {b.unlock();}
      }
      /** Immediately after native redrawLoc, before final RENDER/SATS capture. */
      public function redraw(loc:Object):void
      {
         if(get(get(loc,"grafon"),"sceneLarge")===true) {
            var resident:Array=surfaces.surfaces(loc);
            if(resident!=null)for each(var entry:Object in resident) {
               if(surfaces.replay(loc,entry.nativeBuffers[0],int(entry.x),int(entry.y),state(loc).cells,null))
                  {entry.revision=int(entry.revision)+1;dirty=true;}
            }
            return;
         }
         var b:BitmapData=front(loc);if(b==null)return;
         replay(loc,b);
         if(active===loc) {if(shadow!=null){shadow.dispose();shadow=null;}bitmap=b;shadow=copyFront(loc,b,"redraw");}
      }
      /** Ownership changes invalidate only transport cursors, not room marks. */
      public function roleChanged(loc:Object):void
      {
         var s:Object=state(loc);s.queued={};s.pending=null;s.receipts={};s.incoming={};s.sent={};s.cursor=0;
         if(ordinary(loc)){ordinaryCompose(loc);s.underlays={};}
         tracked=[];contacts=new Dictionary(true);
      }
      // Ordinary frontBmp cells use authority versions. The large-scene path
      // below remains the original protocol, including paintOrder semantics.
      private function ordinary(loc:Object):Boolean
      {
         var s:Object=state(loc),g:Object=get(loc,"grafon");
         if(s.ordinary!==undefined)return s.ordinary===true;
         if(get(g,"loc")===loc)s.ordinary=get(g,"sceneLarge")!==true;
         return s.ordinary===true;
      }
      public function ordinaryRole(loc:Object,authority:Boolean):void
      {var s:Object=state(loc);s.authority=authority;var g:Object=get(loc,"grafon");if(get(g,"loc")===loc)s.ordinary=get(g,"sceneLarge")!==true;}
      private function nextRevision():int
      {if(revision>=2147483646)throw new Error("Wall revision exhausted");return ++revision;}
      private static function integer(value:*):Boolean
      {return value is Number && isFinite(Number(value)) && Number(value)>=0 && Number(value)<=2147483646 && Number(value)==Math.floor(Number(value));}
      private function ordinaryCell(s:Object,x:int,y:int):Object
      {
         var k:String=id(x,y),c:Object=s.cells[k];
         if(c==null)c=s.cells[k]={x:x,y:y,v:0,sv:0,full:false,needsNative:false,rebase:false,values:{},wire:null};
         return c;
      }
      private function ordinaryPacked(c:Object,checkpoint:Boolean=false):Object
      {
         if(c.needsNative===true)return checkpoint?{x:c.x,y:c.y,v:c.v,sv:c.sv,full:false,needsNative:true,rebase:true}:null;
         if(c.wire==null)c.wire={x:c.x,y:c.y,v:c.v,sv:c.sv,full:c.full===true,rebase:c.rebase===true,d:WallCellCodec.pack(c.values)};
         if(!checkpoint)return c.wire;
         return {x:c.x,y:c.y,v:c.v,sv:c.sv,full:c.full===true,d:c.wire.d,rebase:c.rebase===true,needsNative:false};
      }
      private function ordinaryDecode(loc:Object,list:Array,kind:String):Array
      {
         var checkpoint:Boolean=kind=="checkpoint",report:Boolean=kind=="report";
         if(list==null || list.length>(checkpoint?1200:report?3:MAX_CELLS))return null;
         var out:Array=[],seen:Object={},bytes:int=0;
         for each(var c:Object in list) {
            if(c==null || !integer(c.x) || !integer(c.y) || !integer(c.v) || !integer(c.sv) || c.v<c.sv || !(c.full is Boolean))return null;
            var x:int=int(c.x),y:int=int(c.y),k:String=id(x,y);
            if(x>=int(loc.spaceX) || y>=int(loc.spaceY) || seen[k])return null;
            seen[k]=true;
            if(c.needsNative!==undefined && !(c.needsNative is Boolean))return null;
            if(c.rebase!==undefined && !(c.rebase is Boolean))return null;
            var waiting:Boolean=c.needsNative===true;
            if(waiting) {
               if(report || kind=="receive" || c.full || int(c.sv)==0 || c.d!==undefined)return null;
               out.push({x:x,y:y,v:int(c.v),sv:int(c.sv),full:false,needsNative:true,rebase:true,words:[]});continue;
            }
            if(!(c.d is String) || (!checkpoint && (bytes+=String(c.d).length)>MAX_WIRE))return null;
            var words:Array=decodeWords(String(c.d));if(words==null)return null;
            if(!report && int(c.sv)>0 && c.full!==true)return null;
            if(c.full===true && words.length!=CELL*CELL*2)return null;
            // Room cell dimensions are native 40 pixels, including alpha-zero.
            // A full cell must contain every index exactly once (codec sorted).
            if(c.full===true)for(var i:int=0;i<words.length;i+=2)if(int(words[i])!=i/2)return null;
            out.push({x:x,y:y,v:int(c.v),sv:int(c.sv),full:c.full===true,needsNative:false,rebase:c.rebase===true,words:words});
         }
         return out;
      }
      private function ordinaryCapture(loc:Object,x:int,y:int,changed:Rectangle,old:Vector.<uint>,fresh:Vector.<uint>):void
      {
         var s:Object=state(loc),k:String=id(x,y),c:Object=ordinaryCell(s,x,y);
         if(c.needsNative)return;
         var q:Object=s.queued[k];
         if(q==null || q.sv!=c.sv)q=s.queued[k]={x:x,y:y,v:c.sv,sv:c.sv,full:false,values:{}};
         if(s.underlays==null)s.underlays={};
         var base:Object=s.underlays[k];if(base==null)base=s.underlays[k]={};
         var wrote:Boolean=false;
         for(var row:int=0;row<int(changed.height);row++)for(var col:int=0;col<int(changed.width);col++) {
            var i:int=row*int(changed.width)+col;if(old[i]==fresh[i])continue;
            var key:String=String((int(changed.y)+row)*CELL+int(changed.x)+col);
            if(base[key]===undefined)base[key]=old[i];
            q.values[key]=fresh[i];
            if(s.authority!==false)c.values[key]=fresh[i];
            wrote=true;
         }
         if(wrote && s.authority!==false){c.v=nextRevision();c.wire=null;}
      }
      private function ordinaryQueued(s:Object):Array
      {
         var out:Array=[];
         for(var k:String in s.queued) {
            var q:Object=s.queued[k],c:Object=s.cells[k];
            if(c==null || c.needsNative || q.sv!=c.sv){delete s.queued[k];continue;}
            // A worst-case cumulative full ACK is 13340 chars/cell. Three
            // cells leave the existing 48000-char bound intact, without ACKs
            // that retire only an ambiguous subset of one prediction batch.
            out.push({x:q.x,y:q.y,v:q.sv,sv:q.sv,full:false,d:WallCellCodec.pack(q.values)});delete s.queued[k];
            if(out.length==3)break;
         }
         return out;
      }
      private function ordinaryPredictions(s:Object,k:String,sv:int):Object
      {
         var out:Object={},c:Object,words:Array,i:int,key:String;
         if(s.pending!=null)for each(c in s.pending.cells)if(id(c.x,c.y)==k && c.sv==sv) {
            words=decodeWords(String(c.d));
            if(words!=null)for(i=0;i<words.length;i+=2)out[String(words[i])]=uint(words[i+1]);
         }
         c=s.queued[k];if(c!=null && c.sv==sv)for(key in c.values)out[key]=c.values[key];
         return out;
      }
      private function ordinaryCompose(loc:Object,keys:Object=null,b:BitmapData=null):void
      {
         if(b==null)b=front(loc);if(b==null)return;
         var s:Object=state(loc);if(s.restoring===true)return;
         b.lock();
         try {
            for(var k:String in s.cells) {
               if(keys!=null && keys[k]!==true)continue;
               var c:Object=s.cells[k];if(c.needsNative)continue;
               var values:Object={},key:String,base:Object=s.underlays==null?null:s.underlays[k];
               if(base!=null)for(key in base)values[key]=base[key];
               for(key in c.values)values[key]=c.values[key];
               var prediction:Object=s.authority===false?ordinaryPredictions(s,k,int(c.sv)):{};
               for(key in prediction)values[key]=prediction[key];
               for(key in values) {
                  var index:int=int(key),x:int=int(c.x)*CELL+index%CELL,y:int=int(c.y)*CELL+int(index/CELL);
                  if(x>=b.width || y>=b.height)continue;
                  var color:uint=uint(values[key]);
                  if(b.getPixel32(x,y)!=color){b.setPixel32(x,y,NativeWallColor.setter(color));dirty=true;}
               }
               if(base!=null)for(key in base)if(prediction[key]===undefined)delete base[key];
               if(loc===active && shadow!=null && bitmap===b)shadow.copyPixels(b,rect(c.x,c.y,b),new Point(c.x*CELL,c.y*CELL));
            }
         } finally {b.unlock();}
      }
      private function ordinaryIngest(loc:Object,list:Array):Object
      {
         var s:Object=state(loc),touched:Object={};
         for each(var c:Object in list) {
            var k:String=id(c.x,c.y),old:Object=s.cells[k];
            touched[k]=true;
            if(old!=null && (c.sv<old.sv || c.v<old.v || (c.v==old.v && old.needsNative!==true)))continue;
            if(old!=null && c.sv>old.sv && !c.full && !c.needsNative)continue;
            var next:Object={x:c.x,y:c.y,v:c.v,sv:c.sv,full:c.full,needsNative:c.needsNative,rebase:c.rebase,values:{},wire:null};
            if(!c.full && !c.needsNative && old!=null && old.sv==c.sv)for(var key:String in old.values)next.values[key]=old.values[key];
            for(var i:int=0;i<c.words.length;i+=2)next.values[String(c.words[i])]=uint(c.words[i+1]);
            s.cells[k]=next;revision=Math.max(revision,int(c.v),int(c.sv));s.incoming[k]=c.v;
            if(s.queued[k]!=null && s.queued[k].sv!=c.sv)delete s.queued[k];
         }
         return touched;
      }
      private function ordinarySettle(loc:Object,peer:String,request:Object):Object
      {
         if(request==null || !integer(request.seq) || int(request.seq)<=0)return null;
         var s:Object=state(loc);if(s.authority===false)return null;
         var last:Object=s.receipts[peer];
         if(last!=null && request.seq<=last.seq)return request.seq==last.seq?last:null;
         var list:Array=ordinaryDecode(loc,request.cells as Array,"report");if(list==null)return null;
         observe(loc);var accepted:Array=[],touched:Object={};
         for each(var entry:Object in list) {
            var k:String=id(entry.x,entry.y),c:Object=ordinaryCell(s,entry.x,entry.y);touched[k]=true;
            if(!c.needsNative && c.sv==entry.sv) {
               var wrote:Boolean=false;
               for(var i:int=0;i<entry.words.length;i+=2) {
                  var key:String=String(entry.words[i]),color:uint=uint(entry.words[i+1]);
                  if(c.values[key]!==color){c.values[key]=color;wrote=true;}
                  // The authority has already accepted its native local ink.
                  // A later peer ink wins over that unsent local queue too.
                  if(s.queued[k]!=null)delete s.queued[k].values[key];
               }
               if(wrote){c.v=nextRevision();c.wire=null;}
            }
            accepted.push(ordinaryPacked(c,true));
         }
         ordinaryCompose(loc,touched);
         var receipt:Object={seq:int(request.seq),cells:accepted};s.receipts[peer]=receipt;return receipt;
      }
      private function ordinaryAck(loc:Object,receipt:Object):void
      {
         var s:Object=state(loc);
         if(s.pending==null || receipt==null || !integer(receipt.seq) || receipt.seq!=s.pending.seq)return;
         var decoded:Array=ordinaryDecode(loc,receipt.cells as Array,"ack");if(decoded==null)return;
         if(decoded.length!=s.pending.cells.length)return;
         var touched:Object={};for each(var p:Object in s.pending.cells)touched[id(p.x,p.y)]=true;
         for each(var c:Object in decoded)if(touched[id(c.x,c.y)]!==true)return;
         observe(loc);s.pending=null;
         var wallReleaseClock:Object=TcpLink.wallAckTimingReleaseStart(receipt.seq);
         ordinaryIngest(loc,decoded);
         // Even a stale authority v can retire a seq. Always remove its actual
         // visual overlay, then reapply current confirmed + newer predictions.
         ordinaryCompose(loc,touched);
         TcpLink.wallAckTimingReleased(receipt.seq,s.queued,s.cells,wallReleaseClock);
      }
      private function ordinaryList(loc:Object,kind:String):Array
      {
         var s:Object=state(loc),keys:Array=[],out:Array=[],size:int=0;
         if(kind=="checkpoint" && (surfaces.ordinaryFailed || s.nativeFailure===true || s.rasterFailure===true))throw new Error("Unqualified native wall checkpoint");
         for(var k:String in s.cells) {
            var c:Object=s.cells[k];
            if(kind!="checkpoint" && c.needsNative)continue;
            if(kind=="updates" && s.sent[k]!=null && c.v<=s.sent[k])continue;
            keys.push(k);
         }
         keys.sort();if(!keys.length)return kind=="checkpoint"?[]:null;
         var cursor:int=kind=="snapshot"?int(s.cursor)%keys.length:0;
         for(var i:int=0;i<keys.length;i++) {
            c=s.cells[keys[cursor]];var wire:Object=ordinaryPacked(c,kind=="checkpoint");
            var length:int=wire.d==null?0:String(wire.d).length;
            if(kind!="checkpoint" && out.length && (out.length>=MAX_CELLS || size+length>MAX_WIRE))break;
            out.push(wire);size+=length;cursor=(cursor+1)%keys.length;
         }
         if(kind=="snapshot")s.cursor=cursor;
         return out.length?out:kind=="checkpoint"?[]:null;
      }
      public function prepareRestore(loc:Object,list:Array,authority:Boolean):void
      {
         ordinaryRole(loc,authority);
         if(list!=null && list.length && list[0]!=null && list[0].sv!==undefined)state(loc).ordinary=true;
         if(!ordinary(loc)){state(loc).restoreList=list || [];return;}
         var decoded:Array=ordinaryDecode(loc,list || [],"checkpoint");
         if(decoded==null)throw new Error("Invalid ordinary wall checkpoint");
         surfaces.restored(loc);
         rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},sent:{},cursor:0,ordinary:true,authority:authority,underlays:{},restoring:true};
         ordinaryIngest(loc,decoded);
      }
      public function finishRestore(loc:Object):Boolean
      {
         var s:Object=state(loc);
         if(s.restoreList is Array) {
            var list:Array=s.restoreList;delete s.restoreList;
            if(!ordinary(loc)){restore(loc,list);return true;}
            prepareRestore(loc,list,s.authority!==false);s=state(loc);
         }
         s.restoring=false;
         if(hasNeedsNative(loc))return false;
         ordinaryCompose(loc);return true;
      }
      public function hasNeedsNative(loc:Object):Boolean
      {var s:Object=state(loc);if((ordinary(loc) && surfaces.ordinaryFailed) || s.nativeFailure===true || s.rasterFailure===true)return true;for each(var c:Object in s.cells)if(c.needsNative===true)return true;return false;}
      private function structureKeys(loc:Object,bounds:Rectangle):Object
      {
         if(bounds==null || !isFinite(bounds.x+bounds.y+bounds.width+bounds.height) || bounds.width<0 || bounds.height<0)throw new Error("Invalid structural wall bounds");
         var out:Object={},r:Rectangle=bounds.intersection(new Rectangle(0,0,int(loc.spaceX)*CELL,int(loc.spaceY)*CELL));
         if(r.isEmpty())return out;
         for(var x:int=int(Math.floor(r.x/CELL));x<Math.ceil(r.right/CELL);x++)for(var y:int=int(Math.floor(r.y/CELL));y<Math.ceil(r.bottom/CELL);y++)out[id(x,y)]={x:x,y:y};
         return out;
      }
      public function structurePending(loc:Object,bounds:Rectangle):void
      {
         var s:Object=state(loc);if(!ordinary(loc) || s.authority===false)return;
         var keys:Object=structureKeys(loc,bounds);
         for(var k:String in keys) {
            var c:Object=ordinaryCell(s,keys[k].x,keys[k].y);c.v=c.sv=nextRevision();c.full=false;c.needsNative=true;c.rebase=true;c.values={};c.wire=null;
            delete s.queued[k];if(s.underlays!=null)delete s.underlays[k];
         }
      }
      public function structureComplete(loc:Object,b:BitmapData,bounds:Rectangle,rebase:Boolean=true):void
      {
         var s:Object=state(loc),g:Object=get(loc,"grafon");
         if(!ordinary(loc) || s.authority===false || b==null || get(g,"loc")!==loc || get(g,"frontBmp")!==b)throw new Error("Invalid structural wall authority surface");
         var keys:Object=structureKeys(loc,bounds);
         // Validate the whole requested cell set before modifying any state.
         for(var k:String in keys)if(rect(keys[k].x,keys[k].y,b).width!=CELL || rect(keys[k].x,keys[k].y,b).height!=CELL)throw new Error("Incomplete native structural cell");
         for(k in keys) {
            var c:Object=ordinaryCell(s,keys[k].x,keys[k].y),r:Rectangle=rect(c.x,c.y,b),pixels:Vector.<uint>=b.getVector(r);
            c.v=c.sv=nextRevision();c.full=true;c.needsNative=false;c.rebase=rebase;c.values={};c.wire=null;
            for(var i:int=0;i<pixels.length;i++)c.values[String(i)]=pixels[i];
            delete s.queued[k];if(s.underlays!=null)delete s.underlays[k];
            if(active===loc && bitmap===b && shadow!=null)shadow.copyPixels(b,r,new Point(r.x,r.y));
         }
      }
      public function nativeRaster(loc:Object,b:BitmapData,success:Boolean):Boolean
      {
         var s:Object=state(loc);
         if(!success){s.rasterFailure=true;return false;}
         if(!ordinary(loc) || b==null || get(get(loc,"grafon"),"loc")!==loc || get(get(loc,"grafon"),"frontBmp")!==b)return false;
         s.rasterFailure=false;
         if(s.authority!==false) {
            var work:Array=[];for each(var c:Object in s.cells)if(c.needsNative || c.rebase)work.push(new Rectangle(c.x*CELL,c.y*CELL,CELL,CELL));
            for each(var r:Rectangle in work)structureComplete(loc,b,r,false);
         }
         s.restoring=false;ordinaryCompose(loc,null,b);
         if(active===loc){if(shadow!=null){shadow.dispose();shadow=null;}bitmap=b;shadow=copyFront(loc,b,"nativeRaster");}
         return !hasNeedsNative(loc) && s.nativeFailure!==true;
      }
      /** Transport close does not erase offline structural history. */
      public function endSession():void
      {
         for(var loc:Object in rooms) {
            if(!ordinary(loc)){delete rooms[loc];continue;}
            roleChanged(loc);state(loc).authority=true;
         }
         surfaces.networkActive=false;
         surfaces.reset();surfaceOrder=0;
         if(shadow!=null)shadow.dispose();shadow=null;bitmap=null;active=null;
         tracked=[];contacts=new Dictionary(true);tileState={};dirty=false;
         wordCache=new Dictionary();wordOrder=[];wordCount=0;wordChars=0;
      }
      private function ordinaryNative(event:Object):Object
      {
         if(event==null || event.loc==null)return null;
         var loc:Object=event.loc,g:Object=event.grafon,s:Object=state(loc),kind:String=String(event.kind);
         if(get(g,"loc")===loc)s.ordinary=get(g,"sceneLarge")!==true;
         if(s.ordinary===false)return null;
         if(s.ordinary!==true && event.ordinaryPhysical!==true)return null;
         s.ordinary=true;
         var b:BitmapData=event.bitmap as BitmapData,r:Rectangle=event.bounds as Rectangle;
         if(kind=="raster-failed"){s.rasterFailure=true;return null;}
         if(kind=="ink-failed" || kind=="structure-failed"){s.nativeFailure=true;return null;}
         if(kind=="raster")return {ready:nativeRaster(loc,b,true)};
         if(kind=="structure-prepare")return {loc:loc,state:s,tile:event.tile,bounds:r==null?null:r.clone(),valid:event.valid!==false && r!=null};
         if(kind=="structure-before") {
            if(event.ordinaryPhysical!==true)return null;
            var prepared:Object=event.token,valid:Boolean=event.valid!==false && prepared!=null && prepared.loc===loc && prepared.state===s && prepared.tile===event.tile && prepared.valid===true && prepared.bounds is Rectangle;
            if(valid)r=r==null?prepared.bounds.clone():r.union(prepared.bounds);
            if(!valid && s.authority!==false)s.nativeFailure=true;
            return {allow:s.authority!==false,token:{loc:loc,state:s,bitmap:b,bounds:r,valid:valid,authority:s.authority!==false}};
         }
         if(kind=="structure-pending") {
            if(event.ordinaryPhysical===true && s.authority!==false) {
               if(event.valid===false || r==null || event.token==null || event.token.state!==s)s.nativeFailure=true;
               else structurePending(loc,r);
            }
            return null;
         }
         if(kind=="structure-after") {
            var t:Object=event.token;
            if(t!=null && t.loc===loc && t.state===s && t.authority===true && t.valid===true && t.bitmap===b && event.valid!==false && event.written!==false)structureComplete(loc,b,t.bounds,true);
            return null;
         }
         if(kind=="ink-before") {
            if(event.valid===false){s.nativeFailure=true;return null;}
            if(get(g,"loc")!==loc || b==null || get(g,"frontBmp")!==b || r==null)return null;
            before(loc);
            // Snapshot this native operation immediately, not an entire cell
            // against the long-lived shadow. Excluded gwall/mat7 writes may
            // already exist elsewhere (or unchanged inside) this same cell.
            var keys:Object=structureKeys(loc,r),pieces:Array=[];
            r=new Rectangle(Math.floor(r.x),Math.floor(r.y),Math.ceil(r.right)-Math.floor(r.x),Math.ceil(r.bottom)-Math.floor(r.y)).intersection(b.rect);
            for each(var xy:Object in keys) {
               var part:Rectangle=rect(xy.x,xy.y,b).intersection(r);
               if(part.isEmpty())continue;
               var local:Rectangle=part.clone();local.offset(-xy.x*CELL,-xy.y*CELL);
               pieces.push({x:xy.x,y:xy.y,rect:part,local:local,old:b.getVector(part)});
            }
            return {token:{loc:loc,state:s,bitmap:b,pieces:pieces}};
         }
         if(kind=="ink-after") {
            t=event.token;if(t==null || t.loc!==loc || t.state!==s || t.bitmap!==b || bitmap!==b || shadow==null || !(t.pieces is Array))return null;
            pieces=t.pieces;t.pieces=null;
            for each(var piece:Object in pieces) {
               var old:Vector.<uint>=piece.old,fresh:Vector.<uint>=b.getVector(piece.rect),changed:Boolean=false;
               for(var i:int=0;i<fresh.length;i++)if(old[i]!=fresh[i]){changed=true;break;}
               if(changed)ordinaryCapture(loc,piece.x,piece.y,piece.local,old,fresh);
               shadow.copyPixels(b,piece.rect,new Point(piece.rect.x,piece.rect.y));piece.old=null;
            }
         }
         return null;
      }

      public function reset():void
      {
         surfaces.reset();surfaceOrder=0;
         if(shadow!=null)shadow.dispose();shadow=null;bitmap=null;active=null;
         rooms=new Dictionary(true);tracked=[];contacts=new Dictionary(true);tileState={};dirty=false;
         wordCache=new Dictionary();wordOrder=[];wordCount=0;wordChars=0;
      }
   }
}
