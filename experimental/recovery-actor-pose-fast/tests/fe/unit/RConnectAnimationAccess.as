package fe.unit {
   import fixture.Trace;
   public final class RConnectAnimationAccess {
      public static function observe(u:Unit):void {throw new Error("source observe outside pose fixture");}
      public static function receive(u:Unit,p:Object,a:String,o:Object,b:Boolean,c:Boolean):void {Trace.note("receive-body",a,b,c);}
      public static function effects(u:Unit):void {Trace.note("body-effects");}
      public static function tick(u:Unit,p:Object,b:Boolean):Boolean {throw new Error("body tick outside pose fixture");}
      public static function reset():void {}
   }
}
