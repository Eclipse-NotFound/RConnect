package rconnect.core {
   /** Only the disk boundary is replaced; both real codec implementations run. */
   public class Log {
      public static var count:int=0;
      public static var last:String="";
      public static function d(message:String):void {count++;last=message;}
   }
}
