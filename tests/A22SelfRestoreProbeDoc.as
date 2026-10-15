package {
   import flash.desktop.NativeApplication;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Rectangle;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Observation only: the installed complete restore is the sole path tested.
    * A stable already-granted room is NOT the unobserved mine==null commit path.
    * No replacement redraw, artificial enemies, map travel or production hooks.
    * Pixel equality compares every ARGB word, not a checksum or sparse sample.
    * Before-images are compressed in small blocks; only one block is expanded
    * at a time. No BitmapData clones, image files or long-lived raw image copies.
    */
   public class A22SelfRestoreProbeDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const TYPE:String="a22-self-restore-probe";
      private static const BITMAPS:Array=["frontBmp","backBmp","backBmp2","vodaBmp","satsBmp","lightBmp","colorBmp","shadBmp"];
      private static const BITMAP_LAYERS:Object={frontBmp:"visFront",backBmp:"visBack",backBmp2:"visBack2",vodaBmp:"visVoda",satsBmp:"visSats",lightBmp:"visLight"};
      private static const MAX_COMPRESSED:uint=64*1024*1024;
      private static const MAX_PIXELS:Number=64*1024*1024;
      private static const CHUNK_PIXELS:int=32768;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100);
      private var phase:String="boot",started:int=getTimer(),readyAt:int=0,lastSend:int=0;
      private var peerRoom:String="",peerEpoch:int=-1,peerTerm:int=-1,watchingFrames:Boolean=false;
      private var links:Dictionary=new Dictionary(),ids:Dictionary=new Dictionary(),schemas:Object={},nextId:int=0;
      private var savedPixels:Array=[],compressedBytes:uint=0,enterFrames:int=0,renderEvents:int=0;

      public function A22SelfRestoreProbeDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"self-restore "+label);}
      private function report(kind:String,data:Object):void {Log.d("A22 SELF RESTORE "+kind+" "+JSON.stringify(data));}
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function send(op:String):void {
         if(mod==null||mod.session==null)return;
         var p:Object={type:TYPE,op:op,room:mod.game.roomKey(),epoch:mod.session.rooms.epoch,term:mod.session.rooms.term};
         if(host&&mod.session.server!=null)mod.session.server.broadcast(p);
         else if(!host&&mod.session.link!=null)mod.session.link.send(p);
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p==null||p.type!=TYPE)return;
         if(host&&p.op=="ready"){peerRoom=String(p.room);peerEpoch=int(p.epoch);peerTerm=int(p.term);}
         if(!host&&p.op=="done"){check(true,"host observation finished; join performed no restore");finish();}
      }
      private function onFrame(e:Event):void {enterFrames++;}
      private function onRender(e:Event):void {renderEvents++;}
      private function stable():Boolean {
         var g:Object=mod.game,w:Object=g.world,r:Object=g.loc;
         if(w==null||r==null||g.gg==null||w.land==null||w.land.act==null)return false;
         var land:String=String(w.game.curLandId);
         return (land=="rbl"||land.indexOf("random_")==0)&&String(w.land.act.id)==land
            &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!g.isTransitioning()
            &&w.loc===r&&w.land.loc===r&&w.grafon!=null&&w.grafon.loc===r&&r.grafon===w.grafon
            &&int(w.gr_stage)==0&&(!w.vblack.visible||Number(w.vblack.alpha)==0)
            &&GameBridge.probe(w.sats,"active")!==true&&GameBridge.probe(w.pip,"active")!==true;
      }
      private function tick(e:TimerEvent):void {
         if(phase=="done"||phase=="observing")return;
         mod=RConnectMod.instance;
         if(getTimer()-started>180000){check(false,"timeout waiting for stable native room");send("done");finish();return;}
         if(mod==null||mod.game==null||mod.game.gg==null||mod.session==null)return;
         if(!watchingFrames){mod.stage.addEventListener(Event.ENTER_FRAME,onFrame);mod.stage.addEventListener(Event.RENDER,onRender);watchingFrames=true;}
         if(host&&mod.session.server!=null)for each(var link:TcpLink in mod.session.server.clients)watch(link);
         else if(!host)watch(mod.session.link);
         if(!stable()){readyAt=0;return;}
         if(readyAt==0)readyAt=getTimer();
         if(getTimer()-readyAt<1200)return;
         if(!host){if(getTimer()-lastSend>700){lastSend=getTimer();send("ready");}return;}
         if(peerRoom!=mod.game.roomKey()||peerEpoch!=mod.session.rooms.epoch||peerTerm!=mod.session.rooms.term)return;
         phase="observing";timer.stop();
         try {observe();}
         catch(error:Error){check(false,error.getStackTrace());}
         finally {releasePixels();send("done");finish();}
      }
      private function identity(o:Object):int {
         if(o==null)return 0;
         if(ids[o]===undefined)ids[o]=++nextId;
         return int(ids[o]);
      }
      private function scalar(v:*,depth:int=0):* {
         if(v===undefined)return "<undefined>";
         if(v===null||v is String||v is Boolean)return v;
         if(v is Number)return isFinite(Number(v))?v:String(v);
         if(v is Array&&depth<4){var a:Array=[];for each(var item:* in v)a.push(scalar(item,depth+1));return a;}
         return "<ref:"+identity(v)+">";
      }
      /** Missing/non-public is different from an accessible field containing null. */
      private function field(o:Object,name:String):Object {
         if(o==null)return {available:false,field:name,reason:"owner-null"};
         try {
            if(!(name in o))return {available:false,field:name,reason:"not-public-or-missing"};
            return {available:true,value:o[name]};
         } catch(error:Error) {return {available:false,field:name,reason:"read-error-"+error.errorID};}
         return {available:false,field:name,reason:"unreadable"};
      }
      private function fieldState(o:Object,name:String):Object {
         var f:Object=field(o,name);if(f.available)f.value=scalar(f.value);return f;
      }
      private function appearanceField(o:Object,name:String):Object {
         var f:Object=field(o,name);if(f.available)f.value=appearance(f.value);return f;
      }
      private function colorField(o:Object,name:String):Object {
         var f:Object=field(o,name);if(f.available)f.value=color(f.value);return f;
      }
      private function complete(fields:Object):Boolean {
         for each(var f:Object in fields)if(f==null||f.available!==true)return false;
         return true;
      }
      private function publicState(o:Object):Object {
         var out:Object={};if(o==null)return out;
         var cls:String=getQualifiedClassName(o),names:Array=schemas[cls];
         if(names==null){names=[];for each(var v:XML in describeType(o).variable)if(!v.hasOwnProperty("@uri"))names.push(String(v.@name));names.sort();schemas[cls]=names;}
         for each(var name:String in names)out[name]=fieldState(o,name);
         return out;
      }
      private function canonical(o:*):String {
         if(o===null)return "null";
         if(o===undefined)return "undefined";
         if(o is Array){var parts:Array=[];for each(var v:* in o)parts.push(canonical(v));return "["+parts.join(",")+"]";}
         if(o is String||o is Number||o is Boolean)return JSON.stringify(o);
         var keys:Array=[];for(var k:String in o)keys.push(k);keys.sort();parts=[];
         for each(k in keys)parts.push(JSON.stringify(k)+":"+canonical(o[k]));
         return "{"+parts.join(",")+"}";
      }
      private function color(o:Object):Object {
         if(o==null)return null;
         var out:Object={};for each(var k:String in ["redMultiplier","greenMultiplier","blueMultiplier","alphaMultiplier","redOffset","greenOffset","blueOffset","alphaOffset"])out[k]=fieldState(o,k);
         return out;
      }
      private function appearance(o:Object):Object {
         if(o==null)return null;
         var out:Object={ref:identity(o),cls:getQualifiedClassName(o)};
         if(o is BitmapData){out.width=o.width;out.height=o.height;return out;}
         if(o is DisplayObject){var d:DisplayObject=o as DisplayObject,m:Object=d.transform.matrix;
            out.matrix=[m.a,m.b,m.c,m.d,m.tx,m.ty];out.color=color(d.transform.colorTransform);
            out.visible=d.visible;out.alpha=d.alpha;out.blend=d.blendMode;out.mask=identity(d.mask);}
         if(o is MovieClip){out.frame=o.currentFrame;out.playing=o.isPlaying;out.label=o.currentLabel;}
         return out;
      }
      private function sceneState():Object {
         var r:Object=mod.game.loc,g:Object=mod.game.world.grafon,tiles:Array=[],doors:Array=[],backs:Array=[];
         var tilesComplete:Boolean=true,doorsComplete:Boolean=true,backsComplete:Boolean=true;
         for(var x:int=0;x<int(r.spaceX);x++)for(var y:int=0;y<int(r.spaceY);y++){
            var t:Object=r.space[x][y],state:Object=publicState(t),door:Object=fieldState(t,"door");
            tilesComplete=tilesComplete&&complete(state);doorsComplete=doorsComplete&&door.available===true;
            tiles.push(canonical(state));doors.push(canonical(door));}
         var backList:Object=field(r,"backobjs");backsComplete=backList.available===true&&backList.value is Array;
         if(backsComplete)for each(var b:Object in backList.value){
            var fields:Object=publicState(b),views:Object={vis:appearanceField(b,"vis"),light:appearanceField(b,"light"),erase:appearanceField(b,"erase")};
            backsComplete=backsComplete&&complete(fields)&&complete(views);backs.push({ref:identity(b),fields:fields,views:views});}
         var background:Object={};
         for each(var name:String in ["spaceX","spaceY","limX","limY","backwall","backform","transpFon","darkness","gas","tipWater","black","isRebuild","isRelight","isRecalc"])
            background[name]=fieldState(r,name);
         background.cTransform=colorField(r,"cTransform");background.cTransformFon=colorField(r,"cTransformFon");
         var lighting:Object={vis:appearanceField(g,"visLight"),fon:appearanceField(g,"visFon"),resX:fieldState(g,"resX"),resY:fieldState(g,"resY")};
         return {tiles:tiles,doors:doors,background:canonical(background),backObjects:canonical(backs),
            tilesComplete:tilesComplete,doorsComplete:doorsComplete,backgroundComplete:complete(background),backObjectsComplete:backsComplete,
            backObjectsAvailability:backList.available?{available:true}:backList,lightingComplete:complete(lighting),
            context:[identity(mod.game.world),identity(mod.game.world.land),identity(r),identity(g),identity(g.loc),identity(r.grafon)],
            lighting:canonical(lighting)};
      }
      private function differences(a:Array,b:Array,tiles:Boolean=false):Object {
         var count:int=0,first:Array=[],examples:Array=[],n:int=Math.max(a.length,b.length);
         for(var i:int=0;i<n;i++)if(a[i]!==b[i]){
            count++;if(first.length<16)first.push(i);
            if(examples.length<8){
               var delta:Object={index:i};
               if(tiles&&i<a.length&&i<b.length){var av:Object=JSON.parse(a[i]),bv:Object=JSON.parse(b[i]),names:Object={},fields:Object={};
                  for(var key:String in av)names[key]=true;for(key in bv)names[key]=true;
                  for(key in names)if(canonical(av[key])!==canonical(bv[key]))fields[key]={before:av[key],after:bv[key]};delta.fields=fields;
               }else{delta.before=a[i];delta.after=b[i];}
               examples.push(delta);
            }
         }
         return {before:a.length,after:b.length,changed:count,firstIndices:first,examples:examples};
      }
      private function layerOf(d:DisplayObject,g:Object):int {
         if(d==null||d.parent==null)return -1;
         for(var i:int=0;i<g.visObjs.length;i++)if(d.parent===g.visObjs[i])return i;
         return -2;
      }
      private function objectRow(o:Object,tag:String,required:Boolean,g:Object,unit:Boolean=false):Object {
         var vis:DisplayObject=GameBridge.probe(o,"vis") as DisplayObject;
         var expected:int=int(GameBridge.probe(o,"sloy")),layer:int=layerOf(vis,g);
         // Disabled/trigger-hidden Unit.addVisual deliberately returns early.
         if(unit&&(GameBridge.probe(o,"disabled")===true||GameBridge.probe(o,"trigDis")===true))required=false;
         return {ref:identity(o),tag:tag,cls:getQualifiedClassName(o),id:String(GameBridge.probe(o,"id")),
            vis:identity(vis),parent:identity(vis==null?null:vis.parent),layer:layer,expected:expected,
            required:required&&vis!=null,ok:!required||vis==null||layer==expected,
            inChain:GameBridge.probe(o,"in_chain")===true,disabled:GameBridge.probe(o,"disabled")===true,trigDis:GameBridge.probe(o,"trigDis")===true};
      }
      private function dynamicState():Object {
         var r:Object=mod.game.loc,g:Object=mod.game.world.grafon,rows:Array=[],seen:Dictionary=new Dictionary(),bad:Array=[];
         var units:int=0,weapons:int=0,guard:int=0;
         for(var o:Object=r.firstObj;o!=null;o=o.nobj){
            if(++guard>10000||seen[o])throw new Error("Invalid firstObj chain during display audit");
            seen[o]=true;rows.push(objectRow(o,"chain",Boolean(r.active),g,GameBridge.probe(o,"childObjs") is Array));}
         var owners:Array=(r.units as Array).concat();if(owners.indexOf(mod.game.gg)<0)owners.push(mod.game.gg);
         for each(o in owners){
            var active:Boolean=Boolean(r.active)&&(seen[o]===true||o===mod.game.gg)&&GameBridge.probe(o,"disabled")!==true&&GameBridge.probe(o,"trigDis")!==true;
            units++;rows.push(objectRow(o,"unit",active,g,true));
            var children:Object=GameBridge.probe(o,"childObjs");
            if(children!=null)for each(var child:Object in children)if(child!=null&&GameBridge.probe(child,"kol_shoot")!=null){
               weapons++;rows.push(objectRow(child,"weapon-of-"+identity(o),active,g));}
         }
         for each(var row:Object in rows)if(!row.ok)bad.push(row);
         return {chain:guard,units:units,weapons:weapons,rows:rows,invalid:bad};
      }
      private function adler(bytes:ByteArray,previous:uint=1):uint {
         var a:uint=previous&65535,b:uint=previous>>>16;bytes.position=0;
         while(bytes.bytesAvailable){var v:uint=bytes.readUnsignedInt(),p:uint=v>>>24,q:uint=(v>>>16)&255,r:uint=(v>>>8)&255,s:uint=v&255;
            b=(b+4*a+4*p+3*q+2*r+s)%65521;a=(a+p+q+r+s)%65521;}
         return uint((b<<16)|a);
      }
      /** Internal buffers are accessible only if native code exposes their
       * actual BitmapData through one unambiguous public display child. */
      private function bitmapSource(g:Object,name:String):Object {
         var direct:Object=field(g,name);
         if(direct.available&&direct.value is BitmapData)return {available:true,bitmap:direct.value,via:"public."+name};
         if(BITMAP_LAYERS[name]==null)return {available:false,reason:"no-public-bitmap-or-display-alias",field:direct};
         var layerName:String=String(BITMAP_LAYERS[name]);
         var layerField:Object=field(g,layerName),layer:DisplayObjectContainer=layerField.available?layerField.value as DisplayObjectContainer:null;
         if(layer==null)return {available:false,reason:"public-layer-unavailable",field:layerField};
         var found:BitmapData=null,count:int=0;
         for(var i:int=0;i<layer.numChildren;i++)if(layer.getChildAt(i) is Bitmap){count++;found=(layer.getChildAt(i) as Bitmap).bitmapData;}
         if(count!=1||found==null)return {available:false,reason:"public-layer-not-one-live-bitmap",layer:layerName,bitmapChildren:count};
         return {available:true,bitmap:found,via:"public."+layerName+".Bitmap.bitmapData"};
      }
      private function capturePixels():void {
         var g:Object=mod.game.world.grafon,total:Number=0;
         for each(var name:String in BITMAPS){var source:Object=bitmapSource(g,name),bitmap:BitmapData=source.bitmap as BitmapData;
            if(source.available!==true){savedPixels.push({name:name,available:false,unavailable:source,chunks:[]});continue;}
            total+=Number(bitmap.width)*bitmap.height;if(total>MAX_PIXELS)throw new Error("Pixel observation budget exceeded");
            var entry:Object={name:name,available:true,via:source.via,ref:identity(bitmap),width:bitmap.width,height:bitmap.height,checksum:uint(1),chunks:[]};savedPixels.push(entry);
            var rows:int=Math.max(1,int(CHUNK_PIXELS/bitmap.width));
            for(var y:int=0;y<bitmap.height;y+=rows){var rect:Rectangle=new Rectangle(0,y,bitmap.width,Math.min(rows,bitmap.height-y));
               var bytes:ByteArray=bitmap.getPixels(rect);entry.checksum=adler(bytes,uint(entry.checksum));bytes.compress();
               compressedBytes+=bytes.length;entry.chunks.push({rect:rect,bytes:bytes});
               if(compressedBytes>MAX_COMPRESSED)throw new Error("Compressed before-image budget exceeded");}
         }
      }
      private function comparePixels():Array {
         var out:Array=[],g:Object=mod.game.world.grafon;
         for each(var entry:Object in savedPixels){var source:Object=bitmapSource(g,entry.name),bitmap:BitmapData=source.bitmap as BitmapData;
            if(entry.available!==true){out.push({name:entry.name,available:false,beforeUnavailable:entry.unavailable,
               afterAvailable:source.available===true,afterUnavailable:source.available?null:source,equal:null,comparison:"unavailable; no equivalence claim"});continue;}
            var sameSize:Boolean=bitmap!=null&&bitmap.width==entry.width&&bitmap.height==entry.height;
            var changed:Number=0,total:Number=0,sum:uint=1,minX:int=int(entry.width),minY:int=int(entry.height),maxX:int=-1,maxY:int=-1;
            for each(var chunk:Object in entry.chunks){var before:ByteArray=chunk.bytes as ByteArray,after:ByteArray=null;
               try {if(sameSize){before.uncompress();before.position=0;after=bitmap.getPixels(chunk.rect);sum=adler(after,sum);after.position=0;
                  if(before.length!=after.length)throw new Error("Pixel block length changed");
                  var index:int=0;while(before.bytesAvailable){var av:uint=before.readUnsignedInt(),bv:uint=after.readUnsignedInt();
                     if(av!=bv){changed++;var x:int=index%int(entry.width),y:int=int(chunk.rect.y)+int(index/int(entry.width));
                        minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}index++;total++;}}}
               finally {before.clear();if(after!=null)after.clear();chunk.bytes=null;}
            }
            out.push({name:entry.name,available:source.available===true,beforeVia:entry.via,afterVia:source.via,
               unavailable:source.available?null:source,beforeRef:entry.ref,afterRef:identity(bitmap),sameReference:entry.ref==identity(bitmap),
               width:entry.width,height:entry.height,sameSize:sameSize,comparedPixels:total,changedPixels:sameSize?changed:-1,
               beforeAdler32:uint(entry.checksum).toString(16),afterAdler32:sameSize?sum.toString(16):null,
               bounds:maxX<0?null:{x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1},
               equal:source.available?(sameSize&&changed==0):null,comparison:"all ARGB32 words; checksum is informational only"});
         }
         return out;
      }
      private function releasePixels():void {
         for each(var entry:Object in savedPixels)for each(var chunk:Object in entry.chunks)
            if(chunk.bytes is ByteArray){ByteArray(chunk.bytes).clear();chunk.bytes=null;}
         savedPixels=[];compressedBytes=0;
      }
      private function observe():void {
         var game:Object=mod.game,w:Object=game.world,room:Object=game.loc,oldPause:Boolean=Boolean(w.onPause),oldHold:Boolean=Boolean(game.roomHold);
         var start:int=getTimer(),frame:int=enterFrames,render:int=renderEvents;
         var snapshotMs:int=0,beforeMs:int=0,restoreMs:int=0,afterMs:int=0;
         try {
            w.onPause=true;game.roomHold=true;
            var mark:int=getTimer(),snapshot:Object=game.checkpoint();snapshotMs=getTimer()-mark;
            mark=getTimer();var before:Object=sceneState(),beforeObjects:Object=dynamicState();capturePixels();beforeMs=getTimer()-mark;
            var savedSize:uint=compressedBytes;mark=getTimer();
            game.restoreCheckpoint(snapshot,true,false);
            restoreMs=getTimer()-mark;mark=getTimer();
            var after:Object=sceneState(),afterObjects:Object=dynamicState(),pixels:Array=comparePixels();afterMs=getTimer()-mark;
            report("CONTEXT",{scope:"stable already-granted host room; not fresh commit evidence",room:game.roomKey(),land:String(w.game.curLandId),
               authority:mod.session.rooms.authority,epoch:mod.session.rooms.epoch,term:mod.session.rooms.term,
               snapshotUnits:snapshot.units.length,snapshotObjects:snapshot.objs.length,snapshotLoot:snapshot.loots.length,snapshotMines:snapshot.mines.length,
               contextBefore:before.context,contextAfter:after.context,enterFrames:enterFrames-frame,renderEvents:renderEvents-render,
               snapshotMs:snapshotMs,beforeObservationMs:beforeMs,fullRestoreMs:restoreMs,afterObservationMs:afterMs,totalMs:getTimer()-start,
               compressedBeforeBytes:savedSize,pixelBlockMaximum:CHUNK_PIXELS*4,comparisonRawBuffersMaximum:CHUNK_PIXELS*8,partialRestoreExecuted:false});
            report("STATE",{tiles:differences(before.tiles,after.tiles,true),doorRefs:differences(before.doors,after.doors),
               tilesComplete:before.tilesComplete&&after.tilesComplete,doorRefsComplete:before.doorsComplete&&after.doorsComplete,
               backgroundComplete:before.backgroundComplete&&after.backgroundComplete,
               backgroundEqual:before.backgroundComplete&&after.backgroundComplete?before.background===after.background:null,backgroundBefore:before.background,backgroundAfter:after.background,
               backObjectsComplete:before.backObjectsComplete&&after.backObjectsComplete,
               backObjectsEqual:before.backObjectsComplete&&after.backObjectsComplete?before.backObjects===after.backObjects:null,
               backObjectsAvailabilityBefore:before.backObjectsAvailability,backObjectsAvailabilityAfter:after.backObjectsAvailability,
               lightingComplete:before.lightingComplete&&after.lightingComplete,
               lightingEqual:before.lightingComplete&&after.lightingComplete?before.lighting===after.lighting:null,
               lightingBefore:before.lighting,lightingAfter:after.lighting});
            var readable:int=0,missing:Array=[],criticalMissing:Array=[],allEqual:Boolean=true;
            for each(var result:Object in pixels){report("PIXELS",result);
               if(result.available===true){readable++;allEqual=allEqual&&result.equal===true;}
               else{missing.push(result.name);if(BITMAP_LAYERS[result.name]!=null)criticalMissing.push(result.name);}}
            report("PIXEL COVERAGE",{requested:BITMAPS.length,readable:readable,unavailable:missing,criticalUnavailable:criticalMissing,
               completePixelEquivalence:missing.length==0?allEqual:null,allReadablePixelsEqual:readable>0?allEqual:null});
            report("DYNAMIC",{before:beforeObjects,after:afterObjects});
            check(w===game.world&&room===game.loc&&canonical(before.context)===canonical(after.context),"world and active render room identities retained");
            check(enterFrames==frame,"capture and full restore completed in one callback without ENTER_FRAME");
            check(pixels.length==BITMAPS.length&&readable>0&&criticalMissing.length==0,"public render layer access available; unavailable internal caches prevent complete equivalence claims");
            check(afterObjects.invalid.length==0,"restored eligible object and weapon visuals occupy their native layers");
            report("LIMIT",{message:"A zero pixel difference in this stable room does not prove a fresh-commit fast path. No partial redraw was executed.",
               weaponCoverage:afterObjects.weapons,mineCoverage:snapshot.mines.length,lootCoverage:snapshot.loots.length});
         } finally {w.onPause=oldPause;game.roomHold=oldHold;releasePixels();}
      }
      private function uncaught(e:UncaughtErrorEvent):void {
         check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();releasePixels();send("done");finish();
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();releasePixels();
         if(watchingFrames){mod.stage.removeEventListener(Event.ENTER_FRAME,onFrame);mod.stage.removeEventListener(Event.RENDER,onRender);}
         for(var link:Object in links)link.removeEventListener(TcpLink.MESSAGE,receive);
         Log.d("COOP EFFECTS DONE self-restore "+(host?"host":"join"));
      }
   }
}
