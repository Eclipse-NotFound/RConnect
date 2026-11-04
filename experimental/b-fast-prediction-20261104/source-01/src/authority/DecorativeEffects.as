package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** Only the known, stopped native damage-number symbol. No Part simulation. */
   public final class DecorativeEffects {
      private var captured:Dictionary=new Dictionary(true);
      private var blocked:Dictionary=new Dictionary(true);
      private var applied:Dictionary=new Dictionary(true);
      // These layout settings are not fully represented by VisualPose. A live
      // change leaves this Part on the original path for the rest of its life.
      private static const LAYOUT:Array=["width","height","autoSize","wordWrap","embedFonts","antiAliasType",
         "gridFitType","sharpness","thickness","background","backgroundColor","border","borderColor",
         "displayAsPassword","condenseWhite","type"];
      private static const FILTER_FIELDS:Array=["color","alpha","blurX","blurY","strength","quality",
         "inner","knockout","distance","angle","hideObject"];

      public function capture(value:Object):Object {
         if(value==null || getQualifiedClassName(value)!="fe.graph::Part")return reject(value);
         if(blocked[value] || !value.in_chain || value.loc==null || value.isAnim!=0 || value.water!=0 ||
            value.otklad!=0 || value.blitData!=null || value.liv<=0 || value.mliv<=0)return reject(value);
         var display:MovieClip=value.vis as MovieClip;
         if(display==null || getQualifiedClassName(display)!="visualNumb" || display.isPlaying ||
            display.parent==null || display.mask!=null || display.numChildren!=1)return reject(value);
         var text:TextField=display.getChildAt(0) as TextField;
         if(text==null || getQualifiedClassName(text)!="flash.text::TextField" ||
            Object(display).numb!==text || text.name!="numb" || text.mask!=null || text.styleSheet!=null)return reject(value);
         var filters:Array=text.filters;
         var rec:Object=captured[value];
         if(rec!=null && (rec.display!==display || rec.text!==text))rec=null;
         if(rec!=null && !sameLayout(text,rec.layout)) {
            blocked[value]=true;return reject(value);
         }
         if(rec==null || display.currentFrame!=rec.recipe.f || !sameText(text,rec.recipe.children[0].s,filters)) {
            if(!knownFilters(filters))return reject(value);
            // Invisible roots omit children in the original capture contract.
            // Wait for a visible confirmation rather than caching an empty tree.
            if(!display.visible || display.alpha<=0)return reject(value);
            var full:Object=VisualPose.capture(display);
            if(full.children==null || full.children.length!=1 || full.children[0].i!=0 ||
               full.children[0].n!="numb" || full.children[0].cls!="flash.text::TextField")return reject(value);
            var recipe:Object={f:full.f,children:full.children};
            var layout:Array=[];for each(var key:String in LAYOUT)layout.push(text[key]);
            rec={display:display,text:text,layout:layout,recipe:recipe};captured[value]=rec;
         }
         // captureRoot has a separate cache and never walks or stores children.
         // Native Part.step still owns motion, fading, lifetime and removal.
         return {pose:VisualPose.captureRoot(display),decor:{recipe:rec.recipe}};
      }

      private function reject(value:Object):Object {
         if(value!=null)delete captured[value];return null;
      }
      private static function sameLayout(text:TextField,layout:Array):Boolean {
         for(var i:int=0;i<LAYOUT.length;i++)if(text[LAYOUT[i]]!==layout[i])return false;
         return true;
      }
      private static function knownFilters(filters:Array):Boolean {
         for each(var filter:Object in filters) {
            var kind:String=getQualifiedClassName(filter);
            if(kind!="flash.filters::ColorMatrixFilter" && kind!="flash.filters::GlowFilter" &&
               kind!="flash.filters::BlurFilter" && kind!="flash.filters::DropShadowFilter")return false;
         }
         return true;
      }
      private static function sameText(text:TextField,s:Object,filters:Array):Boolean {
         if(text.text!==s.plainText || text.htmlText!==s.text || text.textColor!==s.textColor ||
            text.multiline!==s.multiline || text.scrollH!==s.scrollH || text.scrollV!==s.scrollV ||
            text.visible!==s.v || text.alpha!==s.a || text.blendMode!==s.blend || text.cacheAsBitmap!==s.cache)return false;
         var m:Matrix=text.transform.matrix,c:ColorTransform=text.transform.colorTransform;
         if(s.m==null || m==null || m.a!==s.m[0] || m.b!==s.m[1] || m.c!==s.m[2] ||
            m.d!==s.m[3] || m.tx!==s.m[4] || m.ty!==s.m[5])return false;
         if(c.redMultiplier!==s.c[0] || c.greenMultiplier!==s.c[1] || c.blueMultiplier!==s.c[2] ||
            c.alphaMultiplier!==s.c[3] || c.redOffset!==s.c[4] || c.greenOffset!==s.c[5] ||
            c.blueOffset!==s.c[6] || c.alphaOffset!==s.c[7] || filters.length!=s.filters.length)return false;
         for(var i:int=0;i<filters.length;i++) {
            var filter:Object=filters[i],prior:Object=s.filters[i];
            if(getQualifiedClassName(filter)!==prior.kind)return false;
            if(prior.kind=="flash.filters::ColorMatrixFilter") {
               var matrix:Array=filter.matrix;
               if(matrix.length!=prior.matrix.length)return false;
               for(var j:int=0;j<matrix.length;j++)if(matrix[j]!==prior.matrix[j])return false;
            }else for each(var key:String in FILTER_FIELDS)if(key in filter && filter[key]!==prior[key])return false;
         }
         return true;
      }

      public function apply(display:DisplayObject,pose:Object,decor:Object):void {
         if(display==null || pose==null || decor==null)return;
         if(applied[display]!==decor.recipe) {
            var full:Object=PoseTween.copy(pose);
            // Install the text even when this first received root is hidden.
            // A temporary interpolated child pose, when present, already owns
            // the correct transform and must not be replaced by the template.
            if(full.children==null)full.children=decor.recipe.children;
            VisualPose.apply(display,full);applied[display]=decor.recipe;
         }else VisualPose.apply(display,pose);
      }
      public function motion(display:DisplayObject,pose:Object,decor:Object):void {
         if(display==null || pose==null || decor==null)return;
         if(applied[display]!==decor.recipe)apply(display,pose,decor);
         else VisualPose.motion(display,pose);
      }
      /** Call before full-pose fallback and when the receiver removes a clip. */
      public function forget(display:DisplayObject):void {if(display!=null)delete applied[display];}
   }
}
