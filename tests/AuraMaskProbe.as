package {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Shape;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;

   /** Isolated driver evidence; hides one attributed candidate then restores it. */
   public final class AuraMaskProbe {
      private static var ids:Dictionary=new Dictionary(true),next:int=0;
      private static var owners:Dictionary=new Dictionary(true);
      private static var lastMasks:Dictionary=new Dictionary(true),knownShapes:Dictionary=new Dictionary(true);
      private static function id(o:Object):int {
         if(o==null)return 0;if(!ids[o])ids[o]=++next;return int(ids[o]);
      }
      private static function bitmap(s:Shape):Object {
         try {
            var g:Object=s.graphics,list:Object=g["readGraphicsData"](false);
            for each(var fill:Object in list)if(getQualifiedClassName(fill)=="flash.display::GraphicsBitmapFill")
               return fill;
         } catch(e:Error) {}
         return null;
      }
      private static function signature(s:Shape):String {
         var fill:Object=bitmap(s);if(fill==null || fill.bitmapData==null)return "";
         var b:BitmapData=fill.bitmapData as BitmapData;
         return JSON.stringify([s.x,s.y,s.width,s.height,b.width,b.height,
            fill.matrix==null?null:[fill.matrix.a,fill.matrix.b,fill.matrix.c,fill.matrix.d,fill.matrix.tx,fill.matrix.ty],fill.repeat,fill.smooth]);
      }
      public static function capture(mod:RConnectMod):void {
         if(mod.game==null || mod.game.loc==null)return;
         for each(var u:Object in mod.game.loc.units)if(u is MirrorHitUnit) {
            var body:Object=MirrorHitUnit(u).body;if(body==null)continue;
            for each(var field:String in ["vis","hpbar"]) {
               var v:DisplayObject=GameBridge.probe(body,field) as DisplayObject;
               if(v!=null && v===GameBridge.probe(u,field) && v.mask is Shape) {
                  var s:Shape=v.mask as Shape;
                  owners[s]={body:id(body),proxy:id(u),field:field,visual:id(v),signature:signature(s)};
                  lastMasks[v]=s;
               }
            }
         }
      }
      private static function references(node:DisplayObject,refs:Dictionary):void {
         if(node.mask!=null){if(refs[node.mask]==null)refs[node.mask]=[];refs[node.mask].push(id(node));}
         var c:DisplayObjectContainer=node as DisplayObjectContainer;
         if(c!=null)for(var i:int=0;i<c.numChildren;i++)references(c.getChildAt(i),refs);
      }
      private static function picture(mod:RConnectMod,name:String):void {
         var b:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         b.draw(mod.main as DisplayObject);var f:FileStream=new FileStream();
         try {f.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));}
         finally {f.close();b.dispose();}
      }
      public static function diagnose(mod:RConnectMod,observed:DisplayObject,pixel:Function):void {
         capture(mod);var refs:Dictionary=new Dictionary(true);references(mod.main as DisplayObject,refs);
         var shapes:Array=[],aliases:Array=[],candidates:Array=[];
         for each(var u:Object in mod.game.loc.units)if(u is MirrorHitUnit) {
            var body:Object=MirrorHitUnit(u).body;if(body==null)continue;
            aliases.push({proxy:id(u),body:id(body),name:body.id,bodyIndex:mod.game.loc.units.indexOf(body),
               proxyIndex:mod.game.loc.units.indexOf(u),vis:id(body.vis),proxyVis:id(u.vis),
               hpbar:id(body.hpbar),proxyHpbar:id(u.hpbar),visMask:id(body.vis==null?null:body.vis.mask),
               barMask:id(body.hpbar==null?null:body.hpbar.mask)});
         }
         for each(var layerIndex:int in [2,3]) {
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[layerIndex] as DisplayObjectContainer;
            for(var i:int=0;i<layer.numChildren;i++) {
               var s:Shape=layer.getChildAt(i) as Shape;if(s==null)continue;
               var fill:Object=bitmap(s),sig:String=signature(s),paired:Object=null;
               if(sig!="")for(var m:Object in owners)if(owners[m].signature===sig){paired=owners[m];break;}
               shapes.push({shape:id(s),name:s.name,layer:layerIndex,visible:s.visible,cache:s.cacheAsBitmap,
                  refs:refs[s]||[],bounds:s.getBounds(mod.main as DisplayObject),bitmap:id(fill==null?null:fill.bitmapData),
                  signature:sig,observedOwner:owners[s],matchingOwner:paired});
               if(paired!=null)knownShapes[s]=true;
               if(s.visible && refs[s]==null && paired!=null && s.cacheAsBitmap)candidates.push(s);
            }
         }
         Log.d("TELEKINESIS MASK GRAPH "+JSON.stringify({aliases:aliases,shapes:shapes}));
         for each(s in candidates) {
            var old:Boolean=s.visible,before:int=pixel(observed),after:int=0;
            try {s.visible=false;after=pixel(observed);picture(mod,"presentation-mask-hide-"+id(s)+".png");}
            finally {s.visible=old;}
            Log.d("TELEKINESIS MASK SINGLE HIDE "+JSON.stringify({shape:id(s),before:before,after:after,restored:s.visible}));
         }
         // Different enemy masks overlap this ROI. Preserve the single-object
         // controls above and additionally hide only the attributed orphan set.
         var saved:Array=[],names:Array=[];before=pixel(observed);
         try {
            for each(s in candidates){saved.push(s.visible);names.push(id(s));s.visible=false;}
            after=pixel(observed);picture(mod,"presentation-mask-alias-orphans-hidden.png");
         } finally {
            for(i=0;i<candidates.length;i++)Shape(candidates[i]).visible=Boolean(saved[i]);
         }
         Log.d("TELEKINESIS MASK ATTRIBUTED SET HIDE "+JSON.stringify({shapes:names,before:before,after:after,restored:true}));
      }
      public static function retirementSnapshot(mod:RConnectMod):Array {
         var out:Array=[];
         for each(var u:Object in mod.game.loc.units)if(u is MirrorHitUnit) {
            var b:Object=MirrorHitUnit(u).body;if(b==null)continue;
            var fields:Array=[];
            for each(var field:String in ["vis","hpbar"]) {
               var v:DisplayObject=GameBridge.probe(b,field) as DisplayObject;
               if(v!=null && b.npc===false && u.npc===false && lastMasks[v]!=null)
                  fields.push({v:v,field:field,borrowed:lastMasks[v]});
            }
            out.push({body:b,proxy:u,fields:fields});
         }
         return out;
      }
      public static function retirementState(mod:RConnectMod,snapshot:Array):Object {
         var refs:Dictionary=new Dictionary(true);references(mod.main as DisplayObject,refs);
         var retired:int=0,wrong:int=0,visibleOrphans:int=0,restoredFields:int=0;
         for each(var rec:Object in snapshot) {
            var p:MirrorHitUnit=rec.proxy as MirrorHitUnit;
            if(p.body==null && GameBridge.probe(p,"vis")==null && GameBridge.probe(p,"hpbar")==null && mod.game.loc.units.indexOf(p)<0)retired++;
            for each(var f:Object in rec.fields)if(f.v.stage!=null && GameBridge.probe(rec.body,f.field)===f.v) {
               restoredFields++;if(f.v.mask===f.borrowed)wrong++;
            }
         }
         for(var shape:Object in knownShapes)
            if(shape.parent!=null && shape.visible && !refs[shape])visibleOrphans++;
         return {pairs:snapshot.length,retired:retired,liveFields:restoredFields,proxyMasksRestored:wrong,visibleOrphans:visibleOrphans};
      }
   }
}
