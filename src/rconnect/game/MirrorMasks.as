package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Shape;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;

   /** A collision receiver borrows a body's display objects. Keep the body's
    * native mask and suppress only orphan bitmap masks attributable to that
    * alias; neither eligibility nor another mod's bitmap storage is changed. */
   public final class MirrorMasks {
      private var aliases:Dictionary=new Dictionary(true);
      private var views:Dictionary=new Dictionary(true);
      private var owned:Dictionary=new Dictionary();
      private var roomRef:Object,worldRef:Object,rootRef:DisplayObject;
      /** Only a field not yet shared with the receiver proves native ownership.
       * A matching orphan's shape or draw order never supplies that proof. */
      public function prepare(body:Object):void {
         var proxy:MirrorHitUnit=aliases[body] as MirrorHitUnit;
         for each(var field:String in ["vis","hpbar"]) {
            var v:DisplayObject=GameBridge.probe(body,field) as DisplayObject;
            if(v==null || views[v]!=null)continue;
            var unshared:Boolean=proxy==null || GameBridge.probe(proxy,field)!==v;
            views[v]={body:body,field:field,nativeMask:unshared && owned[v.mask]==null?v.mask:null,
               cache:v.cacheAsBitmap,last:null,hidden:new Dictionary(true),released:false};
         }
      }
      public function register(body:Object,proxy:MirrorHitUnit):void {
         prepare(body);
         aliases[body]=proxy;
      }
      private function bitmapSignature(s:Shape):String {
         if(s==null || !s.cacheAsBitmap)return "";
         try {
            var graphics:Object=s.graphics,list:Object=graphics["readGraphicsData"](false),fill:Object=null;
            for each(var part:Object in list)if(getQualifiedClassName(part)=="flash.display::GraphicsBitmapFill") {
               if(fill!=null)return "";fill=part;
            }
            if(fill==null || fill.bitmapData==null || fill.matrix==null)return "";
            var b:BitmapData=fill.bitmapData as BitmapData;
            // RV alpha fields contain white RGB and transparency, not world art.
            // Read only the fill metadata. Rasterize a standalone graphics copy
            // into our own pixel storage instead of sampling RV's source BMD.
            var bounds:Rectangle=s.getBounds(s),paint:Shape=new Shape(),sample:BitmapData=new BitmapData(1,1,true,0);
            paint.graphics.copyFrom(s.graphics);
            var white:Boolean=true;
            try {
               for each(var point:Array in [[bounds.x,bounds.y],[bounds.right-1,bounds.y],
                  [bounds.x,bounds.bottom-1],[bounds.right-1,bounds.bottom-1],
                  [bounds.x+bounds.width/2,bounds.y+bounds.height/2]]) {
                  sample.fillRect(sample.rect,0);sample.draw(paint,new Matrix(1,0,0,1,-point[0],-point[1]));
                  var p:uint=sample.getPixel32(0,0);
                  if((p>>>24)!=0 && (p&0xFFFFFF)!=0xFFFFFF){white=false;break;}
               }
            } finally {sample.dispose();}
            if(!white)return "";
            return JSON.stringify([s.x,s.y,s.width,s.height,b.width,b.height,
               [fill.matrix.a,fill.matrix.b,fill.matrix.c,fill.matrix.d,fill.matrix.tx,fill.matrix.ty],fill.repeat,fill.smooth]);
         } catch(error:Error) {}
         return "";
      }
      private function maskReferences(node:DisplayObject,refs:Dictionary):void {
         if(node.mask!=null)refs[node.mask]=true;
         var c:DisplayObjectContainer=node as DisplayObjectContainer;
         if(c!=null)for(var i:int=0;i<c.numChildren;i++)maskReferences(c.getChildAt(i),refs);
      }
      private function hide(rec:Object,s:DisplayObject):void {
         if(rec.hidden[s]==null)rec.hidden[s]={visible:s.visible};
         s.visible=false;
      }
      /** Called after native visibility callbacks and before the final render.
       * Inspect layer graphics only when a new mask appears; ordinary frames
       * retain the already-identified mask objects without rescanning graphics. */
      public function capture(room:Object,world:Object,root:DisplayObject):void {
         if(room==null || world==null || root==null)return;
         roomRef=room;worldRef=world;rootRef=root;
         var pending:Array=[],record:Object,body:Object,proxy:MirrorHitUnit;
         for(body in aliases) {
            proxy=aliases[body] as MirrorHitUnit;
            if(proxy==null || proxy.body!==body || GameBridge.probe(body,"loc")!==room)continue;
            register(body,proxy);
            for each(var field:String in ["vis","hpbar"]) {
               var v:DisplayObject=GameBridge.probe(body,field) as DisplayObject;
               if(v==null || GameBridge.probe(proxy,field)!==v || v.mask==null)continue;
               record=views[v];if(record==null || record.last===v.mask)continue;
               record.last=v.mask;
               var s:Shape=v.mask as Shape,sig:String=bitmapSignature(s);
               if(sig!="" && s.parent!=null)pending.push({v:v,rec:record,mask:s,sig:sig,proxy:proxy});
            }
         }
         if(pending.length==0)return;
         var refs:Dictionary=new Dictionary(true),signatures:Dictionary=new Dictionary(true);
         maskReferences(root,refs);
         for each(var work:Object in pending) {
            record=work.rec;s=work.mask;
            // An RV mask is a sibling in the enemy/body or health-bar layer.
            // Do not inspect other layers or remove unrelated drawing content.
            var layer:DisplayObjectContainer=s.parent;
            if(layer!==world.grafon.visObjs[2] && layer!==world.grafon.visObjs[3])continue;
            for(var i:int=0;i<layer.numChildren;i++) {
               var other:Shape=layer.getChildAt(i) as Shape;
               if(other==null || other===s || refs[other] || !other.cacheAsBitmap)continue;
               if(signatures[other]==null)signatures[other]={sig:bitmapSignature(other)};
               if(signatures[other].sig!==work.sig)continue;
               hide(record,other);
            }
         }
      }
      public function release(v:DisplayObject):void {
         if(v==null || v.mask==null)return;
         var record:Object=views[v];
         if(record==null)record=views[v]={nativeMask:v.mask,cache:v.cacheAsBitmap,
            hidden:new Dictionary(true),released:false,last:null};
         record.last=v.mask;
         hide(record,v.mask);v.mask=null;v.cacheAsBitmap=false;record.released=true;
      }
      private function visionActive(room:Object,root:DisplayObject):Boolean {
         try {
            var c:DisplayObjectContainer=root as DisplayObjectContainer;
            var carrier:Object=c==null?null:c.getChildByName("RVExplorationAPI");
            var api:Object=GameBridge.probe(carrier,"api");
            if(api!=null && api.active is Function)return api.active(room)===true;
         } catch(error:Error) {}
         return true;
      }
      /** Independent bitmap storage: never export, clone or dispose RV's BMD.
       * The transitional clip belongs to us, not to a guessed native owner. */
      private function snapshotMask(source:Shape,v:DisplayObject,record:Object):Shape {
         var b:BitmapData=null,out:Shape=null;
         try {
            var r:Rectangle=source.getBounds(source),w:int=Math.ceil(r.width),h:int=Math.ceil(r.height);
            if(w<1 || h<1 || w*h>1000000)return null;
            // A Shape currently used as a mask is not ordinary drawing content.
            // Copy graphics only for this synchronous draw, without exporting
            // its bitmap storage or changing any live mask/visible reference.
            var paint:Shape=new Shape();paint.graphics.copyFrom(source.graphics);
            b=new BitmapData(w,h,true,0);
            b.draw(paint,new Matrix(1,0,0,1,-r.x,-r.y));
            out=new Shape();out.name="RConnectRestoredMask";
            out.graphics.beginBitmapFill(b,new Matrix(1,0,0,1,r.x,r.y),false,true);
            out.graphics.drawRect(r.x,r.y,r.width,r.height);out.graphics.endFill();
            out.transform.matrix=source.transform.matrix.clone();out.cacheAsBitmap=true;
            source.parent.addChild(out);
            owned[out]={view:v,body:record.body,field:record.field,room:roomRef,world:worldRef,bitmap:b};
            b=null;
         } catch(error:Error) {if(out!=null && out.parent!=null)out.parent.removeChild(out);out=null;}
         finally {if(b!=null)b.dispose();}
         return out;
      }
      private function attached(mask:DisplayObject,v:DisplayObject):Boolean {
         return mask!=null && mask.parent!=null && mask.stage!=null && mask.stage===v.stage;
      }
      /** Runs before the game's early returns, including offline and roomHold.
       * A null or foreign/new native mask is a valid renderer takeover. */
      public function clean(room:Object,world:Object,root:DisplayObject):void {
         roomRef=room;worldRef=world;rootRef=root;
         if(root==null)return;
         var active:Boolean=visionActive(room,root);
         for(var key:Object in owned) {
            var s:Shape=key as Shape,rec:Object=owned[key],v:DisplayObject=rec.view as DisplayObject;
            if(v!=null && v.mask===s && v.stage!=null && s.stage===v.stage && active
               && rec.room===room && rec.world===world
               && (rec.body==null || (GameBridge.probe(rec.body,rec.field)===v && GameBridge.probe(rec.body,"loc")===room)))continue;
            if(v!=null && v.mask===s){v.mask=null;v.cacheAsBitmap=false;}
            s.visible=false;if(s.parent!=null)s.parent.removeChild(s);
            BitmapData(rec.bitmap).dispose();delete owned[key];
         }
      }
      public function restore(v:DisplayObject):void {
         var record:Object=views[v];if(record==null)return;
         var aliased:Boolean=record.body!=null && aliases[record.body]!=null;
         if(!record.released && !aliased){delete views[v];return;}
         // A native redraw already replaced this field. Do not attach its old
         // mask to a detached image after the new body has claimed that mask.
         if(record.body!=null && GameBridge.probe(record.body,record.field)!==v){delete views[v];return;}
         try {
            // A newer third-party mask owns its own display state.
            // The user may leave after RV, before our late render callback.
            // A fresh RV mask then has not reached last/released yet.
            var aliasMask:Boolean=aliased && v.mask is Shape && worldRef!=null
               && (v.mask.parent===worldRef.grafon.visObjs[2] || v.mask.parent===worldRef.grafon.visObjs[3])
               && bitmapSignature(v.mask as Shape)!="";
            if(aliasMask)record.last=v.mask;
            if(v.mask==null || record.hidden[v.mask]!=null || v.mask===record.nativeMask || aliasMask) {
               var nativeMask:DisplayObject=record.nativeMask as DisplayObject,refs:Dictionary=new Dictionary(true);
               if(rootRef!=null)maskReferences(rootRef,refs);
               var active:Boolean=visionActive(roomRef,rootRef);
               // Direct historical ownership is not current use permission:
               // assigning a Shape can steal it from a real native weapon.
               if(active && attached(nativeMask,v) && (v.mask===nativeMask || !refs[nativeMask])) {
                  v.mask=nativeMask;
                  var saved:Object=record.hidden[nativeMask];if(saved!=null)nativeMask.visible=saved.visible;
                  v.cacheAsBitmap=nativeMask.cacheAsBitmap || record.cache;
               } else {
                  var source:Shape=attached(nativeMask,v)?nativeMask as Shape:record.last as Shape;
                  var copy:Shape=null;
                  if(active && attached(source,v) && worldRef!=null
                     && (source.parent===worldRef.grafon.visObjs[2] || source.parent===worldRef.grafon.visObjs[3]))
                     copy=snapshotMask(source,v,record);
                  v.mask=copy;v.cacheAsBitmap=copy!=null;
               }
            }
            // The receiver's mask remains hidden until RV sweeps that retired
            // receiver. Restoring its visibility would expose another white quad.
         } catch(error:Error) {}
         delete views[v];
      }
      public function forget(body:Object):void {
         restore(GameBridge.probe(body,"vis") as DisplayObject);
         restore(GameBridge.probe(body,"hpbar") as DisplayObject);delete aliases[body];
      }
      public function reset():void {
         for(var v:Object in views)restore(v as DisplayObject);
         views=new Dictionary(true);aliases=new Dictionary(true);
      }
   }
}
