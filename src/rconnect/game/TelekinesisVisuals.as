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
            if(get(o,"loc")!==loc || get(o,"in_chain")!=true || get(o,"dead")==true || Number(get(o,"sost"))>=3) {
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
         if(rec.style!=null && equalColors(colors(v.transform.colorTransform),rec.style.ct))v.transform.colorTransform=rec.ct;
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
