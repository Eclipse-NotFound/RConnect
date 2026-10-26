package {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.filters.BlurFilter;
   import flash.filters.ColorMatrixFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.system.ApplicationDomain;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;

   /** Standalone component proposal, not a product patch. Compare the exact
    * current TextField import against deferring its first transform. No room,
    * input, timeline, or full-pipeline performance claims are made here. */
   public final class BTextTransformChecks {
      public static function run(mod:Object,domain:ApplicationDomain,check:Function,log:Function=null,iterations:int=0):Object {
         var Pose:Object=domain.getDefinition("authority.VisualPose"),result:Object={assets:[],cases:0,errors:0,timing:[]};
         for each(var name:String in ["hpBar","hpBarBoss","visualNumb","visReplic","visReplic2"]) {
            var Type:Class=mod.access.visualClass(name),asset:MovieClip=new Type();asset.gotoAndStop(1);
            var paths:Array=[];collect(asset,name,paths);
            result.assets.push({asset:name,textFields:paths});Pose.dispose(asset);
         }
         for each(name in ["visualNumb","visReplic","visReplic2","center","right","left","none"]) {
            var source:TextField,reference:TextField,current:TextField,deferred:TextField,roots:Array=[];
            if(name=="visualNumb" || name=="visReplic" || name=="visReplic2") {
               Type=mod.access.visualClass(name);
               for(var n:int=0;n<4;n++){var clip:MovieClip=new Type();clip.gotoAndStop(name=="visualNumb"?4:1);roots.push(clip);}
               source=findText(roots[0]);reference=findText(roots[1]);current=findText(roots[2]);deferred=findText(roots[3]);
            }else {
               source=new TextField();reference=new TextField();current=new TextField();deferred=new TextField();
               for each(var field:TextField in [source,reference,current,deferred]) {
                  field.autoSize=name;field.width=125;field.height=35;
               }
            }
            if(source==null || reference==null || current==null || deferred==null)throw new Error("Missing native text fixture "+name);
            // Reparent only detached test assets, giving every text an identical
            // parent transform and allowing matrix-sensitive bitmap comparison.
            var boards:Array=[];
            for each(field in [source,reference,current,deferred]){var board:Sprite=new Sprite();board.addChild(field);boards.push(board);}
            var cacheCurrent:Object={keys:new Dictionary(true)},cacheDeferred:Object={keys:new Dictionary(true)},recipes:Array=[],exact:Boolean=true,first:Object=null;
            for(var i:int=0;i<24;i++) {
               source.multiline=i%2==0;source.wordWrap=i%3==0;
               reference.wordWrap=current.wordWrap=deferred.wordWrap=source.wordWrap;
               source.htmlText=i%4==0?"<b>Long NPC response</b><br>second line":String(["78","1000000","MISS",""][i%4]);
               source.textColor=i%2==0?0xFFAE42:0x55CCFF;
               source.filters=i%3==0?[new GlowFilter(0x224466,.6,2,2)]:[];
               source.cacheAsBitmap=i%2==0;source.alpha=.2+i/30;source.visible=i%7!=0;
               source.transform.matrix=new Matrix(i%2==0?1:-.85,.12,-.08,1.1,17+i*.25,-13+i*.125);
               var recipe:Object=Pose.capture(source);recipes.push(recipe);
               // Deliberately disturb target geometry before every confirmation;
               // an equality cache must not accidentally hide native changes.
               for each(field in [reference,current,deferred]){field.x=80-i;field.y=50+i;field.alpha=.1;field.visible=!source.visible;}
               Pose.apply(reference,recipe);
               applyText(current,recipe,cacheCurrent,false);
               applyText(deferred,recipe,cacheDeferred,true);
               var r:Object=describe(reference),c:Object=describe(current),d:Object=describe(deferred);
               var same:Boolean=JSON.stringify(r)===JSON.stringify(c) && JSON.stringify(r)===JSON.stringify(d);
               var p0:BitmapData=picture(boards[1]),p1:BitmapData=picture(boards[2]),p2:BitmapData=picture(boards[3]);
               var delta1:*=p0.compare(p1),delta2:*=p0.compare(p2);
               same=same && delta1===0 && delta2===0;
               if(delta1 is BitmapData)BitmapData(delta1).dispose();if(delta2 is BitmapData)BitmapData(delta2).dispose();
               p0.dispose();p1.dispose();p2.dispose();
               result.cases=Number(result.cases)+1;
               if(!same){exact=false;result.errors=Number(result.errors)+1;if(first==null)first={iteration:i,reference:r,current:c,deferred:d};}
            }
            check(exact,"text transform component preserves current native import and pixels: "+name,first);
            if(iterations>0) {
               // Component-only costs; no bitmap draws, capture, assertions or
               // JSON work are inside the timed loops. Alternate the order.
               iterations=Math.min(20000,Math.max(1000,iterations));
               for(i=0;i<200;i++){applyText(current,recipes[i%recipes.length],cacheCurrent,false);applyText(deferred,recipes[i%recipes.length],cacheDeferred,true);}
               for(var round:int=0;round<4;round++)for(var pass:int=0;pass<2;pass++) {
                  var defer:Boolean=(round+pass)%2==0,started:int=getTimer();
                  for(i=0;i<iterations;i++)applyText(defer?deferred:current,recipes[i%recipes.length],defer?cacheDeferred:cacheCurrent,defer);
                  result.timing.push({fixture:name,round:round,deferred:defer,calls:iterations,ms:getTimer()-started});
               }
            }
            for each(board in boards){Pose.dispose(board);board.removeChildren();}
            for each(clip in roots)Pose.dispose(clip);
         }
         if(log!=null)log("TEXT_TRANSFORM_COMPONENT",result);
         return result;
      }
      /** Count transmitted TextField recipes in one discrete confirmation.
       * Call on actual scene frames, not interpolated frames or every render. */
      public static function coverage(frame:Object):Object {
         var out:Object={players:0,weapons:0,projectiles:0,unitBodies:0,healthBars:0,objects:0,effects:0};
         for each(var p:Object in frame.players){out.players+=count(p.visual);if(p.weapon!=null)out.weapons+=count(p.weapon.visual);}
         for each(p in frame.projectiles)out.projectiles+=count(p.visual);
         if(frame.scene!=null) {
            for each(var u:Object in frame.scene.units){out.unitBodies+=count(u.pose);if(u.healthBar!=null)out.healthBars+=count(u.healthBar.pose);for each(var w:Object in u.weapons)out.weapons+=count(w.pose);}
            for each(var o:Object in frame.scene.objects)out.objects+=count(o.pose);
            for each(var e:Object in frame.scene.effects)out.effects+=count(e.pose);
         }
         return out;
      }
      private static function count(pose:Object):int {
         if(pose==null)return 0;var n:int=pose.text!=null?1:0;
         if(pose.children!=null)for each(var child:Object in pose.children)n+=count(child.s);return n;
      }
      private static function collect(display:DisplayObject,path:String,out:Array):void {
         if(display is TextField)out.push(path);
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null)for(var i:int=0;i<parent.numChildren;i++)collect(parent.getChildAt(i),path+"/"+parent.getChildAt(i).name,out);
      }
      private static function findText(display:DisplayObject):TextField {
         if(display is TextField)return display as TextField;
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null)for(var i:int=0;i<parent.numChildren;i++){var t:TextField=findText(parent.getChildAt(i));if(t!=null)return t;}
         return null;
      }
      private static function transform(display:DisplayObject,s:Object):void {
         if(s.m!=null)display.transform.matrix=new Matrix(s.m[0],s.m[1],s.m[2],s.m[3],s.m[4],s.m[5]);
         else {display.x=s.x;display.y=s.y;display.scaleX=s.sx;display.scaleY=s.sy;display.rotation=s.r;}
         display.alpha=s.a;display.visible=s.v;
      }
      private static function applyText(text:TextField,s:Object,cache:Object,defer:Boolean):void {
         if(!defer)transform(text,s);
         if(s.blend!=null)text.blendMode=s.blend;
         var fk:String=key(s.filters,cache.keys),ck:String=key(s.c,cache.keys);
         if(cache.fk!==fk) {
            var filters:Array=[];
            for each(var fs:Object in s.filters) {
               var filter:Object;
               if(fs.kind=="flash.filters::ColorMatrixFilter")filter=new ColorMatrixFilter(fs.matrix);
               else {
                  if(fs.kind=="flash.filters::GlowFilter")filter=new GlowFilter();
                  else if(fs.kind=="flash.filters::BlurFilter")filter=new BlurFilter();
                  else if(fs.kind=="flash.filters::DropShadowFilter")filter=new DropShadowFilter();else continue;
                  for(var k:String in fs)if(k!="kind")filter[k]=fs[k];
               }
               filters.push(filter);
            }
            cache.filters=filters;cache.fk=fk;
         }
         text.filters=cache.filters;if(s.cache!=null)text.cacheAsBitmap=s.cache;
         var multiline:Boolean=text.multiline;text.multiline=true;
         if(text.htmlText!=s.text || s.plainText!=null && text.text!==s.plainText)text.htmlText=s.text;
         if(s.plainText!=null && text.text!==s.plainText && text.text.indexOf(s.plainText)==0 && /^\r+$/.test(text.text.substr(s.plainText.length)))text.replaceText(s.plainText.length,text.length,"");
         text.textColor=s.textColor;text.multiline=s.multiline==null?multiline:Boolean(s.multiline);
         if(s.scrollH!=null)text.scrollH=s.scrollH;if(s.scrollV!=null)text.scrollV=s.scrollV;
         transform(text,s);
         if(s.c!=null && cache.ck!==ck){cache.color=new ColorTransform(s.c[0],s.c[1],s.c[2],s.c[3],s.c[4],s.c[5],s.c[6],s.c[7]);cache.ck=ck;}
         if(s.c!=null)text.transform.colorTransform=cache.color;text.alpha=s.a;
      }
      private static function key(value:Object,keys:Dictionary):String {
         if(value==null)return "null";var found:String=keys[value];
         if(found==null){found=JSON.stringify(value);keys[value]=found;}return found;
      }
      private static function describe(t:TextField):Object {
         var m:Matrix=t.transform.matrix,c:ColorTransform=t.transform.colorTransform;
         return {text:t.text,html:t.htmlText,color:t.textColor,multiline:t.multiline,wrap:t.wordWrap,
            width:t.width,height:t.height,scrollH:t.scrollH,scrollV:t.scrollV,maxScrollH:t.maxScrollH,maxScrollV:t.maxScrollV,
            matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],colorTransform:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset],
            alpha:t.alpha,visible:t.visible,autoSize:t.autoSize,cache:t.cacheAsBitmap,blend:t.blendMode};
      }
      private static function picture(display:DisplayObject):BitmapData {
         var bitmap:BitmapData=new BitmapData(800,400,true,0);bitmap.draw(display,new Matrix(1,0,0,1,400,200));return bitmap;
      }
   }
}
