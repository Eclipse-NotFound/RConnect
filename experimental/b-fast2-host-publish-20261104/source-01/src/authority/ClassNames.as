package authority {
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** A display object's concrete class never changes, so one reflection per
    * object is enough for the whole session. Weak keys keep no strong reference
    * to a display object that native code has already discarded.
    *
    * This is only a cache of a pure function on object identity: it cannot make
    * two different objects share a name, and it never substitutes a different
    * value for an object whose class differs. */
   public final class ClassNames {
      private static var cache:Dictionary=new Dictionary(true);
      public static function of(value:Object):String {
         if(value==null)return "";
         var name:String=cache[value];
         if(name==null){name=getQualifiedClassName(value);cache[value]=name;}
         return name;
      }
   }
}
