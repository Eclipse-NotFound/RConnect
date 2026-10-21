package {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
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

   /** Read-only native Part, production packet and displayed clip observations.
    * Never calls a production capture/receive/tick, Emitter or native step. */
   public class GasPulseProbe {
      private var mod:Object,room:Object,source:Boolean,round:int,gasClass:Class;
      private var old:Dictionary=new Dictionary(),native:Dictionary=new Dictionary(),shown:Dictionary=new Dictionary();
      private var nativeRows:Array=[],visualRows:Array=[],wireRows:Array=[],byWire:Object={};
      private var withPart:BitmapData,withoutPart:BitmapData,pixel:Object;
      public var overflow:Boolean=false,lastBirth:int=0,lastActivity:int=0;
      private var frameLo:int=0,frameHi:int=0;
      /** Bracket GameBridge's 90000-priority source stamp without reading or
       * advancing its private clock. These are bounds, not a playback cursor. */
      public function beginFrame(before:Boolean):void {if(before)frameLo=getTimer();else frameHi=getTimer();}
      public function GasPulseProbe(m:Object,isSource:Boolean,n:int) {
         mod=m;room=m.game.loc;source=isSource;round=n;
         var emitter:Object=m.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr.gas;
         if(emitter==null || emitter.visClass==null)throw new Error("Native gas Part resource missing");
         gasClass=emitter.visClass as Class;
         var guard:int=0;
         for(var o:Object=room.firstObj;o!=null && guard++<20000;o=o.nobj)old[o]=true;
         if(guard>=20000)throw new Error("Native object chain exceeds fixture bound");
         for each(var layer:DisplayObjectContainer in m.game.world.grafon.visObjs)
            if(layer!=null)for(var i:int=0;i<layer.numChildren;i++)old[layer.getChildAt(i)]=true;
      }
      public function get count():int{return source?nativeRows.length:visualRows.length;}
      public function get allEnded():Boolean {
         var rows:Array=source?nativeRows:visualRows;if(rows.length==0)return false;
         for each(var row:Object in rows)if(row.endAt==0)return false;
         return true;
      }
      private function pose(v:DisplayObject,now:int,frame:int):Object {
         var color:Object=v.transform.colorTransform;
         return {at:now,wall:new Date().time,x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,
            f:v is MovieClip?MovieClip(v).currentFrame:1,visible:v.visible,frame:frame,sourceLo:frameLo,sourceHi:frameHi,
            c:[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,
               color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset]};
      }
      private function record(v:DisplayObject,frame:int,now:int):void {
         if(v==null || old[v])return;
         var row:Object=shown[v];
         if(row==null) {
            if(visualRows.length>=96){overflow=true;return;}
            row={id:visualRows.length,cls:getQualifiedClassName(v),bornAt:now,bornWall:new Date().time,
               bornFrame:frame,endAt:0,endWall:0,alphaMin:1,alphaMax:0,samples:[]};
            shown[v]=row;visualRows.push(row);lastBirth=lastActivity=now;
         }
         if(row.endAt>0)row.reappeared=true;
         row.alphaMin=Math.min(row.alphaMin,v.alpha);row.alphaMax=Math.max(row.alphaMax,v.alpha);
         var sample:Object=pose(v,now,frame);
         if(row.samples.length>0 && row.samples[row.samples.length-1].frame==frame)row.samples[row.samples.length-1]=sample;
         else if(row.samples.length<128)row.samples.push(sample);else overflow=true;
         if(withPart==null && v.visible && v.stage!=null && v.alpha>=.5)capturePixels(v,row,frame);
      }
      public function scan(frame:int):void {
         if(mod.game.loc!==room)throw new Error("Gas fixture changed room during trial");
         var now:int=getTimer(),guard:int=0;
         for(var o:Object=room.firstObj;o!=null && guard++<20000;o=o.nobj) {
            if(old[o] || getQualifiedClassName(o)!="fe.graph::Part" || o.vClass!==gasClass)continue;
            var row:Object=native[o];
            if(row==null) {
               if(nativeRows.length>=96){overflow=true;continue;}
               row={id:nativeRows.length,partClass:getQualifiedClassName(o),cls:getQualifiedClassName(o.vis),
                  bornAt:now,bornWall:new Date().time,bornFrame:frame,mliv:int(o.mliv),firstLiv:int(o.liv),
                  x:Number(o.X),y:Number(o.Y),bornLo:frameLo,bornHi:frameHi,endAt:0,endWall:0,finalLiv:null,visual:-1};
               native[o]=row;nativeRows.push(row);lastBirth=lastActivity=now;
            }
            if(row.endAt>0)row.reappeared=true;
            if(source) {record(o.vis as DisplayObject,frame,now);if(shown[o.vis]!=null)row.visual=shown[o.vis].id;}
         }
         if(guard>=20000)overflow=true;
         if(!source)for each(var layer:DisplayObjectContainer in mod.game.world.grafon.visObjs)
            if(layer!=null)for(var i:int=0;i<layer.numChildren;i++) {
               var v:DisplayObject=layer.getChildAt(i);
               if(Object(v).constructor===gasClass)record(v,frame,now);
            }
         for(o in native)if(native[o].endAt==0 && o.in_chain!==true) {
            row=native[o];row.endAt=now;row.endWall=new Date().time;row.endFrame=frame;row.finalLiv=int(o.liv);
            row.endLo=frameLo;row.endHi=frameHi;lastActivity=now;
         }
         for(o in shown)if(shown[o].endAt==0 && (o.parent==null || o.stage==null)) {
            row=shown[o];row.endAt=now;row.endWall=new Date().time;row.endFrame=frame;lastActivity=now;
         }
      }
      public function observePacket(message:Object):void {
         if(source || message==null)return;
         if(message.type=="playerstate")snapshot(message.snap);
         else if(message.type=="worldstate" && message.players is Array)
            for each(var player:Object in message.players)if(int(player.id)!=int(mod.session.myId))snapshot(player.snap);
      }
      private function snapshot(s:Object):void {
         if(s==null || !(s.weapons is Array))return;
         for each(var gun:Object in s.weapons) {
            if(gun.id!="@room-gas" || gun.roomParts!==true || !(gun.impacts is Array))continue;
            for each(var event:Object in gun.impacts) {
               if(event.cls!="visualGas")continue;
               lastActivity=getTimer();
               var key:String=String(gun.stream)+":"+String(event.id),row:Object=byWire[key];
               if(row==null) {
                  if(wireRows.length>=96){overflow=true;continue;}
                  row={key:key,firstAt:getTimer(),firstWall:new Date().time,packets:0,end:0,strictEnd:true,
                     roomKey:String(s.roomKey),roomEpoch:int(s.roomEpoch),frames:[]};byWire[key]=row;wireRows.push(row);
               }
               row.packets++;row.strictEnd=row.strictEnd && event.strictEnd===true;
               if(int(event.end)>0) {
                  if(row.end>0 && row.end!=int(event.end))row.endChanged=true;
                  if(row.end==0){row.endReceivedAt=getTimer();row.endReceivedWall=new Date().time;}
                  row.end=int(event.end);
               }
               for each(var frame:Object in event.frames) {
                  var prior:Object=row.frames.length?row.frames[row.frames.length-1]:null;
                  if(prior!=null && frame.at<prior.at){row.outOfOrder=true;continue;}
                  // Retain the actual received scalar fields, never mutate the packet.
                  var copy:Object={};for(var k:String in frame)copy[k]=frame[k];
                  if(prior!=null && frame.at==prior.at)row.frames[row.frames.length-1]=copy;
                  else if(row.frames.length<128)row.frames.push(copy);else overflow=true;
               }
            }
         }
      }
      private function capturePixels(v:DisplayObject,row:Object,frame:int):void {
         var root:DisplayObject=mod.main as DisplayObject;
         var r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return;
         withPart=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0);withoutPart=withPart.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),visible:Boolean=v.visible,start:int=getTimer();
         try {withPart.draw(root,matrix);v.visible=false;withoutPart.draw(root,matrix);}finally{v.visible=visible;}
         pixel={visual:row.id,frame:frame,sampleAt:row.samples[row.samples.length-1].at,
            pose:pose(v,start,frame),at:start,wall:new Date().time,drawMs:getTimer()-start,
            bounds:{x:r.x,y:r.y,w:r.width,h:r.height},pixels:0};
      }
      private function write(file:File,bytes:ByteArray,text:String=null):void {
         var stream:FileStream=new FileStream();stream.open(file,FileMode.WRITE);
         try{if(text!=null)stream.writeUTFBytes(text);else stream.writeBytes(bytes);}finally{stream.close();}
      }
      public function result():Object {
         var folder:File=File.applicationStorageDirectory.resolvePath("gas-pulse-proof");folder.createDirectory();
         var prefix:String="round-"+round,readAt:int=getTimer();
         if(withPart!=null) {
            var a:Vector.<uint>=withPart.getVector(withPart.rect),b:Vector.<uint>=withoutPart.getVector(withoutPart.rect);
            for(var i:int=0;i<a.length;i++)if(a[i]!=b[i])pixel.pixels++;
            write(folder.resolvePath(prefix+"-with.png"),withPart.encode(withPart.rect,new PNGEncoderOptions()));
            write(folder.resolvePath(prefix+"-without.png"),withoutPart.encode(withoutPart.rect,new PNGEncoderOptions()));
         }
         var data:Object={round:round,source:source,nativeRows:nativeRows,visualRows:visualRows,wireRows:wireRows,
            allEnded:allEnded,overflow:overflow,pixel:pixel,readbackAt:readAt,encodeMs:getTimer()-readAt,
            quietMs:readAt-lastActivity,lastActivity:lastActivity,clockObservation:"source-frame-bounds-only",playbackCursorObserved:false};
         write(folder.resolvePath(prefix+"-proof.json"),null,JSON.stringify(data));dispose();return data;
      }
      public function dispose():void {if(withPart!=null){withPart.dispose();withPart=null;}if(withoutPart!=null){withoutPart.dispose();withoutPart=null;}}
   }
}
