package rconnect.game {
   import fe.weapon.RConnectMeleeAccess;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;

   /** Actual WClub display frames, including thrust offsets and the native
    * slash clip. No attack/actions/step, hit tests, ammo or rewards are replayed. */
   public class MeleeVisuals {
      private static var observed:Dictionary=new Dictionary(true);
      private var painted:Dictionary=new Dictionary(true);
      private static const HISTORY_MS:int=800;
      private static const MAX_FRAMES:int=32;

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function round(n:Number):Number {return Math.round(n*1000)/1000;}

      public static function observe(u:Object,w:Object,stamp:int=0):void {
         if(!RConnectMeleeAccess.isClub(w))return;
         var body:DisplayObject=get(u,"vis") as DisplayObject;
         var layer:DisplayObjectContainer=body==null?null:body.parent;
         var v:DisplayObject=get(w,"vis") as DisplayObject;
         if(layer==null || v==null || v.parent==null)return;
         if(stamp<=0)stamp=getTimer();
         var rec:Object=observed[w];
         if(rec==null)rec=observed[w]={at:-1,frames:[]};
         var replace:Boolean=int(rec.at)==stamp;
         rec.at=stamp;
         var pose:Object=capturePose(u,v,layer),trail:MovieClip=RConnectMeleeAccess.trail(w);
         var slash:Object=trail==null || trail.parent==null?null:capturePose(u,trail,layer);
         var point:Object={at:stamp,weapon:pose,trail:slash,bodyAlpha:body.alpha};
         // The final RENDER sample supersedes the same native simulation frame
         // recorded in ENTER_FRAME; frame scripts may have moved the display.
         if(replace && rec.frames.length>0)rec.frames[rec.frames.length-1]=point;
         else if(rec.frames.length>=2 && same(rec.frames[rec.frames.length-2],rec.frames[rec.frames.length-1])
            && same(rec.frames[rec.frames.length-1],point))rec.frames[rec.frames.length-1]=point;
         else rec.frames.push(point);
         // Keep one preceding sample for interpolation across the cutoff.
         while(rec.frames.length>MAX_FRAMES || (rec.frames.length>2 && stamp-int(rec.frames[1].at)>HISTORY_MS))rec.frames.shift();
      }

      private static function same(a:Object,b:Object):Boolean {
         return a.bodyAlpha===b.bodyAlpha && samePose(a.weapon,b.weapon) && samePose(a.trail,b.trail);
      }
      private static function samePose(a:Object,b:Object):Boolean {
         if(a==null || b==null)return a===b;
         for each(var key:String in ["x","y","r","sx","sy","a","visible","f"])if(a[key]!==b[key])return false;
         if(a.color is Array && b.color is Array)for(var i:int=0;i<8;i++)if(a.color[i]!==b.color[i])return false;
         return true;
      }

      public static function capture(u:Object,w:Object):Object {
         if(!RConnectMeleeAccess.isClub(w))return null;
         var rec:Object=observed[w];
         if(rec==null){observe(u,w);rec=observed[w];}
         return rec==null?null:{kind:"club",player:get(u,"player")===true,frames:rec.frames.concat()};
      }

      private static function capturePose(u:Object,v:DisplayObject,layer:DisplayObjectContainer):Object {
         // Point projection rounds to display units. A one-pixel basis can
         // amplify that rounding into visible angle/scale jitter.
         var basis:Matrix=WeaponDisplay.relativeMatrix(v,layer);if(basis==null)return null;
         var sx:Number=Math.sqrt(basis.a*basis.a+basis.b*basis.b);
         var c:ColorTransform=v.transform.colorTransform;
         return {x:round(basis.tx-Number(u.X)),y:round(basis.ty-Number(u.Y)),r:Math.atan2(basis.b,basis.a),
            sx:round(sx),sy:sx<.0001?0:round((basis.a*basis.d-basis.b*basis.c)/sx),a:round(v.alpha),
            color:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
               c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset],
            visible:v.visible,f:v is MovieClip?MovieClip(v).currentFrame:1};
      }

      /** Pure helper so the native fixture can check the sampled pose against
       * independently recorded source transforms at this exact source time. */
      public static function sample(s:Object,time:Number):Object {
         var frames:Array=s==null?null:s.frames as Array;
         if(frames==null || frames.length==0)return null;
         if(!isFinite(time))time=Number(frames[frames.length-1].at);
         var a:Object=frames[0],b:Object=a;
         for each(var point:Object in frames) {
            if(Number(point.at)>time){b=point;break;}
            a=b=point;
         }
         var span:Number=Number(b.at)-Number(a.at);
         var t:Number=span>0?Math.max(0,Math.min(1,(time-Number(a.at))/span)):0;
         return {weapon:blend(a.weapon,b.weapon,t),trail:blend(a.trail,b.trail,t),bodyAlpha:a.bodyAlpha};
      }

      private static function blend(a:Object,b:Object,t:Number):Object {
         if(a==null || b==null)return a;
         var p:Object={};for(var key:String in a)p[key]=a[key];
         p.x=Number(a.x)+(Number(b.x)-Number(a.x))*t;
         p.y=Number(a.y)+(Number(b.y)-Number(a.y))*t;
         var angle:Number=Number(b.r)-Number(a.r);
         while(angle>Math.PI)angle-=Math.PI*2;
         while(angle<-Math.PI)angle+=Math.PI*2;
         p.r=Number(a.r)+angle*t;
         // Frame, visibility and handedness are source states, not tweens.
         return p;
      }

      public function apply(u:Object,w:Object,s:Object,time:Number=NaN):Boolean {
         if(!RConnectMeleeAccess.isClub(w) || s==null || s.kind!="club")return false;
         var pose:Object=sample(s,time);
         var body:DisplayObject=get(u,"vis") as DisplayObject;
         var layer:DisplayObjectContainer=body==null?null:body.parent;
         var v:DisplayObject=get(w,"vis") as DisplayObject;
         if(pose==null || layer==null || v==null || v.parent==null)return false;
         var trail:MovieClip=RConnectMeleeAccess.trail(w);
         var rec:Object=painted[w];
         if(rec==null)rec=painted[w]={vis:v,visParent:v.parent,visColor:v.transform.colorTransform,
            trail:trail,parent:trail==null?null:trail.parent};
         // WClub is a native world-layer visual. In particular, native stealth
         // fades the pony but does not fade its weapon (UnitPlayer.setFilters).
         // A body child cannot represent that with alpha limited to [0,1].
         if(v.parent!==layer)layer.addChild(v);
         var marker:Number=s.player===true && String(get(u,"id")).indexOf("rconnect_ghost_")==0?.75:1;
         var factor:Number=marker;
         if(marker==1 && isFinite(Number(pose.bodyAlpha)) && Number(pose.bodyAlpha)>0)
            factor=Math.max(0,Math.min(1,body.alpha/Number(pose.bodyAlpha)));
         paint(u,v,pose.weapon,body,layer,factor);
         if(trail!=null) {
            if(pose.trail!=null) {
               if(trail.parent!==layer)layer.addChild(trail);
               paint(u,trail,pose.trail,body,layer,factor);
            } else trail.visible=false;
         }
         return true;
      }

      private function paint(u:Object,v:DisplayObject,p:Object,body:DisplayObject,layer:DisplayObjectContainer,factor:Number):void {
         if(p==null || v.parent==null)return;
         if(v is MovieClip) {
            var clip:MovieClip=v as MovieClip,f:int=Math.max(1,Math.min(clip.totalFrames,int(p.f)));
            if(clip.currentFrame!=f)clip.gotoAndStop(f);
            clip.stop();
         }
         var cos:Number=Math.cos(Number(p.r)),sin:Number=Math.sin(Number(p.r));
         var m:Matrix=new Matrix(cos*Number(p.sx),sin*Number(p.sx),-sin*Number(p.sy),cos*Number(p.sy),
            Number(u.X)+Number(p.x),Number(u.Y)+Number(p.y));
         // apply() has already attached both clips to this exact world layer.
         // A camera/global round trip here loses subpixel placement precision.
         v.transform.matrix=m;
         v.visible=p.visible===true && body.visible;
         if(p.color is Array && p.color.length==8) {
            var c:Array=p.color;
            v.transform.colorTransform=new ColorTransform(Number(c[0]),Number(c[1]),Number(c[2]),Number(c[3]),
               Number(c[4]),Number(c[5]),Number(c[6]),Number(c[7]));
         }
         // Preserve the native slash's own 10/rapid opacity. The teammate
         // marker is separate from the source pony's stealth/tint state.
         v.alpha=Math.max(0,Math.min(1,Number(p.a)*factor));
      }

      public function forget(w:Object):void {
         var rec:Object=painted[w];if(rec==null)return;
         var vis:DisplayObject=rec.vis as DisplayObject;
         if(vis!=null) {
            if(vis.parent!=null && vis.parent!==rec.visParent)vis.parent.removeChild(vis);
            if(rec.visParent!=null && vis.parent!==rec.visParent)DisplayObjectContainer(rec.visParent).addChild(vis);
            if(rec.visColor is ColorTransform)vis.transform.colorTransform=rec.visColor;
         }
         var trail:MovieClip=rec.trail as MovieClip;
         if(trail!=null) {
            if(trail.parent!=null && trail.parent!==rec.parent)trail.parent.removeChild(trail);
            if(rec.parent!=null && trail.parent!==rec.parent)DisplayObjectContainer(rec.parent).addChild(trail);
            trail.visible=false;
         }
         delete painted[w];
      }
      public function reset():void {for(var w:Object in painted)forget(w);painted=new Dictionary(true);}
      public static function resetObserved():void {observed=new Dictionary(true);}
   }
}
