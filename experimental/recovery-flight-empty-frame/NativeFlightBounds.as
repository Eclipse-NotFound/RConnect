package {
   /** External fixture only. Empty animation frames stay in all motion/tail
    * metrics; only their viewport interpretation needs native source proof. */
   public final class NativeFlightBounds {
      private static function number(o:Object,key:String):Boolean {
         return o!=null && o.hasOwnProperty(key) && typeof o[key]=="number" && isFinite(Number(o[key]));
      }
      private static function validScreen(s:Object):Boolean {
         return number(s,"x") && number(s,"y") && number(s,"w") && number(s,"h") && s.w>=0 && s.h>=0;
      }
      public static function empty(s:Object):Boolean {
         return validScreen(s) && (s.w===0 || s.h===0);
      }
      private static function validPoint(p:Object):Boolean {
         if(!number(p,"x") || !number(p,"y") || !number(p,"f") || p.f<1 || int(p.f)!=p.f
            || !validScreen(p.screen) || typeof p.viewport!="boolean")return false;
         var e:Boolean=empty(p.screen);
         if(e && p.viewport)return false;
         if(p.hasOwnProperty("emptyBounds") && (typeof p.emptyBounds!="boolean" || p.emptyBounds!==e))return false;
         if(p.hasOwnProperty("outsideViewport") && (typeof p.outsideViewport!="boolean" || p.outsideViewport!==(!e && !p.viewport)))return false;
         return true;
      }
      private static function sameEmpty(a:Object,b:Object):Boolean {
         if(!validPoint(b) || !empty(b.screen) || a.f!==b.f || a.x!==b.x || a.y!==b.y)return false;
         for each(var key:String in ["x","y","w","h"])if(a.screen[key]!==b.screen[key])return false;
         return true;
      }
      public static function evaluate(source:Array,remote:Array):Object {
         var out:Object={emptySamples:0,matchedNativeEmpty:0,unprovenNativeEmpty:0,outsideViewport:0,invalidBounds:0,proofs:[]};
         for(var i:int=0;i<remote.length;i++) {
            var row:Object=remote[i];
            for(var j:int=0;j<row.clips.length;j++) {
               var p:Object=row.clips[j];
               if(!validPoint(p)){out.invalidBounds++;continue;}
               if(!empty(p.screen)) {if(!p.viewport)out.outsideViewport++;continue;}
               out.emptySamples++;
               var proof:Object=null;
               for(var k:int=0;k<source.length && proof==null;k++) {
                  var nativeRow:Object=source[k];
                  // Only the source's actual Bullet RENDER records qualify.
                  // A wire sample, copied remote record or inferred endpoint does not.
                  if(!number(nativeRow.native,"x") || !number(nativeRow.native,"y") || typeof nativeRow.native.ended!="boolean")continue;
                  for(var n:int=0;n<nativeRow.clips.length;n++)if(sameEmpty(p,nativeRow.clips[n])) {
                     proof={remoteRow:i,remoteClip:j,sourceRow:k,sourceClip:n,f:p.f,x:p.x,y:p.y,
                        remoteFrame:row.frame,sourceFrame:nativeRow.frame,
                        screen:{x:p.screen.x,y:p.screen.y,w:p.screen.w,h:p.screen.h}};break;
                  }
               }
               if(proof==null)out.unprovenNativeEmpty++;
               else {out.matchedNativeEmpty++;out.proofs.push(proof);}
            }
         }
         out.passed=out.outsideViewport==0 && out.unprovenNativeEmpty==0 && out.invalidBounds==0;
         return out;
      }
   }
}
