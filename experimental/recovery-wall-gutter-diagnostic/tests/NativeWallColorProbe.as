package {
   import flash.display.BitmapData;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** External, read-only diagnostic. Sampling copies just one real 40x40
    * world cell from each existing overlapping native buffer. Pixel readback
    * happens only in exportEvidence after BOTH peers ended action sampling. */
   public final class NativeWallColorProbe {
      private static const MAX_PACKETS:int=96,MAX_SNAPSHOTS:int=210,MAX_SURFACES:int=4;
      private var links:Dictionary=new Dictionary(),pending:Dictionary=new Dictionary(true);
      private var grafon:Object,location:Object,cell:Rectangle,active:Boolean=false;
      private var frame:int=0,round:int=-1,source:Boolean=false,role:String;
      private var snapshots:Array=[],packets:Array=[],errors:Array=[];
      public function attach(link:TcpLink):void {
         if(link==null||links[link])return;links[link]=true;
         link.addEventListener(TcpLink.MESSAGE,beforeMessage,false,100000);
         link.addEventListener(TcpLink.MESSAGE,afterMessage,false,-100000);
      }
      public function begin(n:int,target:Object,g:Object,isSource:Boolean,name:String):void {
         disposeSnapshots();packets=[];errors=[];pending=new Dictionary(true);frame=0;
         round=n;source=isSource;role=name;grafon=g;location=g.loc;active=n==2;
         cell=new Rectangle(int(target.x/40)*40,int(target.y/40)*40,40,40);
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
            var cut:Rectangle=cell.intersection(new Rectangle(s.x,s.y,b.width,b.height));
            if(cut.isEmpty())continue;
            if(row.surfaces.length>=MAX_SURFACES)throw new Error("diagnostic overlap capacity exceeded");
            var copy:BitmapData=new BitmapData(cut.width,cut.height,true,0);
            row.surfaces.push({order:order,x:Number(s.x),y:Number(s.y),side:int(s.side),gutter:int(s.gutter),
               revision:int(s.revision),cut:{x:cut.x,y:cut.y,w:cut.width,h:cut.height},bitmap:copy});
            copy.copyPixels(b,new Rectangle(cut.x-s.x,cut.y-s.y,cut.width,cut.height),new Point());
         }
         if(row.surfaces.length==0)throw new Error("diagnostic cell has no real resident surface");
         row.cost=getTimer()-start;return int(row.seq);
      }
      private function selectedCells(p:Object):Array {
            var cells:Array=p.wallPaint is Array?p.wallPaint as Array:p.wall is Array?p.wall as Array:null;
            if(cells==null)return [];
            var selected:Array=[];
            for each(var c:Object in cells)if(int(c.x)==int(cell.x/40)&&int(c.y)==int(cell.y/40)) {
               if(!(c.d is String)||String(c.d).length>13340)throw new Error("diagnostic raw cell exceeds known codec bounds");
               // Exact immutable string and scalar version; do not call any
               // production capture/report/receive or decode on this hot path.
               selected.push({x:c.x,y:c.y,v:c.v,d:c.d});
            }
            return selected;
      }
      private function beforeMessage(e:NetMessageEvent):void {
         if(!active)return;
         try {
            var p:Object=e.data,selected:Array=selectedCells(p);
            if(selected.length==0)return;
            if(packets.length>=MAX_PACKETS)throw new Error("diagnostic packet capacity exceeded");
            var row:Object={seq:packets.length,at:getTimer(),wall:new Date().time,frame:frame,type:String(p.type),
               cells:selected,before:-1,after:-1,multipleCellsUnknown:selected.length>1};
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
      public function exportEvidence():Object {
         // Called after both action samplers stop, immediately before the
         // original proof JSON write. No disk or PNG calls in this helper.
         var start:int=getTimer(),out:Array=[];
         for each(var row:Object in snapshots) {
            var item:Object={seq:row.seq,kind:row.kind,at:row.at,wall:row.wall,frame:row.frame,
               cost:row.cost,hits:row.hits,sameFrameHitOrderUnknown:row.sameFrameHitOrderUnknown,surfaces:[]};
            for each(var s:Object in row.surfaces) {
               var values:Array=[];for each(var value:uint in BitmapData(s.bitmap).getVector(s.bitmap.rect))values.push(Number(value));
               item.surfaces.push({order:s.order,x:s.x,y:s.y,side:s.side,gutter:s.gutter,revision:s.revision,cut:s.cut,words:values});
            }
            out.push(item);
         }
         return {schema:1,diagnosticOnly:true,round:round,role:role,source:source,active:round==2,
            cell:{x:cell.x,y:cell.y,w:cell.width,h:cell.height},snapshots:out,packets:packets,
            errors:errors.concat(),readbackMs:getTimer()-start,
            nativeImpactOrderObserved:false,socketSendTimeObserved:false,rawMessageBeforeProduction:true,
            maxPackets:MAX_PACKETS,maxSnapshots:MAX_SNAPSHOTS,maxSurfaces:MAX_SURFACES};
      }
      public function stopSampling():void {active=false;}
      private function disposeSnapshots():void {
         for each(var row:Object in snapshots)for each(var s:Object in row.surfaces)BitmapData(s.bitmap).dispose();snapshots=[];
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
