package fe.unit {
   public class RConnectAnimationAccess {
      public static function observe(u:Unit):void {}
      public static function receive(u:Unit,p:Object,a:String,o:Object,b:Boolean,c:Boolean):void {throw new Error("body replay outside capture fixture");}
      public static function effects(u:Unit):void {throw new Error("body replay outside capture fixture");}
      public static function tick(u:Unit,p:Object,b:Boolean):Boolean {throw new Error("body replay outside capture fixture");}
      public static function reset():void {}
   }
}
