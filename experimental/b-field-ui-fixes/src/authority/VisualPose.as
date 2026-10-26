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
   /** Native symbol state, with local pixel surfaces only for mutated bitmaps.
    * Never runs a second animation, AI or weapon simulation. */
   public final class VisualPose {
      public static var resolve:Function;
      private static var applied:Dictionary=new Dictionary(true),added:Dictionary=new Dictionary(true);
      private static var captured:Dictionary=new Dictionary(true);
      private static var scriptless:Dictionary=new Dictionary(true);
      private static var pixels:Dictionary=new Dictionary(true);
      private static var immutableKeys:Dictionary=new Dictionary(true);
      private static const EMPTY_FILTERS:Array=[];
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
         var previous:Object=captured[display],m:Array=previous==null?null:previous.m,c:Array=previous==null?null:previous.c;
         // Compare fixed native value tuples before allocating. These arrays
         // are immutable wire recipes; unchanged colors/matrices need neither
         // fresh arrays nor a recursive property-by-property comparison.
         if(m==null || m[0]!==matrix.a || m[1]!==matrix.b || m[2]!==matrix.c || m[3]!==matrix.d || m[4]!==matrix.tx || m[5]!==matrix.ty)
            m=[matrix.a,matrix.b,matrix.c,matrix.d,matrix.tx,matrix.ty];
         if(c==null || c[0]!==color.redMultiplier || c[1]!==color.greenMultiplier || c[2]!==color.blueMultiplier || c[3]!==color.alphaMultiplier ||
            c[4]!==color.redOffset || c[5]!==color.greenOffset || c[6]!==color.blueOffset || c[7]!==color.alphaOffset)
            c=[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset];
         var s:Object={x:display.x,y:display.y,sx:display.scaleX,sy:display.scaleY,r:display.rotation,
            m:m,a:display.alpha,v:display.visible,c:c};
         var nativeFilters:Array=display.filters;
         s.blend=display.blendMode;s.cache=display.cacheAsBitmap;s.filters=nativeFilters.length==0?EMPTY_FILTERS:[];
         if(display is Bitmap){s.smoothing=Bitmap(display).smoothing;s.pixelSnapping=Bitmap(display).pixelSnapping;}
         if(includePixels && display is Bitmap && Bitmap(display).bitmapData!=null)s.pixels=PixelSurface.capture(Bitmap(display).bitmapData);
         for each(var filter:Object in nativeFilters) {
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
      private static function transform(display:DisplayObject,s:Object):void {
         if(s.m!=null)display.transform.matrix=new Matrix(s.m[0],s.m[1],s.m[2],s.m[3],s.m[4],s.m[5]);
         else {display.x=s.x;display.y=s.y;display.scaleX=s.sx;display.scaleY=s.sy;display.rotation=s.r;}
         display.alpha=s.a;display.visible=s.v;
      }
      /** Between confirmations the display tree, text, filters and pixel
       * surfaces already belong to the left frame. Only transforms/alpha can
       * interpolate; never reconstruct or rerun those discrete properties. */
      public static function motion(display:DisplayObject,s:Object):void {
         if(display==null || s==null)return;
         transform(display,s);
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent==null || s.children==null)return;
         var managed:Dictionary=added[parent];
         for each(var child:Object in s.children) {
            var target:DisplayObject=parent.getChildByName(child.n);
            if(target!=null && getQualifiedClassName(target)!=child.cls && (managed==null || managed[target]!==child.cls))target=null;
            if(target==null && int(child.i)<parent.numChildren && getQualifiedClassName(parent.getChildAt(int(child.i)))==child.cls)target=parent.getChildAt(int(child.i));
            if(target==null)throw new Error("Interpolated pose has no confirmed native child");
            motion(target,child.s);
         }
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
         transform(display,s);
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
         if(display is TextField && s.text!=null) {
            var text:TextField=TextField(display);
            var multiline:Boolean=text.multiline;
            // With multiline=false AIR's HTML parser drops paragraph breaks
            // that still exist in native .text. Import with breaks enabled,
            // then restore the field's real presentation mode.
            text.multiline=true;
            if(text.htmlText!=s.text || s.plainText!=null && text.text!==s.plainText)text.htmlText=s.text;
            // AIR's generated <P> wrapper adds a final carriage return when
            // read back through htmlText. Remove only parser-added suffixes,
            // preserving actual native line breaks and all remaining formats.
            if(s.plainText!=null && text.text!==s.plainText && text.text.indexOf(s.plainText)==0 &&
               /^\r+$/.test(text.text.substr(s.plainText.length)))text.replaceText(s.plainText.length,text.length,"");
            text.textColor=s.textColor;
            text.multiline=s.multiline==null?multiline:Boolean(s.multiline);
            // replaceText moves AIR's caret and can scroll a wrapped large
            // damage number to its last line. Restore the native viewport
            // after importing text and removing the parser-added suffix.
            if(s.scrollH!=null)text.scrollH=s.scrollH;if(s.scrollV!=null)text.scrollV=s.scrollV;
            // Center/right autosize can move the field while HTML is imported,
            // and replaceText can perform another layout. The snapshot matrix
            // already describes the post-layout native position. Restore it
            // last so a confirmed frame and its following motion-only frame
            // cannot alternate between two text positions.
            transform(display,s);
         }
         if(s.c!=null && previous.color!==colorKey) {
            previous.nativeColor=new ColorTransform(s.c[0],s.c[1],s.c[2],s.c[3],s.c[4],s.c[5],s.c[6],s.c[7]);previous.color=colorKey;
         }
         if(s.c!=null)display.transform.colorTransform=previous.nativeColor;
         // alpha is also ColorTransform.alphaMultiplier. Reapplying the left
         // confirmation's color must not overwrite the interpolated opacity.
         display.alpha=s.a;
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
