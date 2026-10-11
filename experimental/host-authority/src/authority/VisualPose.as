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
   /** Native symbol state, with local pixel surfaces only for mutated bitmaps.
    * Never runs a second animation, AI or weapon simulation. */
   public final class VisualPose {
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
         if(display is TextField){s.text=TextField(display).htmlText;s.textColor=TextField(display).textColor;}
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
            if(same)return previous;
         }
         captured[display]=s;return s;
      }
      private static function recipeEqual(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!="object" || typeof b!="object" || (a is Array)!=(b is Array))return false;
         if(a is Array && a.length!=b.length)return false;
         for(var k:String in b)if(!a.hasOwnProperty(k) || !recipeEqual(a[k],b[k]))return false;
         for(k in a)if(!b.hasOwnProperty(k))return false;return true;
      }
      public static function apply(display:DisplayObject,s:Object):void {
         if(display==null || s==null)return;
         if(display is Bitmap && s.pixels!=null) {
            var nativePixels:Object=pixels[display];
            if(nativePixels==null || nativePixels.recipe!==s.pixels) {
               if(nativePixels==null)nativePixels=pixels[display]={data:null,recipe:null};
               nativePixels.data=PixelSurface.restore(s.pixels,nativePixels.data);
               Bitmap(display).bitmapData=nativePixels.data;nativePixels.recipe=s.pixels;
            }
         }
         if(s.vector!=null) {
            if(display is Sprite)VectorDraw.apply(display,Sprite(display).graphics,s.vector);
            else if(display is Shape)VectorDraw.apply(display,Shape(display).graphics,s.vector);
         }
         var clip:MovieClip=display as MovieClip;
         if(clip!=null && !scriptless[clip]) {
            // Authored visual symbols can jump to another frame from a frame
            // script (LMG frame 4 returns to 1). Replica playback owns this
            // timeline, so those local scripts must not override confirmation.
            for(var frame:int=0;frame<clip.totalFrames;frame++)clip.addFrameScript(frame,null);
            scriptless[clip]=true;
         }
         if(clip!=null && s.f!=null){if(clip.currentFrame!=int(s.f))clip.gotoAndStop(int(s.f));else clip.stop();}
         // Authored limbs also contain skew and precise fixed-point matrices.
         // Reassigning scale/rotation separately loses both over repeated frames.
         if(s.m!=null)display.transform.matrix=new Matrix(s.m[0],s.m[1],s.m[2],s.m[3],s.m[4],s.m[5]);
         else {display.x=s.x;display.y=s.y;display.scaleX=s.sx;display.scaleY=s.sy;display.rotation=s.r;}
         display.alpha=s.a;display.visible=s.v;
         if(s.blend!=null)display.blendMode=s.blend;
         var previous:Object=applied[display];if(previous==null)previous=applied[display]={};
         // FrameDelta keeps received branches immutable, and PoseTween retains
         // these discrete recipes. Reuse their key across display-only frames.
         var filterKey:String=recipeKey(s.filters),colorKey:String=recipeKey(s.c);
         if(previous.filters!==filterKey) {
         var filters:Array=[];
         for each(var fs:Object in s.filters) {
            var filter:Object;
            if(fs.kind=="flash.filters::ColorMatrixFilter")filter=new ColorMatrixFilter(fs.matrix);
            else {
               if(fs.kind=="flash.filters::GlowFilter")filter=new GlowFilter();
               else if(fs.kind=="flash.filters::BlurFilter")filter=new BlurFilter();
               else if(fs.kind=="flash.filters::DropShadowFilter")filter=new DropShadowFilter();
               else continue;
               for(var k:String in fs)if(k!="kind")filter[k]=fs[k];
            }
            filters.push(filter);
         }
         previous.nativeFilters=filters;
         previous.filters=filterKey;
         }
         display.filters=previous.nativeFilters;
         if(s.cache!=null)display.cacheAsBitmap=s.cache;
         if(display is Bitmap && s.smoothing!=null){Bitmap(display).smoothing=s.smoothing;Bitmap(display).pixelSnapping=s.pixelSnapping;}
         if(display is TextField && s.text!=null){if(TextField(display).htmlText!=s.text)TextField(display).htmlText=s.text;TextField(display).textColor=s.textColor;}
         if(s.c!=null && previous.color!==colorKey) {
            previous.nativeColor=new ColorTransform(s.c[0],s.c[1],s.c[2],s.c[3],s.c[4],s.c[5],s.c[6],s.c[7]);previous.color=colorKey;
         }
         if(s.c!=null)display.transform.colorTransform=previous.nativeColor;
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null && s.children!=null) {
         var managed:Dictionary=added[parent];if(managed==null)managed=added[parent]=new Dictionary(true);
         var live:Dictionary=new Dictionary(true);
         for each(var child:Object in s.children) {
            var target:DisplayObject=parent.getChildByName(child.n);
            if(target!=null && getQualifiedClassName(target)!=child.cls && managed[target]!==child.cls)target=null;
            // Unnamed authored children have different generated instance names.
            if(target==null && int(child.i)<parent.numChildren && getQualifiedClassName(parent.getChildAt(int(child.i)))==child.cls)target=parent.getChildAt(int(child.i));
            if(target==null) {
               if(child.s.vector!=null)target=child.cls=="flash.display::Shape"?new Shape():new Sprite();
               else if(child.cls=="flash.display::Bitmap")target=new Bitmap();
               else if(child.cls=="flash.text::TextField")target=new TextField();
               else if(resolve!=null){var Type:Class=resolve(child.cls);target=new Type() as DisplayObject;}
               if(target!=null){target.name=child.n;parent.addChildAt(target,Math.min(child.i,parent.numChildren));managed[target]=child.cls;}
            }
            if(target!=null){live[target]=true;apply(target,child.s);}
         }
         for(var owned:Object in managed)if(!live[owned]) {
            if(owned.parent===parent)parent.removeChild(owned as DisplayObject);dispose(owned as DisplayObject);delete managed[owned];
         }
         }
      }
      public static function dispose(display:DisplayObject):void {
         if(display==null)return;
         var surface:Object=pixels[display];if(surface!=null){surface.data.dispose();delete pixels[display];}
         VectorDraw.dispose(display);delete applied[display];delete added[display];delete captured[display];delete scriptless[display];
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null)for(var i:int=0;i<parent.numChildren;i++)dispose(parent.getChildAt(i));
      }
   }
}
