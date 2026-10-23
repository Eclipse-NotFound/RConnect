package rconnect.core {
   public class Log {
      public static var errors:Array=[];
      public static function d(s:String):void {
         if(s.indexOf("RConnectRoom: ERROR")>=0 || s.indexOf("handoff timed out")>=0)errors.push(s);
         trace(s);
      }
   }
}
