package rconnect.game {
   import flash.display.DisplayObject;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;

   /** Native glow parameters only. Never enables remote telekinetic physics. */
   public class TelekinesisVisuals {
      private var weapons:Dictionary=new Dictionary();
      private var objects:Dictionary=new Dictionary();
      private var held:Object={};
      private var active:Dictionary=new Dictionary();

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function glows(v:DisplayObject):Array {
         var out:Array=[];
         if(v!=null)for each(var f:Object in v.filters)if(f is GlowFilter)
            out.push([f.color,f.alpha,f.blurX,f.blurY,f.strength,f.quality,f.inner,f.knockout]);
         return out;
      }
      public static function captureWeapon(w:Object):Object {
         var v:DisplayObject=get(w,"vis") as DisplayObject,kor:DisplayObject=get(v,"kor") as DisplayObject;
         return {kor:kor!=null,glow:glows(kor || v)};
      }
      public static function captureObject(o:Object):Object {
         // fracLevit survives release in native objects. It is not a glow flag.
         if(Number(get(o,"levit"))<=0)return null;
         var v:DisplayObject=get(o,"vis") as DisplayObject,list:Array=glows(v);
         return v==null || list.length==0?null:{glow:list,ct:colors(v.transform.colorTransform)};
      }
      /** A peer grip can decorate the real local player, so accept only the
       * finite native glow/color channels, never arbitrary filters or objects. */
      public static function validated(s:Object):Object {
         if(s==null || !(s.glow is Array) || !(s.ct is Array) || s.ct.length!=8 || s.glow.length>4)return null;
         var list:Array=[],ct:Array=[],i:int;
         for each(var a:* in s.glow) {
            if(!(a is Array) || a.length!=8)return null;
            for(i=0;i<6;i++)if(!isFinite(Number(a[i])))return null;
            list.push([uint(a[0])&0xffffff,Math.max(0,Math.min(1,Number(a[1]))),
               Math.max(0,Math.min(64,Number(a[2]))),Math.max(0,Math.min(64,Number(a[3]))),
               Math.max(0,Math.min(16,Number(a[4]))),Math.max(1,Math.min(3,int(a[5]))),a[6]===true,a[7]===true]);
         }
         for(i=0;i<8;i++) {
            if(!isFinite(Number(s.ct[i])))return null;
            ct.push(i<4?Math.max(0,Math.min(4,Number(s.ct[i]))):Math.max(-255,Math.min(255,Number(s.ct[i]))));
         }
         return {glow:list,ct:ct};
      }
      private static function colors(c:ColorTransform):Array {
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private static function equalColors(a:Array,b:Array):Boolean {
         if(a==null || b==null || a.length!=8 || b.length!=8)return false;
         for(var i:int=0;i<8;i++)if(a[i]!=b[i])return false;return true;
      }
      private static function same(a:Array,b:Array):Boolean {
         if(a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++)for(var j:int=0;j<8;j++)if(a[i][j]!=b[i][j])return false;
         return true;
      }
      private static function paint(v:DisplayObject,list:Array):void {
         if(v==null || same(glows(v),list))return;
         var filters:Array=[];
         for each(var f:Object in v.filters)if(!(f is GlowFilter))filters.push(f);
         for each(var s:Array in list)filters.push(new GlowFilter(uint(s[0]),Number(s[1]),Number(s[2]),Number(s[3]),Number(s[4]),int(s[5]),s[6]===true,s[7]===true));
         v.filters=filters;
      }
      public function weapon(w:Object,s:Object):void {
         if(w==null || s==null)return;
         var root:DisplayObject=get(w,"vis") as DisplayObject;
         var v:DisplayObject=s.kor===true?(get(root,"kor") as DisplayObject):root;
         if(v==null)return;
         var old:Object=weapons[w];
         if(old==null || old.v!==v) {
            if(old!=null)old.v.filters=old.filters;
            weapons[w]={v:v,filters:v.filters};
         }
         paint(v,s.glow is Array?s.glow:[]);
      }
      public function forgetWeapon(w:Object):void {
         var rec:Object=weapons[w];if(rec!=null){rec.v.filters=rec.filters;delete weapons[w];}
      }
      public function object(o:Object,s:Object):void {
         if(o==null)return;
         if(s==null)delete objects[o];else objects[o]=s;
      }
      public function hold(id:String,o:Object,s:Object):void {
         if(o==null || s==null)delete held[id];else held[id]={o:o,s:s};
      }
      /** Resolve the native owner first. A locally grabbed object keeps the
       * game's own filters/physics, even while an older remote packet arrives. */
      public function tick(loc:Object,localHeld:Object,authority:Boolean,remoteOwner:Function=null):void {
         var desired:Dictionary=new Dictionary(),o:Object,s:Object,rec:Object;
         for(o in objects)desired[o]=objects[o];
         for each(rec in held)desired[rec.o]=rec.s;
         for(o in active) {
            // Native Q/NPC takeover can replace the visual before the next
            // packet removes the previous holder. Its style is already native.
            if(nativeOwns(o,localHeld,authority,remoteOwner))delete active[o];
            else if(desired[o]==null)release(o);
         }
         for(o in desired) {
            // The actual UnitPlayer is stepped through Location.gg and is not
            // in Location.firstObj. A consenting grabbed player is still live.
            var localPlayer:Boolean=get(loc,"gg")===o && get(o,"player")===true;
            if(get(o,"loc")!==loc || (!localPlayer && get(o,"in_chain")!=true) || get(o,"dead")==true || Number(get(o,"sost"))>=3) {
               release(o);delete objects[o];continue;
            }
            if(nativeOwns(o,localHeld,authority,remoteOwner)) {
               // Native grab has already replaced the visual. Do not restore
               // the old remote style over the new local owner.
               delete active[o];continue;
            }
            var v:DisplayObject=get(o,"vis") as DisplayObject;if(v==null)continue;
            rec=active[o];
            if(rec==null || rec.v!==v) {
               release(o);rec=active[o]={v:v,filters:v.filters,ct:v.transform.colorTransform,style:null};
            }
            s=desired[o];paint(v,s.glow is Array?s.glow:[]);
            if(s.ct is Array && s.ct.length==8 && !equalColors(colors(v.transform.colorTransform),s.ct))
               v.transform.colorTransform=new ColorTransform(s.ct[0],s.ct[1],s.ct[2],s.ct[3],s.ct[4],s.ct[5],s.ct[6],s.ct[7]);
            rec.style=s;
         }
      }
      private static function nativeOwns(o:Object,localHeld:Object,authority:Boolean,remoteOwner:Function):Boolean {
         return o===localHeld || (authority && Number(get(o,"levit"))>0 && (remoteOwner==null || !remoteOwner(o)));
      }
      private function release(o:Object):void {
         var rec:Object=active[o];if(rec==null)return;
         var v:DisplayObject=rec.v;
         // Native code or another local effect may have replaced these fields.
         // Restore only the values still owned by this presentation overlay.
         if(rec.style!=null && same(glows(v),rec.style.glow)) {
            var filters:Array=[];
            for each(var f:Object in v.filters)if(!(f is GlowFilter))filters.push(f);
            for each(f in rec.filters)if(f is GlowFilter)filters.push(f);
            v.filters=filters;
         }
         if(rec.style!=null && rec.style.ct is Array && rec.style.ct.length==8) {
            // DisplayObject.alpha aliases ColorTransform.alphaMultiplier.
            // Native stealth/visibility may change only that channel between
            // our last paint and release. RGB ownership must remain separate;
            // likewise a newer native tint must not keep our old opacity.
            var current:ColorTransform=v.transform.colorTransform,original:ColorTransform=rec.ct;
            var applied:Array=rec.style.ct;
            var ownRGB:Boolean=current.redMultiplier==applied[0] && current.greenMultiplier==applied[1]
               && current.blueMultiplier==applied[2] && current.redOffset==applied[4]
               && current.greenOffset==applied[5] && current.blueOffset==applied[6];
            var ownAlpha:Boolean=current.alphaMultiplier==applied[3] && current.alphaOffset==applied[7];
            if(ownRGB) {
               current.redMultiplier=original.redMultiplier;current.greenMultiplier=original.greenMultiplier;
               current.blueMultiplier=original.blueMultiplier;current.redOffset=original.redOffset;
               current.greenOffset=original.greenOffset;current.blueOffset=original.blueOffset;
            }
            if(ownAlpha){current.alphaMultiplier=original.alphaMultiplier;current.alphaOffset=original.alphaOffset;}
            if(ownRGB || ownAlpha)v.transform.colorTransform=current;
         }
         delete active[o];
      }
      public function reset():void {
         for each(var rec:Object in weapons)rec.v.filters=rec.filters;
         for(var o:Object in active)release(o);
         weapons=new Dictionary();
         objects=new Dictionary();held={};active=new Dictionary();
      }
   }
}
