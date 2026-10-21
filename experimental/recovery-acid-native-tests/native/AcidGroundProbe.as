package {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;

   /** Read actual native Part objects. Never calls a production receiver,
    * emitter or particle step. Bitmap readback/encoding happens after expiry. */
   public class AcidGroundProbe {
      private var mod:Object,room:Object,source:Boolean,round:int,acidClass:Class;
      private var old:Dictionary=new Dictionary(),tracked:Dictionary=new Dictionary();
      private var rows:Array=[],withPart:BitmapData,withoutPart:BitmapData,pixelMeta:Object;
      public var overflow:Boolean=false;
      public var lastBirth:int=0;
      public function AcidGroundProbe(m:Object,isSource:Boolean,n:int) {
         mod=m;room=m.game.loc;source=isSource;round=n;
         var emitter:Object=m.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr.acid;
         if(emitter==null || emitter.visClass==null)throw new Error("Native acid Part resource missing");
         acidClass=emitter.visClass as Class;
         var guard:int=0;
         for(var o:Object=room.firstObj;o!=null && guard++<20000;o=o.nobj)old[o]=true;
         if(guard>=20000)throw new Error("Native object chain exceeds fixture bound");
      }
      public function get count():int {return rows.length;}
      public function get allEnded():Boolean {
         if(rows.length==0)return false;
         for each(var row:Object in rows)if(row.removedFrame<0)return false;
         return true;
      }
      private function surface(x:Number,y:Number):Object {
         var tx:int=int(Math.floor(x/40)),ty:int=int(Math.round(y/40));
         if(tx<0 || ty<2 || tx>=room.spaceX || ty>=room.spaceY)return null;
         var t:Object=room.space[tx][ty],above:Object=room.space[tx][ty-1];
         return {tx:tx,ty:ty,x:(tx+.5)*40,y:Number(t.phY1),phis:Number(t.phis),shelf:t.shelf===true,
            zForm:Number(t.zForm),above:Number(above.phis),water:Number(above.water)};
      }
      public function scan(frame:int):void {
         var guard:int=0,now:int=getTimer();
         for(var o:Object=room.firstObj;o!=null && guard++<20000;o=o.nobj) {
            if(old[o] || getQualifiedClassName(o)!="fe.graph::Part" || o.vClass!==acidClass)continue;
            var row:Object=tracked[o];
            if(row==null) {
               if(rows.length>=256){overflow=true;continue;}
               row={id:rows.length,x:Number(o.X),y:Number(o.Y),bornFrame:frame,bornAt:now,
                  mliv:int(o.mliv),firstLiv:int(o.liv),lastLiv:int(o.liv),partClass:getQualifiedClassName(o),
                  visualClass:getQualifiedClassName(o.vis),surface:source?surface(Number(o.X),Number(o.Y)):null,
                  removedFrame:-1,detached:false,seen:0,alphaMin:1,alphaMax:0,animated:false,
                  firstVisualFrame:o.vis is MovieClip?MovieClip(o.vis).currentFrame:-1,stable:true};
               tracked[o]=row;rows.push(row);lastBirth=now;
            }
            row.seen++;row.lastLiv=int(o.liv);row.lastFrame=frame;
            row.stable=row.stable && Math.abs(Number(o.X)-row.x)<.01 && Math.abs(Number(o.Y)-row.y)<.01;
            var v:DisplayObject=o.vis as DisplayObject;
            if(v!=null) {
               row.alphaMin=Math.min(row.alphaMin,v.alpha);row.alphaMax=Math.max(row.alphaMax,v.alpha);
               if(v is MovieClip && MovieClip(v).currentFrame!=row.firstVisualFrame)row.animated=true;
               if(withPart==null && v.visible && v.stage!=null && v.alpha>=.5)capturePixels(v,row,frame);
            }
         }
         if(guard>=20000)overflow=true;
         for(o in tracked) {
            row=tracked[o];
            if(row.removedFrame<0 && o.in_chain!==true) {
               row.removedFrame=frame;row.removedAt=now;row.finalLiv=int(o.liv);
               row.detached=o.vis==null || o.vis.parent==null || o.vis.stage==null;
            }
         }
      }
      private function capturePixels(v:DisplayObject,row:Object,frame:int):void {
         var root:DisplayObject=mod.main as DisplayObject;
         var r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return;
         withPart=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0);
         withoutPart=withPart.clone();var matrix:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),visible:Boolean=v.visible;
         try {withPart.draw(root,matrix);v.visible=false;withoutPart.draw(root,matrix);}
         finally {v.visible=visible;}
         pixelMeta={part:row.id,frame:frame,at:getTimer(),bounds:{x:r.x,y:r.y,w:r.width,h:r.height},pixels:0};
      }
      private function write(file:File,bytes:ByteArray,text:String=null):void {
         var stream:FileStream=new FileStream();stream.open(file,FileMode.WRITE);
         try {if(text!=null)stream.writeUTFBytes(text);else stream.writeBytes(bytes);}
         finally {stream.close();}
      }
      public function result():Object {
         var folder:File=File.applicationStorageDirectory.resolvePath("acid-ground-proof");folder.createDirectory();
         var prefix:String="round-"+round;
         if(withPart!=null) {
            // No getVector(), PNG encoding or file output in ENTER_FRAME/RENDER.
            var a:Vector.<uint>=withPart.getVector(withPart.rect),b:Vector.<uint>=withoutPart.getVector(withoutPart.rect);
            for(var i:int=0;i<a.length;i++)if(a[i]!=b[i])pixelMeta.pixels++;
            write(folder.resolvePath(prefix+"-with.png"),withPart.encode(withPart.rect,new PNGEncoderOptions()));
            write(folder.resolvePath(prefix+"-without.png"),withoutPart.encode(withoutPart.rect,new PNGEncoderOptions()));
         }
         var data:Object={round:round,source:source,rows:rows,overflow:overflow,pixel:pixelMeta,
            allEnded:allEnded,readbackAt:getTimer(),proofDirectory:folder.nativePath};
         write(folder.resolvePath(prefix+"-proof.json"),null,JSON.stringify(data));dispose();return data;
      }
      public function dispose():void {
         if(withPart!=null){withPart.dispose();withPart=null;}
         if(withoutPart!=null){withoutPart.dispose();withoutPart=null;}
      }
   }
}
