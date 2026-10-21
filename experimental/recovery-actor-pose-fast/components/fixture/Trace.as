package fixture {
   public final class Trace {
      public static var rows:Array=[];
      public static function reset():void {rows=[];Clock.calls=0;}
      public static function note(...args):void {rows.push(args);}
   }
}
