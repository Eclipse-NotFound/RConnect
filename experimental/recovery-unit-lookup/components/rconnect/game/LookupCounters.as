package rconnect.game {
   public class LookupCounters {
      public static var before:int=0,after:int=0;
      public static function reset():void {before=0;after=0;}
      public static function indexOf(list:Array,value:Object,side:String):int {
         if(side=="before")before++;else after++;
         return list.indexOf(value); // actual native Array.indexOf, not a modeled result
      }
   }
}
