package authority {
   import flash.display.BlendMode;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** The authored hpBar recipe, after the host has calculated health/shields.
    * No Unit.visDetails(), private maxima or combat method runs here. */
   public final class HealthBarPose {
      private static const KIND:String="hpbar-native-1";
      private static const SLOTS:Array=["armor","bar","goldstar"];
      private static const EMPTY:Array=[];
      private static var captured:Dictionary=new Dictionary(true);
      private static var drawingProbe:Shape=new Shape();

      /** The caller owns this fresh envelope and may append attached. Only the
       * immutable root/part records can be shared with older confirmations. */
      public static function capture(display:DisplayObject):Object {
         if(display==null || !display.visible || display.alpha<=0)return {kind:"full",pose:VisualPose.capture(display)};
         var slots:Array=known(display);
         if(slots==null)return {kind:"full",pose:VisualPose.capture(display)};
         var pose:Object=VisualPose.captureRoot(display),parts:Array=null;
         // Full VisualPose also omits the subtree while its root is hidden.
         if(pose.v && pose.a>0) {
            parts=[];
            var parent:MovieClip=display as MovieClip;
            for(var i:int=0;i<slots.length;i++)parts.push(part(slots[i],parent.getChildIndex(slots[i])));
         }
         return {kind:KIND,pose:pose,parts:parts};
      }

      private static function known(display:DisplayObject):Array {
         var root:MovieClip=display as MovieClip;
         if(root==null || getQualifiedClassName(root)!="hpBar" || root.totalFrames!=1 || root.currentFrame!=1)return null;
         var slots:Array=[];
         for(var i:int=0;i<SLOTS.length;i++) {
            var child:MovieClip=root.getChildByName(SLOTS[i]) as MovieClip;
            if(child==null || child.parent!==root || Object(root)[SLOTS[i]]!==child)return null;
            var cls:String=getQualifiedClassName(child);
            // hp_bar2_165 has a frame-19 gotoAndPlay loop and is deliberately
            // excluded. hp_bar3/4 only stop on frame 1; goldstar has no class
            // script. Any other named or nested symbol uses the full path.
            if(i<2) {
               if(cls!="pfe_fla::hp_bar4_243" && cls!="pfe_fla::hp_bar3_245")return null;
            }else if(cls!="flash.display::MovieClip")return null;
            if(child.filters.length!=0 || child.blendMode!=BlendMode.NORMAL || child.mask!=null ||
               child.scrollRect!=null || child.scale9Grid!=null)return null;
            for(var j:int=0;j<child.numChildren;j++)if(!(child.getChildAt(j) is Shape))return null;
            // VisualPose reads own Graphics only for an anonymous MovieClip.
            // readGraphicsData can omit drawTriangles, so inspect copied
            // bounds too instead of mistaking those drawings for an empty one.
            if(cls=="flash.display::MovieClip" && hasDrawing(child))return null;
            slots.push(child);
         }
         for(i=0;i<root.numChildren;i++) {
            var member:DisplayObject=root.getChildAt(i);
            // Authored Shape children are also omitted by full VisualPose for
            // MovieClips; the same native asset supplies their artwork.
            if(member is Shape)continue;
            if(member!==slots[0] && member!==slots[1] && member!==slots[2])return null;
         }
         return slots;
      }

      private static function hasDrawing(clip:MovieClip):Boolean {
         if(clip.graphics.readGraphicsData(false).length!=0)return true;
         try {
            drawingProbe.graphics.copyFrom(clip.graphics);
            var bounds:Rectangle=drawingProbe.getBounds(drawingProbe);
            return bounds.width>0 && bounds.height>0;
         }finally {drawingProbe.graphics.clear();}
      }

      private static function part(clip:MovieClip,index:int):Object {
         var previous:Object=captured[clip],matrix:Matrix=clip.transform.matrix,color:ColorTransform=clip.transform.colorTransform;
         var m:Array=previous==null?null:previous.m,c:Array=previous==null?null:previous.c;
         if(m==null || m[0]!==matrix.a || m[1]!==matrix.b || m[2]!==matrix.c || m[3]!==matrix.d || m[4]!==matrix.tx || m[5]!==matrix.ty)
            m=[matrix.a,matrix.b,matrix.c,matrix.d,matrix.tx,matrix.ty];
         if(c==null || c[0]!==color.redMultiplier || c[1]!==color.greenMultiplier || c[2]!==color.blueMultiplier || c[3]!==color.alphaMultiplier ||
            c[4]!==color.redOffset || c[5]!==color.greenOffset || c[6]!==color.blueOffset || c[7]!==color.alphaOffset)
            c=[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset];
         var state:Object={cls:getQualifiedClassName(clip),i:index,f:clip.currentFrame,m:m,c:c,
            sx:clip.scaleX,sy:clip.scaleY,a:clip.alpha,v:clip.visible,cache:clip.cacheAsBitmap};
         if(previous!=null) {
            var same:Boolean=true;
            for(var key:String in state)if(state[key]!==previous[key]){same=false;break;}
            if(same)return previous;
         }
         captured[clip]=state;return state;
      }

      /** Reconstitute only the three known child instructions on the receiver.
       * The existing copier owns frame-script suppression, native class
       * replacement and cleanup of nodes created by a prior full fallback. */
      public static function apply(display:DisplayObject,state:Object,interpolated:Boolean=false):void {
         if(display==null || state==null)return;
         var pose:Object=fullPose(state);
         if(interpolated)VisualPose.motion(display,pose);else VisualPose.apply(display,pose);
      }

      private static function fullPose(state:Object):Object {
         var pose:Object=state.pose;
         if(state.kind===KIND && state.parts!=null && pose!=null && pose.v && pose.a>0) {
            pose=PoseTween.copy(pose);pose.children=[];
            for(var i:int=0;i<SLOTS.length;i++) {
               var p:Object=state.parts[i];
               // PoseTween reads scalar transforms as well as the precise
               // matrix. These are temporary inputs; rendering still uses m.
               var rotation:Number=Math.atan2(Number(p.m[1]),Number(p.m[0]))*180/Math.PI;
               if(!isFinite(rotation))rotation=0;
               var native:Object={f:p.f,m:p.m,x:p.m[4],y:p.m[5],sx:p.sx,sy:p.sy,r:rotation,
                  c:p.c,a:p.a,v:p.v,cache:p.cache,
                  blend:BlendMode.NORMAL,filters:EMPTY,children:EMPTY};
               if(p.cls=="flash.display::MovieClip")native.vector=EMPTY;
               pose.children.push({n:SLOTS[i],i:p.i,cls:p.cls,s:native});
            }
            // Full VisualPose lists children in display-list order. Match it
            // at a compact/full transition: PoseTween pairs array positions
            // before checking the recorded native child index and class.
            pose.children.sortOn("i",Array.NUMERIC);
         }
         return pose;
      }

      public static function tween(a:Object,b:Object,t:Number):Object {
         if(a==null || b==null || a===b)return a;
         var out:Object=PoseTween.copy(a);
         // A mode change must preserve child interpolation too. Materialize
         // temporary native recipes locally, without expanding the wire state.
         if(a.kind!==b.kind) {
            out.kind="full";out.pose=PoseTween.pose(fullPose(a),fullPose(b),t);
            delete out.parts;return out;
         }
         out.pose=PoseTween.pose(a.pose,b.pose,t);
         if(a.kind!==KIND || b.kind!==KIND || a.parts==null || b.parts==null ||
            a.pose.v!==b.pose.v || a.pose.f!==b.pose.f)return out;
         out.parts=[];
         for(var i:int=0;i<SLOTS.length;i++) {
            var p:Object=a.parts[i],q:Object=b.parts[i];
            out.parts.push(p.i===q.i && p.cls===q.cls?tweenPart(p,q,t):p);
         }
         return out;
      }

      private static function tweenPart(a:Object,b:Object,t:Number):Object {
         if(a===b || a.v!==b.v)return a;
         var out:Object=PoseTween.copy(a);out.a=lerp(a.a,b.a,t);
         out.m=a.m.concat();out.m[4]=lerp(a.m[4],b.m[4],t);out.m[5]=lerp(a.m[5],b.m[5],t);
         // Match PoseTween.pose: interpolate each affine basis, and keep a
         // reflected basis discrete so a flipped bar cannot shrink through 0.
         if(a.sx*b.sx>=0 && a.sy*b.sy>=0) {
            out.sx=lerp(a.sx,b.sx,t);out.sy=lerp(a.sy,b.sy,t);
            for(var axis:int=0;axis<4;axis+=2) {
               if(a.m[axis]===b.m[axis] && a.m[axis+1]===b.m[axis+1])continue;
               var ar:Number=Math.sqrt(a.m[axis]*a.m[axis]+a.m[axis+1]*a.m[axis+1]);
               var br:Number=Math.sqrt(b.m[axis]*b.m[axis]+b.m[axis+1]*b.m[axis+1]);
               var rotation:Number=angle(Math.atan2(a.m[axis+1],a.m[axis])*180/Math.PI,Math.atan2(b.m[axis+1],b.m[axis])*180/Math.PI,t)*Math.PI/180;
               var radius:Number=lerp(ar,br,t);out.m[axis]=Math.cos(rotation)*radius;out.m[axis+1]=Math.sin(rotation)*radius;
            }
         }
         return out;
      }
      private static function lerp(a:Number,b:Number,t:Number):Number{return a+(b-a)*t;}
      private static function angle(a:Number,b:Number,t:Number):Number{return a+(((b-a+540)%360)-180)*t;}
   }
}
