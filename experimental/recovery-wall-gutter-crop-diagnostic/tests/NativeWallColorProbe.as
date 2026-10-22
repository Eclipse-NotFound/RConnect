package {
   import flash.display.BitmapData;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   import flash.utils.Endian;
   import flash.utils.getTimer;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** External, read-only diagnostic. Sampling copies the exact real 128x128
    * world crop from each existing overlapping native buffer. Pixel readback
    * happens only in exportEvidence after BOTH peers ended action sampling. */
   public final class NativeWallColorProbe {
      private static const MAX_PACKETS:int=96,MAX_SNAPSHOTS:int=210,MAX_SURFACES:int=4;
      private static const MAX_WIRE_CELLS:int=25,MAX_WIRE_CHARS:int=1280640,MAX_DATA_CHARS:int=6291456;
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      private var wireChars:int=0;
      private var links:Dictionary=new Dictionary(),pending:Dictionary=new Dictionary(true);
      private var grafon:Object,location:Object,crop:Rectangle,active:Boolean=false;
      private var frame:int=0,round:int=-1,source:Boolean=false,role:String;
      private var snapshots:Array=[],packets:Array=[],errors:Array=[];
      public function attach(link:TcpLink):void {
         if(link==null||links[link])return;links[link]=true;
         link.addEventListener(TcpLink.MESSAGE,beforeMessage,false,100000);
         link.addEventListener(TcpLink.MESSAGE,afterMessage,false,-100000);
      }
      public function begin(n:int,target:Object,g:Object,isSource:Boolean,name:String):void {
         disposeSnapshots();packets=[];errors=[];pending=new Dictionary(true);frame=0;
         wireChars=0;round=n;source=isSource;role=name;grafon=g;location=g.loc;active=n==2;
         crop=new Rectangle(target.x-64,target.y-64,128,128);
         if(active)observe("baseline",null);
      }
      public function nextFrame():void {if(active)frame++;}
      private function error(value:*):void {if(errors.length<16)errors.push(String(value));}
      public function observe(kind:String,hits:Array):void {
         if(!active)return;
         try {capture(kind,hits);}catch(e:*){error(e);}
      }
      private function capture(kind:String,hits:Array=null):int {
         if(snapshots.length>=MAX_SNAPSHOTS)throw new Error("diagnostic snapshot capacity exceeded");
         if(grafon.loc!==location)throw new Error("diagnostic location changed");
         var start:int=getTimer(),row:Object={seq:snapshots.length,kind:kind,at:start,wall:new Date().time,
            frame:frame,hits:hits==null?[]:hits.concat(),sameFrameHitOrderUnknown:hits!=null&&hits.length>1,surfaces:[]};
         snapshots.push(row);
         var list:Array=grafon.sceneSurfaces();
         for(var order:int=0;order<list.length;order++) {
            var s:Object=list[order],b:BitmapData=s.nativeBuffers[0] as BitmapData;
            if(b==null)continue;
            var cut:Rectangle=crop.intersection(new Rectangle(s.x,s.y,b.width,b.height));
            if(cut.isEmpty())continue;
            if(row.surfaces.length>=MAX_SURFACES)throw new Error("diagnostic overlap capacity exceeded");
            var copy:BitmapData=new BitmapData(cut.width,cut.height,true,0);
            row.surfaces.push({order:order,x:Number(s.x),y:Number(s.y),side:int(s.side),gutter:int(s.gutter),
               revision:int(s.revision),bufferWidth:b.width,bufferHeight:b.height,cut:{x:cut.x,y:cut.y,w:cut.width,h:cut.height},bitmap:copy});
            copy.copyPixels(b,new Rectangle(cut.x-s.x,cut.y-s.y,cut.width,cut.height),new Point());
         }
         if(row.surfaces.length==0)throw new Error("diagnostic cell has no real resident surface");
         row.cost=getTimer()-start;return int(row.seq);
      }
      private function selectedCells(p:Object):Array {
         var cells:Array=p.wallPaint is Array?p.wallPaint as Array:p.wall is Array?p.wall as Array:null;
         if(cells==null)return [];
         var selected:Array=[],seen:Object={};
         for each(var c:Object in cells) {
            if(!crop.intersects(new Rectangle(int(c.x)*40,int(c.y)*40,40,40)))continue;
            var key:String=int(c.x)+","+int(c.y);
            if(seen[key])throw new Error("diagnostic duplicate actual wire cell");seen[key]=true;
            if(selected.length>=MAX_WIRE_CELLS)throw new Error("diagnostic selected cell capacity exceeded");
            if(!(c.d is String)||String(c.d).length>13340)throw new Error("diagnostic raw cell exceeds known codec bounds");
            // Exact original strings/scalars. No production capture or decoding.
            selected.push({x:c.x,y:c.y,v:c.v,d:c.d});
         }
         return selected;
      }
      private function beforeMessage(e:NetMessageEvent):void {
         if(!active)return;
         try {
            var p:Object=e.data,selected:Array=selectedCells(p);
            if(selected.length==0)return;
            for each(var c:Object in selected)wireChars+=String(c.d).length;
            if(wireChars>MAX_WIRE_CHARS)throw new Error("diagnostic raw message aggregate capacity exceeded");
            if(packets.length>=MAX_PACKETS)throw new Error("diagnostic packet capacity exceeded");
            var row:Object={seq:packets.length,at:getTimer(),wall:new Date().time,frame:frame,type:String(p.type),
               cells:selected,before:-1,after:-1,duplicateCellsUnknown:false};
            packets.push(row);pending[e]=row;
            row.before=capture("wire-before");
         }catch(err:*){error(err);}
      }
      private function afterMessage(e:NetMessageEvent):void {
         var row:Object=pending[e];if(row==null)return;delete pending[e];
         try {
            row.after=capture("wire-after");row.afterCells=selectedCells(e.data);
            row.rawUnchanged=row.cells.length==row.afterCells.length;
            for(var i:int=0;i<row.cells.length&&row.rawUnchanged;i++) {
               var a:Object=row.cells[i],b:Object=row.afterCells[i];
               row.rawUnchanged=a.x===b.x&&a.y===b.y&&a.v===b.v&&a.d===b.d;
            }
         }catch(err:*){error(err);}
      }
      private static function encoded(bytes:ByteArray):String {
         bytes.compress();bytes.position=0;
         if(bytes.length>70000)throw new Error("diagnostic compressed uint block exceeds bound");
         var out:Array=[];
         while(bytes.bytesAvailable) {
            var left:int=bytes.bytesAvailable,a:int=bytes.readUnsignedByte();
            var b:int=left>1?bytes.readUnsignedByte():0,c:int=left>2?bytes.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(b>>4))+
               (left>1?DIGITS.charAt(((b&15)<<2)|(c>>6)):"=")+(left>2?DIGITS.charAt(c&63):"="));
         }
         return out.join("");
      }
      public function exportEvidence():Object {
         // Called after BOTH action samplers stop. Preserve exact native uint,
         // not PNG/premultiplied encoder colors. No compression during sampling.
         var start:int=getTimer(),out:Array=[],encodedChars:int=0;
         for each(var row:Object in snapshots) {
            var item:Object={seq:row.seq,kind:row.kind,at:row.at,wall:row.wall,frame:row.frame,
               cost:row.cost,hits:row.hits,sameFrameHitOrderUnknown:row.sameFrameHitOrderUnknown,surfaces:[]};
            for each(var s:Object in row.surfaces) {
               var values:Vector.<uint>=BitmapData(s.bitmap).getVector(s.bitmap.rect);
               var bytes:ByteArray=new ByteArray();bytes.endian=Endian.BIG_ENDIAN;
               for each(var value:uint in values)bytes.writeUnsignedInt(value);
               var rawBytes:int=bytes.length,data:String=encoded(bytes);encodedChars+=data.length;
               if(encodedChars>MAX_DATA_CHARS)throw new Error("diagnostic uint data aggregate capacity exceeded");
               item.surfaces.push({order:s.order,x:s.x,y:s.y,side:s.side,gutter:s.gutter,revision:s.revision,
                  bufferWidth:s.bufferWidth,bufferHeight:s.bufferHeight,cut:s.cut,
                  encoding:"u32be-zlib-base64",wordCount:values.length,rawBytes:rawBytes,compressedBytes:bytes.length,data:data});
               values=null;bytes.clear();BitmapData(s.bitmap).dispose();s.bitmap=null;
            }
            out.push(item);
         }
         return {schema:2,diagnosticOnly:true,round:round,role:role,source:source,active:round==2,
            crop:{x:crop.x,y:crop.y,w:crop.width,h:crop.height},snapshots:out,packets:packets,
            errors:errors.concat(),readbackMs:getTimer()-start,encodedChars:encodedChars,wireChars:wireChars,
            nativeImpactOrderObserved:false,socketSendTimeObserved:false,rawMessageBeforeProduction:true,
            maxPackets:MAX_PACKETS,maxSnapshots:MAX_SNAPSHOTS,maxSurfaces:MAX_SURFACES,
            maxWireCells:MAX_WIRE_CELLS,maxWireChars:MAX_WIRE_CHARS,maxDataChars:MAX_DATA_CHARS};
      }
      public function stopSampling():void {active=false;}
      private function disposeSnapshots():void {
         for each(var row:Object in snapshots)for each(var s:Object in row.surfaces)if(s.bitmap!=null)BitmapData(s.bitmap).dispose();snapshots=[];
      }
      public function close():void {
         active=false;disposeSnapshots();
         for(var key:Object in links) {
            var link:TcpLink=key as TcpLink;
            link.removeEventListener(TcpLink.MESSAGE,beforeMessage);link.removeEventListener(TcpLink.MESSAGE,afterMessage);
         }
         links=new Dictionary();pending=new Dictionary(true);grafon=location=null;
      }
   }
}
