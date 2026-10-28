package authority {
   import flash.utils.Dictionary;
   /** Conservative proof that applying B makes every write of A redundant.
    * Inputs are the two original immutable confirmation recipes, never the
    * per-render PoseTween/MovementPrediction copies. Unknown topology falls back. */
   public final class PredictionPoseCover {
      private static var pairs:Dictionary=new Dictionary(true);
      public static var lookups:uint=0,hits:uint=0,checks:uint=0,passed:uint=0;
      public static var failures:Object={};
      public static function covers(before:Object,after:Object):Boolean {
         ++lookups;
         if(before===after || before==null){++passed;return true;}
         if(after==null)return fail("missing-pose");
         var targets:Dictionary=pairs[before],cached:*=targets==null?undefined:targets[after];
         if(cached!==undefined){++hits;if(cached===true)++passed;return cached===true;}
         ++checks;
         var ok:Boolean=inspect(before,after);
         if(targets==null){targets=new Dictionary(true);pairs[before]=targets;}
         targets[after]=ok;
         if(ok)++passed;return ok;
      }
      private static function fail(reason:String):Boolean {failures[reason]=uint(failures[reason])+1;return false;}
      private static function inspect(before:Object,after:Object):Boolean {
         // VisualPose.apply has conditional writes. A hidden child recipe may
         // omit its subtree; a missing vector/pixel/text recipe does not erase
         // the previous drawing. None of these old writes may be skipped.
         for each(var field:String in ["pixels","vector","f","blend","cache","smoothing","text","plainText","multiline","scrollH","scrollV","c"])
            if(before[field]!=null && after[field]==null)return fail("missing-"+field);
         if(before.children===after.children || before.children==null)return true;
         if(after.children==null)return fail("hidden-subtree");
         var a:Array=before.children,b:Array=after.children;
         // Authored children are not all owned by VisualPose's cleanup map.
         // Require the same identities/topology instead of assuming an omitted
         // native limb would be destroyed by the later frame's gotoAndStop.
         if(a.length!=b.length)return fail("child-count");
         for(var i:int=0;i<a.length;i++) {
            var old:Object=a[i],next:Object=b[i];
            if(old===next)continue;
            if(old==null || next==null || old.n!==next.n || old.i!==next.i || old.cls!==next.cls)return fail("child-identity");
            if(!covers(old.s,next.s))return false;
         }
         return true;
      }
   }
}
