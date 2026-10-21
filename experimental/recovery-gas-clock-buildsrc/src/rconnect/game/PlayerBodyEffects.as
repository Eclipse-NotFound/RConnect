package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.filters.BlurFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;

   /** Native, presentation-only body state. Never run Effect.setEff/step,
    * spells, particles with gameplay, or UnitPlayer.animate on a ghost.
    * Root visible/masks, weapons, wing poses and emitted fire have other owners.
    */
   public class PlayerBodyEffects {
      private static const PARTS:Array=["shit","inh","cryst","fetter","rat","svet",
         "osn.body.head.morda.magic","osn.body.head.morda.eye"];
      private var observed:Dictionary=new Dictionary(true);
      private var applied:Dictionary=new Dictionary();

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function node(root:Object,path:String):DisplayObject {
         var o:Object=root;
         for each(var key:String in path.split("."))o=get(o,key);
         return o as DisplayObject;
      }
      private static function finite(n:*,fallback:Number=0):Number {
         return n!=null && isFinite(Number(n))?Number(n):fallback;
      }
      private static function clamp(n:*,lo:Number,hi:Number,fallback:Number=0):Number {
         return Math.max(lo,Math.min(hi,finite(n,fallback)));
      }
      private static function equal(a:Array,b:Array):Boolean {
         if(a==null || b==null || a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++) {
            if(a[i] is Array || b[i] is Array) {
               if(!(a[i] is Array) || !(b[i] is Array) || !equal(a[i],b[i]))return false;
            } else if(a[i]!==b[i])return false;
         }
         return true;
      }
      private static function colors(v:DisplayObject):Array {
         var c:ColorTransform=v.transform.colorTransform;
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private static function tint(v:DisplayObject,a:Array,preserveAlpha:Boolean=false):void {
         if(a==null || a.length!=8)return;
         // This runs for every mirrored enemy at final RENDER. Compare the
         // native channels once without four temporary arrays per quiet body.
         var c:ColorTransform=v.transform.colorTransform;
         var r:Number=clamp(a[0],-16,16,1),g:Number=clamp(a[1],-16,16,1),b:Number=clamp(a[2],-16,16,1);
         var alpha:Number=clamp(preserveAlpha?c.alphaMultiplier:a[3],-16,16,1);
         var ro:Number=clamp(a[4],-4096,4096),go:Number=clamp(a[5],-4096,4096),bo:Number=clamp(a[6],-4096,4096);
         var ao:Number=clamp(preserveAlpha?c.alphaOffset:a[7],-4096,4096);
         if(c.redMultiplier!==r || c.greenMultiplier!==g || c.blueMultiplier!==b || c.alphaMultiplier!==alpha
            || c.redOffset!==ro || c.greenOffset!==go || c.blueOffset!==bo || c.alphaOffset!==ao)
            v.transform.colorTransform=new ColorTransform(r,g,b,alpha,ro,go,bo,ao);
      }
      private static function colorOnly(v:DisplayObject,a:Array):void {
         if(a==null || a.length!=8)return;
         // DisplayObject.alpha and ColorTransform.alphaMultiplier are the
         // same channel. An RGB-only enemy update must preserve BOTH alpha
         // terms, including an independently applied native invisibility fade.
         tint(v,a,true);
      }
      private static function filters(v:DisplayObject):Array {
         var out:Array=[];
         for each(var f:Object in v.filters) {
            if(f is GlowFilter)out.push(["g",f.color,f.alpha,f.blurX,f.blurY,f.strength,f.quality,f.inner,f.knockout]);
            else if(f is BlurFilter)out.push(["b",f.blurX,f.blurY,f.quality]);
            else if(f is DropShadowFilter)out.push(["s",f.distance,f.angle,f.color,f.alpha,f.blurX,f.blurY,
               f.strength,f.quality,f.inner,f.knockout,f.hideObject]);
         }
         return out;
      }
      private static function paintFilters(v:DisplayObject,source:Array):void {
         if(source==null || equal(filters(v),source))return;
         var out:Array=[];
         // Preserve filters outside the three native UnitPlayer families.
         for each(var existing:Object in v.filters)
            if(!(existing is GlowFilter) && !(existing is BlurFilter) && !(existing is DropShadowFilter))out.push(existing);
         for each(var a:* in source.slice(0,8)) {
            if(!(a is Array))continue;
            if(a[0]=="g" && a.length==9)out.push(new GlowFilter(uint(a[1])&0xffffff,clamp(a[2],0,1),
               clamp(a[3],0,255),clamp(a[4],0,255),clamp(a[5],0,255),int(clamp(a[6],1,3,1)),a[7]===true,a[8]===true));
            else if(a[0]=="b" && a.length==4)out.push(new BlurFilter(clamp(a[1],0,255),clamp(a[2],0,255),int(clamp(a[3],1,3,1))));
            else if(a[0]=="s" && a.length==12)out.push(new DropShadowFilter(clamp(a[1],-4096,4096),clamp(a[2],-360,360),
               uint(a[3])&0xffffff,clamp(a[4],0,1),clamp(a[5],0,255),clamp(a[6],0,255),clamp(a[7],0,255),
               int(clamp(a[8],1,3,1)),a[9]===true,a[10]===true,a[11]===true));
         }
         v.filters=out;
      }

      /** Observe after native animation once per simulation frame. Some authored
       * timelines advance even when isPlaying is false, so also observe frames.
       * In particular the native shield opens and STOPS on frame 20; it is not a loop.
       */
      public function observe(u:Object,stamp:int):void {
         var root:Object=get(u,"vis");if(root==null)return;
         var rec:Object=observed[u];
         if(rec==null || rec.root!==root)rec=observed[u]={root:root,parts:{}};
         for each(var path:String in PARTS) {
            var clip:MovieClip=node(root,path) as MovieClip;if(clip==null)continue;
            var old:Object=rec.parts[path];
            if(old==null || old.clip!==clip)old=rec.parts[path]={clip:clip,frame:clip.currentFrame,label:clip.currentLabel,run:0,at:-1};
            if(int(old.at)==stamp)continue;
            old.run=clip.visible && clip.currentFrame!=int(old.frame) && clip.currentLabel==old.label?int(old.run)+1:0;
            old.at=stamp;old.frame=clip.currentFrame;old.label=clip.currentLabel;
         }
      }
      private static function style(v:DisplayObject):Object {
         return {v:v.visible,a:v.alpha,c:colors(v),f:filters(v),
            x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY};
      }
      private function part(v:DisplayObject,history:Object):Object {
         if(v==null)return null;
         // Hidden children often keep running offscreen. Only their visibility
         // matters until they are shown; a new visible snapshot is complete.
         if(!v.visible)return {v:false};
         var s:Object=style(v),clip:MovieClip=v as MovieClip;
         if(clip!=null) {
            s.frame=clip.currentFrame;
            s.play=clip.isPlaying || (history!=null && history.clip===clip && int(history.run)>=2);
         }
         return s;
      }

      /** Capture actual display results, including removal/normal states.
       * Native player flags such as f_stealth are internal and are not guessed
       * from another character's skills, inventory or local global appearance.
       */
      public function capture(u:Object):Object {
         var root:DisplayObject=get(u,"vis") as DisplayObject;
         if(root==null)return null;
         var isPlayer:Boolean=get(u,"player")===true;
         var s:Object={player:isPlayer,c:colors(root)};
         if(!isPlayer) {
            // Enemy invisibility/alpha, alicorn shield and held-object aura
            // already have dedicated owners. Only Effect.visEff color and the
            // optional inhibitor attachment were missing from that path.
            s.inh=part(node(root,"inh"),null);
            return s;
         }
         s.a=root.alpha;
         var osn:DisplayObject=node(root,"osn");
         if(osn!=null)s.osn=style(osn);
         s.parts={};
         var rec:Object=observed[u];
         for each(var path:String in PARTS)
            s.parts[path]=part(node(root,path),rec==null?null:rec.parts[path]);
         return s;
      }

      private function remember(rec:Object,path:String,v:DisplayObject):Object {
         var old:Object=rec.nodes[path];
         if(old!=null && old.v===v)return old;
         if(old!=null)restore(old);
         old=rec.nodes[path]={v:v,s:style(v),timeline:false,paused:false,running:false,seen:false};
         if(v is MovieClip){old.frame=MovieClip(v).currentFrame;old.play=MovieClip(v).isPlaying;}
         return old;
      }
      private static function applyStyle(v:DisplayObject,s:Object):void {
         v.visible=s.v===true;
         if(s.a!=null)v.alpha=clamp(s.a,0,1,1);
         if(s.c is Array)tint(v,s.c);
         if(s.f is Array)paintFilters(v,s.f);
         if(s.x!=null)v.x=clamp(s.x,-4096,4096);
         if(s.y!=null)v.y=clamp(s.y,-4096,4096);
         if(s.r!=null)v.rotation=clamp(s.r,-360,360);
         if(s.sx!=null)v.scaleX=clamp(s.sx,-32,32,1);
         if(s.sy!=null)v.scaleY=clamp(s.sy,-32,32,1);
      }
      private function presentPart(rec:Object,root:DisplayObject,path:String,s:Object,paused:Boolean):void {
         var v:DisplayObject=node(root,path);if(v==null || s==null)return;
         var state:Object=remember(rec,path,v),wasVisible:Boolean=v.visible;
         applyStyle(v,s);
         var clip:MovieClip=v as MovieClip;if(clip==null || s.frame==null)return;
         state.timeline=true;
         var frame:int=int(clamp(s.frame,1,clip.totalFrames,1));
         var running:Boolean=s.play===true && !paused && s.v===true;
         if(!running) {
            if(clip.currentFrame!=frame)clip.gotoAndStop(frame);
            clip.stop();
         } else if(!state.seen || !state.running || state.paused || !wasVisible
            || clip.currentFrame==1 && frame>1) {
            // Do not restart a 20fps network sample on each 30fps render. Native
            // frame scripts keep their own loop/end; fresh/stopped clips alone
            // need an explicit start at the authoritative frame. Native shield
            // frame 1 has its own stop script, which can run after gotoAndPlay(1).
            // Once the source leaves that initializer, release a stuck receiver.
            clip.gotoAndPlay(frame);
         }
         state.running=running;state.paused=paused;state.seen=true;
      }

      /** Apply AFTER native pose/wing/weapon placement, also at final RENDER.
       * Use the same delayed/settled snapshot as the body (not the latest packet).
       * A packet's style must never execute its gameplay effects on the receiver.
       */
      public function apply(u:Object,s:Object,paused:Boolean=false,nativeGrip:Boolean=false):void {
         // A receiver must never paint over its real, locally controlled pony.
         if(u==null || get(u,"player")===true)return;
         if(s==null){forget(u);return;}
         var root:DisplayObject=get(u,"vis") as DisplayObject;if(root==null)return;
         var rec:Object=applied[u];
         if(rec==null || rec.root!==root) {
            forget(u);rec=applied[u]={root:root,nodes:{}};
         }
         var base:Object=remember(rec,"",root);
         base.colorOnly=s.player!==true;
         // Keep the existing teammate marking while reflecting native stealth.
         // Enemy alpha/invis belongs to GameBridge.unitView and is left alone.
         if(s.player!==true){colorOnly(root,s.c as Array);presentPart(rec,root,"inh",s.inh,paused);return;}
         // Native Q owns the held teammate root until its authenticated release.
         if(!nativeGrip) {
            if(s.c is Array && s.c.length==8) {
               var marked:Array=s.c.concat();
               marked[3]=.75*clamp(s.a,0,1,finite(marked[3],1));
               marked[7]=.75*finite(marked[7]);
               tint(root,marked);
            } else if(s.a!=null)root.alpha=.75*clamp(s.a,0,1,1);
         }
         var osn:DisplayObject=node(root,"osn");
         if(osn!=null && s.osn!=null){remember(rec,"osn",osn);applyStyle(osn,s.osn);}
         for each(var path:String in PARTS)
            presentPart(rec,root,path,s.parts==null?null:s.parts[path],paused);
      }
      private static function restore(rec:Object):void {
         var v:DisplayObject=rec.v;
         if(v==null)return;
         if(rec.colorOnly===true){colorOnly(v,rec.s.c);return;}
         // The root has receiver-owned visibility, transform and masks. Only
         // opacity/color were borrowed from its owner; restore only those.
         if(rec.rootOnly===true){tint(v,rec.s.c);v.alpha=rec.s.a;return;}
         applyStyle(v,rec.s);
         if(rec.timeline && v is MovieClip) {
            if(rec.play)MovieClip(v).gotoAndPlay(rec.frame);else MovieClip(v).gotoAndStop(rec.frame);
         }
      }
      public function forget(u:Object):void {
         var rec:Object=applied[u];
         if(rec!=null)for(var path:String in rec.nodes) {
            rec.nodes[path].rootOnly=path=="";
            restore(rec.nodes[path]);
         }
         delete applied[u];delete observed[u];
      }
      public function reset():void {
         for(var u:Object in applied)forget(u);
         applied=new Dictionary();observed=new Dictionary(true);
      }
   }
}
