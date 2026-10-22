package rconnect.net {
   public class Protocol {
      public static const MSG_WORLDSTATE:String="worldstate";
      public static function make(type:String,data:Object):Object{data.type=type;return data;}
   }
}
