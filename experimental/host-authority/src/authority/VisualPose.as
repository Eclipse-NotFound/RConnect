package authority {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.text.TextField;
   import flash.filters.GlowFilter;
   import flash.filters.BlurFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.ColorMatrixFilter;
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   /** Native symbol state, not pixels or a second animation/weapon simulation. */
   public final class VisualPose {
      public static var resolve:Function;
      private static var applied:Dictionary=new Dictionary(true),added:Dictionary=new Dictionary(true);
      public static function capture(display:DisplayObject,depth:int=0):Object {
         if(display==null)return null;
         var color:ColorTransform=display.transform.colorTransform;
         var s:Object={x:display.x,y:display.y,sx:display.scaleX,sy:display.scaleY,r:display.rotation,
            a:display.alpha,v:display.visible,c:[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,
               color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset]};
         s.blend=display.blendMode;s.filters=[];
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
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null && depth<6) {
            s.children=[];
            for(var i:int=0;i<parent.numChildren;i++) {
               var child:DisplayObject=parent.getChildAt(i);
               if(child is MovieClip || child is TextField) s.children.push({n:child.name,i:i,cls:getQualifiedClassName(child),s:capture(child,depth+1)});
            }
         }
         return s;
      }
      public static function apply(display:DisplayObject,s:Object):void {
         if(display==null || s==null)return;
         var clip:MovieClip=display as MovieClip;
         if(clip!=null && s.f!=null){if(clip.currentFrame!=int(s.f))clip.gotoAndStop(int(s.f));else clip.stop();}
         display.x=s.x;display.y=s.y;display.scaleX=s.sx;display.scaleY=s.sy;
         display.rotation=s.r;display.alpha=s.a;display.visible=s.v;
         if(s.blend!=null)display.blendMode=s.blend;
         var previous:Object=applied[display];if(previous==null)previous=applied[display]={};
         var filterKey:String=JSON.stringify(s.filters),colorKey:String=JSON.stringify(s.c);
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
         if(display is TextField && s.text!=null){if(TextField(display).htmlText!=s.text)TextField(display).htmlText=s.text;TextField(display).textColor=s.textColor;}
         if(s.c!=null && previous.color!==colorKey) {
            previous.nativeColor=new ColorTransform(s.c[0],s.c[1],s.c[2],s.c[3],s.c[4],s.c[5],s.c[6],s.c[7]);previous.color=colorKey;
         }
         if(s.c!=null)display.transform.colorTransform=previous.nativeColor;
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null) {
         var managed:Dictionary=added[parent];if(managed==null)managed=added[parent]=new Dictionary(true);
         var live:Dictionary=new Dictionary(true);
         for each(var child:Object in s.children) {
            var target:DisplayObject=parent.getChildByName(child.n);
            if(target!=null && getQualifiedClassName(target)!=child.cls)target=null;
            // Unnamed authored children have different generated instance names.
            if(target==null && int(child.i)<parent.numChildren && getQualifiedClassName(parent.getChildAt(int(child.i)))==child.cls)target=parent.getChildAt(int(child.i));
            if(target==null && resolve!=null) {
               if(child.cls=="flash.text::TextField")target=new TextField();
               else {var Type:Class=resolve(child.cls);target=new Type() as DisplayObject;}
               if(target!=null){target.name=child.n;parent.addChildAt(target,Math.min(child.i,parent.numChildren));managed[target]=true;}
            }
            if(target!=null){live[target]=true;apply(target,child.s);}
         }
         for(var owned:Object in managed)if(!live[owned]) {
            if(owned.parent===parent)parent.removeChild(owned as DisplayObject);delete managed[owned];
         }
         }
      }
   }
}
