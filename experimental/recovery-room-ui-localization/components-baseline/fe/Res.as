package fe {
   /** Native resource boundary fixture, linked in this application's domain. */
   public class Res {
      public static var value:String="正在加载…";
      public static var calls:int=0;
      public static var unavailable:Boolean=false;
      public static function guiText(key:String):String {
         calls++;
         if(key!="loading")throw new Error("Unexpected resource key: "+key);
         if(unavailable)throw new Error("Fixture resource unavailable");
         return value;
      }
   }
}
