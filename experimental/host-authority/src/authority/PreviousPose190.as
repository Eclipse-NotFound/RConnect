package authority {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.display.Shape;
   import flash.display.Bitmap;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.text.TextField;
   import flash.filters.GlowFilter;
   import flash.filters.BlurFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.ColorMatrixFilter;
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   /** Frozen B190 capture oracle, used only by the explicit paired pose probe. */
   public final class PreviousPose190 {
      public static var resolve:Function;
      private static var applied:Dictionary=new Dictionary(true),added:Dictionary=new Dictionary(true);
      private static var captured:Dictionary=new Dictionary(true);
      private static var scriptless:Dictionary=new Dictionary(true);
      private static var pixels:Dictionary=new Dictionary(true);
      private static var immutableKeys:Dictionary=new Dictionary(true);
      private static function recipeKey(value:Object):String {
         if(value==null)return "null";
         var key:String=immutableKeys[value];
         if(key==null){key=JSON.stringify(value);immutableKeys[value]=key;}return key;
      }
      public static function capture(display:DisplayObject,depth:int=0,includePixels:Boolean=false):Object {
         if(display==null)return null;
         var began:int=depth==0?Timing.start():0;
         var color:ColorTransform=display.transform.colorTransform;
         var matrix:Matrix=display.transform.matrix;
         var s:Object={x:display.x,y:display.y,sx:display.scaleX,sy:display.scaleY,r:display.rotation,
            m:[matrix.a,matrix.b,matrix.c,matrix.d,matrix.tx,matrix.ty],
            a:display.alpha,v:display.visible,c:[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,
               color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset]};
         s.blend=display.blendMode;s.cache=display.cacheAsBitmap;s.filters=[];
         if(display is Bitmap){s.smoothing=Bitmap(display).smoothing;s.pixelSnapping=Bitmap(display).pixelSnapping;}
         if(includePixels && display is Bitmap && Bitmap(display).bitmapData!=null)s.pixels=PixelSurface.capture(Bitmap(display).bitmapData);
         for each(var filter:Object in display.filters) {
            var fs:Object={kind:getQualifiedClassName(filter)};
            if(filter is ColorMatrixFilter)fs.matrix=filter.matrix;
            else if(filter is GlowFilter || filter is BlurFilter || filter is DropShadowFilter) {
               for each(var k:String in ["color","alpha","blurX","blurY","strength","quality","inner","knockout","distance","angle","hideObject"])
                  if(k in filter)fs[k]=filter[k];
            }else continue;
            s.filters.push(fs);
         }
         if(display is TextField){s.text=TextField(display).htmlText;s.plainText=TextField(display).text;s.textColor=TextField(display).textColor;s.multiline=TextField(display).multiline;
            s.scrollH=TextField(display).scrollH;s.scrollV=TextField(display).scrollV;}
         var clip:MovieClip=display as MovieClip;
         if(clip!=null)s.f=clip.currentFrame;
         // Authored MovieClip geometry is already in the native assets. Runtime
         // Sprite/Shape drawings (laser pointers and curved trails) have no frames.
         if(display is Sprite && (clip==null || getQualifiedClassName(display)=="flash.display::MovieClip"))s.vector=VectorDraw.capture(Sprite(display).graphics);
         else if(display is Shape)s.vector=VectorDraw.capture(Shape(display).graphics);
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         // An invisible parent suppresses its entire subtree. Keep the root
         // state and capture the current children when it becomes visible;
         // hidden health bars otherwise multiply dense-room capture work.
         if(parent!=null && display.visible && display.alpha>0 && depth<12) {
            s.children=[];
            for(var i:int=0;i<parent.numChildren;i++) {
               var child:DisplayObject=parent.getChildAt(i);
               // Authority samples at EXIT_FRAME, after native construction.
               // A null timeline slot is not evidence that a limb is hidden.
               if(child==null)continue;
               if(child is MovieClip || child is TextField || child is Sprite || child is Bitmap || clip==null && child is Shape)
                  s.children.push({n:child.name,i:i,cls:getQualifiedClassName(child),s:capture(child,depth+1,includePixels)});
            }
         }
         // Native authored trees have many unchanged limbs, colors and empty
         // filter lists. Keep their immutable records instead of walking and
         // diffing fresh copies again at every enclosing entity/world level.
         var previous:Object=captured[display];
         if(previous!=null) {
            var same:Boolean=true;
            for(var field:String in s) {
               var value:*=s[field],old:*=previous[field];
               if(value===old)continue;
               if(field=="children") {
                  var equal:Boolean=old!=null && value.length==old.length;
                  if(equal)for(var j:int=0;j<value.length;j++) {
                     var ca:Object=value[j],cb:Object=old[j];
                     if(ca.n!==cb.n || ca.i!==cb.i || ca.cls!==cb.cls || ca.s!==cb.s){equal=false;break;}
                  }
                  if(equal)s[field]=old;else same=false;
               }else if((value is Array || field=="pixels") && recipeEqual(old,value))s[field]=old;
               else same=false;
            }
            for(field in previous)if(!s.hasOwnProperty(field)){same=false;break;}
            if(same){if(depth==0)Timing.end("capture.pose",began);return previous;}
         }
         captured[display]=s;if(depth==0)Timing.end("capture.pose",began);return s;
      }
      public static function recipeEqual(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a is ByteArray || b is ByteArray)return a is ByteArray && b is ByteArray && PixelSurface.sameBytes(a,b);
         if(a==null || b==null || typeof a!="object" || typeof b!="object" || (a is Array)!=(b is Array))return false;
         if(a is Array && a.length!=b.length)return false;
         for(var k:String in b)if(!a.hasOwnProperty(k) || !recipeEqual(a[k],b[k]))return false;
         for(k in a)if(!b.hasOwnProperty(k))return false;return true;
      }
   }
}
