package authority {
   import flash.utils.getQualifiedClassName;
   /** Native saves use associative Arrays. JSON.stringify(Array) loses those
    * named entries, so copy every enumerable key into an explicit map. */
   public class PlainData {
      public static function copy(value:*):* {return visit(value,0,{n:0});}
      /** Native loadGame requires its original associative Array types. */
      public static function nativeCopy(value:*):* {return visit(value,0,{n:0},true);}
      private static function visit(value:*,depth:int,budget:Object,preserveArrays:Boolean=false):* {
         if(depth>20 || ++budget.n>24000)throw new Error("Profile exceeds data budget");
         if(value==null || value is String || value is Boolean)return value;
         if(value is Number){if(!isFinite(Number(value)))throw new Error("Nonfinite profile value");return value;}
         var type:String=getQualifiedClassName(value);
         if(type!="Object" && type!="Array")throw new Error("Profile contains runtime object: "+type);
         var result:Object=preserveArrays && value is Array?new Array(value.length):{};
         for(var key:String in value) {
            if(key=="__proto__" || key=="constructor" || key=="prototype")throw new Error("Invalid data key");
            result[key]=visit(value[key],depth+1,budget,preserveArrays);
         }
         return result;
      }
   }
}
